param rgName string
param location string = 'uksouth'

targetScope = 'subscription'


resource networkingHubs 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgName
  location: location
}
