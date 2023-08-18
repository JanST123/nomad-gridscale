job "fabio" {
  datacenters = ["dc1"]
  type = "system"

  group "fabio" {
    network {
      port "lb" {
        static = 9999
      }
      port "http" {
        static = 80
      }
      port "https" {
        static = 443
      }
      port "ui" {
        static = 9998
      }
    }
    task "fabio" {
      driver = "docker"
      config {
        image = "fabiolb/fabio"
        network_mode = "host"
        ports = ["lb","ui","http","https"]
      }
      env {
        proxy_addr = ":80;proto=http,:443;cs=consul"
        proxy_cs = "cs=consul;type=consul;cert=http://127.0.0.1:8500/v1/kv/certs/active"
        insecure = "1"
      }

      resources {
        cpu    = 200
        memory = 128
      }
    }
  }
}
