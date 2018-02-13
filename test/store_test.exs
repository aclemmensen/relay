defmodule Relay.StoreTest.Macros do
  defmacro xds_tests(name_suffix, assertion) do
    [:lds, :rds, :cds, :eds]
    |> Enum.map(fn(xds) ->
      quote do
        test "#{unquote(xds)} #{unquote(name_suffix)}", %{store: store},
          do: unquote(assertion).(store, unquote(xds))
      end
    end)
  end
end

defmodule Relay.StoreTest do
  use ExUnit.Case, async: true

  alias Relay.Store
  alias Store.Resources
  alias Envoy.Api.V2.{Cluster, ClusterLoadAssignment, Listener, RouteConfiguration}

  import Relay.StoreTest.Macros

  setup do
    {:ok, store} = start_supervised(Store)
    %{store: store}
  end

  def get_resources(store, xds) do
    {:ok, resources} = GenServer.call(store, {:_get_resources, xds})
    resources
  end

  defp subscribe(store, xds, pid), do:
    apply(Store, :"subscribe_#{xds}", [store, pid])

  defp unsubscribe(store, xds, pid), do:
    apply(Store, :"unsubscribe_#{xds}", [store, pid])

  defp update(store, xds, version_info, resources), do:
    apply(Store, :"update_#{xds}", [store, version_info, resources])

  xds_tests "subscribe idempotent", fn(store, xds) ->
    assert get_resources(store, xds) == %Resources{subscribers: MapSet.new()}
    assert subscribe(store, xds, self()) == {:ok, "", []}
    assert get_resources(store, xds) == %Resources{subscribers: MapSet.new([self()])}
    assert subscribe(store, xds, self()) == {:ok, "", []}
    assert get_resources(store, xds) == %Resources{subscribers: MapSet.new([self()])}
  end

  xds_tests "unsubscribe idempotent", fn(store, xds) ->
    assert subscribe(store, xds, self()) == {:ok, "", []}
    assert get_resources(store, xds) == %Resources{subscribers: MapSet.new([self()])}
    assert unsubscribe(store, xds, self()) == :ok
    assert get_resources(store, xds) == %Resources{subscribers: MapSet.new()}
    assert unsubscribe(store, xds, self()) == :ok
    assert get_resources(store, xds) == %Resources{subscribers: MapSet.new()}
  end

  xds_tests "subscribers receive updates", fn(store, xds) ->
    assert subscribe(store, xds, self()) == {:ok, "", []}

    resources = [:foo, :bar]
    assert update(store, xds, "1", resources) == :ok

    assert_receive {^xds, "1", ^resources}, 1_000
  end

  xds_tests "old updates ignored", fn(store, xds) ->
    resources = [:foobar, :baz]
    assert update(store, xds, "2", resources) == :ok

    assert subscribe(store, xds, self()) == {:ok, "2", resources}

    old_resources = [:foo, :bar]
    assert update(store, xds, "1", old_resources) == :ok

    # Assert the stored resources haven't changed
    assert %Resources{version_info: "2", resources: ^resources} = get_resources(store, xds)
    # Assert we don't receive any updates for this xds
    refute_received {^xds, _, _}
  end

  # TODO: break out these tests into smaller tests
  test "lds basics", %{store: store} do
    # We can store something
    resources = [Listener.new(name: "test")]
    assert Store.update_lds(store, "1", resources) == :ok

    # When we subscribe we receive the existing state
    assert Store.subscribe_lds(store, self()) == {:ok, "1", resources}

    # We can update again
    resources2 = [Listener.new(name: "test2")]
    assert Store.update_lds(store, "2", resources2) == :ok

    # ...and we receive the notification
    assert_receive {:lds, "2", ^resources2}, 1_000

    # ...if we try update with older resources
    assert Store.update_lds(store, "1", resources) == :ok
    # we receive no message and the state is unchanged
    assert %Resources{version_info: "2", resources: ^resources2} = get_resources(store, :lds)

    # We can unsubscribe
    assert Store.unsubscribe_lds(store, self()) == :ok

    # ...and we're no longer subscribed
    %Resources{subscribers: subscribers} = get_resources(store, :lds)
    assert subscribers == MapSet.new()
  end

  test "rds basics", %{store: store} do
    # We can store something
    resources = [RouteConfiguration.new(name: "test")]
    assert Store.update_rds(store, "1", resources) == :ok

    # When we subscribe we receive the existing state
    assert Store.subscribe_rds(store, self()) == {:ok, "1", resources}

    # We can update again
    resources2 = [RouteConfiguration.new(name: "test2")]
    assert Store.update_rds(store, "2", resources2) == :ok

    # ...and we receive the notification
    assert_receive {:rds, "2", ^resources2}, 1_000

    # ...if we try update with older resources
    assert Store.update_rds(store, "1", resources) == :ok
    # we receive no message and the state is unchanged
    assert %Resources{version_info: "2", resources: ^resources2} = get_resources(store, :rds)

    # We can unsubscribe
    assert Store.unsubscribe_rds(store, self()) == :ok

    # ...and we're no longer subscribed
    %Resources{subscribers: subscribers} = get_resources(store, :rds)
    assert subscribers == MapSet.new()
  end

  test "cds basics", %{store: store} do
    # We can store something
    resources = [Cluster.new(name: "test")]
    assert Store.update_cds(store, "1", resources) == :ok

    # When we subscribe we receive the existing state
    assert Store.subscribe_cds(store, self()) == {:ok, "1", resources}

    # We can update again
    resources2 = [Cluster.new(name: "test2")]
    assert Store.update_cds(store, "2", resources2) == :ok

    # ...and we receive the notification
    assert_receive {:cds, "2", ^resources2}, 1_000

    # ...if we try update with older resources
    assert Store.update_cds(store, "1", resources) == :ok
    # we receive no message and the state is unchanged
    assert %Resources{version_info: "2", resources: ^resources2} = get_resources(store, :cds)

    # We can unsubscribe
    assert Store.unsubscribe_cds(store, self()) == :ok

    # ...and we're no longer subscribed
    %Resources{subscribers: subscribers} = get_resources(store, :cds)
    assert subscribers == MapSet.new()
  end

  test "eds basics", %{store: store} do
    # We can store something
    resources = [ClusterLoadAssignment.new(name: "test")]
    assert Store.update_eds(store, "1", resources) == :ok

    # When we subscribe we receive the existing state
    assert Store.subscribe_eds(store, self()) == {:ok, "1", resources}

    # We can update again
    resources2 = [ClusterLoadAssignment.new(name: "test2")]
    assert Store.update_eds(store, "2", resources2) == :ok

    # ...and we receive the notification
    assert_receive {:eds, "2", ^resources2}, 1_000

    # ...if we try update with older resources
    assert Store.update_eds(store, "1", resources) == :ok
    # we receive no message and the state is unchanged
    assert %Resources{version_info: "2", resources: ^resources2} = get_resources(store, :eds)

    # We can unsubscribe
    assert Store.unsubscribe_eds(store, self()) == :ok

    # ...and we're no longer subscribed
    %Resources{subscribers: subscribers} = get_resources(store, :eds)
    assert subscribers == MapSet.new()
  end
end
