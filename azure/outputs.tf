output "lb_address_consul_nomad" {
  value = "http://${azurerm_linux_virtual_machine.server[0].public_ip_address}"
}

# output "consul_bootstrap_token_secret" {
#   value = var.nomad_consul_token_secret
# }

output "IP_Addresses" {
  value = <<CONFIGURATION

It will take a little bit for setup to complete and the UI to become available.
Once it is, you can access the Nomad UI at:

http://${azurerm_linux_virtual_machine.server[0].public_ip_address}:4646/ui

Set the Nomad address, run the bootstrap, export the management token, set the token variable, and test connectivity:

export NOMAD_ADDR=http://${azurerm_linux_virtual_machine.server[0].public_ip_address}:4646 && \
nomad acl bootstrap | grep -i secret | awk -F "=" '{print $2}' | xargs > nomad-management.token && \
export NOMAD_TOKEN=$(cat nomad-management.token) && \
nomad server members

Copy the token value and use it to log in to the UI:

cat nomad-management.token
CONFIGURATION
}

# ssh -i tf-key.pem ubuntu@INSTANCE_PUBLIC_IP
output "private_key" {
  value     = tls_private_key.private_key.private_key_pem
  sensitive = true
}