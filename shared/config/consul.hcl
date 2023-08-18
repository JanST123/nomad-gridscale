datacenter = "dc1"
data_dir = "/opt/consul"
encrypt = "CONSUL_KEY"
tls = {
  defaults = {
    ca_file = "/etc/consul.d/consul-agent-ca.pem"
    cert_file = "/etc/consul.d/dc1-server-consul-0.pem"
    key_file = "/etc/consul.d/dc1-server-consul-0-key.pem"
    verify_incoming = true
    verify_outgoing = true
  }
  internal_rpc = {
    verify_server_hostname = true
  }
}
retry_join = ["IP_ADDRESS"]
bind_addr = "0.0.0.0"

acl = {
  enabled = true
  default_policy = "allow"
  enable_token_persistence = true
}

performance {
  raft_multiplier = 1
}