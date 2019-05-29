backend "consul" {
  address = "IP_ADDRESS:8500"
  path = "vault"
}

listener "tcp" {
  address = "0.0.0.0:8200"
  tls_disable = 1
}

api_addr = "https://IP_ADDRESS:8200"
disable_mlock = true
