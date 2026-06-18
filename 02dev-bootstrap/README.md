# az-tfstate-bootstrap

Creating a storage account for the state backend introduces a circular dependency: Terraform needs the storage account to store its state, but the account itself must be created by Terraform. This Bicep code bootstraps the storage backend and avoids the manual work required to create it by hand.

