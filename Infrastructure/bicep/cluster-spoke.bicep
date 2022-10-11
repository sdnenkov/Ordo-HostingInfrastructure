param location string = 'uksouth'
param hubVnetResourceId string

var orgAppId = 'ordo'
var clusterVNetName = 'vnet-spoke-${orgAppId}-00'

// This is 'rg-enterprise-networking-hubs' if using the default values in the walkthrough
resource hubResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  scope: subscription()
  name: '${split(hubVnetResourceId,'/')[4]}'
}

resource hubVirtualNetwork 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  scope: hubResourceGroup
  name: '${last(split(hubVnetResourceId,'/'))}'
}

// Next hop to the regional hub's Azure Firewall
resource routeNextHopToFirewall 'Microsoft.Network/routeTables@2021-05-01' = {
  name: 'route-to-${location}-hub-fw'
  location: location
  properties: {
    routes: [
      {
        name: 'r-nexthop-to-fw'
        properties: {
          nextHopType: 'VirtualAppliance'
          addressPrefix: '0.0.0.0/0'
          // nextHopIpAddress: hubFirewall.properties.ipConfigurations[0].properties.privateIPAddress
        }
      }
    ]
  }
}

// Default NSG on the AKS nodepools. Feel free to constrict further.
resource nsgNodepoolSubnet 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: 'nsg-${clusterVNetName}-nodepools'
  location: location
  properties: {
    securityRules: []
  }
}

// Default NSG on the AKS internal load balancer subnet. Feel free to constrict further.
resource nsgInternalLoadBalancerSubnet 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: 'nsg-${clusterVNetName}-aksilbs'
  location: location
  properties: {
    securityRules: []
  }
}

// NSG on the Application Gateway subnet.
resource nsgAppGwSubnet 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: 'nsg-${clusterVNetName}-appgw'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow443Inbound'
        properties: {
          description: 'Allow ALL web traffic into 443. (If you wanted to allow-list specific IPs, this is where you\'d list them.)'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationPortRange: '443'
          destinationAddressPrefix: 'VirtualNetwork'
          direction: 'Inbound'
          access: 'Allow'
          priority: 100
        }
      }
      {
        name: 'AllowControlPlaneInbound'
        properties: {
          description: 'Allow Azure Control Plane in. (https://learn.microsoft.com/azure/application-gateway/configuration-infrastructure#network-security-groups)'
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: 'GatewayManager'
          destinationPortRange: '65200-65535'
          destinationAddressPrefix: '*'
          direction: 'Inbound'
          access: 'Allow'
          priority: 110
        }
      }
      {
        name: 'AllowHealthProbesInbound'
        properties: {
          description: 'Allow Azure Health Probes in. (https://learn.microsoft.com/azure/application-gateway/configuration-infrastructure#network-security-groups)'
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationPortRange: '*'
          destinationAddressPrefix: '*'
          direction: 'Inbound'
          access: 'Allow'
          priority: 120
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          description: 'No further inbound traffic allowed.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 1000
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowAllOutbound'
        properties: {
          description: 'App Gateway v2 requires full outbound access.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Outbound'
        }
      }
    ]
  }
}

// NSG on the Private Link subnet.
resource nsgPrivateLinkEndpointsSubnet 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: 'nsg-${clusterVNetName}-privatelinkendpoints'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowAll443InFromVnet'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '443'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 1000
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllOutbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 1000
          direction: 'Outbound'
        }
      }
    ]
  }
}

// The spoke virtual network.
// 65,536 (-reserved) IPs available to the workload, split across two subnets for AKS,
// one for App Gateway and one for Private Link endpoints.
resource vnetSpoke 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: clusterVNetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.240.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'snet-clusternodes'
        properties: {
          addressPrefix: '10.240.0.0/22'
          routeTable: {
            id: routeNextHopToFirewall.id
          }
          networkSecurityGroup: {
            id: nsgNodepoolSubnet.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'snet-clusteringressservices'
        properties: {
          addressPrefix: '10.240.4.0/28'
          routeTable: {
            id: routeNextHopToFirewall.id
          }
          networkSecurityGroup: {
            id: nsgInternalLoadBalancerSubnet.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'snet-applicationgateway'
        properties: {
          addressPrefix: '10.240.5.0/24'
          networkSecurityGroup: {
            id: nsgAppGwSubnet.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'snet-privatelinkendpoints'
        properties: {
          addressPrefix: '10.240.4.32/28'
          networkSecurityGroup: {
            id: nsgPrivateLinkEndpointsSubnet.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }

  resource snetClusterNodes 'subnets' existing = {
    name: 'snet-clusternodes'
  }
}

// Peer to regional hub
module peeringSpokeToHub 'virtualNetworkPeering.bicep' = {
  name: take('Peer-${vnetSpoke.name}To${hubVirtualNetwork.name}', 64)
  params: {
    remoteVirtualNetworkId: hubVirtualNetwork.id
    localVnetName: vnetSpoke.name
  }
}

// Connect regional hub back to this spoke, this could also be handled via the
// hub template or via Azure Policy or Portal. How virtual networks are peered
// may vary from organization to organization. This example simply does it in
// the most direct way.
module peeringHubToSpoke 'virtualNetworkPeering.bicep' = {
  name: take('Peer-${hubVirtualNetwork.name}To${vnetSpoke.name}', 64)
  dependsOn: [
    peeringSpokeToHub
  ]
  scope: hubResourceGroup
  params: {
    remoteVirtualNetworkId: vnetSpoke.id
    localVnetName: hubVirtualNetwork.name
  }
}

// Used as primary public entry point for cluster. Expected to be assigned to an Azure Application Gateway.
// This is a public facing IP, and would be best behind a DDoS Policy (not deployed simply for cost considerations)
resource pipPrimaryClusterIp 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: 'pip-${orgAppId}-00'
  location: location
  sku: {
    name: 'Standard'
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    publicIPAddressVersion: 'IPv4'
  }
}

output clusterVnetResourceId string = vnetSpoke.id
output nodepoolSubnetResourceIds array = [
  vnetSpoke::snetClusterNodes.id
]
output appGwPublicIpAddress string = pipPrimaryClusterIp.properties.ipAddress
