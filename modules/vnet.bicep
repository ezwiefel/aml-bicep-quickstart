// Creates a virtual network
targetScope = 'resourceGroup'

param location string = resourceGroup().location
param tags object = {}
param virtualNetworkName string
param networkSecurityGroupId string
param vnetAddressPrefix string = '192.168.0.0/16'
param trainingSubnetPrefix string = '192.168.0.0/24'
param scoringSubnetPrefix string = '192.168.1.0/24'

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2020-07-01' = {
  name: virtualNetworkName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        id: 'snet-training'
        properties: {
          addressPrefix: trainingSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
          serviceEndpoints: [
            {
              service: 'Microsoft.KeyVault'
            }
            {
              service: 'Microsoft.ContainerRegistry'
            }
            {
              service: 'Microsoft.Storage'
            }
          ]
          networkSecurityGroup: {
            id: networkSecurityGroupId
          }
        }
        name: 'snet-training'
      }
      {
        id: 'snet-scoring'
        properties: {
          addressPrefix: scoringSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
          serviceEndpoints: [
            {
              service: 'Microsoft.KeyVault'
            }
            {
              service: 'Microsoft.ContainerRegistry'
            }
            {
              service: 'Microsoft.Storage'
            }
          ]
          networkSecurityGroup: {
            id: networkSecurityGroupId
          }
        }
        name: 'snet-scoring'
      }
    ]
  }
}

output id string = virtualNetwork.id
output name string = virtualNetwork.name
