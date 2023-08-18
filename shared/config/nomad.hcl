# Values for server_count, retry_join, and ip_address are
# placed here during Terraform setup and come from the 
# ../shared/data-scripts/user-data-server.sh script

data_dir  = "/opt/nomad/data"
bind_addr = "0.0.0.0"
datacenter = "dc1"

advertise {
  http = "IP_ADDRESS"
  rpc  = "IP_ADDRESS"
  serf = "IP_ADDRESS"
}

acl {
  enabled = true
}

server {
  enabled          = true
  bootstrap_expect = SERVER_COUNT

  server_join {
    retry_join = ["IP_ADDRESS"]
  }
}

client {
  enabled = true
  options {
    "driver.raw_exec.enable"    = "1"
    "docker.privileged.enabled" = "true"
  }
  server_join {
    retry_join = ["IP_ADDRESS"]
  }

  host_volume "volume1" {
    path      = "/opt/nomad/host-volume1"
    read_only = false
  }

  host_volume "matomo" {
    path      = "/opt/nomad/host-volume-matomo"
    read_only = false
  }

  host_volume "volume_backup" {
    path      = "/opt/nomad/host-volume-backup"
    read_only = false
  }
}
