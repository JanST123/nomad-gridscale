variable "name" {
  description = "Prefix used to name various infrastructure components. Alphanumeric characters only."
  default     = "nomad"
}

variable "server_count" {
  description = "The number of servers to provision."
  default     = "3"
}

variable "nomad_version" {
  description = "The version of the Nomad binary to install."
  default     = "1.6.1"
}

variable "consul_version" {
  description = "The version of the Consul binary to install."
  default     = "1.16.1"
}

variable "gridscale_uuid" {
  description = "User UUID of gridscale user"
}
variable "gridscale_token" {
  description = "API token of gridscale user"
}

variable "size_storage_system" {
  description = "Size in GB of the system storage"
  default = 10
}

variable "speed_storage_system" {
  description = "Speed of the system storage (storage, storage_high or storage_insane)"
  default = "storage_high"
}

variable "sshkey_uuid" {
  description = "UUID of the gridscale SSH key that should be added to the server"
}

variable "publicnet_uuid" {
  description = "UUID of the gridscale public network"
}

variable "server_cpu_cores" {
  description = "number of cpu cores for server"
  default = 2
}

variable "server_memory" {
  description = "memory in GB for server"
  default = 2
}