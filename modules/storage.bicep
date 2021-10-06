// This template is used to create a Storage account with a private endpoint.
targetScope = 'resourceGroup'

// Parameters
param location string
param tags object
param storageName string
param subnetId string
param virtualNetworkId string

@allowed([
  'Standard_LRS'
  'Standard_ZRS'
  'Standard_GRS'
  'Standard_GZRS'
  'Standard_RAGRS'
  'Standard_RAGZRS'
  'Premium_LRS'
  'Premium_ZRS'
])
param storageSkuName string = 'Standard_LRS'

// Variables
var storageNameCleaned = replace(storageName, '-', '')
var blobPrivateDnsZoneName =  {
  azureusgovernment: 'privatelink.blob.core.usgovcloudapi.net'
  azurechinacloud: 'privatelink.blob.core.chinacloudapi.cn'
  azurecloud: 'privatelink.blob.core.windows.net'
  }
var filePrivateDnsZoneName =  {
  azureusgovernment: 'privatelink.file.core.usgovcloudapi.net'
  azurechinacloud: 'privatelink.file.core.chinacloudapi.cn'
  azurecloud: 'privatelink.file.core.windows.net'
  }

// Resources
resource storage 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: storageNameCleaned
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: storageSkuName
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowCrossTenantReplication: false
    allowSharedKeyAccess: true
    
    encryption: {
      keySource: 'Microsoft.Storage'
      requireInfrastructureEncryption: false
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
        queue: {
          enabled: true
          keyType: 'Service'
        }
        table: {
          enabled: true
          keyType: 'Service'
        }
      }
    }
    isHnsEnabled: false
    isNfsV3Enabled: false
    keyPolicy: {
      keyExpirationPeriodInDays: 7
    }
    largeFileSharesState: 'Disabled'
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
    routingPreference: {
      routingChoice: 'MicrosoftRouting'
      publishInternetEndpoints: false
      publishMicrosoftEndpoints: false
    }
    supportsHttpsTrafficOnly: true
  }
}

// Blob PE
resource storagePrivateEndpointBlob 'Microsoft.Network/privateEndpoints@2020-11-01' = {
  name: 'storage-blob-pe'
  location: location
  tags: tags
  properties: {
    manualPrivateLinkServiceConnections: []
    privateLinkServiceConnections: [
      {
        name: 'storage-blob-pe'
        properties: {
          groupIds: [
            'blob'
          ]
          privateLinkServiceId: storage.id
          requestMessage: ''
          privateLinkServiceConnectionState: {
            status: 'Approved'
            description: 'Auto-Approved'
            actionsRequired: 'None'
          }
        }
      }
    ]
    subnet: {
      id: subnetId
    }
    /* customDnsConfigs: [
      {
        fqdn: '${storage.name}.blob.core.windows.net'
        ipAddresses: [
          '172.25.0.14'
        ]
      }
    ] */
  }
}

//File
resource storagePrivateEndpointFile 'Microsoft.Network/privateEndpoints@2020-11-01' = {
  name: 'storage-file-pe'
  location: location
  tags: tags
  properties: {
    manualPrivateLinkServiceConnections: []
    privateLinkServiceConnections: [
      {
        name: 'storage-file-pe'
        properties: {
          groupIds: [
            'file'
          ]
          privateLinkServiceId: storage.id
          requestMessage: ''
          privateLinkServiceConnectionState: {
            status: 'Approved'
            description: 'Auto-Approved'
            actionsRequired: 'None'
          }
        }
      }
    ]
    subnet: {
      id: subnetId
    }
    /* customDnsConfigs: [
      {
        fqdn: '${storage.name}.file.core.windows.net'
        ipAddresses: [
          '172.25.0.14'
        ]
      }
    ] */
  }
}

resource blobPrivateDnsZone 'Microsoft.Network/privateDnsZones@2018-09-01' = {
  name: blobPrivateDnsZoneName[toLower(environment().name)]
  dependsOn: [
    storagePrivateEndpointBlob
  ]
  location: 'global'
  properties: {
  }
}

resource privateEndpointDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-06-01' = {
  name: '${storagePrivateEndpointBlob.name}/blob-PrivateDnsZoneGroup'
  dependsOn: [
    storagePrivateEndpointBlob
    blobPrivateDnsZone
  ]
  properties:{
    privateDnsZoneConfigs: [
      {
        name: blobPrivateDnsZoneName[toLower(environment().name)]
        properties:{
          privateDnsZoneId: blobPrivateDnsZone.id
        }
      }
    ]
  }
}

resource blobPrivateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  name: '${blobPrivateDnsZone.name}/${uniqueString(storage.id)}'
  dependsOn: [
    blobPrivateDnsZone
  ]
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetworkId
    }
  }
}

resource filePrivateDnsZone 'Microsoft.Network/privateDnsZones@2018-09-01' = {
  name: filePrivateDnsZoneName[toLower(environment().name)]
  dependsOn: [
    storagePrivateEndpointFile
  ]
  location: 'global'
  properties: {
  }
}

resource filePrivateEndpointDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-06-01' = {
  name: '${storagePrivateEndpointFile.name}/flie-PrivateDnsZoneGroup'
  dependsOn: [
    storagePrivateEndpointFile
    filePrivateDnsZone
  ]
  properties:{
    privateDnsZoneConfigs: [
      {
        name: filePrivateDnsZoneName[toLower(environment().name)]
        properties:{
          privateDnsZoneId: filePrivateDnsZone.id
        }
      }
    ]
  }
}

resource filePrivateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  name: '${filePrivateDnsZone.name}/${uniqueString(storage.id)}'
  location: 'global'
  dependsOn: [
    storagePrivateEndpointFile
  ]
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetworkId
    }
  }
}

// Outputs
output storageId string = storage.id
