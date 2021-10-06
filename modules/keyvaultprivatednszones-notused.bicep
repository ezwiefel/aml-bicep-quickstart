param keyVaultName string
param keyVaultId string
param virtualNetworkId string
param subnetId string
param location string
param tags object

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
          privateLinkServiceId: keyVaultId
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
  name: 'privatelink.vaultcore.azure.net'
  dependsOn: [
    keyVaultPrivateEndpoint
  ]
  location: 'global'
  properties: {
  }
}

resource keyVaultPrivateDnsZoneARecord 'Microsoft.Network/privateDnsZones/A@2018-09-01' = {
  name: '${keyVaultPrivateDnsZone.name}/${keyVaultName}'
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
  name: '${keyVaultPrivateDnsZone.name}/${uniqueString(keyVaultId)}'
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
