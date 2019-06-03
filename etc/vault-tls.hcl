ui = true
disable_mlock = true
api_addr = "https://IP_ADDRESS:8200"

storage "consul" {
  path = "vault/"
  service = "vault"
  address = "IP_ADDRESS:8500"
}

listener "tcp" {
  address = "0.0.0.0:8200"
  tls_key_file = "/etc/ssl/private/consul-vault.key.pem"
  tls_cert_file = "/etc/ssl/certs/consul-vault.cert.pem"
} 
