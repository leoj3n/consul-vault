backend "consul" {
  address = "IP_ADDRESS:8500"
  path = "vault"
}

listener "tcp" {
  address = "0.0.0.0:8200"
  tls_cert_file = "/etc/ssl/certs/consul-vault.cert.pem"
  tls_key_file = "/etc/ssl/private/consul-vault.key.pem"
}

api_addr = "https://IP_ADDRESS:8200"
disable_mlock = true
