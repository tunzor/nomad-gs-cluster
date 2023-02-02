# Values for SERVER_COUNT, RETRY_JOIN, and IP_ADDRESS are
# placed here during Terraform setup and come from the 
# ../shared/data-scripts/user-data-server.sh script

data_dir  = "/opt/nomad/data"
bind_addr = "0.0.0.0"

server {
  enabled          = true
  bootstrap_expect = SERVER_COUNT

  server_join {
    retry_join = ["RETRY_JOIN"]
  }
}

client {
  enabled       = true
}

log_level = "debug"

consul {
  auto_advertise      = false
  server_auto_join    = false
  client_auto_join    = false
}

acl {
  enabled = true
}

advertise {
  http = "IP_ADDRESS"
  rpc  = "IP_ADDRESS"
  serf = "IP_ADDRESS"
}