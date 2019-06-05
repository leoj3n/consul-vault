# consul-vault

Implementation of the Autopilot Pattern for HashiCorp's Consul and Vault.

Works with the latest versions of [`docker`](https://hub.docker.com/editions/community/docker-ce-desktop-mac) and [`triton`](https://github.com/joyent/node-triton#installation), and uses the latest releases of [`consul`](https://github.com/leoj3n/consul-vault/blob/f0a8e8e2384538062ce52b742f8c0d009397fbdb/Dockerfile#L14), [`vault`](https://github.com/leoj3n/consul-vault/blob/f0a8e8e2384538062ce52b742f8c0d009397fbdb/Dockerfile#L24), and [`containerpilot`](https://github.com/leoj3n/consul-vault/blob/f0a8e8e2384538062ce52b742f8c0d009397fbdb/Dockerfile#L5). Also, shell scripts help exemplify and simplify CLI usage.

## `./run` scripts

These scripts are written for [`zsh`](http://zsh.org/).

- [`./run/local/dev/up.sh`](run/local/dev/up.sh) brings up a single local docker consul-vault `-dev` instance.
- [`./run/local/demo/provision.sh`](run/local/demo/provision.sh) generates example certs and keys via self-signed CA before using them to stand up a local docker consul-vault cluster scaled to three instances.
- [`./run/remote/triton/example.sh`](run/remote/triton/example.sh) uses generated example certs and keys in the `./secrets/` directory to stand up a remote triton-docker consul-vault cluster scaled to three instances.
  - This must be run after `./run/local/demo/provision.sh` for the `./secrets/` directory to exist.

## Including `consul-vault` in another docker project

There are three ways of getting vault (plus consul) into another docker-compose project.

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
      name: consul-vault_default
```

The name of the other project is `consul-vault`, thus the network is called `consul-vault_default` thanks to docker's standardized naming conventions for container instances.

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

  consul-vault:
    image: "${CONSUL_VAULT_LATEST}"
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

Similar to the `IS_DEV=1` method, a final way you might bring consul-vault in `-dev` mode into another docker project that perhaps contains your app code is by cloning the consul-vault repo and specifying the `--file` locations of `local-compose.yml` and `dev-compose.yml` within the cloned consul-vault directory.

For example, you could run a command like:

```console
$ docker-compose --project-name 'myapp' --file 'local-compose.yml' --file '../consul-vault/yml/local-compose.yml' --file '../consul-vault/yml/dev-compose.yml' up --detach
```
