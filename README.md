# consul-vault

Implementation of the [Autopilot Pattern](http://autopilotpattern.io/) for HashiCorp's Consul and Vault.

 Uses the latest [`consul`](https://www.consul.io/), [`vault`](https://www.vaultproject.io/), and [`containerpilot`](https://www.joyent.com/containerpilot)... Works with the latest [`docker`](https://hub.docker.com/editions/community/docker-ce-desktop-mac) or [`triton`](https://github.com/joyent/node-triton#installation).

Reference the shell scripts in [`./run/`](#run-scripts) and related compose files in [`./yml/`](./yml) to understand how to use consul-vault.

## Run scripts

These scripts are written for [zsh](http://zsh.org/).

- [`./run/local/dev/up.sh`](./run/local/dev/up.sh)
  - Brings up a single local docker consul-vault `-dev` instance.
- [`./run/local/demo/provision.sh`](./run/local/demo/provision.sh)
  - Generates example certs and keys via self-signed CA before using them to stand up a local docker consul-vault cluster scaled to three instances.
- [`./run/remote/triton/example.sh`](./run/remote/triton/example.sh)
  - Uses generated example certs and keys in the `./secrets/` directory to stand up a remote triton-docker consul-vault cluster scaled to three instances.
  - This must be run after `./run/local/demo/provision.sh` for the `./secrets/` directory to exist.

See all available scripts at [`./run/`](./run).

## How to use in other docker-compose projects?

There are three methods of including consul-vault in another docker-compose project:

- `network:`
  - Creates a fully functioning cluster of three instances.
  - Requires cloning the `consul-vault` repo.
  - Allows your project to communicate with consul-vault across the same local docker host network.
- `IS_DEV=1`
  - Creates a single `-dev` mode instance.
  - Requires a built image (perhaps from docker hub).
  - Pulls in consul-vault from the built docker image.
- `--file`
  - Creates a single `-dev` mode instance.
  - Requires cloning the `consul-vault` repo.
  - Pulls in consul-vault from the cloned repo directory.

### `network:`

If your development process would be aided by persisting consul and vault data to a backend locally, or if you are wanting to test out consul+vault clustering locally, or perhaps (if for some reason) your app needs to connect to consul and vault over TLS when locally under development, then consider use the `networks:` method. However, the `IS_DEV=1` method might be better.

Two separately-spun-up projects are able to communicate over the local docker network using the following configuration with the `local-compose.yml` of the project containing the app code:

```yml
version: "3.7"

# Use existing network instead of the service if already running consul-vault
# separately beforehand.
networks:
  default:
    external:
      name: consulvault_default
```

The directory name of the "other project" is `consul-vault`, thus by default the network would be called `consul-vault_default` thanks to docker's standardized naming conventions for container instances, however we set the docker `--project-name` to `consulvault` because of a problem where Triton strips dashes out of container instance names in the cloud, so the network name is actually `consulvault_default`.

You could save this as `net-compose.yml` and run a docker command like:

```console
$ docker-compose --project-name 'myapp' --file 'local-compose.yml' --file 'net-compose.yml' up --detach
```

### `IS_DEV=1`

If you need a simple, single-instance dev setup for your app to connect to for development purposes, then it is probably more lightweight to use the image method with `IS_DEV=1` in your `local-compose.yml`. This also might have the benefit of a clean consul and vault database every time you start your app cluster, which makes your app development process more reproducible.

It's possible to pull in an image that simply spins up vault and consul in their zero-setup-required but also no-data-preserved `-dev` modes (notice the `IS_DEV=1`):

```yml
version: "3.7"

services:

  consul-vault-service:
    image: leoj3n/consul-vault:latest
    ports:
      - "8200:8200"
      - "8500:8500"
    environment:
      - IS_DEV=1

  mongo:
    depends_on:
      - consul-vault
```

You could save this as `image-compose.yml` and run a docker command like:

```console
$ docker-compose --project-name 'myapp' --file 'local-compose.yml' --file 'image-compose.yml' up --detach
```

### `--file`

Similar to the `IS_DEV=1` method, a final way you might bring consul-vault in `-dev` mode into another docker project that contains your app code is by cloning the consul-vault repo and specifying the `--file` locations of `local-compose.yml` and `dev-compose.yml` within the cloned consul-vault directory.

For example, you could run a command like:

```console
$ docker-compose --project-name 'myapp' --file 'local-compose.yml' --file '../consul-vault/yml/local-compose.yml' --file '../consul-vault/yml/dev-compose.yml' up --detach
```

Where `../consul-vault/yml/dev-compose.yml` (or [yml/dev-compose.yml](yml/dev-compose.yml)) does the setting of `IS_DEV=1`, etc.

This works as long as the service is named `consul-vault-service`.
