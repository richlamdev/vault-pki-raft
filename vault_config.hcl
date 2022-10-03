storage "raft" {
  path = "./data/"
  node_id = "01"
}

listener "tcp" {
  address = "127.0.0.1:8200"
  tls_disable = true
}

ui=true
disable_mlock = true
cluster_addr = "http://127.0.0.1:8201"
api_addr = "http://127.0.0.1:8200"
