output "lb_address_consul_nomad" {
  value = "http://${aws_instance.server[0].public_ip}"
}

output "consul_bootstrap_token_secret" {
  value = var.nomad_consul_token_secret
}

output "IP_Addresses" {
  value = <<CONFIGURATION



Server public IPs: ${join(", ", aws_instance.server[*].public_ip)}

The Nomad UI can be accessed at http://${aws_instance.server[0].public_ip}:4646/ui
with the bootstrap token: ${var.nomad_consul_token_secret}
CONFIGURATION
}
