// This template is used to create a KeyVault with a private endpoint.
targetScope = 'resourceGroup'

// Parameters
param location string
param tags object
param keyvaultName string
param subnetId string
param virtualNetworkId string

// Resources

var privateDnsZoneName =  {
  azureusgovernment: 'privatelink.vaultcore.usgovcloudapi.net'
  azurechinacloud: 'privatelink.vaultcore.azure.cn'
  azurecloud: 'privatelink.vaultcore.azure.net'
}

resource keyVault 'Microsoft.KeyVault/vaults@2021-04-01-preview' = {
  name: keyvaultName
  location: location
  tags: tags
  properties: {
    accessPolicies: []
    createMode: 'default'
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enablePurgeProtection: true
    enableRbacAuthorization: true
    enableSoftDelete: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
    sku: {
      family: 'A'
      name: 'standard'
    }
    softDeleteRetentionInDays: 7
    tenantId: subscription().tenantId
  }
}

resource keyVaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2020-11-01' = {
  name: 'keyvault-pe'
  location: location
  tags: tags
  properties: {
    manualPrivateLinkServiceConnections: []
    privateLinkServiceConnections: [
      {
        name: 'keyvault-pe'
        properties: {
          groupIds: [
            'vault'
          ]
          privateLinkServiceId: keyVault.id
          requestMessage: ''
        }
      }
    ]
    subnet: {
      id: subnetId
    }
  }
}

resource keyVaultPrivateDnsZone 'Microsoft.Network/privateDnsZones@2018-09-01' = {
  name: privateDnsZoneName[toLower(environment().name)]
  dependsOn: [
    keyVaultPrivateEndpoint
  ]
  location: 'global'
  properties: {
  }
}

resource keyVaultPrivateDnsZoneARecord 'Microsoft.Network/privateDnsZones/A@2018-09-01' = {
  name: '${keyVaultPrivateDnsZone.name}/${keyVault.name}'
  dependsOn: [
    keyVaultPrivateDnsZone
  ]
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: keyVaultPrivateEndpoint.properties.customDnsConfigs[0].ipAddresses[0]
      }
    ]
  }
}

resource keyVaultPrivateDnsZoneSOARecord 'Microsoft.Network/privateDnsZones/SOA@2018-09-01' = {
  name: '${keyVaultPrivateDnsZone.name}/@'
  dependsOn: [
    keyVaultPrivateDnsZone
  ]
  properties: {
    ttl: 3600
    soaRecord: {
      email: 'azureprivatedns-host.microsoft.com'
      expireTime: 2419200
      host: 'azureprivatedns.net'
      minimumTtl: 10
      refreshTime: 3600
      retryTime: 300
      serialNumber: 1
    }
  }
}

resource keyVaultPrivateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  name: '${keyVaultPrivateDnsZone.name}/${uniqueString(keyVault.id)}'
  location: 'global'
  dependsOn: [
    keyVaultPrivateDnsZone
  ]
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetworkId
    }
  }
}

// Outputs
output keyvaultId string = keyVault.id
