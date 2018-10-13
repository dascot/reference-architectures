#
# Deploy_ReferenceArchitecture.ps1
#
param(
  [Parameter(Mandatory=$true)]
  $SubscriptionId,

  [Parameter(Mandatory=$false)]
  $Location = "eastus",

  [Parameter(Mandatory=$false)]
  [ValidateSet("Windows", "Linux")]
  $OSType = "Windows",

  [Parameter(Mandatory=$true)]
  [ValidateSet("onpremise", "onpremise-rf", "ntier")]
  $Mode
)

$ErrorActionPreference = "Stop"

$templateRootUriString = $env:TEMPLATE_ROOT_URI
if ($templateRootUriString -eq $null) {
  $templateRootUriString = "https://raw.githubusercontent.com/mspnp/mspnp/-blocks/v1.0.0/"
}
if (![System.Uri]::IsWellFormedUriString($templateRootUriString, [System.UriKind]::Absolute)) {
  throw "Invalid value for TEMPLATE_ROOT_URI: $env:TEMPLATE_ROOT_URI"
}
Write-Host
Write-Host "Using $templateRootUriString to locate templates"
Write-Host

$templateRootUri = New-Object System.Uri -ArgumentList @($templateRootUriString)
$virtualNetworkTemplate = New-Object System.Uri -ArgumentList @($templateRootUri, 'templates/buildingBlocks/vnet-n-subnet/azuredeploy.json')
$virtualMachineTemplate = New-Object System.Uri -ArgumentList @($templateRootUri, 'templates/buildingBlocks/multi-vm-n-nic-m-storage/azuredeploy.json')
$virtualMachineExtensionsTemplate = New-Object System.Uri -ArgumentList @($templateRootUri, "templates/buildingBlocks/virtualMachine-extensions/azuredeploy.json")
$loadBalancedVmSetTemplate = New-Object System.Uri -ArgumentList @($templateRootUri, 'templates/buildingBlocks/loadBalancer-backend-n-vm/azuredeploy.json')
$networkSecurityGroupTemplate = New-Object System.Uri -ArgumentList @($templateRootUri, 'templates/buildingBlocks/networkSecurityGroups/azuredeploy.json')

# Login to Azure and select your subscription
Login-AzureRmAccount -SubscriptionId $SubscriptionId | Out-Null

if ($Mode -eq "onpremise") {
	# Azure Account Forest Onpremise Parameter Files
	$onpremiseVirtualNetworkParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\onpremise\virtualNetwork.parameters.json")
	$onpremiseVirtualNetworkDnsParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\onpremise\virtualNetwork-adds-dns.parameters.json")
	$onpremiseADDSVirtualMachinesParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\onpremise\virtualMachines-adds.parameters.json")
	$onpremiseCreateAddsForestExtensionParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\onpremise\create-adds-forest-extension.parameters.json")
	$onpremiseAddAddsDomainControllerExtensionParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\onpremise\add-adds-domain-controller.parameters.json")
	$onpremisADCJoinDomainExtensionParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\onpremise\virtualMachines-adc-joindomain.parameters.json")
	$onpremisPingJoinDomainExtensionParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\onpremise\virtualMachines-ping-joindomain.parameters.json")
	$azureAdcVirtualMachinesParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\onpremise\virtualMachines-adc.parameters.json")
	$azurePingVirtualMachinesParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\onpremise\virtualMachines-ping.parameters.json")


	$onpremiseNetworkResourceGroupName = "af-onpremise-rg"

	# Azure Account Forest Onpremise Deployments
	#1 af-onpremise-vnet-deployment
    $onpremiseNetworkResourceGroup = New-AzureRmResourceGroup -Name $onpremiseNetworkResourceGroupName -Location $Location
    Write-Host "Creating Account Forest onpremise virtual network..."
    New-AzureRmResourceGroupDeployment -Name "af-onpremise-vnet-deployment" `
        -ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName -TemplateUri $virtualNetworkTemplate.AbsoluteUri `
        -TemplateParameterFile $onpremiseVirtualNetworkParametersFile

	#2 af-onpremise-adc-deployment
    Write-Host "Deploying Account Forest AD Connect servers..."
    New-AzureRmResourceGroupDeployment -Name "af-onpremise-adc-deployment" `
		-ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineTemplate.AbsoluteUri -TemplateParameterFile $azureAdcVirtualMachinesParametersFile

	#3 af-onpremise-ping-deployment
    Write-Host "Deploying Account Forest Ping servers..."
    New-AzureRmResourceGroupDeployment -Name "af-onpremise-ping-deployment" `
		-ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineTemplate.AbsoluteUri -TemplateParameterFile $azurePingVirtualMachinesParametersFile

	#4 af-onpremise-adds-deployment
    Write-Host "Deploying Account Forest ADDS servers..."
    New-AzureRmResourceGroupDeployment -Name "af-onpremise-adds-deployment" `
        -ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineTemplate.AbsoluteUri -TemplateParameterFile $onpremiseADDSVirtualMachinesParametersFile

	#5 af-onpremise-dns-vnet-deployment
    # Remove the Azure DNS entry since the forest will create a DNS forwarding entry.
    Write-Host "Updating Account Forest virtual network DNS servers..."
    New-AzureRmResourceGroupDeployment -Name "af-onpremise-dns-vnet-deployment" `
        -ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName -TemplateUri $virtualNetworkTemplate.AbsoluteUri `
        -TemplateParameterFile $onpremiseVirtualNetworkDnsParametersFile

	#6 af-onpremise-adds-forest-deployment
    Write-Host "Creating Account Forest ADDS forest..."
    New-AzureRmResourceGroupDeployment -Name "af-onpremise-adds-forest-deployment" `
        -ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineExtensionsTemplate.AbsoluteUri -TemplateParameterFile $onpremiseCreateAddsForestExtensionParametersFile

	#7 af-onpremise-adds-dc-deployment
    Write-Host "Creating Account Forest ADDS domain controller..."
    New-AzureRmResourceGroupDeployment -Name "af-onpremise-adds-dc-deployment" `
        -ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineExtensionsTemplate.AbsoluteUri -TemplateParameterFile $onpremiseAddAddsDomainControllerExtensionParametersFile

	#8 af-onpremise-adds-adc-deployment
    Write-Host "Join Account Forest AD Connect servers to Domain......"
    New-AzureRmResourceGroupDeployment -Name "af-onpremise-adds-adc-deployment" `
        -ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineExtensionsTemplate.AbsoluteUri -TemplateParameterFile $onpremisADCJoinDomainExtensionParametersFile

	#9 af-onpremise-ping-deployment
    Write-Host "Join Account Forest Ping servers to Domain......"
    New-AzureRmResourceGroupDeployment -Name "af-onpremise-adds-ping-deployment" `
        -ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineExtensionsTemplate.AbsoluteUri -TemplateParameterFile $onpremisPingJoinDomainExtensionParametersFile
}
elseif ($Mode -eq "onpremise-rf") {
	# Azure Resource Forest Onpremise Parameter Files
	$onpremiseVirtualNetworkParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\onpremise-rf\virtualNetwork.parameters.json")
	$onpremiseVirtualNetworkDnsParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\onpremise-rf\virtualNetwork-adds-dns.parameters.json")
	$onpremiseADDSVirtualMachinesParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\onpremise-rf\virtualMachines-adds.parameters.json")
	$onpremiseCreateAddsForestExtensionParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\onpremise-rf\create-adds-forest-extension.parameters.json")
	$onpremiseAddAddsDomainControllerExtensionParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\onpremise-rf\add-adds-domain-controller.parameters.json")
	$onpremiseEXJoinDomainExtensionParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\onpremise-rf\virtualMachines-ex-joindomain.parameters.json")
	$onpremiseSPJoinDomainExtensionParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\onpremise-rf\virtualMachines-sp-joindomain.parameters.json")
	$onpremiseSFBJoinDomainExtensionParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\onpremise-rf\virtualMachines-sfb-joindomain.parameters.json")

	$azureEXVirtualMachinesParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\onpremise-rf\virtualMachines-ex.parameters.json")
	$azureSPVirtualMachinesParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\onpremise-rf\virtualMachines-sp.parameters.json")
	$azureSFBVirtualMachinesParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\onpremise-rf\virtualMachines-sfb.parameters.json")


	$onpremiseNetworkResourceGroupName = "rf-onpremise-rg"

	# Azure Resource Forest Onpremise Deployments
	#1 rf-onpremise-vnet-deployment
    $onpremiseNetworkResourceGroup = New-AzureRmResourceGroup -Name $onpremiseNetworkResourceGroupName -Location $Location
    Write-Host "Creating Resource Forest onpremise virtual network..."
    New-AzureRmResourceGroupDeployment -Name "rf-onpremise-vnet-deployment" `
        -ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName -TemplateUri $virtualNetworkTemplate.AbsoluteUri `
        -TemplateParameterFile $onpremiseVirtualNetworkParametersFile

	#2 rf-onpremise-ex-deployment
    Write-Host "Deploying Resource Forest Exchange servers..."
    New-AzureRmResourceGroupDeployment -Name "rf-onpremise-ex-deployment" `
		-ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineTemplate.AbsoluteUri -TemplateParameterFile $azureEXVirtualMachinesParametersFile

	#3 rf-onpremise-sp-deployment
    Write-Host "Deploying Resource Forest SharePoint servers..."
    New-AzureRmResourceGroupDeployment -Name "rf-onpremise-sp-deployment" `
		-ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineTemplate.AbsoluteUri -TemplateParameterFile $azureSPVirtualMachinesParametersFile

	#4 rf-onpremise-sfb-deployment
    Write-Host "Deploying Resource Forest Skype servers..."
    New-AzureRmResourceGroupDeployment -Name "rf-onpremise-sfb-deployment" `
		-ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineTemplate.AbsoluteUri -TemplateParameterFile $azureSFBVirtualMachinesParametersFile

	#5 rf-onpremise-adds-deployment
    Write-Host "Deploying Resource Forest ADDS servers..."
    New-AzureRmResourceGroupDeployment -Name "rf-onpremise-adds-deployment" `
        -ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineTemplate.AbsoluteUri -TemplateParameterFile $onpremiseADDSVirtualMachinesParametersFile

	#6 rf-onpremise-dns-vnet-deployment
    # Remove the Azure DNS entry since the forest will create a DNS forwarding entry.
    Write-Host "Updating Resource Forest virtual network DNS servers..."
    New-AzureRmResourceGroupDeployment -Name "rf-onpremise-dns-vnet-deployment" `
        -ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName -TemplateUri $virtualNetworkTemplate.AbsoluteUri `
        -TemplateParameterFile $onpremiseVirtualNetworkDnsParametersFile

	#7 rf-onpremise-adds-forest-deployment
    Write-Host "Creating Resource Forest ADDS forest..."
    New-AzureRmResourceGroupDeployment -Name "rf-onpremise-adds-forest-deployment" `
        -ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineExtensionsTemplate.AbsoluteUri -TemplateParameterFile $onpremiseCreateAddsForestExtensionParametersFile

	#8 rf-onpremise-adds-dc-deployment
    Write-Host "Creating ADDS domain controller..."
    New-AzureRmResourceGroupDeployment -Name "rf-onpremise-adds-dc-deployment" `
        -ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineExtensionsTemplate.AbsoluteUri -TemplateParameterFile $onpremiseAddAddsDomainControllerExtensionParametersFile

	#9 rf-onpremise-adds-ex-deployment
    Write-Host "Join Resource Forest Exchange servers to Domain......"
    New-AzureRmResourceGroupDeployment -Name "rf-onpremise-adds-ex-deployment" `
        -ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineExtensionsTemplate.AbsoluteUri -TemplateParameterFile $onpremiseEXJoinDomainExtensionParametersFile

	#10 rf-onpremise-adds-sp-deployment
    Write-Host "Join Resource Forest SharePoint servers to Domain......"
    New-AzureRmResourceGroupDeployment -Name "rf-onpremise-adds-sp-deployment" `
        -ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineExtensionsTemplate.AbsoluteUri -TemplateParameterFile $onpremiseSPJoinDomainExtensionParametersFile

	#11 rf-onpremise-adds-sfb-deployment
    Write-Host "Join Resource Forest Skype servers to Domain......"
    New-AzureRmResourceGroupDeployment -Name "rf-onpremise-adds-sfb-deployment" `
        -ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineExtensionsTemplate.AbsoluteUri -TemplateParameterFile $onpremiseSFBJoinDomainExtensionParametersFile
}
elseif ($Mode -eq "ntier") {

	$resourceGroupName = "ra-aad-ntier-rg"

	# Template parameters for respective deployments
	$virtualNetworkParametersFile = [System.IO.Path]::Combine($PSScriptRoot, 'parameters', $OSType.ToLower(), 'virtualNetwork.parameters.json')
	$businessTierParametersFile = [System.IO.Path]::Combine($PSScriptRoot, 'parameters', $OSType.ToLower(), 'businessTier.parameters.json')
	$dataTierParametersFile = [System.IO.Path]::Combine($PSScriptRoot, 'parameters', $OSType.ToLower(), 'dataTier.parameters.json')
	$webTierParametersFile = [System.IO.Path]::Combine($PSScriptRoot, 'parameters', $OSType.ToLower(), 'webTier.parameters.json')
	$managementTierParametersFile = [System.IO.Path]::Combine($PSScriptRoot, 'parameters', $OSType.ToLower(), 'managementTier.parameters.json')
	$networkSecurityGroupParametersFile = [System.IO.Path]::Combine($PSScriptRoot, 'parameters', $OSType.ToLower(), 'networkSecurityGroups.parameters.json')


	# Login to Azure and select your subscription
	Login-AzureRmAccount -SubscriptionId $SubscriptionId | Out-Null

	# Create the resource group
	$resourceGroup = New-AzureRmResourceGroup -Name $resourceGroupName -Location $Location

	#1 -aad-ntier-vnet-deployment
	Write-Host "Deploying virtual network..."
	New-AzureRmResourceGroupDeployment -Name "ra-aad-ntier-vnet-deployment" -ResourceGroupName $resourceGroup.ResourceGroupName `
		-TemplateUri $virtualNetworkTemplate.AbsoluteUri -TemplateParameterFile $virtualNetworkParametersFile

	#2 ra-aad-ntier-web-deployment
	Write-Host "Deploying web tier..."
	New-AzureRmResourceGroupDeployment -Name "ra-aad-ntier-web-deployment" -ResourceGroupName $resourceGroup.ResourceGroupName `
		-TemplateUri $loadBalancedVmSetTemplate.AbsoluteUri -TemplateParameterFile $webTierParametersFile

	#3 ra-aad-ntier-biz-deployment
	Write-Host "Deploying business tier..."
	New-AzureRmResourceGroupDeployment -Name "ra-aad-ntier-biz-deployment" -ResourceGroupName $resourceGroup.ResourceGroupName `
		-TemplateUri $loadBalancedVmSetTemplate.AbsoluteUri -TemplateParameterFile $businessTierParametersFile

	#4 ra-aad-ntier-data-deployment
	Write-Host "Deploying data tier..."
	New-AzureRmResourceGroupDeployment -Name "ra-aad-ntier-data-deployment" -ResourceGroupName $resourceGroup.ResourceGroupName `
		-TemplateUri $virtualMachineTemplate.AbsoluteUri -TemplateParameterFile $dataTierParametersFile

	#5 ra-aad-ntier-mgmt-deployment
	Write-Host "Deploying management tier..."
	New-AzureRmResourceGroupDeployment -Name "ra-aad-ntier-mgmt-deployment" -ResourceGroupName $resourceGroup.ResourceGroupName `
		-TemplateUri $virtualMachineTemplate.AbsoluteUri -TemplateParameterFile $managementTierParametersFile

	#6 ra-aad-ntier-nsg-deployment
	Write-Host "Deploying network security group"
	New-AzureRmResourceGroupDeployment -Name "ra-aad-ntier-nsg-deployment" -ResourceGroupName $resourceGroup.ResourceGroupName `
		-TemplateUri $networkSecurityGroupTemplate.AbsoluteUri -TemplateParameterFile $networkSecurityGroupParametersFile
}
