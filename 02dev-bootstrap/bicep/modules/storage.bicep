@description('Storage redundancy (recommended to use at least ZRS)')
@allowed([
  'Standard_LRS'
  'Standard_ZRS'
  'Standard_GRS'
  'Standard_GZRS'
])
param skuName string = 'Standard_LRS'

@description('The ID of the user who should be allowed to manage Terraform state')
param groupIds array

@description('The storage account name')
param saName string

@description('The storage container names')
param scNames array

@description('Skip default event grid system topics')
param deploySystemTopics bool = false

resource rgLock 'Microsoft.Authorization/locks@2020-05-01' = {
  name: 'delete-lock'
  properties: {
    level: 'CanNotDelete'
    notes: 'This lock prevents accidental deletion of the resource group.'
  }
}

resource account 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: saName
  location: resourceGroup().location
  tags: {
    owner: 'qdata'
    department: 'devops'
    managedby: 'bicep'
    repository: 'qdata-azure-bootstrap'
    product: 'q'
  }
  sku: {
    name: skuName
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowSharedKeyAccess: false
    supportsHttpsTrafficOnly: true
    defaultToOAuthAuthentication: true 
    publicNetworkAccess: 'Enabled' 
    minimumTlsVersion: 'TLS1_2'
    isLocalUserEnabled: false
  }
}

var blobDataContributor = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for groupId in groupIds: {
  name: guid(resourceGroup().id, groupId)
  scope: account
  properties: {
    principalType: 'Group'
    principalId: groupId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', blobDataContributor)
  }
}]

resource systemTopic 'Microsoft.EventGrid/systemTopics@2022-06-15' = if (deploySystemTopics) {
  name: saName
  location: resourceGroup().location
  properties: {
    topicType: 'Microsoft.Storage.StorageAccounts'
    source: '/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Storage/storageAccounts/{storageAccountName}'
  }
}

resource bs 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  name: 'default'
  parent: account
  properties: {
    changeFeed: {
      enabled: true
    }
    deleteRetentionPolicy: {
      allowPermanentDelete: false
      enabled: true
      days: 31
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 31
    }
    restorePolicy: {
      enabled: true
      days: 30
    }
    isVersioningEnabled: true
  }
}

resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = [for scName in scNames: {
  name: scName
  parent: bs
  properties: {
    publicAccess: 'None'
    denyEncryptionScopeOverride: false
    defaultEncryptionScope: '$account-encryption-key'
  }
}]

output account string = account.name
