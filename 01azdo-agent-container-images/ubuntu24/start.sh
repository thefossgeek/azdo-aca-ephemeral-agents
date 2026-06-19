#!/bin/bash
set -e

if [ -z "${AZP_URL}" ]; then
  echo 1>&2 "error: missing AZP_URL environment variable"
  exit 1
fi

# Acquire AzDO access token via User Assigned Managed Identity.
# ACA injects IDENTITY_ENDPOINT and IDENTITY_HEADER automatically when a UAMI is assigned.
if [ -n "${USRMI_ID}" ]; then
  echo "Logging in with managed identity..."
  az login --identity --client-id "${USRMI_ID}" --allow-no-subscriptions --output none

  APPLICATION_ID="499b84ac-1321-427f-aa17-267ca6975798"
  AZP_TOKEN=$(az account get-access-token --resource "${APPLICATION_ID}" --query accessToken -o tsv)

  if [ -z "${AZP_TOKEN}" ]; then
    echo 1>&2 "error: failed to get access token using managed identity"
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
  if [ -n "${AZP_PLACEHOLDER}" ]; then
    echo "Placeholder mode — skipping deregistration"
    return
  fi
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

if [ -n "${AZP_PLACEHOLDER}" ]; then
  echo "Placeholder mode — agent registered, skipping run"
else
  ./run.sh "$@" --once & wait $!
fi
