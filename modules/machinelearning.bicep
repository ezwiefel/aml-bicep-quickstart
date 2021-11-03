// Creates a machine learning workspace, private endpoints and compute resources
// Compute resources include a GPU cluster, CPU cluster, compute instance and attached private AKS cluster
targetScope = 'resourceGroup'

// Parameters
param prefix string
param location string
param tags object
param machineLearningName string
param machineLearningPleName string
param applicationInsightsId string
param containerRegistryId string
param keyVaultId string
param storageAccountId string
param subnetId string
param computeSubnetId string
param aksSubnetId string
param virtualNetworkId string

// Resources
resource machineLearning 'Microsoft.MachineLearningServices/workspaces@2021-04-01' = {
  name: machineLearningName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    allowPublicAccessWhenBehindVnet: false
    description: machineLearningName
    friendlyName: machineLearningName
    hbiWorkspace: true
    imageBuildCompute: 'cpucluster001'
    primaryUserAssignedIdentity: ''
    serviceManagedResourcesSettings: {
      cosmosDb: {
        collectionsThroughput: 400
      }
    }
    applicationInsights: applicationInsightsId
    containerRegistry: containerRegistryId
    keyVault: keyVaultId
    storageAccount: storageAccountId
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

// AML Compute - GPU cluster
resource machineLearningGpuCluster001 'Microsoft.MachineLearningServices/workspaces/computes@2021-04-01' = {
  parent: machineLearning
  name: 'gpucluster001'
  dependsOn: [
    machineLearningPrivateEndpoint
  ]
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
}

// AML Compute - CPU cluster
resource machineLearningCpuCluster001 'Microsoft.MachineLearningServices/workspaces/computes@2021-04-01' = {
  parent: machineLearning
  name: 'cpucluster001'
  dependsOn: [
    machineLearningPrivateEndpoint
  ]
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
      vmSize: 'Standard_Ds3_v2'
    }
  }
}

// Compute Instance
resource machineLearningComputeInstance001 'Microsoft.MachineLearningServices/workspaces/computes@2021-04-01' = {
  parent: machineLearning
  name: '${prefix}-ci001'
  dependsOn: [
    machineLearningPrivateEndpoint
  ]
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
        adminPublicKey: ''
        sshPublicAccess: 'Disabled'
      }
      subnet: {
        id: computeSubnetId
      }
      vmSize: 'Standard_DS3_v2'
    }
  }
}

module machineLearningAksCompute 'privateaks.bicep' = {
  name: 'mlprivateaks001'
  dependsOn: [
    machineLearning
    machineLearningPrivateEndpoint
  ]
  scope: resourceGroup()
  params: {
    location: location
    tags: tags
    aksClusterName: 'privateaks001'
    computeName: 'aks001'
    aksSubnetId: aksSubnetId
    workspaceName: machineLearningName
  }
}
// Outputs
output machineLearningId string = machineLearning.id
