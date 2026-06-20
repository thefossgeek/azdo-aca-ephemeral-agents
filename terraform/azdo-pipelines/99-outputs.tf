output "pipeline_ids" {
  description = "Map of pipeline name to Azure DevOps pipeline definition ID. Use with azdo-pipeline-permissions."
  value       = { for k, v in azuredevops_build_definition.this : k => v.id }
}
