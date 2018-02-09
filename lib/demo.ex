defmodule Relay.Demo do
  alias Envoy.Api.V2.DiscoveryResponse
  alias Envoy.Api.V2.Core.{Http1ProtocolOptions}
  alias Google.Protobuf.{Any, Duration}

  @cds_type "type.googleapis.com/envoy.api.v2.Cluster"
  @lds_type "type.googleapis.com/envoy.api.v2.Listener"

  defp typed_resource(type, res) do
    value = GRPC.Message.Protobuf.encode(Any, res)
    Any.new(type_url: type, value: value)
  end

  defp typed_resources(type, resources) do
    resources |> Enum.map(&typed_resource(type, &1))
  end

  defp socket_address(address, port) do
    alias Envoy.Api.V2.Core.{Address, SocketAddress}
    sock = SocketAddress.new(address: address, port_specifier: {:port_value, port})
    Address.new(address: {:socket_address, sock})
  end

  def clusters do
    alias Envoy.Api.V2.Cluster

    resources = [
      Cluster.new(
        name: "demo",
        type: Cluster.DiscoveryType.value(:STATIC),
        hosts: [socket_address("127.0.0.1", 8081)],
        connect_timeout: Duration.new(seconds: 30),
        lb_policy: Cluster.LbPolicy.value(:ROUND_ROBIN),
        health_checks: [],
        http_protocol_options: Http1ProtocolOptions.new()
      )
    ]
    DiscoveryResponse.new(
      version_info: "1",
      resources: typed_resources(@cds_type, resources),
      type_url: @cds_type
    )
  end

  defp route_config do
    alias Envoy.Api.V2.RouteConfiguration
    alias Envoy.Api.V2.Route.{Route, RouteAction, RouteMatch, VirtualHost}
    RouteConfiguration.new(
      name: "demo",
      virtual_hosts: [
        VirtualHost.new(
          name: "demo",
          domains: ["example.com"],
          routes: [
            Route.new(
              match: RouteMatch.new(path_specifier: {:prefix, "/"}),
              action: {:route, RouteAction.new(cluster_specifier: {:cluster, "demo"})})
          ])
      ])
  end

  defp router_filter do
    alias Envoy.Config.Filter.Network.HttpConnectionManager.V2.HttpFilter
    alias Envoy.Config.Filter.Http.Router.V2.Router
    alias Envoy.Config.Filter.Accesslog.V2.{AccessLog, FileAccessLog}
    import Relay.ProtobufUtil
    HttpFilter.new(
      name: "envoy.router",
      config: mkstruct(Router.new(upstream_log: [
        AccessLog.new(
          name: "envoy.file_access_log",
          config: mkstruct(FileAccessLog.new(path: "upstream.log")))
      ]))
    )
  end

  defp default_http_conn_manager_filter(name) do
    alias Envoy.Api.V2.Listener.Filter
    alias Envoy.Config.Filter.Network.HttpConnectionManager.V2.HttpConnectionManager
    import Relay.ProtobufUtil
    Filter.new(
      name: "envoy.http_connection_manager",
      config: mkstruct(HttpConnectionManager.new(
        codec_type: HttpConnectionManager.CodecType.value(:AUTO),
        route_specifier: {:route_config, route_config()},
        stat_prefix: name,
        http_filters: [router_filter()]))
      )
  end

  def listeners do
    alias Envoy.Api.V2.Listener

    resources = [
      Listener.new(
        name: "http",
        address: socket_address("0.0.0.0", 8080),
        filter_chains: [
          Listener.FilterChain.new(
            filter_chain_match: Listener.FilterChainMatch.new(),
            filters: [default_http_conn_manager_filter("http")]
          ),
        ]
      )
    ]

    DiscoveryResponse.new(
      version_info: "1",
      resources: typed_resources(@lds_type, resources),
      type_url: @lds_type
    )
  end
end