// This template is used to create a secure Azure Machine Learning workspace with CPU cluster, GPU cluster, Compute Instance and attached private AKS cluster.

targetScope = 'resourceGroup'

// General parameters
@description('Specifies the location for all resources.')
param location string = resourceGroup().location

@minLength(2)
@maxLength(10)
@description('Specifies the prefix for all resources created in this deployment.')
param prefix string

@description('Specifies the tags that you want to apply to all resources.')
param tags object = {}

// Resource parameters
// Vnet/Subnet address prefixes
@description('Specifies the address prefix of the virtual network.')
param vnetAddressPrefix string = '192.168.0.0/16'

@description('Specifies the address prefix of the training subnet.')
param trainingSubnetPrefix string = '192.168.0.0/24'

@description('Specifies the address prefix of the scoring subnet.')
param scoringSubnetPrefix string = '192.168.1.0/24'

@description('Specifies the address prefix of the azure bastion subnet.')
param azureBastionSubnetPrefix string = '192.168.250.0/27'

// DSVM Jumpbox username and password
param dsvmJumpboxUsername string
@secure()
param dsvmJumpboxPassword string

// Variables
var name = toLower('${prefix}')

// Create a short, unique suffix, that will be unique to each resource group
// The default 'uniqueString' function will return a 13 char string, here, we're taking 
// the first 4 characters - which will reduce the uniqueness, but increase readability
var uniqueSuffix = substring(uniqueString(resourceGroup().id), 0, 4)

// Resources

module nsg 'modules/nsg.bicep' = {
  // Name of the deploymnet
  name: 'nsg-${name}-${uniqueSuffix}-deployment'
  scope: resourceGroup()
  params: {
    location: location
    tags: tags
    // Name of the NSG
    nsgName: 'nsg-${name}-${uniqueSuffix}'
  }
}

module vnet 'modules/vnet.bicep' = {
  // Name of the deployment
  name: 'vnet-${name}-${uniqueSuffix}-deployment'
  dependsOn: [
    nsg
  ]
  scope: resourceGroup()
  params: {
    location: location
    tags: tags

    // Name of the VNet
    virtualNetworkName: 'vnet-${name}-${uniqueSuffix}'
    networkSecurityGroupId: nsg.outputs.networkSecurityGroup
    vnetAddressPrefix: vnetAddressPrefix
    trainingSubnetPrefix: trainingSubnetPrefix
    scoringSubnetPrefix: scoringSubnetPrefix
    azureBastionSubnetPrefix: azureBastionSubnetPrefix
  }
}


module storage 'modules/storage.bicep' = {
  // Name of the deployment
  name: 'st${name}${uniqueSuffix}-deployment'
  dependsOn: [
    vnet
  ]
  scope: resourceGroup()
  params: {
    location: location
    tags: tags
    // Name of the storage account
    storageName: 'st${name}${uniqueSuffix}'
    storageSkuName: 'Standard_LRS'
    subnetId: '${vnet.outputs.virtualNetworkId}/subnets/snet-training'
    virtualNetworkId: '${vnet.outputs.virtualNetworkId}'
  }
}

// Resources
module keyvault 'modules/keyvault.bicep' = {
  // Name of the deployment
  name: 'kv-${name}-${uniqueSuffix}-deployment'
  dependsOn: [
    vnet
  ]
  scope: resourceGroup()
  params: {
    location: location
    tags: tags
    // Name of the keyvault
    keyvaultName: 'kv-${name}-${uniqueSuffix}'
    subnetId: '${vnet.outputs.virtualNetworkId}/subnets/snet-training'
    virtualNetworkId: '${vnet.outputs.virtualNetworkId}'
  }
}

module containerRegistry 'modules/containerregistry.bicep' = {
  // Name of the deployment
  name: 'cr${name}${uniqueSuffix}-deployment'
  dependsOn: [
    vnet
  ]
  scope: resourceGroup()
  params: {
    location: location
    tags: tags
    // Name of the container registry
    containerRegistryName: 'cr${name}${uniqueSuffix}'
    subnetId: '${vnet.outputs.virtualNetworkId}/subnets/snet-training'
    virtualNetworkId: '${vnet.outputs.virtualNetworkId}'
  }
}

module applicationInsights 'modules/applicationinsights.bicep' = {
  // Name of the deployment
  name: 'ai-${name}-${uniqueSuffix}-deployment'
  dependsOn: [
    vnet
  ]
  scope: resourceGroup()
  params: {
    location: location
    tags: tags
    // Name of the Application Insights workspace
    applicationInsightsName: 'ai-${name}-${uniqueSuffix}'
  }
}

module amlWorkspace 'modules/machinelearning.bicep' = {
  // Name of the deployment
  name: 'mlw-${name}-${uniqueSuffix}-deployment'
  dependsOn: [
    keyvault
    containerRegistry
    applicationInsights
    storage
  ]
  scope: resourceGroup()
  params: {
    location: location
    prefix: name
    tags: tags
    // Name of the AML workspace
    machineLearningName: 'mlw-${name}-${uniqueSuffix}'
    applicationInsightsId: applicationInsights.outputs.applicationInsightsId
    containerRegistryId: containerRegistry.outputs.containerRegistryId
    keyVaultId: keyvault.outputs.keyvaultId
    storageAccountId: storage.outputs.storageId
    subnetId: '${vnet.outputs.virtualNetworkId}/subnets/snet-training'
    computeSubnetId: '${vnet.outputs.virtualNetworkId}/subnets/snet-training'
    aksSubnetId: '${vnet.outputs.virtualNetworkId}/subnets/snet-scoring'
    virtualNetworkId: '${vnet.outputs.virtualNetworkId}'
  }
}

module dsvm 'modules/dsvmjumpbox.bicep' = {
  // Name of the deployment
  name: 'dsvm-${name}-${uniqueSuffix}-deployment'
  scope: resourceGroup()
  params: {
    location: location
    // Name of the DSVM
    virtualMachineName: 'dsvm-${name}-${uniqueSuffix}'
    subnetId: '${vnet.outputs.virtualNetworkId}/subnets/snet-training'
    adminUsername: dsvmJumpboxUsername
    adminPassword: dsvmJumpboxPassword
    networkSecurityGroupId: nsg.outputs.networkSecurityGroup 
  }
}
