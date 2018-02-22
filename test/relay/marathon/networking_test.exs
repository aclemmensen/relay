defmodule Relay.Marathon.NetworkingTest do
  use ExUnit.Case, async: true

  alias Relay.Marathon.Networking

  @test_app %{
    "id" => "/foovu1",
    "cmd" => "python -m http.server 8080",
    "args" => None,
    "user" => None,
    "env" => %{},
    "instances" => 1,
    "cpus" => 0.1,
    "mem" => 32,
    "disk" => 0,
    "gpus" => 0,
    "executor" => "",
    "constraints" => [],
    "uris" => [],
    "fetch" => [],
    "storeUrls" => [],
    "backoffSeconds" => 1,
    "backoffFactor" => 1.15,
    "maxLaunchDelaySeconds" => 3600,
    "container" => None,
    "healthChecks" => [],
    "readinessChecks" => [],
    "dependencies" => [],
    "upgradeStrategy" => %{
      "minimumHealthCapacity" => 1,
      "maximumOverCapacity" => 1,
    },
    "labels" => %{},
    "ipAddress" => None,
    "version" => "2017-05-22T08:53:15.476Z",
    "residency" => None,
    "secrets" => %{},
    "taskKillGracePeriodSeconds" => None,
    "unreachableStrategy" => %{
      "inactiveAfterSeconds" => 300,
      "expungeAfterSeconds" => 600,
    },
    "killSelection" => "YOUNGEST_FIRST",
    "versionInfo" => %{
      "lastScalingAt" => "2017-05-22T08:53:15.476Z",
      "lastConfigChangeAt" => "2017-05-22T08:53:15.476Z",
    },
    "tasksStaged" => 0,
    "tasksRunning" => 1,
    "tasksHealthy" => 0,
    "tasksUnhealthy" => 0,
    "deployments" => [],
  }

  @container_host_networking %{
    "type" => "DOCKER",
    "volumes" => [],
    "docker" => %{
      "image" => "praekeltfoundation/marathon-lb:1.6.0",
      "network" => "HOST",
      "portMappings" => [],
      "privileged" => true,
      "parameters" => [],
      "forcePullImage" => false
    }
  }

  @container_user_networking %{
    "type" => "DOCKER",
    "volumes" => [],
    "docker" => %{
      "image" => "python:3-alpine",
      "network" => "USER",
      "portMappings" => [
        %{
          "containerPort" => 8080,
          "servicePort" => 10004,
          "protocol" => "tcp",
          "name" => "foovu1http",
          "labels" => %{
            "VIP_0" => "/foovu1:8080",
          },
        },
      ],
      "privileged" => false,
      "parameters" => [],
      "forcePullImage" => false,
    },
  }

  @container_bridge_networking %{
    "type" => "DOCKER",
    "volumes" => [],
    "docker" => %{
      "image" => "index.docker.io/jerithorg/testapp:0.0.12",
      "network" => "BRIDGE",
      "portMappings" => [
        %{
          "containerPort" => 5858,
          "hostPort" => 0,
          "servicePort" => 10008,
          "protocol" => "tcp",
          "labels" => %{},
        },
      ],
      "privileged" => false,
      "parameters" => [],
      "forcePullImage" => true,
    },
  }

  # We've never run a container with the Mesos containerizer before. This is from
  # https://mesosphere.github.io/marathon/docs/external-volumes.html
  @container_mesos %{
    "type" => "MESOS",
    "volumes" => [
      %{
        "containerPath" => 'test-rexray-volume',
        "external" => %{
          "size" => 100,
          "name" => 'my-test-vol',
          "provider" => "dvdi",
          "options" => %{"dvdi/driver" => "rexray"},
        },
        "mode" => "RW",
      },
    ],
  }

  # https://github.com/mesosphere/marathon/blob/v1.5.1/docs/docs/networking.md#host-mode
  @networks_container_host_marathon15 [%{"mode" => "host"}]
  @container_mesos_host_networking_marathon15 %{
    "type" => "MESOS",
    "docker" => %{
      "image" => 'my-image:1.0'
    },
  }

  # https://github.com/mesosphere/marathon/blob/v1.5.1/docs/docs/networking.md#specifying-ports-1
  @networks_container_bridge_marathon15 [%{"mode" => "container/bridge"}]
  @container_bridge_networking_marathon15 %{
    "type" => "DOCKER",
    "docker" => %{
      "forcePullImage" => true,
      "image" => 'praekeltfoundation/mc2:release-3.11.2',
      "parameters" => [
        %{
          "key" => 'add-host',
          "value" => 'servicehost:172.17.0.1'
        }
      ],
      "privileged" => false
    },
    "volumes" => [],
    "portMappings" => [
      %{
        "containerPort" => 80,
        "hostPort" => 0,
        "labels" => %{},
        "protocol" => "tcp",
        "servicePort" => 10005
      }
    ]
  }
  @container_mesos_bridge_networking_marathon15 %{
    "type" => "MESOS",
    "docker" => %{
      "image" => 'my-image:1.0'
    },
    "portMappings" => [
      %{"containerPort" => 80, "hostPort" => 0, "name" => "http"},
      %{"containerPort" => 443, "hostPort" => 0, "name" => "https"},
      %{"containerPort" => 4000, "hostPort" => 0, "name" => "mon"}
    ]
  }

  # https://github.com/mesosphere/marathon/blob/v1.5.1/docs/docs/networking.md#enabling-container-mode
  @networks_container_user_marathon15 [%{"mode" => "container", "name" => "dcos"}]
  @container_user_networking_marathon15 %{
    "type" => "DOCKER",
    "docker" => %{
      "forcePullImage" => false,
      "image" => 'python:3-alpine',
      "parameters" => [],
      "privileged" => false
    },
    "volumes" => [],
    "portMappings" => [
      %{
        "containerPort" => 8080,
        "labels" => %{
          "VIP_0" => '/foovu1:8080'
        },
        "name" => "foovu1http",
        "protocol" => "tcp",
        "servicePort" => 10004
      }
    ],
  }

  @ip_address_no_ports %{
    "groups" => [],
    "labels" => %{},
    "discovery" => %{
      "ports" => [],
    },
    "networkName" => "dcos",
  }

  @ip_address_two_ports %{
    "groups" => [],
    "labels" => %{},
    "discovery" => %{
      "ports" => [
        %{"number" => 80, "name" => "http", "protocol" => "tcp"},
        %{"number" => 443, "name" => "http", "protocol" => "tcp"},
      ],
    },
  }

  @port_definitions_one_port [
    %{
      "port" => 10008,
      "protocol" => "tcp",
      "name" => "default",
      "labels" => %{},
    },
  ]

  describe "get_number_of_ports/1" do
    test "host networking Mesos containerizer - Marathon 1.5+" do
      app = @test_app
      |> Map.put("container", @container_mesos_host_networking_marathon15)
      |> Map.put("networks", @networks_container_host_marathon15)
      |> Map.put("portDefinitions", @port_definitions_one_port)

      assert Networking.get_number_of_ports(app) == 1
    end

    test "bridge networking - Marathon 1.5+" do
      app = @test_app
      |> Map.put("container", @container_bridge_networking_marathon15)
      |> Map.put("networks", @networks_container_bridge_marathon15)

      assert Networking.get_number_of_ports(app) == 1
    end

    test "bridge networking Mesos containerizer - Marathon 1.5+" do
      app = @test_app
      |> Map.put("container", @container_mesos_bridge_networking_marathon15)
      |> Map.put("networks", @networks_container_bridge_marathon15)

      assert Networking.get_number_of_ports(app) == 3
    end

    test "user networking - Marathon 1.5+" do
      app = @test_app
      |> Map.put("container", @container_user_networking_marathon15)
      |> Map.put("networks", @networks_container_user_marathon15)

      assert Networking.get_number_of_ports(app) == 1
    end

    test "host networking - Marathon < 1.5" do
      app = @test_app
      |> Map.put("container", @container_host_networking)
      |> Map.put("portDefinitions", @port_definitions_one_port)

      assert Networking.get_number_of_ports(app) == 1
    end

    test "user networking - Marathon < 1.5" do
      app = @test_app
      |> Map.put("container", @container_user_networking)
      |> Map.put("ipAddress", @ip_address_no_ports)

      assert Networking.get_number_of_ports(app) == 1
    end

    test "IP-per-task no container - Marathon < 1.5" do
      app = @test_app
      |> Map.put("ipAddress", @ip_address_two_ports)

      assert Networking.get_number_of_ports(app) == 2
    end

    test "IP-per-task Mesos containerizer - Marathon < 1.5" do
      app = @test_app
      |> Map.put("container", @container_mesos)
      |> Map.put("ipAddress", @ip_address_two_ports)

      assert Networking.get_number_of_ports(app) == 2
    end

    test "bridge networking - Marathon < 1.5" do
      app = @test_app
      |> Map.put("container", @container_bridge_networking)
      |> Map.put("portDefinitions", @port_definitions_one_port)

      assert Networking.get_number_of_ports(app) == 1
    end
  end

  @test_task %{
    "stagedAt" => "2018-02-15T00:19:09.174Z",
    "state" => "TASK_RUNNING",
    "startedAt" => "2018-02-15T00:19:40.911Z",
    "version" => "2017-09-29T09:51:28.863Z",
    "id" => "dcos-ingress.d7470966-11e5-11e8-a2a6-1653cd73b500",
    "appId" => "/dcos-ingress",
    "slaveId" => "7e76e0e4-f16c-4d63-a629-dd05d137a223-S4",
    "servicePorts" => [
      10008
    ]
  }

  @task_host "10.0.91.103"
  @task_ports [
    31791
  ]
  @task_ip_addresses [
    %{
      "ipAddress" => "9.0.4.130",
      "protocol" => "IPv4"
    }
  ]

  describe "get_task_ip/2" do
    test "host networking" do
      app = @test_app
      |> Map.put("networks", @networks_container_host_marathon15)

      task = @test_task
      |> Map.put("host", @task_host)

      assert Networking.get_task_ip(app, task) == @task_host
    end

    test "bridge networking" do
      app = @test_app
      |> Map.put("networks", @networks_container_bridge_marathon15)

      task = @test_task
      |> Map.put("host", @task_host)

      assert Networking.get_task_ip(app, task) == @task_host
    end

    test "container networking" do
      app = @test_app
      |> Map.put("networks", @networks_container_user_marathon15)

      task = @test_task
      |> Map.put("ipAddresses", @task_ip_addresses)

      assert Networking.get_task_ip(app, task) == "9.0.4.130"
    end
  end

  describe "get_task_ports/2" do
    test "host networking" do
      app = @test_app
      |> Map.put("networks", @networks_container_host_marathon15)

      task = @test_task
      |> Map.put("ports", @task_ports)

      assert Networking.get_task_ports(app, task) == @task_ports
    end

    test "bridge networking" do
      app = @test_app
      |> Map.put("networks", @networks_container_bridge_marathon15)

      task = @test_task
      |> Map.put("ports", @task_ports)

      assert Networking.get_task_ports(app, task) == @task_ports
    end

    test "container networking" do
      app = @test_app
      |> Map.put("networks", @networks_container_user_marathon15)
      |> Map.put("container", @container_user_networking_marathon15)

      task = @test_task

      assert Networking.get_task_ports(app, task) == [8080]
    end
  end
end
