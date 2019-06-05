# consul-vault

Implementation of the Autopilot Pattern for HashiCorp's Consul and Vault.

More information: https://github.com/autopilotpattern/vault/issues/7

## `./run` scripts

- [`./run/local/dev/up.sh`](run/local/dev/up.sh) brings up a single local docker consul-vault `-dev` instance.
- [`./run/local/demo/provision.sh`](run/local/demo/provision.sh) generates example certs and keys via self-signed CA before using them to stand up a local docker consul-vault cluster scaled to three instances.
- [`./run/remote/triton/example.sh`](run/remote/triton/example.sh) uses generated example certs and keys in the `./secrets/` directory to stand up a remote triton-docker consul-vault cluster scaled to three instances.
  - This must be run after `./run/local/demo/provision.sh` for the `./secrets/` directory to exist.
