/*
     Copyright (c) Microsoft Corporation.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

          http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
*/

@description('The base URI where artifacts required by this template are located. When the template is deployed using the accompanying scripts, a private location in the subscription will be used and this value will be automatically generated.')
param _artifactsLocation string = deployment().properties.templateLink.uri

@description('The sasToken required to access _artifactsLocation.  When the template is deployed using the accompanying scripts, a sasToken will be automatically generated. Use the defaultValue if the staging location is not secured.')
@secure()
param _artifactsLocationSasToken string = ''

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Boolean value indicating, if user wants to deploy a tWAS single server for evaluation only.')
param useTrial bool

@description('Username of your IBMid account.')
param ibmUserId string = ''

@description('Password of your IBMid account.')
@secure()
param ibmUserPwd string = ''

@description('Boolean value indicating, if user agrees to IBM contacting my company or organization.')
param shareCompanyName bool = false

@description('The size of virtual machine to provision.')
param vmSize string

@description('The string to prepend to the DNS label.')
param dnsLabelPrefix string

@description('Username for the Virtual Machine.')
param adminUsername string

@description('SSH Key or password for the Virtual Machine. SSH key is recommended.')
@secure()
param adminPasswordOrKey string

@description('Type of authentication to use on the Virtual Machine. SSH key is recommended.')
@allowed([
  'sshPublicKey'
  'password'
])
param authenticationType string

@description('Username for WebSphere admin.')
param wasUsername string

@description('Password for WebSphere admin.')
@secure()
param wasPassword string

@description('VNET for Single Server.')
param vnetForSingleServer object = {
  name: 'twassingle-vnet'
  resourceGroup: resourceGroup().name
  addressPrefixes: [
    '10.0.0.32/28'
  ]
  addressPrefix: '10.0.0.32/28'
  newOrExisting: 'new'
  subnets: {
    subnet1: {
      name: 'twassingle-subnet'
      addressPrefix: '10.0.0.32/29'
      startAddress: '10.0.0.36'
    }
  }
}
@description('To mitigate ARM-TTK error: Control Named vnetForSingleServer must output the newOrExisting property when hideExisting is false')
param newOrExistingVnetForSingleServer string = 'new'
@description('To mitigate ARM-TTK error: Control Named vnetForSingleServer must output the resourceGroup property when hideExisting is false')
param vnetRGNameForSingleServer string = resourceGroup().name

@description('Boolean value indicating, if user wants to enable database connection.')
param enableDB bool = false
@allowed([
  'db2'
  'oracle'
])
@description('One of the supported database types')
param databaseType string = 'db2'
@description('JNDI Name for JDBC Datasource')
param jdbcDataSourceJNDIName string = 'jdbc/contoso'
@description('JDBC Connection String')
param dsConnectionURL string = 'jdbc:db2://contoso.db2.database:50000/sample'
@description('User id of Database')
param dbUser string = 'contosoDbUser'
@secure()
@description('Password for Database')
param dbPassword string = newGuid()

param guidValue string = newGuid()

var const_arguments = format(' {0} {1} {2} {3} {4} {5} {6} {7}', wasUsername, wasPassword, enableDB, databaseType, base64(jdbcDataSourceJNDIName), base64(dsConnectionURL), base64(dbUser), base64(dbPassword))
var const_dnsLabelPrefix = format('{0}{1}', dnsLabelPrefix, take(replace(guidValue, '-', ''), 6))
var const_linuxConfiguration = {
  disablePasswordAuthentication: true
  ssh: {
    publicKeys: [
      {
        path: format('/home/{0}/.ssh/authorized_keys', adminUsername)
        keyData: adminPasswordOrKey
      }
    ]
  }
}
var const_newVNet = (newOrExistingVnetForSingleServer == 'new') ? true : false
var const_scriptLocation = uri(_artifactsLocation, 'scripts/')
var name_networkInterface = '${const_dnsLabelPrefix}-if'
var name_networkInterfaceNoPubIp = '${const_dnsLabelPrefix}-if-no-pub-ip'
var name_networkSecurityGroup = '${const_dnsLabelPrefix}-nsg'
var name_publicIPAddress = '${const_dnsLabelPrefix}-ip'
var name_virtualMachine = '${const_dnsLabelPrefix}-vm'

// Work around arm-ttk test "Variables Must Be Referenced"
var configBase64 = loadFileAsBase64('config.json')
var config = base64ToJson(configBase64)

module partnerCenterPid './modules/_pids/_empty.bicep' = {
  name: 'pid-5d69db5c-7773-47d1-9455-890d05fb3c2b-partnercenter'
  params: {}
}

module shareCompanyNamePid './modules/_pids/_empty.bicep' = if (useTrial && shareCompanyName) {
  name: config.shareCompanyNamePid
  params: {}
}

module singleServerStartPid './modules/_pids/_empty.bicep' = {
  name: (useTrial ? config.singleserverTrialStart : config.singleserverStart)
  params: {}
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2021-08-01' = if (const_newVNet) {
  name: name_networkSecurityGroup
  location: location
  properties: {
    securityRules: [
      {
        name: 'TCP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 300
          direction: 'Inbound'
          destinationPortRanges: [
            '9060'
            '9080'
            '9043'
            '9443'
          ]
        }
      }
    ]
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-08-01' = if (const_newVNet) {
  name: vnetForSingleServer.name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: vnetForSingleServer.addressPrefixes
    }
    subnets: [
      {
        name: vnetForSingleServer.subnets.subnet1.name
        properties: {
          addressPrefix: vnetForSingleServer.subnets.subnet1.addressPrefix
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
        }
      }
    ]
  }
}

resource existingVNet 'Microsoft.Network/virtualNetworks@2021-08-01' existing = if (!const_newVNet) {
  name: vnetForSingleServer.name
  scope: resourceGroup(vnetRGNameForSingleServer)
}

resource existingSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-08-01' existing = if (!const_newVNet) {
  parent: existingVNet
  name: vnetForSingleServer.subnets.subnet1.name
}

resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2021-08-01' = if (const_newVNet) {
  name: name_publicIPAddress
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: concat(toLower(const_dnsLabelPrefix))
    }
  }
}

resource networkInterface 'Microsoft.Network/networkInterfaces@2021-08-01' = if (const_newVNet) {
  name: name_networkInterface
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIPAddress.id
          }
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetForSingleServer.name, vnetForSingleServer.subnets.subnet1.name)
          }
        }
      }
    ]
    dnsSettings: {
      internalDnsNameLabel: name_virtualMachine
    }
  }
  dependsOn: [
    virtualNetwork
  ]
}

resource networkInterfaceNoPubIp 'Microsoft.Network/networkInterfaces@2021-08-01' = if (!const_newVNet) {
  name: name_networkInterfaceNoPubIp
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: existingSubnet.id
          }
        }
      }
    ]
  }
}

resource virtualMachine 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: name_virtualMachine
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: config.imagePublisher
        offer: config.twasImageOffer
        sku: config.twasImageSku
        version: config.twasImageVersion
      }
      osDisk: {
        name: '${name_virtualMachine}-disk'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    osProfile: {
      computerName: name_virtualMachine
      adminUsername: adminUsername
      adminPassword: adminPasswordOrKey
      linuxConfiguration: ((authenticationType == 'password') ? json('null') : const_linuxConfiguration)
      customData: base64(useTrial ? ' ' : format('{0} {1}', ibmUserId, ibmUserPwd))
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: const_newVNet ? networkInterface.id : networkInterfaceNoPubIp.id
        }
      ]
    }
  }
  plan: {
    name: config.twasImageSku
    publisher: config.imagePublisher
    product: config.twasImageOffer
  }
}

module singleServerVMCreated './modules/_pids/_empty.bicep' = {
  name: 'singleServerVMCreated'
  params: {}
  dependsOn: [
    virtualMachine
  ]
}

module dbConnectionStartPid './modules/_pids/_empty.bicep' = if (enableDB) {
  name: config.dbConnectionStart
  params: {}
  dependsOn: [
    virtualMachine
  ]
}

resource vmExtension 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = {
  parent: virtualMachine
  name: 'install'
  location: location
  properties: {
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.0'
    settings: {
      fileUris: [
        uri(const_scriptLocation, 'install.sh${_artifactsLocationSasToken}')
        uri(const_scriptLocation, 'create-ds.sh${_artifactsLocationSasToken}')
        uri(const_scriptLocation, 'create-ds-db2.py.template${_artifactsLocationSasToken}')
        uri(const_scriptLocation, 'create-ds-oracle.py.template${_artifactsLocationSasToken}')
      ]
    }
    protectedSettings: {
      commandToExecute: 'sh install.sh${const_arguments}'
    }
  }
}

module dbConnectionEndPid './modules/_pids/_empty.bicep' = if (enableDB) {
  name: config.dbConnectionEnd
  params: {}
  dependsOn: [
    vmExtension
  ]
}

module singleServerEndPid './modules/_pids/_empty.bicep' = {
  name: (useTrial ? config.singleserverTrialEnd : config.singleserverEnd)
  params: {}
  dependsOn: [
    vmExtension
  ]
}

output adminSecuredConsole string = uri(format('https://{0}:9043/', const_newVNet ? publicIPAddress.properties.dnsSettings.fqdn : reference(name_networkInterfaceNoPubIp).ipConfigurations[0].properties.privateIPAddress), 'ibm/console/logon.jsp')
output snoopServletUrl string = uri(format('https://{0}:9443/', const_newVNet ? publicIPAddress.properties.dnsSettings.fqdn : reference(name_networkInterfaceNoPubIp).ipConfigurations[0].properties.privateIPAddress), 'snoop')
output hitCountServletUrl string = uri(format('https://{0}:9443/', const_newVNet ? publicIPAddress.properties.dnsSettings.fqdn : reference(name_networkInterfaceNoPubIp).ipConfigurations[0].properties.privateIPAddress), 'hitcount')
