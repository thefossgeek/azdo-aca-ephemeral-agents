targetScope = 'subscription'

@description('Timestamp used to uniquely name deployed modules to retain all deployment history')
param deploymentTimestamp string = utcNow()

@description('The IDs of the groups who should be allowed to manage Terraform state')
param entrGroupIds array

@description('The resource group name')
param rgName string

@description('The storage account name')
param storageAccountName string

@description('The storage container names')
param storageContainerName array

@description('Storage redundancy (recommended to use at least ZRS)')
@allowed([
  'Standard_LRS'
  'Standard_ZRS'
  'Standard_GRS'
  'Standard_GZRS'
])
param skuName string = 'Standard_ZRS'

@description('Skip default event grid system topics')
param deploySystemTopics bool = false


@description('Resource group for Terraform state resources')
resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: rgName
  location: deployment().location
  tags: {
    owner: 'qdata'
    department: 'devops'
    managedby: 'bicep'
    repository: 'qdata-azure-bootstrap'
    product: 'q'
  }
}

module storage 'modules/storage.bicep' = {
  scope: rg
  name: '${deploymentTimestamp}-storage-module'
  params: {
    skuName: skuName
    groupIds: entrGroupIds
    saName: storageAccountName
    scNames: storageContainerName
    deploySystemTopics: deploySystemTopics
  }
}

var template = '''
terraform {{
  backend "azurerm" {{
    resource_group_name  = "{0}"
    storage_account_name = "{1}"
    container_name       = ''
    key                  = "terraform.tfstate"
    use_azuread_auth     = true
    subscription_id      = "{2}"
    tenant_id            = "{3}"
  }}
}}
'''

var aad = tenant().tenantId
var sub = subscription().subscriptionId
var acc = storage.outputs.account

output outputBlock string = format(template, rg.name, acc, sub, aad)
