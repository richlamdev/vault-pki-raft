#!/bin/bash

CONFIG_FILE=vault_config.hcl
VAULT_LOG=vault.log
CURRENT_SNAP=vault.snap
STORAGE_FOLDER="./data"
ADDRESS="http://127.0.0.1:8200"
#VAULT_ADDR="http://127.0.0.1:8200"


function stop_vault {

  echo "Checking for vault process running."
  VAULT_ID=$(pgrep -u $USER vault)
  VAULT_ID_STATUS=$?
  if [ $VAULT_ID_STATUS -eq 0 ]; then
      echo "Stopping vault process"
      echo
      kill $VAULT_ID
  fi

  echo "Checking if $STORAGE_FOLDER exists."
  if [ -d "$STORAGE_FOLDER" ]; then
      echo "Deleting storage folder: $STORAGE_FOLDER"
      echo
      rm -rf $STORAGE_FOLDER
  fi

  echo "Checking if unseal_key exists."
  if [ -f unseal_key ]; then
      echo "Deleting unseal_key, root_token, and vault.log"
      echo
      rm unseal_key
      rm root_token
      rm $VAULT_LOG
  fi

  echo "Checking for existance of root and intermediate certificate folder: root_inter_certs"
  if [ -d "root_inter_certs" ]; then
      echo "Removing root and intermediate certificates folder: root_inter_certs"
      echo
      rm -rf root_inter_certs
  fi

  echo "Checking for the existence of any *.middleearth.test folders"
  CERTS_EXISTS=$(ls *middleearth.test 1> /dev/null 2>&1)
  CERTS_EXISTS_STATUS=$?
  if [ $CERTS_EXISTS_STATUS -eq 0 ]; then
      echo "Removing *.middleearth.test folders"
      echo
      rm -rf *.middleearth.test
  fi

  echo
}


function start_vault {

  printf "\n%s"\
      ""\
      "Removing any prior data or services before continuing..."\
      ""\

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

  if [ $# -ne 3 ]; then
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


function clean_all {

  stop_vault

  printf "\n%s" \
      "Checking for existance of root and intermediate certificate folder: root_inter_certs"\
      "Checking for the existence of any *.middleearth.test folders"\
      ""\
      ""

  if [ -d "root_inter_certs" ]; then
      echo "Removing root and intermediate certificates folder: root_inter_certs"
      rm -rf root_inter_certs
  fi

  CERTS_EXISTS=$(ls *middleearth.test 1> /dev/null 2>&1)
  CERTS_EXISTS_STATUS=$?
  if [ $CERTS_EXISTS_STATUS -eq 0 ]; then
      echo "Removing *.middleearth.test folders"
      echo
      rm -rf *.middleearth.test
  fi
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
    cleanup)
      clean_all
      ;;
    *)
      printf "\n%s" \
          "This script creates a single Vault instance using raft storage." \
          "" \
          "Usage: $0 [start|stop|save|restore|status|cleanup|putdata|getdata]" \
          ""
      ;;
esac


#vault secrets enable -path=kvDemo -version=2 kv
#vault kv put /kvDemo/legacy_app_creds_01 username=legacyUser password=supersecret

# Take snapshot, this should be done pointing to the active node
# Will get a 0-byte snapshot if not, as standby nodes will not forward this request (though this might be fixed in later ver)
#vault operator raft snapshot save raft01.snap
