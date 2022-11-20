#!/bin/bash

# edit the domain to reflect the domain you choose to generate certificates
# This is only used for the cleanup function, should you need a quick way
# to remove all issued certificates stored in folders
DOMAIN="middleearth.test"

ROOT_INTER_DIR="./root_inter_certs"
CONFIG_FILE=vault_config.hcl
VAULT_LOG=vault.log
STORAGE_FOLDER="./data"
ADDRESS="http://127.0.0.1:8200"
NO_TLS="-tls-skip-verify"
#VAULT_ADDR="http://127.0.0.1:8200"


function stop_vault {

  echo "Checking for vault process running."
  VAULT_ID=$(pgrep -u $USER vault)
  if [[ $? -eq 0 ]]; then
    echo "[ Stopping vault process ]"
    echo
    kill $VAULT_ID
  fi

  echo "Checking if $STORAGE_FOLDER exists."
  if [[ -d "$STORAGE_FOLDER" ]]; then
    echo "[ Deleting storage folder: $STORAGE_FOLDER ]"
    echo
    rm -rf $STORAGE_FOLDER
  fi

  echo "Checking if unseal_key exists."
  if [[ -f unseal_key ]]; then
    echo "[ Deleting unseal_key, root_token, and vault.log ]"
    echo
    rm unseal_key
    rm root_token
    rm $VAULT_LOG
  fi

  echo
}


function start_vault {

  printf "\n%s"\
    "Removing any prior data or services before continuing..."\
    ""\
    ""

  stop_vault

  printf "\n%s" \
    "Starting vault"\
    "Cleaning up existing vault data created"\
    "Starting vault server"\
    "Creating storage folder: $STORAGE_FOLDER"\
    ""\

  mkdir $STORAGE_FOLDER

  vault server --log-level=trace -config "$CONFIG_FILE" > "$VAULT_LOG" 2>&1 &

  printf "\n%s" \
    "Initializing and capturing the unseal key and root token" \
    ""
  sleep 1

  INIT_RESPONSE=$(vault operator init \
                  -format=json -key-shares 1 -key-threshold 1)
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

  vault operator unseal "$UNSEAL_KEY"
  vault login "$VAULT_TOKEN"

  xclip -selection clipboard root_token
  printf "\n%s"\
    "The root token has been copied to the system buffer"\
    "Root token:"\
    "$VAULT_TOKEN"\
    ""\
    "Use ctrl-v to paste"\
    "Use(paste) token at ${ADDRESS} via web browser, to login to vault GUI"\
    ""\
    ""
}


function save_snapshot {

  RANDOM_ID=$(openssl rand -hex 2)

  mkdir "backup_${RANDOM_ID}"

  printf "\n%s" \
    "Saving snapshot to: backup_${RANDOM_ID}/snapshot${RANDOM_ID}"\
    "Saving unseal key to: backup_${RANDOM_ID}/unseal_key${RANDOM_ID}"\
    "Saving root token to: backup_${RANDOM_ID}/root_token${RANDOM_ID}"\
    ""\
    ""

  vault operator raft snapshot save "backup_${RANDOM_ID}/snapshot${RANDOM_ID}"
  cp unseal_key "backup_$RANDOM_ID/unseal_key$RANDOM_ID"
  cp root_token "backup_${RANDOM_ID}/root_token${RANDOM_ID}"
}


function restore_snapshot {

  if [[ $# -ne 1 ]]; then
    printf "\n%s" \
      "Please provide snapshot folder."\
      ""\
      "Eg:./raft.sh restore backup_1a6e"\
      ""\
      ""
    exit 1
  fi

  # retrieve ID of backup folder - last four chars of the folder name
  ID=${1:7:4}

  printf "\n%s" \
    "Restoring vault from folder: $1"\
    ""\
    "Restoring snapshot from file backup_${ID}/snapshot${ID}"\
    "Using unseal token from file backup_${ID}/unseal_key${ID}"\
    "Using root token from file backup_${ID}/unseal_key${ID}"\
    ""

  # force restoration of the backup snapshot
  vault operator raft snapshot restore -force backup_"${ID}"/snapshot"${ID}"

  # copy backup unseal key and root token as current unseal key and root token
  # in other words copy to the current working directory
  cp backup_$ID/unseal_key$ID unseal_key
  cp backup_$ID/root_token$ID root_token

  UNSEAL_KEY=$(cat backup_$ID/unseal_key$ID)
  VAULT_TOKEN=$(cat backup_$ID/root_token$ID)

  printf "\n%s" \
    "Setting UNSEAL_KEY to key: $UNSEAL_KEY" \
    "Setting VAULT_TOKEN to token: $VAULT_TOKEN" \
    ""\
    "Unsealing and logging in" \
    ""\
    ""

  vault operator unseal "$UNSEAL_KEY"
  vault login "$VAULT_TOKEN"

  xclip -selection clipboard root_token
  printf "\n%s"\
    "The root token is copied to the system buffer"\
    "Root token:"\
    "$VAULT_TOKEN"\
    ""\
    "Use ctrl-v to paste"\
    "Paste the token at ${ADDRESS} via web browser, to login to the Vault GUI"\
    ""
  source ./env.sh
}


function put_data {

  printf "\n%s" \
    "Entering mock data"\
    ""\
    ""

  vault secrets enable -path=kv kv-v2
  vault kv put /kv/apikey webapp=AAABBB238472320238CCC
}


function get_data {

  printf "\n%s" \
    "Fetching mock data"\
    ""\
    ""

  vault kv get /kv/apikey
}




function clean_all {

  stop_vault

  echo "Checking for root and intermediate certificate folder:\
        ${ROOT_INTER_DIR}"
  if [[ -d "${ROOT_INTER_DIR}" ]]; then
    echo "[ Removing root and intermediate certificates folder:\
        ${ROOT_INTER_DIR} ]"
    echo
    rm -rf "${ROOT_INTER_DIR}"
  fi

  echo "Checking for any *.${DOMAIN} folders"
  CERTS_EXISTS=$(ls *${DOMAIN} 1> /dev/null 2>&1)
  if [[ $? -eq 0 ]]; then
    echo "[ Removing *.${DOMAIN} folders ]"
    echo
    rm -rf *."${DOMAIN}"
  fi

  echo "Checking for any backup folders"
  BACKUPS_EXISTS=$(ls backup_* 1> /dev/null 2>&1)
  if [[ $? -eq 0 ]]; then
    echo "[ Removing backup_* folders ]"
    echo
    rm -rf backup_*
  fi

  echo
}

function main {

  source ./env.sh

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
    cleanup)
      clean_all
      ;;
    *)
      printf "\n%s" \
        "This script creates a single Vault instance using raft storage." \
        "" \
        "Usage: $0 [start|stop|save|restore|cleanup|putdata|getdata]" \
        ""
      ;;
  esac
}

main "$@"

#vault secrets enable -path=kvDemo -version=2 kv
#vault kv put /kvDemo/legacy_app_creds_01 username=legacyUser password=supersecret

# Take snapshot, this should be done pointing to the active node
# Will get a 0-byte snapshot if not, as standby nodes will not forward this request (though this might be fixed in later ver)
#vault operator raft snapshot save raft01.snap
