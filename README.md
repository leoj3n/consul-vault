# Consul with the Autopilot Pattern

[Consul](http://www.consul.io/) in Docker, designed to be self-operating according to the autopilot pattern. This application demonstrates support for configuring the Consul raft so it can be used as a highly-available discovery catalog for other applications using the Autopilot pattern.

[![DockerPulls](https://img.shields.io/docker/pulls/autopilotpattern/consul.svg)](https://registry.hub.docker.com/u/autopilotpattern/consul/)
[![DockerStars](https://img.shields.io/docker/stars/autopilotpattern/consul.svg)](https://registry.hub.docker.com/u/autopilotpattern/consul/)

## Using Consul with ContainerPilot

This design starts up all Consul instances with the `-bootstrap-expect` flag. This option tells Consul how many nodes we expect and automatically bootstraps when that many servers are available. We still need to tell Consul how to find the other nodes, and this is where [Triton Container Name Service (CNS)](https://docs.joyent.com/public-cloud/network/cns) and [ContainerPilot](https://joyent.com/containerpilot) come into play.

The ContainerPilot configuration has a management script that is run on each health check interval. This management script runs `consul info` and gets the number of peers for this node. If the number of peers is not equal to 2 (there are 3 nodes in total but a node isn't its own peer), then the script will attempt to find another node via `consul join`. This command will use the Triton CNS name for the Consul service. Because each node is automatically added to the A Record for the CNS name when it starts, the nodes will all eventually find at least one other node and bootstrap the Consul raft.

When run locally for testing, we don't have access to Triton CNS. The `local-compose.yml` file uses the v2 Compose API, which automatically creates a user-defined network and allows us to use Docker DNS for the service.

## Run it!

1. [Get a Joyent account](https://my.joyent.com/landing/signup/) and [add your SSH key](https://docs.joyent.com/public-cloud/getting-started).
1. Install the [Docker Toolbox](https://docs.docker.com/installation/mac/) (including `docker` and `docker-compose`) on your laptop or other environment, as well as the [Joyent Triton CLI](https://www.joyent.com/blog/introducing-the-triton-command-line-tool) (`triton` replaces our old `sdc-*` CLI tools).

Check that everything is configured correctly by changing to the `examples/triton` directory and executing `./provision.sh`. This will check that your environment is setup correctly and will create an `_env` file that includes injecting an environment variable for a service name for Consul in Triton CNS. We'll use this CNS name to bootstrap the cluster.

```bash
$ docker-compose up -d
Creating consul_consul_1

$ docker-compose scale consul=3
Creating and starting consul_consul_2 ...
Creating and starting consul_consul_3 ...

$ docker-compose ps
Name                        Command                 State       Ports
--------------------------------------------------------------------------------
consul_consul_1   /usr/local/bin/containerpilot...   Up   53/tcp, 53/udp,
                                                          8300/tcp, 8301/tcp,
                                                          8301/udp, 8302/tcp,
                                                          8302/udp, 8400/tcp,
                                                          0.0.0.0:8500->8500/tcp
consul_consul_2   /usr/local/bin/containerpilot...   Up   53/tcp, 53/udp,
                                                          8300/tcp, 8301/tcp,
                                                          8301/udp, 8302/tcp,
                                                          8302/udp, 8400/tcp,
                                                          0.0.0.0:8500->8500/tcp
consul_consul_3   /usr/local/bin/containerpilot...   Up   53/tcp, 53/udp,
                                                          8300/tcp, 8301/tcp,
                                                          8301/udp, 8302/tcp,
                                                          8302/udp, 8400/tcp,
                                                          0.0.0.0:8500->8500/tcp

$ docker exec -it consul_consul_3 consul info | grep num_peers
    num_peers = 2

```

### Run it with more than one datacenter!

Within the `examples/triton-multi-dc` directory, execute `./setup-multi-dc.sh`, providing as arguments Triton profiles which belong to the desired data centers.

Since interacting with multiple data centers requires switching between Triton profiles it's easier to perform the following steps in separate terminals. It is possible to perform all the steps for a single data center and then change profiles. Additionally, setting `COMPOSE_PROJECT_NAME` to match the profile or data center will help distinguish nodes in Triton Portal and the `triton instance ls` listing.

One `_env` and one `docker-compose-<PROFILE>.yml` should be generated for each profile. Execute the following commands, once for each profile/datacenter, within `examples/triton-multi-dc`:

```
$ eval "$(TRITON_PROFILE=<PROFILE> triton env -d)"

# The following helps when executing docker-compose multiple times. Alternatively, pass the -f flag to each invocation of docker-compose.
$ export COMPOSE_FILE=docker-compose-<PROFILE>.yml

# The following is not strictly necessary but helps to discern between clusters. Alternatively, pass the -p flag to each invocation of docker-compose.
$ export COMPOSE_PROJECT_NAME=<PROFILE>

$ docker-compose up -d
Creating <PROFILE>_consul_1 ... done

$ docker-compose scale consul=3
```

Note: the `cns.joyent.com` hostnames cannot be resolved from outside the datacenters. Change `cns.joyent.com` to `triton.zone` to access the web UI.

## Environment Variables

- `CONSUL_DEV`: Enable development mode, allowing a node to self-elect as a cluster leader. Consul flag: [`-dev`](https://www.consul.io/docs/agent/options.html#_dev).
    - The following errors will occur if `CONSUL_DEV` is omitted and not enough Consul instances are deployed:
    ```
    [ERR] agent: failed to sync remote state: No cluster leader
    [ERR] agent: failed to sync changes: No cluster leader
    [ERR] agent: Coordinate update error: No cluster leader
    ```
- `CONSUL_DATACENTER_NAME`: Explicitly set the name of the data center in which Consul is running. Consul flag: [`-datacenter`](https://www.consul.io/docs/agent/options.html#datacenter).
    - If this variable is specified it will be used as-is.
    - If not specified, automatic detection of the datacenter will be attempted. See [issue #23](https://github.com/autopilotpattern/consul/issues/23) for more details.
    - Consul's default of "dc1" will be used if none of the above apply.

- `CONSUL_BIND_ADDR`: Explicitly set the corresponding Consul configuration. This value will be set to `0.0.0.0` if `CONSUL_BIND_ADDR` is not specified and `CONSUL_RETRY_JOIN_WAN` is provided. Be aware of the security implications of binding the server to a public address and consider setting up encryption or using a VPN to isolate WAN traffic from the public internet.
- `CONSUL_SERF_LAN_BIND`: Explicitly set the corresponding Consul configuration. This value will be set to the server's private address automatically if not specified. Consul flag: [`-serf-lan-bind`](https://www.consul.io/docs/agent/options.html#serf_lan_bind).
- `CONSUL_SERF_WAN_BIND`: Explicitly set the corresponding Consul configuration. This value will be set to the server's public address automatically if not specified. Consul flag: [`-serf-wan-bind`](https://www.consul.io/docs/agent/options.html#serf_wan_bind).
- `CONSUL_ADVERTISE_ADDR`: Explicitly set the corresponding Consul configuration. This value will be set to the server's private address automatically if not specified. Consul flag: [`-advertise-addr`](https://www.consul.io/docs/agent/options.html#advertise_addr).
- `CONSUL_ADVERTISE_ADDR_WAN`: Explicitly set the corresponding Consul configuration. This value will be set to the server's public address automatically if not specified. Consul flag: [`-advertise-addr-wan`](https://www.consul.io/docs/agent/options.html#advertise_addr_wan).

- `CONSUL_RETRY_JOIN_WAN`: sets the remote datacenter addresses to join. Must be a valid HCL list (i.e. comma-separated quoted addresses). Consul flag: [`-retry-join-wan`](https://www.consul.io/docs/agent/options.html#retry_join_wan).
    - The following error will occur if `CONSUL_RETRY_JOIN_WAN` is provided but improperly formatted:
    ```
    ==> Error parsing /etc/consul/consul.hcl: ... unexpected token while parsing list: IDENT
    ```
    - Gossip over the WAN requires the following ports to be accessible between data centers, make sure that adequate firewall rules have been established for the following ports (this should happen automatically when using docker-compose with Triton):
      - `8300`: Server RPC port (TCP)
      - `8302`: Serf WAN gossip port (TCP + UDP)

## Using this in your own composition

There are two ways to run Consul and both come into play when deploying ContainerPilot, a cluster of Consul servers and individual Consul client agents.

### Servers

The Consul container created by this project provides a scalable Consul cluster. Use this cluster with any project that requires Consul and not just ContainerPilot/Autopilot applications.

The following Consul service definition can be dropped into any Docker Compose file to run a Consul cluster alongside other application containers.

```yaml
version: '2.1'

services:

  consul:
    image: autopilotpattern/consul:1.0.0r43
    restart: always
    mem_limit: 128m
    ports:
      - 8500
    environment:
      - CONSUL=consul
      - LOG_LEVEL=info
    command: >
      /usr/local/bin/containerpilot
```

In our experience, including a Consul cluster within a project's `docker-compose.yml` can help developers understand and test how a service should be discovered and registered within a wider infrastructure context.

### Clients

ContainerPilot utilizes Consul's [HTTP Agent API](https://www.consul.io/api/agent.html) for a handful of endpoints, such as `UpdateTTL`, `CheckRegister`, `ServiceRegister` and `ServiceDeregister`. Connecting ContainerPilot to Consul can be achieved by running Consul as a client to a cluster (mentioned above). It's easy to run this Consul client agent from ContainerPilot itself.

The following snippet demonstrates how to achieve running Consul inside a container and connecting it to ContainerPilot by configuring a `consul-agent` job.

```json5
{
  consul: 'localhost:8500',
  jobs: [
    {
      name: "consul-agent",
      restarts: "unlimited",
      exec: [
        "/usr/bin/consul", "agent",
          "-data-dir=/data",
          "-log-level=err",
          "-rejoin",
          "-retry-join", '{{ .CONSUL | default "consul" }}',
          "-retry-max", "10",
          "-retry-interval", "10s",
      ],
      health: {
        exec: "curl -so /dev/null http://localhost:8500",
        interval: 10,
        ttl: 25,
      }
    }
  ]
}
```

Many application setups in the Autopilot Pattern library include a Consul agent process within each container to handle connecting ContainerPilot itself to a cluster of Consul servers. This helps performance of Consul features at the cost of more clients connected to the cluster.

A more detailed example of a ContainerPilot configuration that uses a Consul agent co-process can be found in [autopilotpattern/nginx](https://github.com/autopilotpattern/nginx).

## Triton-specific availability advantages

Some details about how Docker containers work on Triton have specific bearing on the durability and availability of this service:

1. Docker containers are first-order objects on Triton. They run on bare metal, and their overall availability is similar or better than what you expect of a virtual machine in other environments.
1. Docker containers on Triton preserve their IP and any data on disk when they reboot.
1. Linked containers in Docker Compose on Triton are distributed across multiple unique physical nodes for maximum availability in the case of  node failures.

## Consul encryption

Consul supports TLS encryption for RPC and symmetric pre-shared key encryption for its gossip protocol. Deploying these features requires managing these secrets, and a demonstration of how to do so can be found in the [Vault example](https://github.com/autopilotpattern/vault).

### Testing

The `tests/` directory includes integration tests for both the Triton and Compose example stacks described above. Build the test runner by making sure you've pulled down the submodule with `git submodule update --init` and then `make build/tester`.

Running `make test/triton` will run the tests in a container locally but targeting Triton Cloud. To run those tests you'll need a Triton Cloud account with your Triton command line profile set up. The test rig will use the value of the `TRITON_PROFILE` environment variable to determine what data center to target. The tests use your own credentials mounted from your Docker host (your laptop, for example), so if you have a passphrase on your ssh key you'll need to add `-it` to the arguments of the `test/triton` Make target.

## Credit where it's due

This project builds on the fine examples set by [Jeff Lindsay](https://github.com/progrium)'s ([Glider Labs](https://github.com/gliderlabs)) [Consul in Docker](https://github.com/gliderlabs/docker-consul/tree/legacy) work. It also, obviously, wouldn't be possible without the outstanding work of the [Hashicorp team](https://hashicorp.com) that made [consul.io](https://www.consul.io).

# Autopilot Pattern Vault

[Hashicorp Vault](https://www.vaultproject.io) deployment designed for automated operation using the [Autopilot Pattern](http://autopilotpattern.io/). This repo serves as a blueprint demonstrating the pattern that can be reused as part of other application stacks.

## Architecture

This application blueprint consists of Vault running in the same Docker container as its Consul storage backend. We run Consul with ContainerPilot, with Hashicorp Vault running as a ContainerPilot [co-process](https://www.joyent.com/containerpilot/docs/coprocesses). Vault is running under HA mode. The Consul configuration is the same as that in the [HA Consul](https://github.com/autopilotpattern/consul) blueprint; this container image's Dockerfile extends that image.

### Bootstrapping Consul

Bootstrapping Consul is identical to [autopilotpattern/consul](https://github.com/autopilotpattern/consul). All Consul instances start with the `-bootstrap-expect` flag. This option tells Consul how many nodes we expect and automatically bootstraps when that many servers are available. We use ContainerPilot's `health` check to check if the node has been joined to peers and attempt to join its peers at the A-record associated with the [Triton Container Name Service (CNS)](https://docs.joyent.com/public-cloud/network/cns) name.

When run locally for testing, we don't have access to Triton CNS. The local-compose.yml file uses the v2 Compose API, which automatically creates a user-defined network and allows us to use Docker DNS for the service.

### Encrypted communications

Consul provides a mechanism to encrypt both the gossip protocol (via symmetric encryption with a token) and the RPC protocol (via TLS certificates). These shared key and certificate must be present at the time we start Consul. This precludes us from using the ContainerPilot `preStart` to configure the encryption unless we embed the keys within the image or as environment variables. Instead, after the cluster is launched but before we initialize Vault, we'll use `docker exec` to install all the appropriate key material, update the configuration to use it, and restart the cluster.

### Key Sharing

When the Vault is first initialized it is in a sealed state and a number of keys are created that can be used to unseal it. Vault uses Shamir Secret Splitting so that `-key-shares` number of keys are created and `-key-theshold` number of those keys are required to unseal the Vault. If `vault init` is used without providing the `-pgp-keys` argument these keys are presented to the user in plaintext. This blueprint expects that the the `-pgp-keys` argument will be passed. An encrypted secret will be provided for each PGP key provided, and only the holder of the PGP private key will be able to unseal or reseal the Vault.

### Unsealing

The Vault health check will check to make sure that we're unsealed and not advertise itself to Consul for client applications until it is unsealed.

The operator will then initialize one of the Vault nodes. To do so, the operator provides a PGP public key file for each user and a script will take these files and initialize the vault with `-key-shares` equal to the number of keys provided and `-key-threshold=2` (so that any two of the operators can unseal or force it to be rekeyed -- this is the minimum). The script will then decrypt the operator's own Vault key and use it to unseal all the Vault nodes. The script will also provide the operator with the root key, which will get used to set up ACLs for client applications (see below).


### High Availability

Vault elects a primary via locks in Consul. If the primary fails, a new node will become the primary. Other nodes will automatically forward client requests to the primary. If a node is restarted or a new node created it will be sealed and unable to enter the pool until it's manually unsealed.

---

## Run the demo!

This repo provides a tool (`./provision.sh`) to launch and manage the Vault cluster. You'll need the following to get started:

1. [Get a Joyent account](https://my.joyent.com/landing/signup/) and [add your SSH key](https://docs.joyent.com/public-cloud/getting-started).
1. Install the [Docker Toolbox](https://docs.docker.com/installation/mac/) (including `docker` and `docker-compose`) on your laptop or other environment, as well as the [Joyent Triton CLI](https://www.joyent.com/blog/introducing-the-triton-command-line-tool).

If you want to see how a completed stack looks, try the demo first.

**`provision.sh demo`:** Runs a demonstration of the entire stack on Triton, creating a 3-node cluster with RPC over TLS. The demo includes initializing the Vault and unsealing it with PGP keys. You can either provide the demo with PGP keys and TLS certificates or allow the script to generate them for you. Parameters:

	-p, --pgp-key        use this PGP key in lieu of creating a new one
	-k, --tls-key        use this TLS key file in lieu of creating a CA and cert
	-c, --tls-cert       use this TLS cert file in lieu of creating a CA and cert
	-f, --compose-file   use this Docker Compose manifest
	-o, --openssl-conf   use this OpenSSL config file

**`provision.sh demo clean`:** Cleans up the demo PGP keys and CA.

The Vault cluster runs as Docker containers on Triton, so you can use your Docker client and Compose to explore the cluster further.

```bash
$ docker-compose ps
Name                      Command                 State       Ports
--------------------------------------------------------------------------------
vault_vault_1   /usr/local/bin/containerpilot...   Up   53/tcp, 53/udp,
                                                        8200/tcp, 8300/tcp
                                                        8301/tcp, 8301/udp,
                                                        8302/tcp, 8302/udp,
                                                        8400/tcp,
                                                        0.0.0.0:8500->8500/tcp
vault_vault_2   /usr/local/bin/containerpilot...   Up   53/tcp, 53/udp,
                                                        8200/tcp, 8300/tcp
                                                        8301/tcp, 8301/udp,
                                                        8302/tcp, 8302/udp,
                                                        8400/tcp,
                                                        0.0.0.0:8500->8500/tcp
vault_vault_3   /usr/local/bin/containerpilot...   Up   53/tcp, 53/udp,
                                                        8200/tcp, 8300/tcp
                                                        8301/tcp, 8301/udp,
                                                        8302/tcp, 8302/udp,
                                                        8400/tcp,
                                                        0.0.0.0:8500->8500/tcp

$ docker exec -it vault_vault_3 consul info | grep num_peers
    num_peers = 2

$ docker exec -it vault_vault_3 vault write secret/hello value=world
Success! Data written to: secret/hello

```

---

## Run it in production!

Once you've seen the demo, you'll want to run the stack as you will in production.

**`provision.sh check`:** Checks that your Triton and Docker environment is sane and configures an environment file `_env` with a CNS record for Consul. We'll use this CNS name to bootstrap the Consul cluster.

**`provision.sh up`:** Starts the Vault cluster via Docker Compose and waits for all instances to be up. Once instances are up, it will poll Consul's status to ensure the raft has been created.

**`provision.sh secure`:** Generates a token for gossip encryption and uploads the TLS cert for RPC encryption to the Consul cluster, updates the Consul configuration file to use these keys, and SIGHUPs all the instances. This should be run before the Vault is initialized and unsealed. Use the following options:

	--tls-key/-k <val>:
		The file containing the TLS key (in PEM format) used to encrypt RPC.

	--tls-cert/-c <val>:
		The file containing the TLS cert (in PEM format) used to encrypt RPC.

	--ca-cert/-a <val>:
		The file containing the CA cert (in PEM format) used to sign the TLS
		cert. If the cert is self-signed or signed by a CA found in the
		container's certificate chain, this argument may be omitted.

**`provision.sh init`:** Initializes a started Vault cluster. Creates encrypted keyfiles for each operator's public key, which should be redistributed back to operators out-of-band. Use the following options:

	--keys/-k "<val>,<val>":
		List of public keys used to initialize the vault. These keys
		must be base64 encoded public keys without ASCII armoring.
	--threshold/-t <val>:
		Optional number of keys required to unseal the vault. Defaults
		to 1 if a single --keys argument was provided, otherwise 2.

**`provision.sh unseal [keyfile]`:** Unseals a Vault with the provided operator's key. Requires access to all Vault nodes via `docker exec`. A number of operator keys equal to the `--threshold` parameter (above) must be used to unseal the Vault.

**`provision.sh policy [policyname] [policyfile]`:** Adds an ACL to the Vault cluster by uploading a policy HCL file and writing it via `vault policy-write`.
