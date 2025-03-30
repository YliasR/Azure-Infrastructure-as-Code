param namePrefix string = 'aziac'
param location string = resourceGroup().location
param containerImage string = 'oefaziac.azurecr.io/aziac:v1'
param dnsLabel string = '${namePrefix}aci'
param logAnalyticsWorkspaceId string = '/subscriptions/b2de44bd-8504-46c5-b276-9456e84949a7/resourceGroups/AzureIac/providers/Microsoft.OperationalInsights/workspaces/aziaclog'
param registryUsername string = 'oefaziac'
@description('Container Registry Password')
@secure()
param registryPassword string


// Get the workspace ID and key using the resource ID
var logAnalyticsWorkspace = reference(logAnalyticsWorkspaceId, '2020-03-01-preview')
var workspaceId = logAnalyticsWorkspace.customerId
var workspaceKey = listKeys(logAnalyticsWorkspaceId, '2020-03-01-preview').primarySharedKey

// Create a Network Security Group to restrict traffic
resource nsg 'Microsoft.Network/networkSecurityGroups@2020-11-01' = {
  name: '${namePrefix}-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-AppGw-Ephemeral'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '65200-65535'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 101
          direction: 'Inbound'
        }
      }
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

// virtual network with two subnets: one for container instance and one for Application Gateway
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
        name: '${namePrefix}-subnet' // For container group
        properties: {
          addressPrefix: '10.0.0.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
          delegations: [
            {
              name: 'aciDelegation'
              properties: {
                serviceName: 'Microsoft.ContainerInstance/containerGroups'
              }
            }
          ]
        }
      }
      {
        name: '${namePrefix}-appgw-subnet' // For Application Gateway
        properties: {
          addressPrefix: '10.0.1.0/24'
          // No delegation—this subnet is dedicated to the Application Gateway
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
              memoryInGB: 2
            }
          }
        }
      }
    ]
    osType: 'Linux'
    
    // Deploy ACI within the dedicated subnet
    subnetIds: [
      {
        id: vnet.properties.subnets[0].id
      }
    ]
    // Supply registry credentials for the private container image.
    imageRegistryCredentials: [
      {
        server: 'oefaziac.azurecr.io'
        username: registryUsername
        password: registryPassword
      }
    ]
    // Configure diagnostics to send logs to Azure Monitor
    diagnostics: {
      logAnalytics: {
        workspaceId: workspaceId
        workspaceKey: workspaceKey
      }
    }
  }
}
// Public IP for the container instance
resource publicIp 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: '${namePrefix}-pubip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: dnsLabel
    }
  }
}
// Application Gateway deployment
resource appGateway 'Microsoft.Network/applicationGateways@2022-07-01' = {
  name: '${namePrefix}-appgw'
  location: location
  properties: {
    sku: {
      name: 'Standard_V2'
      tier: 'Standard_V2'
      capacity: 1
    }
    gatewayIPConfigurations: [
      {
        name: 'appGwIpConfig'
        properties: {
          subnet: {
            //the subnet for the Application Gateway
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, '${namePrefix}-appgw-subnet')
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGwFrontend'
        properties: {
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'appGwFrontendPort'
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'appGwBackendPool'
        properties: {
          backendAddresses: [
            {
              ipAddress: '10.0.0.5'
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'appGwBackendHttpSettings'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
        }
      }
    ]
    httpListeners: [
      {
        name: 'appGwHttpListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', '${namePrefix}-appgw', 'appGwFrontend')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', '${namePrefix}-appgw', 'appGwFrontendPort')
          }
          protocol: 'Http'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'appGwRoutingRule'
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', '${namePrefix}-appgw', 'appGwHttpListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', '${namePrefix}-appgw', 'appGwBackendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', '${namePrefix}-appgw', 'appGwBackendHttpSettings')
          }
        }
      }
    ]
    probes: [
      {
        name: 'healthProbe'
        properties: {
          protocol: 'Tcp'
          port: 80
          interval: 5
          timeout: 30
          unhealthyThreshold: 2
        }
      }
    ]
  }
}
output containerGroupIP string = containerGroup.properties.ipAddress.ip
