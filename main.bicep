@description('Prefix for resource names (e.g., "oef")')
param namePrefix string = 'oef' 

@description('Location for all resources (should match the resource group location)')
param location string = resourceGroup().location

@description('Container image URI (e.g., oefaziac.azurecr.io/aziac:v1)')
param containerImage string

@description('DNS label for the public IP of the container instance')
param dnsLabel string = '${namePrefix}aci'

@description('Log Analytics Workspace Resource ID for container diagnostics')
param logAnalyticsWorkspaceId string

// Create a Network Security Group to restrict traffic
resource nsg 'Microsoft.Network/networkSecurityGroups@2020-11-01' = {
  name: '${namePrefix}-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
    ]
  }
}

// dedicated Subnet and associate the NSG
resource vnet 'Microsoft.Network/virtualNetworks@2020-11-01' = {
  name: '${namePrefix}-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: '${namePrefix}-subnet'
        properties: {
          addressPrefix: '10.0.0.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

// Azure Container Instance deployment
resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2021-09-01' = {
  name: '${namePrefix}-aci'
  location: location
  properties: {
    containers: [
      {
        name: '${namePrefix}-container'
        properties: {
          image: containerImage
          ports: [
            {
              port: 80
            }
          ]
          resources: {
            requests: {
              cpu: 1
              memoryInGb: 2
            }
          }
          // Add environmentVariables if needed
        }
      }
    ]
    osType: 'Linux'
    ipAddress: {
      type: 'Public'
      dnsNameLabel: dnsLabel
      ports: [
        {
          protocol: 'tcp'
          port: 80
        }
      ]
    }
    // Deploy ACI within the dedicated subnet
    subnetIds: [
      {
        id: vnet.properties.subnets[0].id
      }
    ]
    // Configure diagnostics to send logs to Azure Monitor
    diagnostics: {
      logAnalytics: {
        workspaceResourceId: logAnalyticsWorkspaceId
      }
    }
  }
}

output containerGroupIP string = containerGroup.properties.ipAddress.ip
