#!/bin/bash

CONFIG_FILE=vault_config.hcl
VAULT_LOG=vault.log
CURRENT_SNAP=vault.snap
STORAGE_FOLDER="./vault/"
ADDRESS="http://127.0.0.1:8200"
VAULT_ADDR="http://127.0.0.1:8200"

function start_vault {

  printf "\n%s" \
    "Starting vault server" \
    "Creating storage folder: $STORAGE_FOLDER"\
    ""\
    ""

  if [ ! -d "$STORAGE_FOLDER" ]
  then
    mkdir $STORAGE_FOLDER
  fi

  vault server --log-level=trace -config "$CONFIG_FILE" > "$VAULT_LOG" 2>&1 &


  printf "\n%s" \
    "[vault] initializing and capturing the unseal key and root token" \
    ""\
    ""
  sleep 2 # Added for human readability

  INIT_RESPONSE=$(vault operator init -address="$ADDRESS" -format=json -key-shares 1 -key-threshold 1)

  UNSEAL_KEY=$(echo "$INIT_RESPONSE" | jq -r .unseal_keys_b64[0])
  VAULT_TOKEN=$(echo "$INIT_RESPONSE" | jq -r .root_token)

  echo "$UNSEAL_KEY" > unseal_key
  echo "$VAULT_TOKEN" > root_token

  printf "\n%s" \
    "[vault] Unseal key: $UNSEAL_KEY" \
    "[vault] Root token: $VAULT_TOKEN" \
    ""

  printf "\n%s" \
    "[vault] unsealing and logging in" \
    ""\
    ""

  sleep 2 # Added for human readability

  vault operator unseal -address="$ADDRESS" "$UNSEAL_KEY"
  vault login -address="$ADDRESS" "$VAULT_TOKEN"
}


function stop_vault {

  printf "\n%s" \
    "Stopping vault server" \
    "Deleting storage folder: $STORAGE_FOLDER"\
    "Deleting unseal_key and root_token"\
    "Unsetting VAULT_TOKEN, UNSEAL_KEY, VAULT_ADDR, VAULT_LOG environment variables"\
    ""

  kill $(ps aux | grep '[v]ault server' | awk '{print $2}')
  rm -rf $STORAGE_FOLDER
  rm unseal_key
  rm root_token
  rm $VAULT_LOG

  unset VAULT_TOKEN
  unset UNSEAL_KEY
  unset VAULT_ADDR
  unset VAULT_LOG
}


function save_snapshot {

  if [ -z "$1" ]
    then
      printf "\n%s" \
        "Please provide filename for snapshot to save."\
        "Eg ./raft.sh save mysnap.snap"\
        ""\
        ""
      exit 1
  fi

  printf "\n%s" \
    "Saving snapshot: $1" \
    ""\
    ""

  vault operator raft snapshot save -address="$ADDRESS"  "$1"
}


function restore_snapshot {

  if [ $# -ne 3 ]
    then
      printf "\n%s" \
        "Please provide snapshot filename to restore, and matching unseal key, and root token file."\
        "./raft.sh restore <snapshot_filename> <unseal_key_file> <root_token_file> "\
        ""\
        "./raft.sh restore mysnap.snapshot unseal_key root_token"\
        ""
      exit 1
  fi

  printf "\n%s" \
    "Restoring snapshot: $1"\
    ""\
    ""

  vault operator raft snapshot restore -address="$ADDRESS" -force $1

  export UNSEAL_KEY=$(cat $2)
  export VAULT_TOKEN=$(cat $3)

  printf "\n%s" \
    "Setting UNSEAL_KEY to token: $UNSEAL_KEY" \
    "Setting VAULT_TOKEN to token: $VAULT_TOKEN" \
    ""\
    ""

  printf "\n%s" \
    "Unsealing and logging in" \
    ""\
    ""

  vault operator unseal -address="$ADDRESS" "$UNSEAL_KEY"
  vault login -address="$ADDRESS" "$VAULT_TOKEN"
}


function backup_key_token {

  printf "\n%s" \
    "Backing up current unseal key: unseal_key.old"\
    "Backing up current root token: root_token.old"\
    ""\
    ""

  cp unseal_key unseal_key.old
  cp root_token root_token.old
}


function put_data {

  printf "\n%s" \
    "Entering mock data"\
    ""\
    ""

  vault secrets enable -address="$ADDRESS" -path=kv kv-v2
  vault kv put -address="$ADDRESS" /kv/apikey webapp=AAABBB238472320238CCC
}


function get_data {

  printf "\n%s" \
    "Get mock data"\
    ""\
    ""

  vault kv get -address="$ADDRESS" /kv/apikey
}

case "$1" in
  start)
    start_vault
    ;;
  stop)
    stop_vault
    ;;
  backup)
    backup_key_token
    ;;
  save)
    shift ;
    save_snapshot "$@"
    ;;
  restore)
    shift ;
    restore_snapshot "$@"
    ;;
  putdata)
    put_data
    ;;
  getdata)
    get_data
    ;;
  *)
    printf "\n%s" \
      "This script creates a single Vault instance using raft storage." \
      "" \
      "Usage: $0 [start|stop|backup|save|restore|putdata|getdata]" \
      ""
    ;;
esac


#vault secrets enable -path=kvDemo -version=2 kv
#vault kv put /kvDemo/legacy_app_creds_01 username=legacyUser password=supersecret

# Take snapshot, this should be done pointing to the active node
# Will get a 0-byte snapshot if not, as standby nodes will not forward this request (though this might be fixed in later ver)
#vault operator raft snapshot save raft01.snap
