# Azure DevOps Ephemeral Agents on Azure Container Apps

![Terraform](https://img.shields.io/badge/Terraform-≥1.15.6-623CE4?logo=terraform&logoColor=white)
![Azure Container Apps](https://img.shields.io/badge/Azure-Container_Apps-0078D4?logo=microsoftazure&logoColor=white)
![Terragrunt](https://img.shields.io/badge/Terragrunt-latest-3A3A3A?logo=gruntjs&logoColor=white)
![Azure DevOps](https://img.shields.io/badge/Azure_DevOps-Ephemeral_Agents-0078D4?logo=azuredevops&logoColor=white)
![License](https://img.shields.io/badge/License-Apache_2.0-D22128?logo=apache&logoColor=white)

Reusable Terraform modules and Terragrunt configurations for running self-hosted Azure DevOps agents as ephemeral Azure Container App Jobs. Agents spin up on demand when a pipeline job is queued and terminate immediately after — zero idle compute cost.

---

## Deployment Guides

| Guide | When to use |
|---|---|
| [DEPLOY-CYON.md](DEPLOY-CYON.md) | **Create Your Own Network** — Terraform creates the VNet, subnets, and all agent resources from scratch |
| [DEPLOY-BYON.md](DEPLOY-BYON.md) | **Bring Your Own Network** — an existing VNet and subnet are provided; Terraform creates only the agent resources inside them |

---

## How It Works

A pipeline job enters the Azure DevOps queue. KEDA polls the queue every 15 seconds using a read-only PAT. When depth reaches 1, KEDA triggers the Container App Job — the agent container starts, acquires an Azure DevOps token via managed identity, registers with the pool, runs the job, then exits. The replica is destroyed and billing stops.

```
Pipeline job queued
       │
       ▼
  KEDA scaler polls AzDO queue (read-only PAT, every 15 s)
       │  queue depth ≥ 1
       ▼
  Container App Job — new replica started
       │
       ▼
  Agent container: acquire token → register → run job → exit
       │
       ▼
  Replica terminated — billing stops — pool scales to zero
```

KEDA uses a permanent offline **placeholder agent** (registered automatically during `terragrunt apply`) to read the pool's agent capabilities. This lets multiple scalers share the same pool and respond only to jobs that match their `agent_type` demand — preventing two scalers from both responding to the same queued job.

---

## Agent Images

Two pre-packaged agent images are provided. Both bake the Azure Pipelines agent binary at build time — no internet access is needed at container start.

| Image | Base | Use case |
|---|---|---|
| `alpine` | `alpine:3.20` | Lightweight general-purpose jobs |
| `ubuntu24` | `mcr.microsoft.com/azure-powershell:ubuntu-24.04` | Jobs requiring Azure PowerShell, Azure CLI, or glibc tooling |

Both images use managed identity (UAMI) to authenticate to Azure DevOps at startup — no PAT is mounted into the container.

```bash
# Build alpine
cd 01azdo-agent-container-images/alpine
./download-agent.sh
docker build --platform linux/amd64 -t <acr>.azurecr.io/azp-agent/alpine:<tag> .
docker push <acr>.azurecr.io/azp-agent/alpine:<tag>

# Build ubuntu24
cd 01azdo-agent-container-images/ubuntu24
./download-agent.sh
docker build --platform linux/amd64 -t <acr>.azurecr.io/azp-agent/ubuntu24:<tag> .
docker push <acr>.azurecr.io/azp-agent/ubuntu24:<tag>
```

---

## Deploying Multiple Agent Types

The `azdo-ephemeral-agent-job` module is standalone — it can be applied once per agent type against the same shared infrastructure. A single Container App Environment hosts all jobs; each job has its own KEDA scaler and responds only to pipeline demands that match its `agent_type`.

```
ACA Environment (shared)
  ├── Container App Job — alpine    ← demand: agent_type -equals alpine
  └── Container App Job — ubuntu24  ← demand: agent_type -equals ubuntu24
```

**Apply order:**
1. Core infra stack (`01azdo-ephemeral-agent-aca-byon` or `01azdo-ephemeral-agent-aca`) — creates the ACA environment, UAMI, and agent pool, plus the first agent job (alpine)
2. Additional job stack (`azdo-ephemeral-agent-job`) — adds a second Container App Job (ubuntu24) into the same environment, reading all shared outputs from the infra stack via Terragrunt dependency

The additional job stack reads the resource group, CAE ID, UAMI, and pool name from the infra stack's Terraform state automatically — no duplication of values.

**Pipeline YAML targeting a specific agent type:**
```yaml
pool:
  name: 'pool-eph-agent-dev'
  demands: agent_type -equals alpine   # or: agent_type -equals ubuntu24
```

---

## Image Build Pipelines

Pipelines that build and push agent container images run on the ephemeral agents themselves. Authentication uses a dedicated managed identity — no secrets or credentials are stored anywhere.

### How It Works

```
Push to 01azdo-agent-container-images/alpine/** or ubuntu24/**
        │
        ▼
Ephemeral agent picks up the build job
        │
        ├── az login --identity --client-id <ACR_MI_CLIENT_ID>
        │       └── Uses the acrpush UAMI — separate from the agent's own UAMI
        │
        └── az acr build --registry <ACR_NAME> ...
                └── Build runs in ACR Tasks — no Docker daemon needed on the agent
```

### Step 1 — Create the pipeline managed identity

All pipeline identities share one resource group:

```bash
cd 03dev-azdo-agent-tg/managed-identity/01resource-group
terragrunt apply
```

Create the acrpush identity — edit `03dev-azdo-agent-tg/managed-identity/02acrpush/terragrunt.hcl` and set the ACR scope:

```hcl
role_assignments = [
  {
    scope = "/subscriptions/<SUB-ID>/resourceGroups/<ACR-RG>/providers/Microsoft.ContainerRegistry/registries/<ACR-NAME>"
    role  = "Contributor"
  }
]
```

> **Why `Contributor` and not `AcrPush`?**  
> `az acr build` calls the Azure Resource Manager API to schedule a build task (`scheduleRun` action). `AcrPush` only covers Docker data-plane operations. When the identity lacks ARM read, Azure returns **404 not found** (not 403) — hiding the resource entirely.  
> `Contributor` scoped to just the ACR resource gives exactly what is needed: ARM read + schedule build + image push.

```bash
cd 03dev-azdo-agent-tg/managed-identity/02acrpush
terragrunt apply
# Note the mi_client_id output — needed for the variable group in Step 3
```

### Step 2 — Attach the managed identity to agent ACA jobs

The identity must be **attached to the compute** (the ACA job) — simply having a role assignment is not enough. `extra_identity_ids` in each agent stack wires the acrpush UAMI alongside the agent's own UAMI:

```hcl
# Already declared in cyon/01azdo-ephemeral-agent-aca and byon/01azdo-ephemeral-agent-aca-byon
extra_identity_ids = [dependency.acrpush_mi.outputs.mi_id]
```

Apply the agent stacks to attach the identity:

```bash
# CYON
cd 03dev-azdo-agent-tg/cyon/01azdo-ephemeral-agent-aca && terragrunt apply
cd ../azdo-ephemeral-agent-job && terragrunt apply

# BYON
cd 03dev-azdo-agent-tg/byon/01azdo-ephemeral-agent-aca-byon && terragrunt apply
cd ../azdo-ephemeral-agent-job && terragrunt apply
```

Inside the pipeline, the right identity is selected by client ID:

```bash
az login --identity --client-id "$ACR_MI_CLIENT_ID"
```

### Step 3 — Create the variable group in Azure DevOps

**Pipelines → Library → + Variable group → name: `acr-build-vars`**

| Variable | Value |
|---|---|
| `ACR_NAME` | ACR name without `.azurecr.io` |
| `ACR_MI_CLIENT_ID` | `mi_client_id` from Step 1 output |

### Step 4 — Register pipelines via Terraform

All pipelines are declared in one file — no portal clicks needed:

```bash
export AZDO_PERSONAL_ACCESS_TOKEN=<your-pat>
export AZDO_ORG_SERVICE_URL=https://dev.azure.com/<YOUR-ORG>

cd 03dev-azdo-agent-tg/pipelines
terragrunt apply
```

To add a new pipeline, add one entry to the `pipelines` map in `03dev-azdo-agent-tg/pipelines/terragrunt.hcl` and apply again.

---

## Repository Structure

```
.
├── 01azdo-agent-container-images/        # Docker images for ACA agents
│   ├── alpine/
│   │   ├── Dockerfile                    # Alpine 3.20 — lightweight
│   │   ├── download-agent.sh             # Downloads agent binary at build time
│   │   └── start.sh                      # UAMI token + agent registration
│   └── ubuntu24/
│       ├── Dockerfile                    # Ubuntu 24 — Azure PowerShell + Azure CLI
│       ├── download-agent.sh
│       └── start.sh
│
├── 02dev-bootstrap/                      # Bicep bootstrap — Terraform remote state storage
│   ├── bicep/                            # Storage account + RBAC Bicep modules
│   ├── backends/spai/                    # Per-project backend config
│   └── run.sh                            # what-if → apply wrapper
│
├── 03dev-azdo-agent-tg/                  # Terragrunt stacks — dev environment
│   ├── root.hcl                          # Subscription, region, backend, shared inputs
│   ├── root.hcl.example
│   │
│   ├── cyon/                             # CYON — Create Your Own Network
│   │   ├── 01azdo-ephemeral-agent-aca/   # Core: RG + VNet + UAMI + CAE + alpine job
│   │   └── azdo-ephemeral-agent-job/     # Additional job: ubuntu24 (reads infra from above)
│   │
│   └── byon/                             # BYON — Bring Your Own Network
│       ├── 01azdo-ephemeral-agent-aca-byon/  # Core: RG + UAMI + CAE + alpine job (existing VNet)
│       └── azdo-ephemeral-agent-job/         # Additional job: ubuntu24 (reads infra from above)
│
├── terraform/                            # Reusable Terraform modules (shared across environments)
│   ├── resource-group/                   # Resource group + optional CanNotDelete lock
│   ├── vnet/                             # Virtual network + delegated subnets
│   ├── udr/                              # Route table → hub firewall (optional)
│   ├── azdo-ephemeral-agent-access/      # UAMI + AzDO agent pool + RBAC
│   ├── azdo-ephemeral-agent-env/         # Log Analytics Workspace + Container App Environment
│   ├── azdo-ephemeral-agent-job/         # Container App Job + KEDA scaler + placeholder registration
│   ├── azdo-pipeline-permissions/        # Per-pipeline or all-pipeline queue authorization
│   ├── azdo-ephemeral-agent-aca-cyon/    # Orchestrator — CYON: new VNet + all agent resources
│   └── azdo-ephemeral-agent-aca-byon/    # Orchestrator — BYON: existing VNet + agent resources
│
├── common.hcl                            # Shared Terragrunt: versions, providers, backend, globals
├── versions.tf                           # Provider version constraints
├── vars.hcl / vars.hcl.example           # Tenant/subscription IDs, Entra group, tags
├── DEPLOY-CYON.md                        # Step-by-step CYON deployment guide
└── DEPLOY-BYON.md                        # Step-by-step BYON deployment guide
```

---

## Terraform Module Reference

### Module Dependency Graph

```
azdo-ephemeral-agent-aca-cyon  (CYON orchestrator)
  ├── resource-group
  ├── vnet
  ├── udr                             (when enable_udr = true)
  ├── azdo-ephemeral-agent-access     (UAMI + AzDO pool + RBAC)
  ├── azdo-ephemeral-agent-env        (LAW + Container App Environment)
  └── azdo-ephemeral-agent-job        (Container App Job + KEDA)

azdo-ephemeral-agent-aca-byon  (BYON orchestrator)
  ├── resource-group                  (or data source when create_resource_group = false)
  ├── data: azurerm_virtual_network   (existing VNet)
  ├── data: azurerm_subnet            (existing subnet)
  ├── udr                             (when enable_udr = true)
  ├── azdo-ephemeral-agent-access
  ├── azdo-ephemeral-agent-env
  └── azdo-ephemeral-agent-job

azdo-ephemeral-agent-job  (standalone — additional agent types)
  └── reads: resource_group, cae_id, uami_id, pool from infra stack outputs
```

### Modules

| Module | Purpose |
|---|---|
| `resource-group` | Resource group with optional CanNotDelete lock |
| `vnet` | Virtual network with dynamically configured subnets |
| `udr` | Route table → hub firewall, scoped to agent subnet only |
| `azdo-ephemeral-agent-access` | UAMI, AzDO agent pool, service principal entitlement, Azure RBAC |
| `azdo-ephemeral-agent-env` | Log Analytics Workspace (optional) + private Container App Environment |
| `azdo-ephemeral-agent-job` | Container App Job + KEDA azure-pipelines scaler + placeholder agent registration |
| `azdo-pipeline-permissions` | Authorize specific pipelines or all pipelines to use the agent queue |
| `azdo-ephemeral-agent-aca-cyon` | CYON orchestrator — wires all modules for new-VNet deployments |
| `azdo-ephemeral-agent-aca-byon` | BYON orchestrator — wires all modules for existing-VNet deployments |

### Environment Isolation

Each environment (`dev`, `preprod`, `prod`) has its own numbered directory under the repo root (e.g. `03dev-azdo-agent-tg/`). Each environment directory contains its own `root.hcl` declaring the subscription, region, backend storage account, and shared tags. The reusable Terraform modules in `terraform/` are environment-agnostic — they have no hardcoded values.

Terragrunt's `generate` blocks inject providers, backend configuration, and shared variables into each module workspace at runtime, keeping the modules portable and testable outside of Terragrunt.

---

## Networking

### CYON — Terraform creates the VNet

```
Virtual Network  10.100.0.0/16
  └── snet-devopsagent-aca  10.100.0.0/23
        delegation: Microsoft.App/environments
        optional route table → hub firewall
```

### BYON — Existing VNet and subnet

The module reads the VNet and subnet via data sources. The subnet must:
- Exist before `terragrunt apply`
- Be delegated to `Microsoft.App/environments`
- Be at least `/23` (512 addresses)

Provide the VNet name, VNet resource group, and subnet name in the Terragrunt inputs. The VNet resource group can differ from the agent resource group (hub-spoke topology is supported).

---

## Security

| Concern | Approach |
|---|---|
| ACR image pull | UAMI with `AcrPull` — no credentials in container |
| AzDO registration | Token acquired at runtime from ACA IMDS endpoint using UAMI client ID |
| KEDA PAT | Stored as ACA secret (`keda-pat`), never exposed as env var |
| Placeholder PAT | Read from `AZDO_PERSONAL_ACCESS_TOKEN` shell env during `apply` — never written to Terraform state |
| Terraform state | Azure AD + OIDC backend auth — no storage access keys |
| Network | Internal load balancer only, no public ingress; outbound HTTPS to AzDO |

---

## Scaling

| Queue depth | Replicas |
|---|---|
| 0 | 0 — scale to zero, no cost |
| 1 | 1 |
| N | N (up to `max_executions`) |

KEDA polls every 15 seconds (`targetPipelinesQueueLength = 1`). Each agent runs with `--once` — one job per container, full isolation, no shared state between runs.

---

## Key Variables

| Variable | Module | Default | Description |
|---|---|---|---|
| `agent_type` | job | — | Label used in job name and `AZP_AGENT_NAME_PREFIX`; must match pipeline `demands` |
| `keda_parent` | job | `""` | Placeholder agent name — registered automatically during apply so KEDA can filter by `agent_type` |
| `max_executions` | job | `10` | Maximum parallel agent replicas |
| `replica_timeout_in_seconds` | job | `1800` | Hard stop per pipeline job (30 min) |
| `cpu` / `memory` | job | `0.5` / `1Gi` | Per-replica resource allocation |
| `enable_udr` | cyon/byon | `false` | Route agent egress through hub firewall |
| `hub_firewall_ip` | cyon/byon | `null` | Hub firewall private IP (required when `enable_udr = true`) |
| `create_law` | env | `true` | Create a Log Analytics Workspace or reuse an existing one |
| `create_resource_group` | byon | `true` | Set `false` when the resource group already exists |

---

## Operations

```bash
# Manually trigger an agent job (useful for debugging)
az containerapp job start \
  --name "caj-spai-dev-alpine-001" \
  --resource-group "rg-uaen-spai-dev-eph-agent-001"

# Re-register a placeholder agent that was accidentally deleted
cd 03dev-azdo-agent-tg/cyon/01azdo-ephemeral-agent-aca
terragrunt apply -replace=null_resource.register_placeholder

# Format all HCL and Terraform files
make format

# Remove all Terragrunt cache directories
make clean
```

---

## Provider Versions

| Provider | Version |
|---|---|
| `hashicorp/azurerm` | `>= 4.76.0, < 5.0.0` |
| `microsoft/azuredevops` | `>= 1.15.0` |
| `hashicorp/azuread` | `3.8.0` |
| `hashicorp/time` | `>= 0.11.0` |

Terraform minimum: **1.15.6**

---

## License

[Apache 2.0](LICENSE)
