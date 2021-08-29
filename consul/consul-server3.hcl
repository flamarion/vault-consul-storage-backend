datacenter = "dc1"
node_name = "consul-server3"
server = true
ui_config {
  enabled = true
}
data_dir = "/opt/consul"
retry_join = ["consul-server1", "consul-server2", "consul-server3"]
bootstrap_expect = 3
encrypt = "YPXR+ci3gyAlm3Cp3XrxdmVio7ZpUBy478NzvtlYZ7g="
ca_file = "/etc/consul.d/certs/consul-agent-ca.pem"
cert_file = "/etc/consul.d/certs/dc1-server-consul-0.pem"
key_file = "/etc/consul.d/certs/dc1-server-consul-0-key.pem"
verify_incoming = true
verify_outgoing = true
verify_server_hostname = true
addresses {
  http = "0.0.0.0"
}
performance {
  raft_multiplier = 1
}
client_addr = "0.0.0.0"
connect {
  enabled = true
}
acl {
  enabled = true
  default_policy = "deny"
  enable_token_persistence = true
  tokens {
    agent = "4e4e9e02-78cf-05c2-4848-bd9ab6c71c2a"
  }
}