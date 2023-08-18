variable "email_address" {
    type = string
    description = "your email adress for the lets encrypt certificate authority"
  }
  variable "nomad_token" {
    type = string
    description = "nomad development token, required to start the challenge-responder job"
  }

job "aleff" {
  datacenters = ["dc1"]
  type = "system"

  group "processor" {
    # Only one instance of aleff can run at once.
    count = 1

    ephemeral_disk {
      size = 10
    }

    task "processor" {
      driver = "docker"

      config {
        image = "stut/aleff:latest"
        force_pull = true
        network_mode = "host"
      }

      env {
        # How frequently to check for new domains and pending renewals.
        RUN_INTERVAL = "24h"

        # Location of the challenge responder job definition file (see template below).
        CHALLENGE_RESPONDER_JOB_FILENAME = "local/challenge-responder.hcl"

        # Requires access to both Nomad and Consul so set up any URLs, tokens, etc in the environment.
        NOMAD_ADDR = "http://localhost:4646"
        NOMAD_TOKEN = var.nomad_token
        CONSUL_HTTP_ADDR = "http://localhost:8500"
        EMAIL_ADDRESS = var.email_address
      }

      resources {
        cpu    = 8
        memory = 16
      }

      logs {
        max_files     = 1
        max_file_size = 5
      }

      template {
        destination = "local/challenge-responder.hcl"
        data = <<EOH
job "aleff-challenge-responder" {
  datacenters = ["dc1"]
  type = "system"

  group "responder" {
    count = 1

    network {
      port "http" {}
    }

    ephemeral_disk {
      size = 10
    }

    task "server" {
      driver = "docker"

      config {
        image      = "stut/aleff-challenge-responder:latest"
        force_pull = true
        network_mode = "host"
        ports      = ["http"]
      }

      env {
        # Requires access to Consul so set up any URLs, tokens, etc in the environment.
        CONSUL_HTTP_ADDR = "http://localhost:8500"
      }

      resources {
        cpu    = 8
        memory = 16
      }

      logs {
        max_files     = 1
        max_file_size = 5
      }

      service {
        # The necessary urlprefix- tag will be added by aleff before deploying this service.
        tags = []
        port = "http"
        check {
          type     = "http"
          port     = "http"
          path     = "/.well-known/acme-challenge/health"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
EOH
      }
    }
  }
}

