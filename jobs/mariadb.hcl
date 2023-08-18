variable "root_pw" {
  type = string
  description = "root password for mariaDB"
}

job "mariadb" {
  datacenters = ["dc1"]
  type        = "service"

  group "mariadb" {
    count = 1

    volume "volume1" {
      type      = "host"
      read_only = false
      source    = "volume1"
    }

    restart {
      attempts = 10
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }

    task "mariadb-server" {
      driver = "docker"

      volume_mount {
        volume      = "volume1"
        destination = "/var/lib/mysql"
        read_only   = false
      }

      env = {
        "MARIADB_ROOT_PASSWORD" = var.root_pw
      }

      config {
        image = "mariadb:11"

        ports = ["db"]
      }

      resources {
        cpu    = 500
        memory = 1024
      }

      service {
        name = "mariadb-server"
        port = "db"
        provider = "nomad"

        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
    network {
      port "db" {
        to = 3306
      }
    }


  }
}