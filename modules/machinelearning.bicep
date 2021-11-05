// Creates a machine learning workspace, private endpoints and compute resources
// Compute resources include a GPU cluster, CPU cluster, compute instance and attached private AKS cluster
targetScope = 'resourceGroup'

@description('Prefix for resource names')
param prefix string

@description('Azure region of the deployment')
param location string

@description('Tags to add to the resources')
param tags object

@description('Machine learning workspace name')
param machineLearningName string

@description('Machine learning workspace display name')
param machineLearningFriendlyName string = machineLearningName

@description('Machine learning workspace description')
param machineLearningDescription string

@description('Resource ID of the application insights resource')
param applicationInsightsId string

@description('Resource ID of the container registry resource')
param containerRegistryId string

@description('Resource ID of the key vault resource')
param keyVaultId string

@description('Resource ID of the storage account resource')
param storageAccountId string

@description('Resource ID of the subnet resource')
param subnetId string

@description('Resource ID of the compute subnet')
param computeSubnetId string

@description('Resource ID of the Azure Kubernetes services resource')
param aksSubnetId string

@description('Resource ID of the virtual network')
param virtualNetworkId string
 
resource machineLearning 'Microsoft.MachineLearningServices/workspaces@2021-04-01' = {
  name: machineLearningName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    // workspace organization
    friendlyName: machineLearningFriendlyName
    description: machineLearningDescription

    // dependent resources
    applicationInsights: applicationInsightsId
    containerRegistry: containerRegistryId
    keyVault: keyVaultId
    storageAccount: storageAccountId

    // configuration for workspaces with private link endpoint
    imageBuildCompute: 'cpucluster001'
    allowPublicAccessWhenBehindVnet: false
  }
}

module machineLearningPrivateEndpoint 'machinelearningprivatednszones.bicep' = {
  name: 'machineLearningPrivateDnsZones001'
  scope: resourceGroup()
  params: {
    location: location
    tags: tags
    virtualNetworkId: virtualNetworkId
    workspaceArmId: machineLearning.id
    subnetId: subnetId
  }
}

resource machineLearningCpuCluster001 'Microsoft.MachineLearningServices/workspaces/computes@2021-04-01' = {
  parent: machineLearning
  name: 'cpucluster001'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    computeType: 'AmlCompute'
    computeLocation: location
    description: 'Machine Learning cluster 001'
    disableLocalAuth: true
    properties: {
      vmPriority: 'Dedicated'
      vmSize: 'Standard_Ds3_v2'
      enableNodePublicIp: false
      isolatedNetwork: false
      osType: 'Linux'
      remoteLoginPortPublicAccess: 'Disabled'
      scaleSettings: {
        minNodeCount: 0
        maxNodeCount: 8
        nodeIdleTimeBeforeScaleDown: 'PT120S'
      }
      subnet: {
        id: computeSubnetId
      }
    }
  }
  dependsOn: [
    machineLearningPrivateEndpoint
  ]
}

resource machineLearningGpuCluster001 'Microsoft.MachineLearningServices/workspaces/computes@2021-04-01' = {
  parent: machineLearning
  name: 'gpucluster001'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    computeType: 'AmlCompute'
    computeLocation: location
    description: 'Machine Learning cluster 001'
    disableLocalAuth: true
    properties: {
      enableNodePublicIp: false
      isolatedNetwork: false
      osType: 'Linux'
      remoteLoginPortPublicAccess: 'Disabled'
      scaleSettings: {
        minNodeCount: 0
        maxNodeCount: 8
        nodeIdleTimeBeforeScaleDown: 'PT120S'
      }
      subnet: {
        id: computeSubnetId
      }
      vmPriority: 'Dedicated'
      vmSize: 'Standard_NC6'
    }
  }
  dependsOn: [
    machineLearningPrivateEndpoint
  ]
}

resource machineLearningComputeInstance001 'Microsoft.MachineLearningServices/workspaces/computes@2021-04-01' = {
  parent: machineLearning
  name: '${prefix}-ci001'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    computeType: 'ComputeInstance'
    computeLocation: location
    description: 'Machine Learning compute instance 001'
    disableLocalAuth: true
    properties: {
      applicationSharingPolicy: 'Personal'
      computeInstanceAuthorizationType: 'personal'
      sshSettings: {
        sshPublicAccess: 'Disabled'
        adminPublicKey: ''
      }
      subnet: {
        id: computeSubnetId
      }
      vmSize: 'Standard_DS3_v2'
    }
  }
  dependsOn: [
    machineLearningPrivateEndpoint
  ]
}

module machineLearningAksCompute 'privateaks.bicep' = {
  name: 'mlprivateaks001'
  scope: resourceGroup()
  params: {
    location: location
    tags: tags
    aksClusterName: 'privateaks001'
    computeName: 'aks001'
    aksSubnetId: aksSubnetId
    workspaceName: machineLearningName
  }
  dependsOn: [
    machineLearning
    machineLearningPrivateEndpoint
  ]
}

output machineLearningId string = machineLearning.id
