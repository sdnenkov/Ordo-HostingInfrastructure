param targetVnetResourceId string
param publicIPAddresses_38e92ada_592d_48ae_97a4_2d207b2e9c8f_externalid string = '/subscriptions/c0c87753-81bc-4758-a393-19c88c177d7c/resourceGroups/MC_sdn-rg-transport_transport_uksouth/providers/Microsoft.Network/publicIPAddresses/38e92ada-592d-48ae-97a4-2d207b2e9c8f'
param userAssignedIdentities_transport_agentpool_externalid string = '/subscriptions/c0c87753-81bc-4758-a393-19c88c177d7c/resourceGroups/MC_sdn-rg-transport_transport_uksouth/providers/Microsoft.ManagedIdentity/userAssignedIdentities/transport-agentpool'

var nodeResourceGroupName = '${resourceGroup().name}-nodepools'
var clusterName = 'aks-ordo-cluster'
// var nplinuxMinCount = 1
// var nplinuxMaxCount = 1
var vnetNodePoolSubnetResourceId = '${targetVnetResourceId}/subnets/snet-cluster-nodepools'

// Begin AKS cluster ------------------------------------------------------------------------------
resource cluster 'Microsoft.ContainerService/managedClusters@2022-07-02-preview' = {
  name: clusterName
  location: 'uksouth'
  sku: {
    name: 'Basic'
    tier: 'Free'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    kubernetesVersion: '1.22.6'
    dnsPrefix: uniqueString(subscription().subscriptionId, resourceGroup().id, clusterName)
    agentPoolProfiles: [
      {
        name: 'agentpool'
        count: 0
        vmSize: 'Standard_B2s'
        osDiskSizeGB: 128
        osDiskType: 'Managed'
        kubeletDiskType: 'OS'
        maxPods: 110
        type: 'VirtualMachineScaleSets'
        enableAutoScaling: false
        powerState: {
          code: 'Stopped'
        }
        orchestratorVersion: '1.22.6'
        enableNodePublicIP: false
        enableCustomCATrust: false
        mode: 'System'
        osType: 'Linux'
        osSKU: 'Ubuntu'
        enableFIPS: false
      }
    ]
    servicePrincipalProfile: {
      clientId: 'msi'
    }
    addonProfiles: {
      azureKeyvaultSecretsProvider: {
        enabled: false
      }
      azurepolicy: {
        enabled: false
      }
      httpApplicationRouting: {
        enabled: false
      }
    }
    vnetSubnetID: vnetNodePoolSubnetResourceId
    nodeResourceGroup: nodeResourceGroupName
    enableRBAC: true
    networkProfile: {
      networkPlugin: 'kubenet'
      loadBalancerSku: 'Standard'
      loadBalancerProfile: {
        managedOutboundIPs: {
          count: 1
        }
        effectiveOutboundIPs: [
          {
            id: publicIPAddresses_38e92ada_592d_48ae_97a4_2d207b2e9c8f_externalid
          }
        ]
      }
      podCidr: '10.244.0.0/16'
      serviceCidr: '10.0.0.0/16'
      dnsServiceIP: '10.0.0.10'
      dockerBridgeCidr: '172.17.0.1/16'
      outboundType: 'loadBalancer'
    }
    identityProfile: {
      kubeletidentity: {
        resourceId: userAssignedIdentities_transport_agentpool_externalid
        clientId: '7b790c02-484e-4bda-a66b-3986d5f9b469'
        objectId: 'a1ab438a-bb1f-435d-8a6c-4d2a8f0d3896'
      }
    }
    securityProfile: {
    }
    storageProfile: {
      diskCSIDriver: {
        enabled: true
        version: 'v1'
      }
      fileCSIDriver: {
        enabled: true
      }
      snapshotController: {
        enabled: true
      }
    }
    oidcIssuerProfile: {
      enabled: false
    }
  }
}
