// This template is used to create a DSVM jump box.

param location string = resourceGroup().location
param subnetId string
param networkSecurityGroupId string
param virtualMachineName string
param adminUsername string = 'azureuser'

@secure()
param adminPassword string

var aadLoginExtensionName = 'AADLoginForWindows'

resource networkInterface 'Microsoft.Network/networkInterfaces@2018-10-01' = {
  name: '${virtualMachineName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
    networkSecurityGroup: {
      id: networkSecurityGroupId
    }
  }
}

resource virtualMachine 'Microsoft.Compute/virtualMachines@2021-03-01' = {
  name: virtualMachineName
  dependsOn: [
    networkInterface
  ]
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_DS3_v2'
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      imageReference: {
        publisher: 'microsoft-dsvm'
        offer: 'dsvm-win-2019'
        sku: 'server-2019'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
    osProfile: {
      computerName: virtualMachineName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
        patchSettings: {
          enableHotpatching: false
          patchMode: 'AutomaticByOS'
        }
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource virtualMachineName_aadLoginExtensionName 'Microsoft.Compute/virtualMachines/extensions@2018-10-01' = {
  name: '${virtualMachine.name}/${aadLoginExtensionName}'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: aadLoginExtensionName
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
  }
}
