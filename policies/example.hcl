path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/foo" {
  capabilities = ["read"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
