#!/bin/bash
set -e -o pipefail

help() {
cat << EOF
Usage: ./provision.sh [options] <command>
--------------------------------------------------------------------------------
provision.sh check:
	Checks that you have the needed programs.

provision.sh up:
	Starts a 3-node Vault cluster via Docker Compose and waits for all instances
	to be up. Once instances are up, it will poll Consul's status to ensure the
	raft has been created.

provision.sh secure:
	Generates a token for gossip encryption and uploads the TLS cert for RPC
	encryption to the Consul cluster, updates the Consul configuration file to
	use these keys, and SIGHUPs all the instances. This should be run before the
	Vault is initialized and unsealed. Use the following options:

	--tls-key/-k <val>:
		The file containing the TLS key (in PEM format) used to encrypt RPC.

	--tls-cert/-c <val>:
		The file containing the TLS cert (in PEM format) used to encrypt RPC.

	--ca-cert/-a <val>:
		The file containing the CA cert (in PEM format) used to sign the TLS
		cert. If the cert is self-signed or signed by a CA found in the
		container's certificate chain, this argument may be omitted.

    --gossip/-g <val>:
        The file containing a Consul gossip key. If the argument is omitted,
        one will be generated.

provision.sh init:
	Initializes a started Vault cluster. Creates encrypted keyfiles for each
	operator's public key, which should be redistributed back to operators
	out-of-band. Use the following options:

	--keys/-k "<val>,<val>":
		List of public keys used to initialize the vault. These keys
		must be base64 encoded public keys without ASCII armoring in the
		secrets/ directory.
	--threshold/-t <val>:
		Optional number of keys required to unseal the vault. Defaults
		to 1 if a single --keys argument was provided, otherwise 2.

provision.sh unseal [keyfile]:
	Unseals a Vault with the provided operator's key. Requires access to all
	Vault nodes via 'docker exec'. A number of operator keys equal to the
	'--threshold' parameter (above) must be used to unseal the Vault.

provision.sh policy [policyname] [policyfile]:
	Adds an ACL to the Vault cluster by uploading a policy HCL file and writing
	it via 'vault policy-write'.

provision.sh engine path [path]:
  Enable the "kv" secrets engine at passed path(s).

--------------------------------------------------------------------------------

provision.sh demo:
  Runs a demonstration of the entire stack on k8s, creating a 3-node cluster
  with RPC over TLS. The demo includes initializing the Vault and unsealing it
  with PGP keys. You can either provide the demo with PGP keys and TLS
  certificates or allow the script to generate them for you.
	Parameters:

	-p, --pgp-key        use this PGP key in lieu of creating a new one
	-k, --tls-key        use this TLS key file in lieu of creating a CA and cert
	-c, --tls-cert       use this TLS cert file in lieu of creating a CA and cert
	-f, --compose-file   use this Docker Compose manifest
	-o, --openssl-conf   use this OpenSSL config file

provision.sh demo clean:
	Cleans up the demo PGP keys and CA.

EOF
}

# project and service name
repo=consul-vault
project_version=0.1
project=consulvault
service=consul-vault
instance="${project}_${service}"
COMPOSE_FILE=${COMPOSE_FILE:-yml/docker-compose.yml}

instances=("${instance}_1" "${instance}_2" "${instance}_3")
if [[ "${COMPOSE_FILE##*/}" != 'local-compose.yml' ]]; then
  kubectl='yes'
  instances=()
  for pod in $(kubectl -n kre-chatbot get pods --output=jsonpath={.items..metadata.name}); do
    if [[ "${pod}" =~ "${service}" ]]; then
      echo "POD $pod"
      instances+=(${pod})
    fi
  done
fi

# TLS setup paths
openssl_config=/usr/local/etc/openssl/openssl.cnf
ca=secrets/CA
tls_cert=
tls_key=
ca_cert=

# formatting
fmt_rev=$(tput rev)
fmt_bold=$(tput bold)
fmt_reset=$(tput sgr0)

# prints the argument bold and then resets the terminal colors
bold() {
  echo "${fmt_bold}${1}${fmt_reset}"
}

# checks that a file exists and exits with an error if not
_file_or_exit() {
  if [ ! -f "${1}" ]; then
    echo "${2}"
    exit 1
  fi
}

# checks if a variable is set and exits with an error if not
# usage: _var_or_exit myvar "text of error"
_var_or_exit() {
  if [ -z ${!1} ]; then
    echo "${2}"
    exit 1
  fi
}

_copy_chown() {
  local src=$1
  local inst=$2
  local dest=$3
  if [[ "${kubectl}" == 'yes' ]]; then
    _docker cp ${src} kre-chatbot/${inst}:${dest}
  else
    _docker cp ${src} ${inst}:${dest}
  fi
  _docker_exec ${inst} chown root:root ${dest}
  _docker_exec ${inst} chmod 755 ${dest}
}

# copy public key file to first instance
_copy_key() {
  local keyfile=$1
  echo "Copying public keyfile ${keyfile} to instance"
  _copy_chown "./secrets/${keyfile}" "${instances[0]}" "${keyfile}"
}

# create gossip token, and install token and keys on instances to encrypt both
# gossip and RPC
secure() {
  while true; do
    case $1 in
      -k | --tls-key ) tls_key=$2; shift 2;;
      -c | --tls-cert ) tls_cert=$2; shift 2;;
      -a | --ca-cert ) ca_cert=$2; shift 2;;
      -g | --gossip ) gossipKeyFile=$2; shift 2;;
      *) break;;
    esac
  done

  if [ -z ${gossipKeyFile} ]; then
    echo 'Gossip key not provided; will be generated at ./secrets/gossip.key'
    gossipKey=$(_docker_exec ${instances[0]} consul keygen | tr -d '\r')
    echo ${gossipKey} > ./secrets/gossip.key
  else
    gossipKey=$(cat ${gossipKeyFile})
  fi

  if [ -z ${ca_cert} ]; then
    echo "CA cert not provided. Assuming self-signed or already in cert store"
  fi
  _file_or_exit "${ca_cert}" "CA cert ${ca_cert} does not exist. Exiting!"
  _file_or_exit "${tls_cert}" "TLS cert ${tls_cert} does not exist. Exiting!"
  _file_or_exit "${tls_key}" "TLS cert ${tls_key} does not exist. Exiting!"

  # we're generating this file so that the embedded gossip key doesn't end up
  # getting committed to git
  cp ./etc/consul.hcl ./etc/consul-tls.hcl
  cat << EOF >> './etc/consul-tls.hcl'
ca_file = "/usr/local/share/ca-certificates/ca_cert.pem"
cert_file = "/etc/ssl/certs/consul-vault.cert.pem"
key_file = "/etc/ssl/private/consul-vault.key.pem"
encrypt = "${gossipKey}"
EOF

  for inst in "${instances[@]}"; do
    echo "Securing ${inst}..."

    echo ' copying certificates and keys'
    _docker_exec "${inst}" mkdir -p '/etc/ssl/private'
    _copy_chown "${ca_cert}" "${inst}" '/usr/local/share/ca-certificates/ca_cert.pem'
    _copy_chown "${tls_cert}" "${inst}" '/etc/ssl/certs/consul-vault.cert.pem'
    _copy_chown "${tls_key}" "${inst}" '/etc/ssl/private/consul-vault.key.pem'

    echo ' copying Consul and Vault configuration for TLS'
    _copy_chown './etc/consul-tls.hcl' "${inst}" '/etc/consul/consul.hcl'
    _copy_chown './etc/vault-tls.hcl' "${inst}" '/etc/vault.hcl'

    echo ' updating trusted root certificate (ignore the following warning)'
    _docker_exec "${inst}" update-ca-certificates

    echo " reloading ${inst} containerpilot"
    _docker_exec "${inst}" containerpilot -reload
  done
}

# ensure that the user has provided public key(s) and that a valid threshold
# value has been set.
_validate_args() {
  _var_or_exit KEYS 'You must supply at least one public keyfile!'
  if [ -z ${threshold} ]; then
    if [ ${#KEYS[@]} -lt 2 ]; then
      echo 'No threshold provided; 1 key will be required to unseal vault'
      threshold=1
    else
      echo 'No threshold provided; 2 keys will be required to unseal vault'
      threshold=2
    fi
  fi
  if [ ${threshold} -gt ${#KEYS[@]} ]; then
    echo 'Threshold is greater than the number of keys!'
    exit 1
  fi
  if [ ${#KEYS[@]} -gt 1 ] && [ ${threshold} -lt 2 ]; then
    echo 'Threshold must be greater than 1 if you have multiple keys!'
    exit 1
  fi
}

# Extracts keys from vault.keys and writes to, f.ex: example.asc.key for easy
# distribution to operators.
_split_encrypted_keys() {
  KEYS=${1}
  for i in "${!KEYS[@]}"; do
    keyNum=$(($i+1))
    awk -F': ' "/^Unseal Key $keyNum/{print \$2}" \
      secrets/vault.keys > "secrets/${KEYS[$i]}.key"
    echo "Created encrypted key file for ${KEYS[$i]}: ${KEYS[$i]}.key"
  done
}

# Prints the root token if it was successfully written to vault.keys
_print_root_token() {
  grep 'Initial Root Token' secrets/vault.keys || {
    echo 'Failed to initialize Vault'
    exit 1
  }
}

# Copies PGP keys passed in as comma-separated file names and then initializes
# the instance with those keys.
#
# The first key will be used in unseal(), so it should be your own key.
init() {
  local already_initialized vault_stdout

  while true; do
    case $1 in
      -k | --keys ) keys_arg=$2; shift 2;;
      -t | --threshold ) threshold=$2; shift 2;;
      *) break;;
    esac
  done

  mkdir -p './secrets/'

  # read the passed keys into an array
  IFS=',' read -r -a KEYS <<< "${keys_arg}"
  _validate_args
  for key in ${KEYS[@]}; do
    _copy_key "${key}"
  done

  echo 'Attempting to initialize vault (local may take up to 30 seconds before succeeding)...'

  already_initialized='no'

  until
    vault_stdout="$(2>&1 _docker_exec ${instances[0]} vault operator init \
      -key-shares=${#KEYS[@]} \
      -key-threshold=${threshold} \
      -pgp-keys="/${keys_arg}" > secrets/vault.keys)"
  do
    if [[ "${vault_stdout}" =~ 'already' ]]; then
      already_initialized='yes'
      break
    fi

    sleep 1
  done

  if [[ ${already_initialized} == 'no' ]]; then
    echo 'Vault initialized.'
    echo
    _split_encrypted_keys ${KEYS[@]}
    _print_root_token
  else
    echo 'Vault already initialized.'
    echo
  fi

  echo 'Distribute encrypted key files to operators for unsealing.'
}

# Use the encrypted keyfile to unseal all instances. this needs to be performed
# by a minimum number of operators equal to the threshold set when initializing
unseal() {
  local keyfile=$1
  _var_or_exit keyfile 'You must provide an encrypted key file!'
  _file_or_exit "${keyfile}" "${keyfile} not found."

  echo 'Decrypting key. You may be prompted for your key password...'
  cat ${keyfile} | base64 -D | gpg -d

  echo
  echo 'Use the unseal key above when prompted while we unseal each Vault node...'
  echo
  for inst in "${instances[@]}"; do
    echo
    bold "* Unsealing ${inst}"
    until
      _docker_exec -it ${inst} vault operator unseal
    do
      sleep 1
    done
  done
}

# copy a local policy file to the first instance and `vault policy write`
policy() {
  local policyname=$1
  local policyfile=$2

  _var_or_exit policyname 'You must provide a name for the policy!'
  _file_or_exit "${policyfile}" "${policyfile} not found."

  _copy_chown "${policyfile}" "${instances[0]}" "/tmp/$(basename ${policyfile})"

  until
    _docker_exec -it ${instances[0]} vault login
  do
    sleep 1
  done

  _docker_exec -it ${instances[0]} \
    vault policy write "${policyname}" "/tmp/$(basename ${policyfile})"
}

# enable the "kv" secrets engine at passed paths using the first instance
engine() {
  local paths=("${@}")

  for path in "${paths[@]}"; do
    _docker_exec -it "${instances[0]}" vault secrets enable -path="${path}" kv
  done
}

# Check for needed programs.
check() {
  command -v gpg >/dev/null 2>&1 || {
    echo
    echo 'Error! GPG is not installed!'
    exit 1
  }

  command -v docker >/dev/null 2>&1 || {
    echo
    echo 'Error! Docker is not installed!'
    exit 1
  }

  if [[ "${kubectl}" == 'yes' ]]; then
    command -v kubectl >/dev/null 2>&1 || {
      echo
      echo 'Error! kubectl is not installed!'
      exit 1
    }
  fi
}

check_kubectl() {
  echo
  bold '* Checking your setup...'
  echo './provision.sh check'
  check
}

up() {
  _kubectl_up
  _demo_wait_for_consul
}

_docker() {
  local docker

  if [[ "${kubectl}" == 'yes' ]]; then
    docker='kubectl'
    namespace='--namespace kre-chatbot'
  else
    docker='docker'
  fi

  cat << EOF >> './docker_call_log'
${docker} ${namespace} ${@}
EOF

  "${docker}" ${namespace} ${@}
}

_docker_exec() {
  local inst="${1}"
  shift
  local extra=''
  [[ "${kubectl}" == 'yes' ]] && extra='--'
  _docker exec ${inst} ${extra} ${@}
}

_docker_compose() {
  local compose

  echo "COMPOSE_FILE = ${COMPOSE_FILE##*/}"

  compose='docker-compose'

  cat << EOF >> './docker_call_log'
${compose} --project-name ${project} --file ${COMPOSE_FILE} ${@}
EOF

  "${compose}" --project-name "${project}" --file "${COMPOSE_FILE}" ${@}
}

_kubectl_up() {
  echo
  bold "* Composing cluster of 3 ${service} service instances on k8s..."
  _docker_compose up -d && _docker_compose scale "${service}=3"
}

_demo_up() {
  echo
  bold "* Composing cluster of 3 ${service} service instances..."
  echo "docker-compose up --detach --scale ${service}=3"
  _docker_compose up --detach --scale "${service}=3"
}

_demo_secure() {
  echo
  bold '* Encrypting Consul gossip and RPC'
  echo "./provision.sh secure -k ${tls_key} -c ${tls_cert} -a ${ca_cert}"
  secure -k ${tls_key} -c ${tls_cert} -a ${ca_cert}
}

_demo_wait_for_consul() {
  echo
  bold '* Waiting for Consul to form raft...'
  until
    _docker_exec ${instances[0]} consul info | grep -q "num_peers = 2"
  do
    echo -n '.'
    sleep 1
  done
}

check_tls() {
  if [ -z "${tls_cert}" ] || [ -z "${tls_key}" ]; then
    cat << EOF
${fmt_rev}${fmt_bold}You have not provided a value for --tls-cert or --tls-key.
In the next step we will create a temporary certificate authority in the
secrets/ directory and use it to issue a TLS certificate. The TLS cert and its
key will be copied to the instances.${fmt_reset}
EOF
    echo
    read -rsp $'Press any key to continue or Ctrl-C to cancel...\n' -n1 key
    echo
    _ca
    _cert
  fi
  _file_or_exit "${tls_cert}" "${tls_cert} does not exist!"
  _file_or_exit "${tls_key}" "${tls_key} does not exist!"
}

_ca() {
  [ -f "${ca}/ca_key.pem" ] && echo 'CA exists' && ca_cert="${ca}/ca_cert.pem" && return
  [ -f "${ca_cert}" ] && echo 'CA exists' && return

  bold '* Creating a certificate authority...'
  mkdir -p "${ca}"

  # create a cert we can use to sign other certs (a CA)
  openssl req -new -x509 -days 3650 -extensions v3_ca \
    -keyout "${ca}/ca_key.pem" -out "${ca}/ca_cert.pem" \
    -config ${openssl_config} \
    -subj "/C=US/ST=California/L=San Francisco/O=Example/OU=Example/emailAddress=example@example.com"

  # we'll use this var later
  ca_cert="${ca}/ca_cert.pem"
}

_cert() {
  tls_key="${tls_key:-./secrets/consul-vault.key.pem}"
  tls_cert="${tls_cert:-./secrets/consul-vault.cert.pem}"

  [ -f "${tls_key}" ] && echo 'TLS certificate exists!' && return
  # ---------------------------------------------------------------------------
  # -f "${tls_key}"                   [read] ./secrets/consul-vault.key.pem
  # ---------------------------------------------------------------------------

  [ -f "${tls_cert}" ] && echo 'TLS certificate exists!' && return
  # ---------------------------------------------------------------------------
  # -f "${tls_cert}"                  [read] ./secrets/consul-vault.cert.pem
  # ---------------------------------------------------------------------------

  echo
  bold '* Creating a private key for Consul and Vault...'
  openssl genrsa -out "${tls_key}" 2048
  # ---------------------------------------------------------------------------
  # -out "${tls_key}"                [write] ./secrets/consul-vault.key.pem
  # ---------------------------------------------------------------------------

  echo
  bold '* Generating a Certificate Signing Request for Consul and Vault...'

  cp "${openssl_config}" './secrets/openssl.cnf'
  # ---------------------------------------------------------------------------
  # cp "${openssl_config}"            [read] /usr/local/etc/openssl/openssl.cnf
  # cp                               [write] ./secrets/openssl.cnf
  # ---------------------------------------------------------------------------

  # The cert generation doesn't take the -config argument, so we need to create
  # the -extfile part and then cat it together with the regular config.
  echo '[ SAN ]' > 'secrets/openssl-ext.cnf'
  echo 'subjectAltName = DNS:vault,DNS:consul,IP:127.0.0.1' \
    >> './secrets/openssl-ext.cnf'
  # ---------------------------------------------------------------------------
  # echo                             [write] ./secrets/openssl-ext.cnf
  # ---------------------------------------------------------------------------

  cat './secrets/openssl-ext.cnf' >> './secrets/openssl.cnf'
  # ---------------------------------------------------------------------------
  # cat                              [write] ./secrets/openssl.cnf
  # ---------------------------------------------------------------------------

  openssl req \
    -config './secrets/openssl.cnf' \
    -reqexts 'SAN' \
    -extensions 'SAN' \
    -key "${tls_key}" \
    -new -sha256 \
    -out './secrets/consul-vault.csr.pem' \
    -subj "/C=US/ST=California/L=San Francisco/O=Example/OU=Example/CN=vault/emailAddress=example@example.com"
  # ---------------------------------------------------------------------------
  # -config                           [read] ./secrets/openssl.cnf
  # -key "${tls_key}"                 [read] ./secrets/consul-vault.key.pem
  # -out                             [write] ./secrets/consul-vault.csr.pem
  # ---------------------------------------------------------------------------

  echo
  bold '* Generating a TLS certificate for Consul and Vault...'
  openssl x509 -req -days 365 -sha256 \
    -CA "${ca_cert}" \
    -CAkey "${ca}/ca_key.pem" \
    -extensions 'SAN' \
    -extfile './secrets/openssl-ext.cnf' \
    -in './secrets/consul-vault.csr.pem' \
    -CAcreateserial \
    -out "${tls_cert}"
  # ---------------------------------------------------------------------------
  # -CA "${ca_cert}"                  [read] ./secrets/CA/ca_cert.pem
  # -CAkey "${ca}/ca_key.pem"         [read] ./secrets/CA/ca_key.pem
  # -extfile                          [read] ./secrets/openssl-ext.cnf         
  # -in                               [read] ./secrets/consul-vault.csr.pem
  # -CAcreateserial                  [write] ./secrets/CA/ca_cert.srl
  # -out                             [write] ./secrets/consul-vault.cert.pem
  # ---------------------------------------------------------------------------

  echo
  bold '* Verifying certificate...'
  openssl x509 -noout -text -in "${tls_cert}"
  # ---------------------------------------------------------------------------
  # -in "${tls_cert}"                 [read] ./secrets/consul-vault.cert.pem
  # ---------------------------------------------------------------------------
}

# `gpg` creates an "Example User", and exports the resulting [PGP Public Key]
# to <./secrets/example.asc>. Or, alternatively, it exports the [PGP Public
# Key] of the passed user to, f.ex: <./secrets/jane.asc>. The exported [PGP
# Public Key] is piped into `base64` before being written to file.
#
# An ASC file is an armored ASCII file used by Pretty Good Privacy (PGP).
check_pgp() {
  if [ -z ${pgp_key} ]; then
    cat << EOF
${fmt_rev}${fmt_bold}You have not provided a value for --pgp-key. In the next
step we will create a trusted PGP keypair in your GPG key ring. The public key
will be uploaded to the instances. The private key will not be exported or
leave this machine!${fmt_reset}
EOF
    echo
    read -rsp $'Press any key to continue or Ctrl-C to cancel...\n' -n1 key
    echo
    mkdir -p ./secrets/
    bold '* Creating PGP key...'
    gpg -q --batch --gen-key << EOF
Key-Type: RSA
Key-Length: 2048
Name-Real: Example User
Name-Email: example@example.com
Expire-Date: 0
%commit
EOF
    PGP_KEYFILE='example.asc'
    gpg --export 'Example User <example@example.com>' | base64 > ./secrets/${PGP_KEYFILE}
    bold "* Created a PGP key and exported the public key to ./secrets/${PGP_KEYFILE}"
  else
    bold "* Exporting PGP public key ${pgp_key} to file"
    PGP_KEYFILE="./secrets/${pgp_key}.asc"
    gpg --export "${pgp_key}" | base64 > ./secrets/${PGP_KEYFILE}
  fi
}

_demo_init() {
  echo
  bold '* Initializing the vault with your PGP key. If you had multiple';
  bold '  keys you would pass these into the setup script as follows:'
  echo '  ./provision.sh init -k 'mykey1.asc,mykey2.asc' -t 2'
  echo
  echo "./provision.sh init -k ${PGP_KEYFILE} -t 1"
  init -k "${PGP_KEYFILE}" -t 1
}

_demo_unseal() {
  echo
  bold '* Unsealing the vault with your PGP key. If you had multiple keys,';
  bold '  each operator would unseal the vault with their own key as follows:'
  echo '  ./provision.sh unseal ./secrets/mykey1.asc.key'
  echo
  echo "./provision.sh unseal ${PGP_KEYFILE}.key"
  unseal "./secrets/${PGP_KEYFILE}.key"
}

_demo_policy() {
  echo
  bold '* Adding an example ACL policy. Use the token you received'
  bold '  previously when prompted.'
  echo
  echo './provision.sh policy secret ./policies/example.hcl'
  policy 'secret' './policies/example.hcl'
}

_demo_engine() {
  echo
  bold '* Enabling the "kv" secrets engine at the secret/ path.'
  echo
  echo './provision.sh engine secret/'
  engine 'secret/'
}

clean() {
  bold '* Deleting the key(s) associated with the example user'
  local key=$(gpg --list-keys 'Example User <example@example.com>' | awk -F'/| +' '/pub/{print $3}')
  gpg --delete-secret-keys $key
  gpg --delete-keys $key
  bold '* Deleting the CA and associated keys'
  rm -rf './secrets/'
}

demo() {
  while true; do
    case $1 in
      -p | --pgp-key ) pgp_key=$2; shift 2;;
      -k | --tls-key ) tls_key=$2; shift 2;;
      -c | --tls-cert ) tls_cert=$2; shift 2;;
      -a | --ca-cert ) ca_cert=$2; shift 2;;
      -f | --compose-file ) COMPOSE_FILE=$2; shift 2;;
      -o | --openssl-conf ) openssl_config=$2; shift 2;;
      _ca | check_* | clean | help) cmd=$1; shift 1; $cmd; exit;;
      *) break;;
    esac
  done

  check_tls
  check_pgp
  #check_kubectl

  _demo_up              # docker-compose up
  _demo_wait_for_consul # wait for consul to form 3-node raft
  _demo_secure          # copy certificates, restart raft
  _demo_init            # copy secret keys, run vault operator init
  _demo_unseal          # ask operator for unseal key
  _demo_policy          # login to vault, apply policy
  _demo_engine          # enable the "kv" secrets engine at secret/
}


build() {
  _docker build --tag leoj3n/consul-vault .
}

ship() {
  local githash=$(git rev-parse --short HEAD)
  _docker tag ${repo}:latest ${repo}:${project_version}-${githash}
  _docker push ${repo}:latest
  _docker push ${repo}:${project_version}-${githash}
}

# ---------------------------------------------------
# parse arguments

while true; do
    case $1 in
        check | check_* | up | secure | init | unseal | policy | engine | demo | build | ship | help) cmd=$1; shift; break;;
        *) break;;
    esac
done

if [ -z $cmd ]; then
    help
    exit
fi

[ -f './docker_call_log' ] && rm './docker_call_log'

$cmd $@
