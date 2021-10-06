// This template is used to create Private DNS Zones, A records and VNet Links for an AML workspace.
targetScope = 'resourceGroup'

// Parameters
param location string
param virtualNetworkId string
param subnetId string
param workspaceId string
param workspaceArmId string
param workspaceName string
param tags object


var privateDnsZoneName =  {
  azureusgovernment: 'privatelink.api.ml.azure.us'
  azurechinacloud: 'privatelink.api.ml.azure.cn'
  azurecloud: 'privatelink.api.azureml.ms'
}

var privateAznbDnsZoneName = {
    azureusgovernment: 'privatelink.notebooks.usgovcloudapi.net'
    azurechinacloud: 'privatelink.notebooks.chinacloudapi.cn'
    azurecloud: 'privatelink.notebooks.azure.net'
}

resource machineLearningPrivateEndpoint 'Microsoft.Network/privateEndpoints@2020-11-01' = {
  name: 'workspace-pe'
  location: location
  tags: tags
  properties: {
    manualPrivateLinkServiceConnections: []
    privateLinkServiceConnections: [
      {
        name: 'workspace-pe'
        properties: {
          groupIds: [
            'amlworkspace'
          ]
          privateLinkServiceId: workspaceArmId
          requestMessage: ''
        }
      }
    ]
    subnet: {
      id: subnetId
    }
  }
}

resource amlPrivateDnsZone 'Microsoft.Network/privateDnsZones@2018-09-01' = {
  name: privateDnsZoneName[toLower(environment().name)]
  dependsOn: [
    machineLearningPrivateEndpoint
  ]
  location: 'global'
  properties: {
  }
}

resource amlCertPrivateDnsZoneARecord 'Microsoft.Network/privateDnsZones/A@2018-09-01' = {
  name: '${amlPrivateDnsZone.name}/${workspaceId}.workspace.${location}.cert'
  dependsOn: [
    amlPrivateDnsZone
  ]
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: machineLearningPrivateEndpoint.properties.customDnsConfigs[0].ipAddresses[0]
      }
    ]
  }
}

resource amlPrivateDnsZoneARecord 'Microsoft.Network/privateDnsZones/A@2018-09-01' = {
  name: '${amlPrivateDnsZone.name}/${workspaceId}.workspace.${location}'
  dependsOn: [
    amlPrivateDnsZone
  ]
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: machineLearningPrivateEndpoint.properties.customDnsConfigs[0].ipAddresses[0]
      }
    ]
  }
}

resource amlPrivateDnsZoneSOARecord 'Microsoft.Network/privateDnsZones/SOA@2018-09-01' = {
  name: '${amlPrivateDnsZone.name}/@'
  dependsOn: [
    amlPrivateDnsZone
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

resource amlPrivateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  name: '${amlPrivateDnsZone.name}/${uniqueString(workspaceArmId)}'
  dependsOn: [
    amlPrivateDnsZone
  ]
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetworkId
    }
  }
}

// Notebook
resource notebookPrivateDnsZone 'Microsoft.Network/privateDnsZones@2018-09-01' = {
  name: privateAznbDnsZoneName[toLower(environment().name)]
  dependsOn: [
    machineLearningPrivateEndpoint
  ]
  location: 'global'
  properties: {
  }
}

resource notebookPrivateDnsZoneSOARecord 'Microsoft.Network/privateDnsZones/SOA@2018-09-01' = {
  name: '${notebookPrivateDnsZone.name}/@'
  dependsOn: [
    notebookPrivateDnsZone
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

resource notebookPrivateDnsZoneARecord 'Microsoft.Network/privateDnsZones/A@2018-09-01' = {
  name: '${notebookPrivateDnsZone.name}/ml-${workspaceName}-${location}-${workspaceId}'
  dependsOn: [
    notebookPrivateDnsZone
  ]
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: machineLearningPrivateEndpoint.properties.customDnsConfigs[2].ipAddresses[0]
      }
    ]
  }
}

resource notebookPrivateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  name: '${notebookPrivateDnsZone.name}/${uniqueString(workspaceArmId)}'
  dependsOn: [
    notebookPrivateDnsZone
  ]
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetworkId
    }
  }
}
