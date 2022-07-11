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
param guidValue string = newGuid()

var const_addressPrefix = '10.0.0.0/16'
var const_arguments = format(' {0} {1}', wasUsername, wasPassword)
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
var const_scriptLocation = uri(_artifactsLocation, 'scripts/')
var const_subnetAddressPrefix = '10.0.1.0/24'
var const_subnetName = 'subnet01'
var name_networkInterface = '${const_dnsLabelPrefix}-if'
var name_networkSecurityGroup = '${const_dnsLabelPrefix}-nsg'
var name_publicIPAddress = '${const_dnsLabelPrefix}-ip'
var name_virtualMachine = '${const_dnsLabelPrefix}-vm'
var name_virtualNetwork = '${const_dnsLabelPrefix}-vnet'

// Work around arm-ttk test "Variables Must Be Referenced"
var configBase64 = loadFileAsBase64('config.json')
var config = base64ToJson(configBase64)

module partnerCenterPid './modules/_pids/_empty.bicep' = {
  name: config.customerUsageAttributionId
  params: {}
}

module singleServerStartPid './modules/_pids/_empty.bicep' = {
  name: (useTrial ? config.singleserverTrialStart : config.singleserverStart)
  params: {}
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2021-08-01' = {
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

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-08-01' = {
  name: name_virtualNetwork
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        const_addressPrefix
      ]
    }
    enableDdosProtection: false
    enableVmProtection: false
  }
  dependsOn: [
    networkSecurityGroup
  ]
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2021-08-01' = {
  parent: virtualNetwork
  name: const_subnetName
  properties: {
    addressPrefix: const_subnetAddressPrefix
    networkSecurityGroup: {
      id: networkSecurityGroup.id
    }
  }
}

resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2021-08-01' = {
  name: name_publicIPAddress
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: concat(toLower(const_dnsLabelPrefix))
    }
  }
}

resource networkInterface 'Microsoft.Network/networkInterfaces@2021-08-01' = {
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
            id: subnet.id
          }
        }
      }
    ]
    dnsSettings: {
      internalDnsNameLabel: name_virtualMachine
    }
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
          id: networkInterface.id
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
      ]
    }
    protectedSettings: {
      commandToExecute: 'sh install.sh${const_arguments}'
    }
  }
}

module singleServerEndPid './modules/_pids/_empty.bicep' = {
  name: (useTrial ? config.singleserverTrialEnd : config.singleserverEnd)
  params: {}
  dependsOn: [
    vmExtension
  ]
}

output adminSecuredConsole string = uri(format('https://{0}:9043/', publicIPAddress.properties.dnsSettings.fqdn), 'ibm/console')
output snoopServletUrl string = uri(format('https://{0}:9443/', publicIPAddress.properties.dnsSettings.fqdn), 'snoop')
output hitCountServletUrl string = uri(format('https://{0}:9443/', publicIPAddress.properties.dnsSettings.fqdn), 'hitcount')
