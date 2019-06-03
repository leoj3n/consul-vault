ui = true
disable_mlock = true
api_addr = "https://IP_ADDRESS:8200"

storage "consul" {
  path = "vault/"
  service = "service"
  address = "IP_ADDRESS:8500"
}

listener "tcp" {
  tls_disable = 1
  address = "0.0.0.0:8200"
} 
