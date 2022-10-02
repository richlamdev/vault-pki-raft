#!/bin/bash

CONFIG_FILE=vault_config.hcl
VAULT_LOG=vault.log
CURRENT_SNAP=vault.snap
STORAGE_FOLDER="./data"
ADDRESS="http://127.0.0.1:8200"
#VAULT_ADDR="http://127.0.0.1:8200"


function stop_vault () {

  printf "\n%s" \
    "Stopping vault"\

  VAULT_ID=$(pgrep -u $USER vault)
  if [ -n "${VAULT_ID}" ]; then
      echo
      echo "Stopping vault process"
      kill $VAULT_ID
  fi

  #kill $(ps aux | grep '[v]ault server' | awk '{print $2}')

  if [ -d "$STORAGE_FOLDER" ]; then
    echo "Deleting storage folder: $STORAGE_FOLDER"
    rm -rf $STORAGE_FOLDER
  fi

  #rm -rf $STORAGE_FOLDER

  if [ -f unseal_key ]; then
    echo "Deleting unseal_key, root_token, and vault.log"
    echo
    rm unseal_key
    rm root_token
    rm $VAULT_LOG
  fi
}


function start_vault {

  stop_vault

  printf "\n%s" \
    "Starting vault"\
    "Cleaning up existing vault data created"\
    "Starting vault server"\
    "Creating storage folder: $STORAGE_FOLDER"\
    ""\

  mkdir $STORAGE_FOLDER

  vault server -address=$ADDRESS --log-level=trace -config "$CONFIG_FILE" > "$VAULT_LOG" 2>&1 &

  printf "\n%s" \
    "Initializing and capturing the unseal key and root token" \
    ""
  sleep 1

  INIT_RESPONSE=$(vault operator init -address="$ADDRESS" -format=json -key-shares 1 -key-threshold 1)
  echo

  UNSEAL_KEY=$(echo "$INIT_RESPONSE" | jq -r .unseal_keys_b64[0])
  VAULT_TOKEN=$(echo "$INIT_RESPONSE" | jq -r .root_token)

  echo "$UNSEAL_KEY" > unseal_key
  echo "$VAULT_TOKEN" > root_token

  printf "\n%s"\
    "Unseal key: $UNSEAL_KEY"\
    "Root token: $VAULT_TOKEN"\
    ""\
    "Unsealing and logging in"\
    ""

  vault operator unseal -address="$ADDRESS" "$UNSEAL_KEY"
  vault login -address="$ADDRESS" "$VAULT_TOKEN"

  xclip -selection clipboard root_token
  printf "\n%s"\
    "The root token is copied to the system buffer"\
    "Root token:"\
    "$VAULT_TOKEN"\
    ""\
    "Use ctrl-shift-v to paste"\
    "Paste in as Token at http://127.0.0.1:8200 via web browser"\
    ""
}


function save_snapshot {

  RANDOM_ID=$(openssl rand -hex 2)

  mkdir "backup_$RANDOM_ID"

  printf "\n%s" \
    "Saving snapshot to: backup_$RANDOM_ID/snapshot$RANDOM_ID" \
    "Backing up current unseal key: backup_$RANDOM_ID/unseal_key$RANDOM_ID"\
    "Backing up current root token: backup_$RANDOM_ID/root_token$RANDOM_ID"\
    ""\
    ""

  vault operator raft snapshot save -address="$ADDRESS" "backup_$RANDOM_ID/snapshot$RANDOM_ID"
  cp unseal_key "backup_$RANDOM_ID/unseal_key$RANDOM_ID"
  cp root_token "backup_$RANDOM_ID/root_token$RANDOM_ID"
}


function restore_snapshot {

  if [ $# -ne 3 ]
    then
      printf "\n%s" \
        "Please provide snapshot, matching unseal key, and root token filenames."\
        "./raft.sh restore <snapshot_file> <unseal_key_file> <root_token_file>"\
        ""\
        "./raft.sh restore snapshot_XXXX unseal_key_XXXX root_token_XXXX"\
        ""
      exit 1
  fi

  printf "\n%s" \
    "Restoring vault: $1"\
    ""\
    ""

  vault operator raft snapshot restore -address="$ADDRESS" -force $1

  # copy restored unseal key and root token as current unseal key and root token
  cp $2 unseal_key
  cp $3 root_token

  UNSEAL_KEY=$(cat $2)
  VAULT_TOKEN=$(cat $3)

  printf "\n%s" \
    "Setting UNSEAL_KEY to key: $UNSEAL_KEY" \
    "Setting VAULT_TOKEN to token: $VAULT_TOKEN" \
    ""\
    "Unsealing and logging in" \
    ""\
    ""

  vault operator unseal -address="$ADDRESS" "$UNSEAL_KEY"
  vault login -address="$ADDRESS" "$VAULT_TOKEN"

  xclip -selection clipboard root_token
  printf "\n%s"\
    "The root token is copied to the system buffer"\
    "Root token:"\
    "$VAULT_TOKEN"\
    ""\
    "Use ctrl-shift-v to paste"\
    "Paste in as Token at http://127.0.0.1:8200 via web browser"\
    ""
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
    "Fetching mock data"\
    ""\
    ""

  vault kv get -address="$ADDRESS" /kv/apikey
}


function get_status {

  printf "\n%s" \
    "vault status"\
    ""\
    ""

  vault status -address="$ADDRESS"
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
    save_snapshot
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
  status)
    get_status
    ;;
  *)
    printf "\n%s" \
      "This script creates a single Vault instance using raft storage." \
      "" \
      "Usage: $0 [start|stop|save|restore|status|putdata|getdata]" \
      ""
    ;;
esac


#vault secrets enable -path=kvDemo -version=2 kv
#vault kv put /kvDemo/legacy_app_creds_01 username=legacyUser password=supersecret

# Take snapshot, this should be done pointing to the active node
# Will get a 0-byte snapshot if not, as standby nodes will not forward this request (though this might be fixed in later ver)
#vault operator raft snapshot save raft01.snap
