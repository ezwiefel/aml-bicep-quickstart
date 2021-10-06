// This template is used to create a Virtual Network.
targetScope = 'resourceGroup'

// Parameters
param location string
param tags object
param virtualNetworkName string
param networkSecurityGroupId string
param vnetAddressPrefix string = '192.168.0.0/16'
param trainingSubnetPrefix string = '192.168.0.0/24'
param scoringSubnetPrefix string = '192.168.1.0/24'
param azureBastionSubnetPrefix string = '192.168.250.0/27'

// Resources
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
      {
        id: 'AzureBastionSubnet'
        properties: {
          addressPrefix: azureBastionSubnetPrefix
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
        }
        name: 'AzureBastionSubnet'
      }
    ]
  }
}

resource publicIpAddressForBastion 'Microsoft.Network/publicIpAddresses@2020-08-01' = {
  name: 'bastion-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastionHost 'Microsoft.Network/bastionHosts@2019-04-01' = {
  name: 'bastion-jumpbox'
  dependsOn: [
    virtualNetwork
    publicIpAddressForBastion
    ]
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: '${virtualNetwork.id}/subnets/AzureBastionSubnet'
          }
          publicIPAddress: {
            id: publicIpAddressForBastion.id
          }
        }
      }
    ]
  }
}

// Outputs
output virtualNetworkId string = virtualNetwork.id
