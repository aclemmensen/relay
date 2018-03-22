defmodule Relay.Resources.LDS do
  alias Relay.{ProtobufUtil, Resources.CertInfo}
  import Relay.Resources.Common

  alias Envoy.Api.V2.Core.Address
  alias Envoy.Api.V2.Listener
  alias Listener.{Filter, FilterChain}
  alias Envoy.Config.Filter.Accesslog.V2.{AccessLog, FileAccessLog}
  alias Envoy.Config.Filter.Http.Router.V2.Router

  alias Envoy.Config.Filter.Network.HttpConnectionManager.V2.{
    HttpConnectionManager,
    HttpFilter,
    Rds
  }

  @spec listeners([CertInfo.t()]) :: [Listener.t()]
  def listeners(cert_infos) do
    https_filter_chains = Enum.map(cert_infos, &https_filter_chain/1)

    [
      listener(:http, [filter_chain(:http)]),
      listener(:https, https_filter_chains)
    ]
  end

  defp https_filter_chain(cert_info) do
    alias Envoy.Api.V2.Auth

    tls_context =
      Auth.DownstreamTlsContext.new(
        common_tls_context:
          Auth.CommonTlsContext.new(
            alpn_protocols: ["h2,http/1.1"],
            tls_certificates: [
              Auth.TlsCertificate.new(
                certificate_chain: inline_string(cert_info.cert_chain),
                private_key: inline_string(cert_info.key)
              )
            ]
          )
      )

    filter_chain(:https, {tls_context, cert_info.domains})
  end

  defp inline_string(text),
    do: Envoy.Api.V2.Core.DataSource.new(specifier: {:inline_string, text})

  defp filter_chain(listener, {tls_context, sni_domains} \\ {nil, []}) do
    alias Envoy.Api.V2.Listener.{FilterChain, FilterChainMatch}

    FilterChain.new(
      filter_chain_match: FilterChainMatch.new(sni_domains: sni_domains),
      filters: [http_connection_manager_filter(listener)],
      tls_context: tls_context
    )
  end

  @spec listener(atom, [FilterChain.t()], keyword) :: Listener.t()
  def listener(listener, filter_chains, options \\ []) do
    Listener.new(
      [
        name: Atom.to_string(listener) |> truncate_obj_name(),
        address: listener_address(listener),
        filter_chains: filter_chains
      ] ++ options
    )
  end

  @spec listener_config(atom) :: keyword
  defp listener_config(listener), do: fetch_envoy_config!(:listeners) |> Keyword.fetch!(listener)

  defp get_listener_config(listener, key, default),
    do: listener_config(listener) |> Keyword.get(key, default)

  defp fetch_listener_config!(listener, key), do: listener_config(listener) |> Keyword.fetch!(key)

  @spec listener_address(atom) :: Address.t()
  defp listener_address(listener) do
    listen = fetch_listener_config!(listener, :listen)
    socket_address(Keyword.fetch!(listen, :address), Keyword.fetch!(listen, :port))
  end

  @spec http_connection_manager_filter(atom) :: Filter.t()
  def http_connection_manager_filter(listener, options \\ []) do
    Filter.new(
      name: "envoy.http_connection_manager",
      config: ProtobufUtil.mkstruct(http_connection_manager(listener, options))
    )
  end

  @spec http_connection_manager(atom, keyword) :: HttpConnectionManager.t()
  defp http_connection_manager(listener, options) do
    config = fetch_listener_config!(listener, :http_connection_manager)

    default_name = Atom.to_string(listener)
    route_config_name = get_listener_config(listener, :route_config_name, default_name)
    stat_prefix = Keyword.get(config, :stat_prefix, default_name)

    access_log = Keyword.get(config, :access_log) |> access_logs_from_config()

    {options, router_opts} = Keyword.pop(options, :router_opts, [])

    HttpConnectionManager.new(
      [
        codec_type: HttpConnectionManager.CodecType.value(:AUTO),
        route_specifier:
          {:rds,
           Rds.new(config_source: api_config_source(), route_config_name: route_config_name)},
        stat_prefix: stat_prefix,
        access_log: access_log,
        http_filters: [router_http_filter(listener, router_opts)]
      ] ++ options
    )
  end

  @spec router_http_filter(atom, keyword) :: HttpFilter.t()
  defp router_http_filter(listener, options) do
    HttpFilter.new(
      name: "envoy.router",
      config: ProtobufUtil.mkstruct(router(listener, options))
    )
  end

  @spec router(atom, keyword) :: Router.t()
  defp router(listener, options) do
    config = fetch_listener_config!(listener, :router)
    upstream_log = Keyword.get(config, :upstream_log) |> access_logs_from_config()

    Router.new([upstream_log: upstream_log] ++ options)
  end

  @spec access_logs_from_config(keyword) :: [AccessLog.t()]
  defp access_logs_from_config(config) do
    # Don't configure log file if path is empty
    # TODO: Test this properly
    case Keyword.get(config, :path, "") do
      "" -> []
      path -> [file_access_log(path, Keyword.get(config, :format))]
    end
  end

  @spec file_access_log(String.t(), String.t(), keyword) :: AccessLog.t()
  def file_access_log(path, format, options \\ []) do
    # TODO: Make it easier to configure filters (currently the only extra
    # AccessLog option).
    AccessLog.new(
      [
        name: "envoy.file_access_log",
        config: ProtobufUtil.mkstruct(FileAccessLog.new(path: path, format: format))
      ] ++ options
    )
  end
end
