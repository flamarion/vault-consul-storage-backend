listener "tcp" {
    address = "0.0.0.0:8200"
    cluster_address = "vault-server1:8201"
    tls_disable = true
}
ui = true
# This part need to be added after genereate the Agente Token in Consul
storage "consul" {
    address = "consul-server1:8500"
    path = "vault"
    token = "1073a540-9651-c9e9-bd90-7fb422417cc2"
}
service_registration "consul" {
    address = "consul-server1:8500"
    token = "1073a540-9651-c9e9-bd90-7fb422417cc2"
    service = "vault"
}
api_addr =  "http://vault-server1:8200"
cluster_addr = "http://vault-server1:8201"