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

### Alpine agent stack — `cyon/01azdo-ephemeral-agent-aca/terragrunt.hcl`

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

agent_type   = "alpine"
keda_parent  = "caj-<project>-<env>-alpine-001-ph"   # placeholder agent name — created automatically during apply
acr_server   = "<ACR-NAME>.azurecr.io"
agent_image  = "<ACR-NAME>.azurecr.io/azp-agent/alpine:<IMAGE-TAG from Step 2>"
azdo_org_url = "https://dev.azure.com/<YOUR-ORG>"
```

### Ubuntu24 agent stack — `cyon/azdo-ephemeral-agent-job/terragrunt.hcl`

```bash
cd ../azdo-ephemeral-agent-job
cp terragrunt.hcl.example terragrunt.hcl
```

Edit `terragrunt.hcl`:
```hcl
agent_type   = "ubuntu24"
keda_parent  = "caj-<project>-<env>-ubuntu24-001-ph"  # placeholder agent name — created automatically during apply
acr_server   = "<ACR-NAME>.azurecr.io"
agent_image  = "<ACR-NAME>.azurecr.io/azp-agent/ubuntu24:<IMAGE-TAG from Step 2>"
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

## Step 6 — Plan & Apply

Apply the alpine stack first (creates shared infra — VNet, ACA environment, agent pool, UAMI), then the ubuntu24 stack (adds a second Container App Job into the same environment).

Each apply also registers a permanent offline placeholder agent in the AzDO pool via the built-in bash script. The placeholder gives KEDA a reference to filter the queue — only jobs matching the agent type trigger scaling.

```bash
# Alpine agent + shared infra
cd azdo-aca-ephemeral-agents/03dev-azdo-agent-tg/cyon/01azdo-ephemeral-agent-aca
terragrunt plan
terragrunt apply

# Ubuntu24 agent (shares the infra created above)
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
