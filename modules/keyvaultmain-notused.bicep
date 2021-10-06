// This template is used to create a KeyVault.
targetScope = 'resourceGroup'

// Parameters
param location string
param tags object
param keyvaultName string
param subnetId string
param virtualNetworkId string

module keyVault 'keyvault.bicep' = {
  name: 'keyvault001'
  scope: resourceGroup()
  params: {
    location: location
    tags: tags
    keyvaultName: keyvaultName
  }
}

module keyVaultPrivateDns 'keyvaultprivatednszones.bicep' = {
  name: 'keyvaultprivateDnsZones001'
  scope: resourceGroup()
  params: {
    virtualNetworkId: virtualNetworkId
    keyVaultName: keyVault.outputs.keyvaultName
    keyVaultId: keyVault.outputs.keyvaultId
    location: location
    tags: tags
    subnetId: subnetId
  }
}

output keyvaultId string = keyVault.outputs.keyvaultId
