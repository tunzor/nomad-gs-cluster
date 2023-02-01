data_dir  = "/opt/nomad/data"
bind_addr = "0.0.0.0"

# Enable the server
server {
  enabled          = true
  bootstrap_expect = SERVER_COUNT
}

client {
  enabled       = true
}

// consul {
//   address = "127.0.0.1:8500"
//   token = "CONSUL_TOKEN"
// }

consul {
  auto_advertise      = false
  server_auto_join    = false
  client_auto_join    = false
}


server_join {
  retry_join = ["RETRY_JOIN"]
}

acl {
  enabled = true
}

advertise {
  http = "PUBLIC_IP"
  rpc  = "PUBLIC_IP"
  serf = "PUBLIC_IP"
}

// vault {
//   enabled          = false
//   address          = "http://active.vault.service.consul:8200"
//   task_token_ttl   = "1h"
//   create_from_role = "nomad-cluster"
//   token            = ""
// }