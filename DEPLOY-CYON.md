# CYON Deployment — Azure DevOps Ephemeral Agents on ACA

**CYON** = Create Your Own Network. Terragrunt creates the VNet, ACA environment, agent pool, and job.

---

## Prerequisites

- Azure CLI installed and working
- Docker Desktop running
- Terragrunt + Terraform installed
- Access to an Azure Container Registry (ACR)
- Azure DevOps project exists (e.g. `spai-prod-azure-infra`)

---

## Step 0 — Entra ID group (manual, once)

1. Create a security group in Entra ID (e.g. `entra-sg-spai-dev-tfstate-backend-access`)
2. Add members who need Terraform state access
3. **Copy the Group Object ID** — needed in Step 2

```
Entra ID → Groups → New Group → Security → Add members → Copy Object ID
```

---

## Step 1 — Clone repo

```bash
git clone <repo-url>
cd azdo-aca-ephemeral-agents
```

---

## Step 2 — Build & push agent image

```bash
export ACR_NAME=<your-acr-name>           # without .azurecr.io
export IMAGE_REPO=azp-agent/alpine
IMAGE_TAG="$(date +%Y%m%d)-$(git rev-parse --short=8 HEAD)"

cd 01azdo-agent-container-images/alpine

./download-agent.sh                       # run once per agent version upgrade

docker build --no-cache --platform linux/amd64 \
  -t ${ACR_NAME}.azurecr.io/${IMAGE_REPO}:${IMAGE_TAG} .

az acr login --name ${ACR_NAME}

docker push ${ACR_NAME}.azurecr.io/${IMAGE_REPO}:${IMAGE_TAG}

rm agent.tar.gz
```

> **Note the full image tag** — e.g. `myacr.azurecr.io/azp-agent/alpine:20260619-abc12345`  
> Required in Step 5.

---

## Step 3 — Bootstrap Terraform backend

```bash
cd azdo-aca-ephemeral-agents/02dev-bootstrap/backends/spai

cp cli.json.example cli.json
cp bicep.json.example bicep.json
```

Edit `cli.json`:
```json
{
  "subscription": "<SUBSCRIPTION-ID>",
  "location": "uaenorth",
  "deployment_name": "dep-uaen-spai-tfstate",
  "template_file": "bicep/main-sa.bicep"
}
```

Edit `bicep.json`:
```json
{
  "parameters": {
    "entrGroupIds": { "value": ["<ENTRA-GROUP-ID from Step 0>"] },
    "rgName":       { "value": "rg-uaen-spai-dev-tfstate" },
    "storageAccountName": { "value": "<unique-storage-account-name>" },
    "storageContainerName": { "value": ["azdo-aca-ephemeral-agents"] }
  }
}
```

```bash
az login
az account set --subscription "<SUBSCRIPTION-ID>"

cd ../../
./run.sh -p backends/spai/bicep.json
```

> **Copy the script output** — storage account name, container name, resource group.  
> Required in Step 4.

---

## Step 4 — Configure Terragrunt

### `vars.hcl` (repo root)

```bash
cd azdo-aca-ephemeral-agents
cp vars.hcl.example vars.hcl
```

Edit `vars.hcl`:
```hcl
locals {
  tf_contrib_group_id = "<ENTRA-GROUP-ID from Step 0>"
  tags = {
    owner      = "<your-name>"
    department = "infra"
    terraform  = "True"
    repository = "azdo-aca-ephemeral-agents"
  }
}
inputs = {
  tenant_id = "<AZURE-TENANT-ID>"
  spai_dev  = "<SUBSCRIPTION-ID>"
}
```

### `root.hcl`

```bash
cd 03dev-azdo-agent-tg
cp root.hcl.example root.hcl
```

Edit `root.hcl` — update backend values from Step 3 output:
```hcl
locals {
  tfbackend_state_storage_account = "<storage-account-name>"
  tfbackend_container_name        = "azdo-aca-ephemeral-agents"
  tfbackend_subscription_id       = local.vars.inputs.spai_dev
  tfbackend_resource_group        = "<tfstate-resource-group>"

  environment   = "dev"
  location      = "uaenorth"
  location_code = "uaen"
  project       = "spai"
  ...
}
```

### `terragrunt.hcl`

```bash
cd cyon/01azdo-ephemeral-agent-aca
cp terragrunt.hcl.example terragrunt.hcl
```

Edit `terragrunt.hcl` — update these values:
```hcl
role_assignments = [{
  scope = "/subscriptions/<SUB-ID>/resourceGroups/<RG>/providers/Microsoft.ContainerRegistry/registries/<ACR-NAME>"
  role  = "AcrPull"
}]

acr_server  = "<ACR-NAME>.azurecr.io"
agent_image = "<ACR-NAME>.azurecr.io/azp-agent/alpine:<IMAGE-TAG from Step 2>"
azdo_org_url = "https://dev.azure.com/<YOUR-ORG>"
```

---

## Step 5 — Create PATs

### PAT A — KEDA queue polling (`TF_VAR_AZDO_KEDA_PAT`)

> Best practice: create a dedicated service account `svc-keda@yourdomain.com`, add to AzDO as Stakeholder, grant Agent Pools → Reader only.

| Setting | Value |
|---|---|
| Organization | your org |
| Scope | Agent Pools → **Read** |

```bash
export TF_VAR_AZDO_KEDA_PAT=<PAT-A>
```

### PAT B — Terraform runner (`AZDO_PERSONAL_ACCESS_TOKEN`)

> Your own user PAT. Your account must be **Project Collection Administrator** in AzDO.

| PAT Scope | Level |
|---|---|
| Agent Pools | Read & Manage |
| Member Entitlement Management | Read & Write |
| Pipeline Resources | Use and Manage |
| Project and Team | Read |

```bash
export AZDO_PERSONAL_ACCESS_TOKEN=<PAT-B>
export AZDO_ORG_SERVICE_URL=https://dev.azure.com/<YOUR-ORG>
```

---

## Step 6 — Plan & Apply

```bash
cd azdo-aca-ephemeral-agents/03dev-azdo-agent-tg/cyon/01azdo-ephemeral-agent-aca

terragrunt plan

terragrunt apply
```

---

## Step 7 — Register placeholder agent

KEDA requires at least one agent registered in the pool to read the queue length.  
After apply, get the pool ID from the AzDO UI (Agent Pools → your pool → URL contains the ID).

```bash
export POOL_ID="<POOL-ID>"
export B64_TOKEN=$(echo -n ":${AZDO_PERSONAL_ACCESS_TOKEN}" | base64)

curl -X POST \
  -H "Authorization: Basic ${B64_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "placeholder-agent-do-not-delete",
    "version": "3.225.0",
    "osDescription": "Linux",
    "status": "offline",
    "enabled": true
  }' \
  "${AZDO_ORG_SERVICE_URL}/_apis/distributedtask/pools/${POOL_ID}/agents?api-version=7.1"
```

---

## Done

Run a pipeline that targets the agent pool. KEDA will spin up an ephemeral container for each job and tear it down when complete.
