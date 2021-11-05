// Creates private endpoints and DNS zones for the azure machine learning workspace
targetScope = 'resourceGroup'

@description('Azure region of the deployment')
param location string

@description('Resource ID of the virtual network resource')
param virtualNetworkId string

@description('Resource ID of the subnet resource')
param subnetId string

@description('Resource ID of the machine learning workspace')
param workspaceArmId string

@description('Tags to add to the resources')
param tags object

var groupName = 'amlworkspace'

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
            groupName
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

resource privateEndpointDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-06-01' = {
  name: '${machineLearningPrivateEndpoint.name}/${groupName}-PrivateDnsZoneGroup'
  dependsOn: [
    machineLearningPrivateEndpoint
    notebookPrivateDnsZone
  ]
  properties:{
    privateDnsZoneConfigs: [
      {
        name: privateDnsZoneName[environment().name]
        properties:{
          privateDnsZoneId: amlPrivateDnsZone.id
        }
      }
      {
        name: privateAznbDnsZoneName[environment().name]
        properties:{
          privateDnsZoneId: notebookPrivateDnsZone.id
        }
      }
    ]
  }
}
