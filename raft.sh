#!/bin/bash

# edit the domain to reflect the domain you choose to generate certificates
# This is only used for the cleanup function, should you need a quick way
# to remove all issued certificates stored in folders
DOMAIN="middleearth.test"

ROOT_DIR="./root_certs"
INTERMEDIATE_DIR="./intermediate_certs"
CONFIG_FILE=vault_config.hcl
VAULT_LOG=vault.log
STORAGE_FOLDER="./data"
ADDRESS="http://127.0.0.1:8200"
NO_TLS="-tls-skip-verify"
#VAULT_ADDR="http://127.0.0.1:8200"

# Define colors from env.sh
BLACK='\033[0;30m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # No Color

function stop_vault {

  echo -e "${CYAN}Checking for vault process running.${NC}"
  #VAULT_ID=$(pgrep -u "$USER" vault)
  #if [[ $? -eq 0 ]]; then
  if VAULT_ID=$(pgrep -u "$USER" vault); then
    echo -e "${RED}[ Stopping vault process ]${NC}"
    echo
    kill "$VAULT_ID"
  else
    echo -e "${YELLOW}Vault process not found.${NC}"
  fi

  echo -e "${CYAN}Checking if $STORAGE_FOLDER exists.${NC}"
  if [[ -d "$STORAGE_FOLDER" ]]; then
    echo -e "${RED}[ Deleting storage folder: $STORAGE_FOLDER ]${NC}"
    echo
    rm -rf $STORAGE_FOLDER
  fi

  echo -e "${CYAN}Checking if unseal_key exists.${NC}"
  if [[ -f unseal_key ]]; then
    echo -e "${RED}[ Deleting unseal_key, root_token, and vault.log ]${NC}"
    echo
    rm unseal_key
    rm root_token
    rm $VAULT_LOG
  fi

  echo
}

function start_vault {

  printf "\n${GREEN}%s${NC}" \
    "Removing any prior data or services before continuing..." \
    "" \
    ""

  stop_vault

  printf "\n${GREEN}%s${NC}" \
    "Starting vault" \
    "Cleaning up existing vault data created" \
    "Starting vault server" \
    "Creating storage folder: $STORAGE_FOLDER" \
    ""

  mkdir $STORAGE_FOLDER

  vault server --log-level=trace -config "$CONFIG_FILE" >"$VAULT_LOG" 2>&1 &

  printf "\n${GREEN}%s${NC}" \
    "Initializing and capturing the unseal key and root token" \
    ""
  sleep 2

  INIT_RESPONSE=$(vault operator init \
    -format=json -key-shares 1 -key-threshold 1)
  echo

  UNSEAL_KEY=$(echo "$INIT_RESPONSE" | jq -r .unseal_keys_b64[0])
  VAULT_TOKEN=$(echo "$INIT_RESPONSE" | jq -r .root_token)

  echo "$UNSEAL_KEY" >unseal_key
  echo "$VAULT_TOKEN" >root_token

  printf "\n${GREEN}%s${NC}" \
    "Unseal key: $UNSEAL_KEY" \
    "Root token: $VAULT_TOKEN" \
    "" \
    "Unsealing vault" \
    "" \
    ""

  vault operator unseal "$UNSEAL_KEY"
  sleep 2

  printf "\n${GREEN}%s${NC}" \
    "Logging into vault as root" \
    "" \
    ""

  vault login "${NO_TLS}" "$VAULT_TOKEN"

  xclip -selection clipboard root_token
  printf "\n${GREEN}%s${NC}" \
    "The root token has been copied to the system buffer" \
    "Root token:" \
    "$VAULT_TOKEN" \
    "" \
    "Use ctrl-v to paste" \
    "Use(paste) token at ${ADDRESS} via web browser, to login to vault GUI" \
    "" \
    ""
}

function save_snapshot {

  RANDOM_ID=$(openssl rand -hex 2)

  mkdir "backup_${RANDOM_ID}"

  printf "\n${CYAN}%s${NC}" \
    "Saving snapshot to: backup_${RANDOM_ID}/snapshot${RANDOM_ID}" \
    "Saving unseal key to: backup_${RANDOM_ID}/unseal_key${RANDOM_ID}" \
    "Saving root token to: backup_${RANDOM_ID}/root_token${RANDOM_ID}" \
    "" \
    ""

  vault operator raft snapshot save "backup_${RANDOM_ID}/snapshot${RANDOM_ID}"
  cp unseal_key "backup_$RANDOM_ID/unseal_key$RANDOM_ID"
  cp root_token "backup_${RANDOM_ID}/root_token${RANDOM_ID}"
}

function restore_snapshot {

  if [[ $# -ne 1 ]]; then
    printf "\n${RED}%s${NC}" \
      "Please provide snapshot folder." \
      "" \
      "Eg:./raft.sh restore backup_1a6e" \
      "" \
      ""
    exit 1
  fi

  # retrieve ID of backup folder - last four chars of the folder name
  ID=${1:7:4}

  printf "\n${CYAN}%s${NC}" \
    "Restoring vault from folder: $1" \
    "" \
    "Restoring snapshot from file backup_${ID}/snapshot${ID}" \
    "Using unseal token from file backup_${ID}/unseal_key${ID}" \
    "Using root token from file backup_${ID}/unseal_key${ID}" \
    ""

  # force restoration of the backup snapshot
  vault operator raft snapshot restore -force backup_"${ID}"/snapshot"${ID}"

  # copy backup unseal key and root token as current unseal key and root token
  # in other words copy to the current working directory
  cp "backup_$ID/unseal_key$ID" unseal_key
  cp "backup_$ID/root_token$ID" root_token

  UNSEAL_KEY=$(cat "backup_$ID/unseal_key$ID")
  VAULT_TOKEN=$(cat "backup_$ID/root_token$ID")

  printf "\n${CYAN}%s${NC}" \
    "Setting UNSEAL_KEY to key: $UNSEAL_KEY" \
    "Setting VAULT_TOKEN to token: $VAULT_TOKEN" \
    "" \
    "Unsealing and logging in" \
    "" \
    ""

  vault operator "${NO_TLS}" unseal "$UNSEAL_KEY"
  vault login "${NO_TLS}" "$VAULT_TOKEN"

  xclip -selection clipboard root_token
  printf "\n${CYAN}%s${NC}" \
    "The root token is copied to the system buffer" \
    "Root token:" \
    "$VAULT_TOKEN" \
    "" \
    "Use ctrl-v to paste" \
    "Paste the token at ${ADDRESS} via web browser, to login to the Vault GUI" \
    ""
  source ./env.sh
}

function put_data {

  printf "\n${MAGENTA}%s${NC}" \
    "Entering mock data" \
    "" \
    ""

  vault secrets enable -path=kv kv-v2
  vault kv put /kv/apikey webapp=AAABBB238472320238CCC
}

function get_data {

  printf "\n${MAGENTA}%s${NC}" \
    "Fetching mock data" \
    "" \
    ""

  vault kv get /kv/apikey
}

function clean_all {

  stop_vault

  echo -e "${CYAN}Checking for root and intermediate certificate folder:\
        ${ROOT_DIR}${NC}"
  if [[ -d "${ROOT_DIR}" ]]; then
    echo -e "${RED}[ Removing root and intermediate certificates folder:\
        ${ROOT_DIR} ]${NC}"
    echo
    rm -rf "${ROOT_DIR}"
  fi

  echo -e "${CYAN}Checking for root and intermediate certificate folder:\
        ${INTERMEDIATE_DIR}${NC}"
  if [[ -d "${INTERMEDIATE_DIR}" ]]; then
    echo -e "${RED}[ Removing root and intermediate certificates folder:\
        ${INTERMEDIATE_DIR} ]${NC}"
    echo
    rm -rf "${INTERMEDIATE_DIR}"
  fi

  echo -e "${CYAN}Checking for any *.${DOMAIN} folders${NC}"
  if compgen -G "*.${DOMAIN}" >/dev/null; then
    echo -e "${RED}[ Removing *.${DOMAIN} folders ]${NC}"
    echo
    rm -rf ./*."${DOMAIN}"
  else
    echo -e "${YELLOW}No *.${DOMAIN} folders found.${NC}"
  fi

  echo -e "${CYAN}Checking for any backup folders${NC}"
  if compgen -G "backup_*" >/dev/null; then
    echo -e "${RED}[ Removing backup_* folders ]${NC}"
    echo
    rm -rf ./backup_*
  else
    echo -e "${YELLOW}No backup folders found.${NC}"
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
      shift
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
      printf "\n${YELLOW}%s${NC}" \
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
