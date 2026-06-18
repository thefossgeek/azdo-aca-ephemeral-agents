#!/bin/bash
set -e

if [ -z "${AZP_URL}" ]; then
  echo 1>&2 "error: missing AZP_URL environment variable"
  exit 1
fi

# Acquire ADO access token via ACA managed identity endpoint — no Azure CLI needed.
# ACA injects IDENTITY_ENDPOINT and IDENTITY_HEADER automatically when a UAMI is assigned.
if [ -n "${USRMI_ID}" ]; then
  APPLICATION_ID="499b84ac-1321-427f-aa17-267ca6975798"

  AZP_TOKEN=$(curl -sf \
    -H "X-IDENTITY-HEADER: ${IDENTITY_HEADER}" \
    "${IDENTITY_ENDPOINT}?api-version=2019-08-01&resource=${APPLICATION_ID}&client_id=${USRMI_ID}" \
    | jq -r '.access_token')

  if [ -z "${AZP_TOKEN}" ] || [ "${AZP_TOKEN}" = "null" ]; then
    echo 1>&2 "error: failed to get access token from managed identity endpoint"
    exit 1
  fi

  echo "Access token acquired via managed identity"
fi

if [ -z "${AZP_TOKEN_FILE}" ]; then
  if [ -z "${AZP_TOKEN}" ]; then
    echo 1>&2 "error: missing AZP_TOKEN environment variable"
    exit 1
  fi
  AZP_TOKEN_FILE="/azp/.token"
  echo -n "${AZP_TOKEN}" > "${AZP_TOKEN_FILE}"
fi

unset AZP_TOKEN

[ -n "${AZP_WORK}" ] && mkdir -p "${AZP_WORK}"

print_header() {
  echo -e "\n\033[1;36m$1\033[0m\n"
}

cleanup() {
  if [ -e ./config.sh ]; then
    print_header "Cleanup: deregistering agent..."
    while true; do
      ./config.sh remove --unattended --auth PAT --token "$(cat "${AZP_TOKEN_FILE}")" && break
      echo "Retrying in 30 seconds..."
      sleep 30
    done
  fi
}

export VSO_AGENT_IGNORE="AZP_TOKEN,AZP_TOKEN_FILE"

# env.sh is extracted from the agent package at image build time
source ./env.sh

trap "cleanup; exit 0"   EXIT
trap "cleanup; exit 130" INT
trap "cleanup; exit 143" TERM

print_header "1. Configuring Azure Pipelines agent..."

_AGENT_NAME=${AZP_AGENT_NAME:-${AZP_AGENT_NAME_PREFIX:-azure-devops-agent}-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13)}
echo "Agent name: ${_AGENT_NAME}"

./config.sh --unattended \
  --agent   "${_AGENT_NAME}" \
  --url     "${AZP_URL}" \
  --auth    PAT \
  --token   "$(cat "${AZP_TOKEN_FILE}")" \
  --pool    "${AZP_POOL:-Default}" \
  --work    "${AZP_WORK:-_work}" \
  --replace \
  --acceptTeeEula & wait $!

print_header "2. Running Azure Pipelines agent..."

chmod +x ./run.sh
./run.sh "$@" --once & wait $!
