variable "db_name" {
  type = string
  description = "Database Name"
  default = "matomo"
}
variable "db_prefix" {
  type = string
  description = "Database Name"
  default = "matomo_"
}
variable "db_user" {
  type = string
  description = "Database Username"
  default = "matomo"
}
variable "db_pass" {
  type = string
  description = "Database Password"
}
variable "matomo_url" {
  type = string
  description = "URL (without protocol) to your matomo installation"
}

job "matomo" {
 datacenters = ["dc1"]
 type = "service" 

  group "matomo" {
    count = 1

    volume "matomo" {
      type      = "host"
      read_only = false
      source    = "matomo"
    }


    task "matomo-web" {
      driver = "docker"

      env = {
        // "MATOMO_DATABASE_HOST" = ""    <-- set by service discovery, see below
        "MATOMO_DATABASE_ADAPTER" = "mysql"
        "MATOMO_DATABASE_TABLES_PREFIX" = var.db_prefix
        "MATOMO_DATABASE_DBNAME" = var.db_name
        "MATOMO_DATABASE_USERNAME" = var.db_user
        "MATOMO_DATABASE_PASSWORD" = var.db_pass
      }

      volume_mount {
        volume      = "matomo"
        destination = "/var/www/html"
        read_only   = false
      }

      config {
        image = "matomo:4.15.1-apache"
        ports = ["web"]
      }

      service {
        name = "matomo-server"
        port = "web"

        tags = [
          "urlprefix-${var.matomo_url}/"
        ]

        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }

      template {
        data = <<EOH
{{ range nomadService "mariadb-server" }}
MATOMO_DATABASE_HOST={{ .Address }}:{{ .Port }}
MATOMO_DATABASE_HOSTNAME={{ .Address }}
MATOMO_DATABASE_PORT={{ .Port }}
{{ end }}
EOH
        destination = "local/env.txt"
        env         = true
      }
    }

    network {
      port "web" {
        to = 80
      }
    }

 }
}