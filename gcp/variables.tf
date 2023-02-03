variable "project" {
  description = "The GCP project to use."
}

variable "region" {
  description = "The GCP region to deploy to."
}

variable "zone" {
  description = "The GCP zone to deploy to."
}

variable "name" {
  description = "Prefix used to name various infrastructure components. Alphanumeric characters only."
  default     = "nomad"
}

variable "retry_join" {
  description = "Used by Consul to automatically form a cluster."
  type        = string
}

variable "allowlist_ip" {
  description = "IP to allow access for the security groups (set 0.0.0.0/0 for world)"
  default     = "0.0.0.0/0"
}

variable "server_instance_type" {
  description = "The compute engine instance type to use for servers."
  default     = "e2-medium"
}

variable "client_instance_type" {
  description = "The compute engine instance type to use for clients."
  default     = "e2-medium"
}

variable "server_count" {
  description = "The number of servers to provision."
  default     = "3"
}

variable "client_count" {
  description = "The number of clients to provision."
  default     = "2"
}

variable "root_block_device_size" {
  description = "The volume size of the root block device."
  default     = 20
}

variable "nomad_binary" {
  description = "URL of a zip file containing a nomad executable to replace the Nomad binaries in the AMI with. Example: https://releases.hashicorp.com/nomad/0.10.0/nomad_0.10.0_linux_amd64.zip"
  default     = ""
}