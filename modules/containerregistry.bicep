// Creates an Azure Container Registry with Azure Private Link endpoint
targetScope = 'resourceGroup'

@description('Azure region of the deployment')
param location string

@description('Tags to add to the resources')
param tags object

@description('Container registry name')
param containerRegistryName string

@description('Container registry private link endpoint name')
param containerRegistryPleName string

@description('Resource ID of the subnet')
param subnetId string

@description('Resource ID of the virtual network')
param virtualNetworkId string

var containerRegistryNameCleaned = replace(containerRegistryName, '-', '')
var privateDnsZoneName = {
  azureusgovernment: 'privatelink.azurecr.us'
  azurechinacloud: 'privatelink.azurecr.cn'
  azurecloud: 'privatelink.azurecr.io'
}

var groupName = 'registry' 

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
        name: containerRegistryPleName
        properties: {
          groupIds: [
            groupName
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

resource privateEndpointDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-06-01' = {
  name: '${containerRegistryPrivateEndpoint.name}/${groupName}-PrivateDnsZoneGroup'
  dependsOn: [
    containerRegistryPrivateEndpoint
    acrPrivateDnsZone
  ]
  properties:{
    privateDnsZoneConfigs: [
      {
        name: privateDnsZoneName[toLower(environment().name)]
        properties:{
          privateDnsZoneId: acrPrivateDnsZone.id
        }
      }
    ]
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

output containerRegistryId string = containerRegistry.id
