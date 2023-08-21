terraform {
  required_version = ">= 0.12"
  required_providers {
    gridscale = {
      source = "gridscale/gridscale"
    }
  }
}

provider "gridscale" {
  uuid = var.gridscale_uuid
  token = var.gridscale_token
}

resource "gridscale_storage" "nomad-storage-main" {
  name = "${var.name}-storage-system"
  capacity = var.size_storage_system
  storage_type = var.speed_storage_system
  template {
    template_uuid = var.template_uuid
    sshkeys = [var.sshkey_uuid]
    hostname = var.name
  }
  timeouts {
    create="10m"
  }
}

resource "gridscale_ipv4" "nomad-ipv4" {
  name = "${var.name}-ipv4"
  timeouts {
      create="10m"
  }
}

resource "gridscale_ipv6" "nomad-ipv6" {
  name = "${var.name}-ipv6"
  timeouts {
      create="10m"
  }
}


resource "gridscale_server" "nomad-server" {
  name = "${var.name}-server"
  cores = var.server_cpu_cores
  memory = var.server_memory
  storage {
    object_uuid = gridscale_storage.nomad-storage-main.id
  }
  network {
    object_uuid = var.publicnet_uuid
    rules_v4_in {
        order = 0
        protocol = "tcp"
        action = "accept"
        dst_port = "22"
        comment = "ssh"
    }
    rules_v4_in {
        order = 0
        protocol = "tcp"
        action = "accept"
        dst_port = "80"
        comment = "http"
    }
    rules_v4_in {
        order = 0
        protocol = "tcp"
        action = "accept"
        dst_port = "443"
        comment = "https"
    }
    rules_v4_in {
        order = 1
        protocol = "tcp"
        action = "accept"
        dst_port = "4646"
        comment = "nomad UI"
    }
    rules_v4_in {
        order = 1
        protocol = "udp"
        action = "accept"
        dst_port = "4646"
        comment = "nomad UI udp for VNC connection"
    }
    rules_v4_in {
        order = 1
        protocol = "tcp"
        action = "accept"
        dst_port = "9998"
        comment = "fabio UI"
    }
    rules_v6_in    {
        order = 1
        protocol = "tcp"
        action = "accept"
        dst_port = "22"
        comment = "ssh"
    }
      rules_v6_in {
        order = 0
        protocol = "tcp"
        action = "accept"
        dst_port = "80"
        comment = "http"
    }
    rules_v6_in {
        order = 0
        protocol = "tcp"
        action = "accept"
        dst_port = "443"
        comment = "https"
    }
    rules_v6_in {
        order = 1
        protocol = "tcp"
        action = "accept"
        dst_port = "4646"
        comment = "nomad UI"
    }
    rules_v6_in {
        order = 1
        protocol = "udp"
        action = "accept"
        dst_port = "4646"
        comment = "nomad udp for VNC connection"
    }
    rules_v6_in {
        order = 1
        protocol = "tcp"
        action = "accept"
        dst_port = "9998"
        comment = "fabio UI"
    }
  }
  ipv4 = gridscale_ipv4.nomad-ipv4.id
  ipv6 = gridscale_ipv6.nomad-ipv6.id
  power = true


  user_data_base64 = base64encode(templatefile("../shared/data-scripts/user-data-server.sh", {
    server_count              = var.server_count
    cloud_env                 = "gridscale"
    nomad_version             = var.nomad_version
    consul_version            = var.consul_version
    CONSUL_VERSION            = var.consul_version
    public_ip                 = gridscale_ipv4.nomad-ipv4.ip
  }))


  timeouts {
      create="10m"
  }
}



resource "tls_private_key" "private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}





