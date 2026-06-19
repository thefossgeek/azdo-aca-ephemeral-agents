#!/usr/bin/env bash
# Idempotent — creates the placeholder agent only if it does not already exist,
# then sets the agent_type capability so KEDA can filter the queue by agent type.
#
# Required env var : AZDO_PERSONAL_ACCESS_TOKEN  (Agent Pools: Read & Manage scope)
# Arguments        : <org_url> <pool_id> <agent_name> <agent_type>

set -euo pipefail

ORG_URL="$1"
POOL_ID="$2"
AGENT_NAME="$3"
AGENT_TYPE="$4"

AUTH="Authorization: Basic $(printf ":%s" "${AZDO_PERSONAL_ACCESS_TOKEN}" | base64 | tr -d '\n')"
API="${ORG_URL}/_apis/distributedtask/pools/${POOL_ID}"

# Check if the agent already exists
echo "Checking if agent '${AGENT_NAME}' exists..."
EXISTING=$(curl -s -H "${AUTH}" "${API}/agents?agentName=${AGENT_NAME}&api-version=7.1")

if echo "${EXISTING}" | grep -q '"count":0'; then
  echo "Not found — creating agent '${AGENT_NAME}'..."
  CREATED=$(curl -s -X POST \
    -H "${AUTH}" \
    -H "Content-Type: application/json" \
    -d @- "${API}/agents?api-version=7.1" <<EOF
{
  "name": "${AGENT_NAME}",
  "version": "3.225.0",
  "osDescription": "Linux",
  "status": "offline",
  "enabled": true
}
EOF
)
  AGENT_ID=$(echo "${CREATED}" | grep -oE '"id":[0-9]+' | head -1 | grep -oE '[0-9]+')
  echo "Created agent with ID ${AGENT_ID}"
else
  AGENT_ID=$(echo "${EXISTING}" | grep -oE '"id":[0-9]+' | head -1 | grep -oE '[0-9]+')
  echo "Agent already exists with ID ${AGENT_ID} — skipping creation"
fi

# Always update the capability (PUT is idempotent)
echo "Setting agent_type=${AGENT_TYPE}..."
curl -s -X PUT \
  -H "${AUTH}" \
  -H "Content-Type: application/json" \
  -d @- "${API}/agents/${AGENT_ID}/usercapabilities?api-version=7.1" <<EOF
{
  "agent_type": "${AGENT_TYPE}"
}
EOF

echo "Done — '${AGENT_NAME}' ready with agent_type=${AGENT_TYPE}"
