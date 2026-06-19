# BYON Deployment — Azure DevOps Ephemeral Agents on ACA

**BYON** = Bring Your Own Network. You supply an existing VNet and subnet; Terragrunt creates only the ACA environment, agent pool, UAMI, and Container App Jobs inside it.

---

## Prerequisites

- Azure CLI installed and working
- Docker Desktop running
- Terragrunt + Terraform installed
- Access to an Azure Container Registry (ACR)
- Azure DevOps project exists (e.g. `spai-prod-azure-infra`)
- An existing VNet with a subnet delegated to `Microsoft.App/environments` (minimum **/23**)

### Subnet requirements

The target subnet must meet Azure Container Apps requirements before applying:

| Requirement | Detail |
|---|---|
| Minimum size | `/23` (512 addresses) |
| Delegation | `Microsoft.App/environments` |
| No conflicting policies | Private endpoint policies must be disabled on the subnet |

To check delegation on an existing subnet:

```bash
az network vnet subnet show \
  --resource-group <VNET-RG> \
  --vnet-name <VNET-NAME> \
  --name <SUBNET-NAME> \
  --query "delegations[].serviceName"
```

Expected output: `["Microsoft.App/environments"]`

---

## Step 0 — Entra ID group (manual, once)

1. Create a security group in Entra ID (e.g. `entra-sg-spai-dev-tfstate-backend-access`)
2. Add members who need Terraform state access
3. **Copy the Group Object ID** — needed in Step 3

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

## Step 2 — Build & push agent images

Two agent types are used — `alpine` (lightweight) and `ubuntu24` (Azure PowerShell + Azure CLI). Build and push each one.

```bash
export ACR_NAME=<your-acr-name>    # without .azurecr.io
az acr login --name ${ACR_NAME}
IMAGE_TAG="$(date +%Y%m%d)-$(git rev-parse --short=8 HEAD)"
```

### Alpine

```bash
cd 01azdo-agent-container-images/alpine

./download-agent.sh                # run once per agent version upgrade

docker build --no-cache --platform linux/amd64 \
  -t ${ACR_NAME}.azurecr.io/azp-agent/alpine:${IMAGE_TAG} .

docker push ${ACR_NAME}.azurecr.io/azp-agent/alpine:${IMAGE_TAG}

rm agent.tar.gz
```

### Ubuntu 24

```bash
cd 01azdo-agent-container-images/ubuntu24

./download-agent.sh                # run once per agent version upgrade

docker build --no-cache --platform linux/amd64 \
  -t ${ACR_NAME}.azurecr.io/azp-agent/ubuntu24:${IMAGE_TAG} .

docker push ${ACR_NAME}.azurecr.io/azp-agent/ubuntu24:${IMAGE_TAG}

rm agent.tar.gz
```

> **Note the full image tags** — e.g. `<acr>.azurecr.io/azp-agent/alpine:20260619-abc12345`  
> Required in Step 4.

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

## Step 4 — Collect your network details

Before configuring Terragrunt, gather the following from your existing network:

```bash
# List VNets to find the right one
az network vnet list --output table

# List subnets inside the target VNet
az network vnet subnet list \
  --resource-group <VNET-RG> \
  --vnet-name <VNET-NAME> \
  --output table
```

Note down:

| Value | Example | Description |
|---|---|---|
| VNet name | `vnet-hub-prod-uaen-001` | Name of the existing virtual network |
| VNet resource group | `rg-hub-prod-uaen-001` | Resource group where the VNet lives |
| Subnet name | `snet-devopsagent-aca` | Subnet delegated to `Microsoft.App/environments` |
| Agent resource group | `rg-uaen-spai-dev-eph-agent-001` | Where agent resources will be created |

---

## Step 5 — Configure Terragrunt

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

### Alpine agent stack — `byon/01azdo-ephemeral-agent-aca-byon/terragrunt.hcl`

```bash
cd byon/01azdo-ephemeral-agent-aca-byon
cp terragrunt.hcl.example terragrunt.hcl
```

Edit `terragrunt.hcl` — fill in the network details collected in Step 4:

```hcl
# ── Resource Group ──────────────────────────────────────────────────────────
resource_group_name   = "rg-<location_code>-<project>-<env>-eph-agent-001"
enable_rg_lock        = false
create_resource_group = true    # set false if the resource group already exists

# ── Virtual Network — existing (looked up, not created) ─────────────────────
vnet_name                = "<YOUR-VNET-NAME>"             # from Step 4
vnet_resource_group_name = "<YOUR-VNET-RESOURCE-GROUP>"   # from Step 4
infra_subnet_name        = "<YOUR-SUBNET-NAME>"           # from Step 4

# ── AzDO Access ─────────────────────────────────────────────────────────────
role_assignments = [{
  scope = "/subscriptions/<SUB-ID>/resourceGroups/<RG>/providers/Microsoft.ContainerRegistry/registries/<ACR-NAME>"
  role  = "AcrPull"
}]

# ── Container App Job (alpine) ───────────────────────────────────────────────
agent_type   = "alpine"
keda_parent  = "caj-<project>-<env>-alpine-001-ph"
acr_server   = "<ACR-NAME>.azurecr.io"
agent_image  = "<ACR-NAME>.azurecr.io/azp-agent/alpine:<IMAGE-TAG from Step 2>"
azdo_org_url = "https://dev.azure.com/<YOUR-ORG>"
```

### Ubuntu24 agent stack — `byon/azdo-ephemeral-agent-job/terragrunt.hcl`

```bash
cd ../azdo-ephemeral-agent-job
cp terragrunt.hcl.example terragrunt.hcl
```

Edit `terragrunt.hcl`:
```hcl
agent_type   = "ubuntu24"
keda_parent  = "caj-<project>-<env>-ubuntu24-001-ph"
acr_server   = "<ACR-NAME>.azurecr.io"
agent_image  = "<ACR-NAME>.azurecr.io/azp-agent/ubuntu24:<IMAGE-TAG from Step 2>"
azdo_org_url = "https://dev.azure.com/<YOUR-ORG>"
```

> The ubuntu24 stack reads the VNet/RG/pool details from the alpine stack's Terraform outputs via `dependency.infra` — no need to repeat them here.

---

## Step 6 — Create PATs

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
> This PAT is also used by the placeholder registration script during `terragrunt apply`.

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

## Step 7 — Plan & Apply

Apply the alpine stack first (creates shared agent resources — ACA environment, agent pool, UAMI), then the ubuntu24 stack (adds a second Container App Job into the same ACA environment).

Each apply also registers a permanent offline placeholder agent in the AzDO pool via the built-in bash script. The placeholder gives KEDA a reference to filter the queue — only jobs matching the agent type trigger scaling.

```bash
# Alpine agent + shared infra (ACA env, UAMI, pool)
cd azdo-aca-ephemeral-agents/03dev-azdo-agent-tg/byon/01azdo-ephemeral-agent-aca-byon
terragrunt plan
terragrunt apply

# Ubuntu24 agent (joins the ACA environment created above)
cd ../azdo-ephemeral-agent-job
terragrunt plan
terragrunt apply
```

> To re-register a placeholder that was manually deleted from the pool:
> ```bash
> terragrunt apply -replace=null_resource.register_placeholder
> ```

---

## Done

Run a pipeline that targets the agent pool. Each job with `demands: agent_type -equals alpine` triggers the alpine scaler; `demands: agent_type -equals ubuntu24` triggers the ubuntu24 scaler. KEDA spins up exactly one ephemeral container per queued job and tears it down when complete.

---

## Test Pipeline

Add the following as `azure-pipelines.yml` in your Azure DevOps repository to verify both agent types are working:

```yaml
trigger: none

jobs:

- job: RunOnAlpineAgent
  displayName: 'Run on Alpine Agent'
  pool:
    name: 'pool-eph-agent-dev'
    demands: agent_type -equals alpine

  steps:
  - script: |
      echo "=== Alpine Agent ==="
      echo "Running on Agent: $(Agent.Name)"
    displayName: 'Print Agent Details'


- job: RunOnUbuntu24Agent
  displayName: 'Run on Ubuntu24 Agent'
  pool:
    name: 'pool-eph-agent-dev'
    demands: agent_type -equals ubuntu24

  steps:
  - script: |
      echo "=== Ubuntu24 Agent ==="
      echo "Running on Agent: $(Agent.Name)"
    displayName: 'Print Agent Details'
```

Run the pipeline manually from Azure DevOps. Each job should spin up its own ephemeral container, print the agent name, and terminate. Check the agent pool in Azure DevOps — you should see one `alpine` and one `ubuntu24` agent appear briefly while the jobs run, then go offline.
