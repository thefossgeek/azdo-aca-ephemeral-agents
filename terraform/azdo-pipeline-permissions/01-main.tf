# ============================================================================
# Option A — Authorize ALL pipelines in the project (authorize_all_pipelines = true)
# No pipeline_id = AzDO treats it as an org-wide grant for this queue.
# Use for dev/test. For prod, prefer Option B (explicit per-pipeline).
# ============================================================================

resource "azuredevops_pipeline_authorization" "queue_all" {
  count = var.authorize_all_pipelines ? 1 : 0

  project_id  = var.project_id
  resource_id = var.agent_queue_id
  type        = "queue"
}

# ============================================================================
# Option B — Authorize specific pipelines only (default, recommended for prod)
# Add a new entry to var.pipelines each time a new pipeline needs access.
# ============================================================================

resource "azuredevops_pipeline_authorization" "queue" {
  for_each = var.authorize_all_pipelines ? {} : var.pipelines

  project_id  = var.project_id
  resource_id = var.agent_queue_id
  type        = "queue"
  pipeline_id = each.value
}
