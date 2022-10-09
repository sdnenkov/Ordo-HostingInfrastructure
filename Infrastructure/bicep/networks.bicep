param rgName string = 'rg-enterprise-networking-hubs'
param location string = 'uksouth'

targetScope = 'subscription'


resource networkingHubs 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgName
  location: location
}
