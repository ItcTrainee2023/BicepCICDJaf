targetScope = 'subscription'

// General Parameters 
// =================
@description('The location to deploy resources to.')
param location string = 'uksouth'

@description('The Resource Tags to add to deployed resources')
param tags object = {
  environmentType: 'Production'
  projectCode: 'ZEUS'
  'App Id': 'prod\\alm'
  'Project Code': '8088030'
  Environment : 'Production'
  'Application Name': 'Production_ALM'
  'Business Owner': 'Grade 1 E.S.;Matt Oldrieve'
  'License Required': 'Unknown'
  'Operations Team': 'ddatcloudoperations@nca.gov.uk'
  'Project Name': 'Production_ALM'
  'Cost Code' : '60-005-121'
}

// Subnet Parameters for adding new subnet to existing VNet
// ========================================================

@description('The existing VNET Resourcegroup that you are deploying the Subnet to.')
param vnetResourceGroup string = 'vnetRG' //Change
@description('The existing VNET name that you are deploying the Subnet to.')
param existingVnetName string = 'testvnet' //change
@description('The new Subnet name that you are deploying')
param newSubnetName string = 'ACRSubnet' //change
@description('The Subnet Address that you are deploying.')
param newSubnetAddressPrefix string = '10.0.1.0/24' //change


// Resource Group Parameters for ACR network
// =========================================

@description('The Resource Group to deploy resources to.')
param resourceGroupName string = 'NCA_ACR_RG' //change

// Azure Container Registry (ACR) Parameters 
// =========================================



// ===============================================================================================================
// ===============================================================================================================

// Create New Resource Group for ACR
// =================================
resource NCA_ACR_RG 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// Add new Subnet to existing VNet
// ===============================

module NCA_ACR_Subnet './bicep/SubnetAdd/deploy.bicep' = {
  name: '${uniqueString(deployment().name, location)}-nca-acr-subnet-deployment' 
  scope: resourceGroup(vnetResourceGroup)
  params: {
    existingVNETName: existingVnetName
    newSubnetName: newSubnetName
    newSubnetAddressPrefix: newSubnetAddressPrefix
  }
}


// Create ACR
// =================

module NCA_ACR './bicep/ACR/deploy.bicep' = {
  name: '${uniqueString(deployment().name, location)}-nca-acr-deployment' 
  scope: resourceGroup(NCA_ACR_RG.name)
  params: {
    name: 'NCAContainerRegistry001'
    acrAdminUserEnabled: false
    acrSku: 'Premium'
    anonymousPullEnabled: false
    azureADAuthenticationAsArmPolicyStatus: 'enabled'
    exportPolicyStatus: 'enabled'
    location: location
    publicNetworkAccess: 'Disabled'
    quarantinePolicyStatus: 'enabled'
    retentionPolicyStatus: 'enabled'
    retentionPolicyDays: 15 
    networkRuleBypassOptions: 'AzureServices'
    zoneRedundancy: 'Enabled'
    tags: tags
   
    
  }
}

// Create Private DNS Zone
module privateDNSZone 'bicep/PrivateDNS/deploy.bicep' = {
  name: '${uniqueString(deployment().name, location)}-nca-privatednszone-deployment'
  scope: resourceGroup(NCA_ACR_RG.name)
  params: {
   
    virtualNetworkLinkName:'NCAPrivateEndpoint'
    virtualNetworkId: NCA_ACR_Subnet.outputs.virtualNetworkId
    tags: tags
    // privateEndpointResourceId: privateEndpointDeploy.outputs.privateEndpointResourceId
    // acrEndpointArecord: 'NCAprivateEndpointArecord'
    // privateDnsZoneName: 'nca.private.dns.zone'
    // location: location
  }
}


// Create Private Endpoint
module privateEndpointDeploy './bicep/PrivateEndpoint/deploy.bicep' = {
  name: '${uniqueString(deployment().name, location)}-nca-privateendpoint-deployment'
  scope: resourceGroup(NCA_ACR_RG.name)
  params: {
    endPointName: 'NCAPrivateEndpoint'
    location: location
    resourceID: NCA_ACR.outputs.resourceId
    subnetId: NCA_ACR_Subnet.outputs.subnetId
    subnetName: NCA_ACR_Subnet.outputs.subnetName
    privateDnsZoneId: privateDNSZone.outputs.privateDnsZoneResourceId
    privatelinkName: 'NCRprivateLink'

    tags: tags
  }
}






