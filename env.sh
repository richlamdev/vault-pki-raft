### issue_cert_template.sh variables
HOST_STRING="${1:-$HOST_STRING}"
SLD_STRING="middleearth"
TLD_STRING="test"
DOMAIN_STRING="${SLD_STRING}.${TLD_STRING}"
SUBJECT_CN="${HOST_STRING}.${DOMAIN_STRING}"
ISSUER_NAME_CN_STRING="Lord of the Rings"
IP_SAN1="127.0.0.1"
ALT_NAME1="${SUBJECT_CN}"
IP_SAN2_STRING="192.168.70.33"
#ALT_NAME2_STRING=""
TTL="9528h"

### create_root_inter_certs.sh variables
DOMAIN="$DOMAIN_STRING"
ISSUER_NAME_CN="$ISSUER_NAME_CN_STRING"
CN_ROOT="${ISSUER_NAME_CN} Root Certificate Authority"
CN_INTER="${ISSUER_NAME_CN} Intermediate Certificate Authority"
CN_ROOT_NO_SPACE="${CN_ROOT// /_}"
CN_INTER_NO_SPACE="${CN_INTER// /_}"

### common variables
# VAULT_ROLE_STRING="common_vault_role"
export VAULT_ADDR="http://127.0.0.1:8200"
VAULT_ROLE="common_vault_role"
NO_TLS="-tls-skip-verify"
KEY_TYPE="ec"
KEY_BITS="384"
ROOT_DIR="./root_certs"
INTERMEDIATE_DIR="./intermediate_certs"

# Define color codes
BLACK='\033[0;30m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # No Color
