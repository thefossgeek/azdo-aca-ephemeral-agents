#!/bin/bash
set -e

cd "$(dirname "$0")"

AGENT_VERSION="${1:-$(curl -sL https://api.github.com/repos/microsoft/azure-pipelines-agent/releases/latest | jq -r '.tag_name | ltrimstr("v")')}"
echo "Downloading agent v${AGENT_VERSION}..."

curl -L --progress-bar \
  "https://download.agent.dev.azure.com/agent/${AGENT_VERSION}/vsts-agent-linux-x64-${AGENT_VERSION}.tar.gz" \
  -o agent.tar.gz

echo "Done: $(du -sh agent.tar.gz | cut -f1)"
