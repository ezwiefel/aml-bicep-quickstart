// This template is used to create a Container Registry with private endpoint.
targetScope = 'resourceGroup'

// Parameters
param location string
param tags object
param containerRegistryName string
param subnetId string
param virtualNetworkId string

// Variables
var containerRegistryNameCleaned = replace(containerRegistryName, '-', '')

var privateDnsZoneName = {
  azureusgovernment: 'privatelink.azurecr.us'
  azurechinacloud: 'privatelink.azurecr.cn'
  azurecloud: 'privatelink.azurecr.io'
  }
// Resources
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2020-11-01-preview' = {
  name: containerRegistryNameCleaned
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Premium'
  }
  properties: {
    adminUserEnabled: true
    anonymousPullEnabled: false
    dataEndpointEnabled: false
    networkRuleBypassOptions: 'AzureServices'
    networkRuleSet: {
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
    policies: {
      quarantinePolicy: {
        status: 'enabled'
      }
      retentionPolicy: {
        status: 'enabled'
        days: 7
      }
      trustPolicy: {
        status: 'disabled'
        type: 'Notary'
      }
    }
    publicNetworkAccess: 'Disabled'
    // zoneRedundancy: 'Enabled'  // Uncomment to allow zone redundancy for your Container Registry
  }
}

resource containerRegistryPrivateEndpoint 'Microsoft.Network/privateEndpoints@2020-11-01' = {
  name: 'acr-pe'
  location: location
  tags: tags
  properties: {
    manualPrivateLinkServiceConnections: []
    privateLinkServiceConnections: [
      {
        name: 'acr-pe'
        properties: {
          groupIds: [
            'registry'
          ]
          privateLinkServiceId: containerRegistry.id
          requestMessage: ''
        }
      }
    ]
    subnet: {
      id: subnetId
    }
  }
}

resource acrPrivateDnsZone 'Microsoft.Network/privateDnsZones@2018-09-01' = {
  name: privateDnsZoneName[toLower(environment().name)]

  dependsOn: [
    containerRegistryPrivateEndpoint
  ]
  location: 'global'
  properties: {
  }
}

resource acrDataPrivateDnsZoneARecord 'Microsoft.Network/privateDnsZones/A@2018-09-01' = {
  name: '${acrPrivateDnsZone.name}/${containerRegistry.name}.${location}.data'
  dependsOn: [
    acrPrivateDnsZone
  ]
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: containerRegistryPrivateEndpoint.properties.customDnsConfigs[0].ipAddresses[0]
      }
    ]
  }
}

resource acrPrivateDnsZoneARecord 'Microsoft.Network/privateDnsZones/A@2018-09-01' = {
  name: '${acrPrivateDnsZone.name}/${containerRegistry.name}'
  dependsOn: [
    acrPrivateDnsZone
  ]
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: containerRegistryPrivateEndpoint.properties.customDnsConfigs[1].ipAddresses[0]
      }
    ]
  }
}

resource acrPrivateDnsZoneSOARecord 'Microsoft.Network/privateDnsZones/SOA@2018-09-01' = {
  name: '${acrPrivateDnsZone.name}/@'
  dependsOn: [
    acrPrivateDnsZone
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

resource acrPrivateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  name: '${acrPrivateDnsZone.name}/${uniqueString(containerRegistry.id)}'
  dependsOn: [
    acrPrivateDnsZone
  ]
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetworkId
    }
  }
}

// Outputs
output containerRegistryId string = containerRegistry.id
