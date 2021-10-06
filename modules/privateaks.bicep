param aksClusterName string
param location string
param tags object
param aksSubnetId string
param workspaceName string
param computeName string

resource aksCluster 'Microsoft.ContainerService/managedClusters@2020-07-01' = {
  name: aksClusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  tags: tags
  properties: {
    kubernetesVersion: '1.20.7'
    dnsPrefix: '${aksClusterName}-dns'
    sku: {
      name: 'Basic'
    }
    agentPoolProfiles: [
      {
        name: toLower('agentpool')
        count: 3
        vmSize: 'Standard_DS2_v2'
        osDiskSizeGB: 128
        vnetSubnetID: aksSubnetId
        maxPods: 110
        osType: 'Linux'
        mode: 'System'
        type: 'VirtualMachineScaleSets'
        availabilityZones: [
          '1'
          '2'
          '3'
      ]
      }
    ]
    enableRBAC: true
    networkProfile: {
      networkPlugin: 'kubenet'
      serviceCidr: '10.0.0.0/16'
      dnsServiceIP: '10.0.0.10'
      dockerBridgeCidr: '172.17.0.1/16'
      loadBalancerSku: 'standard'
    }
    apiServerAccessProfile: {
      enablePrivateCluster: true
    }
  }
}

//Output
output aksResourceId string = aksCluster.id

resource workspaceName_computeName 'Microsoft.MachineLearningServices/workspaces/computes@2021-01-01' = {
  name: '${workspaceName}/${computeName}'
  location: location
  properties: {
    computeType: 'AKS'
    resourceId: aksCluster.id
    // Not tested with this subnet config
    properties: {
      aksNetworkingConfiguration:  {
        subnetId: aksSubnetId
      } 
      loadBalancerType: 'InternalLoadBalancer'
      loadBalancerSubnet: 'snet-scoring'
    }
  }
}
