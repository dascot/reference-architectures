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
  $templateRootUriString = "https://raw.githubusercontent.com/dascot/template-building-blocks/v1.0.0/"
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
	$onpremisWKSJoinDomainExtensionParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\onpremise\virtualMachines-wks-joindomain.parameters.json")
	$azureAdcVirtualMachinesParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\onpremise\virtualMachines-adc.parameters.json")
	$azurePingVirtualMachinesParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\onpremise\virtualMachines-ping.parameters.json")
	$azureWKSVirtualMachinesParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\onpremise\virtualMachines-wks.parameters.json")


	$onpremiseNetworkResourceGroupName = "js-onpremise-rg"

	# Azure Account Forest Onpremise Deployments
	#1 js-onpremise-vnet-deployment
    $onpremiseNetworkResourceGroup = New-AzureRmResourceGroup -Name $onpremiseNetworkResourceGroupName -Location $Location
    Write-Host "Creating Account Forest onpremise virtual network..." -ForegroundColor Yellow
    New-AzureRmResourceGroupDeployment -Name "js-onpremise-vnet-deployment" `
        -ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName -TemplateUri $virtualNetworkTemplate.AbsoluteUri `
        -TemplateParameterFile $onpremiseVirtualNetworkParametersFile

	#2 js-onpremise-adc-deployment
    Write-Host "Deploying Account Forest AD Connect servers..." -ForegroundColor Yellow
    New-AzureRmResourceGroupDeployment -Name "js-onpremise-adc-deployment" `
		-ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineTemplate.AbsoluteUri -TemplateParameterFile $azureAdcVirtualMachinesParametersFile

	#3 js-onpremise-ping-deployment
    Write-Host "Deploying Account Forest Ping servers..." -ForegroundColor Yellow
    New-AzureRmResourceGroupDeployment -Name "js-onpremise-ping-deployment" `
		-ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineTemplate.AbsoluteUri -TemplateParameterFile $azurePingVirtualMachinesParametersFile

	#4 js-onpremise-wks-deployment
    Write-Host "Deploying Account Forest workstations..." -ForegroundColor Yellow
    New-AzureRmResourceGroupDeployment -Name "js-onpremise-wks-deployment" `
		-ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineTemplate.AbsoluteUri -TemplateParameterFile $azurePingVirtualMachinesParametersFile

	#5 js-onpremise-adds-deployment
    Write-Host "Deploying Account Forest ADDS servers..." -ForegroundColor Yellow
    New-AzureRmResourceGroupDeployment -Name "js-onpremise-adds-deployment" `
        -ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineTemplate.AbsoluteUri -TemplateParameterFile $onpremiseADDSVirtualMachinesParametersFile

	#6 js-onpremise-dns-vnet-deployment
    # Remove the Azure DNS entry since the forest will create a DNS forwarding entry.
    Write-Host "Updating Account Forest virtual network DNS servers..." -ForegroundColor Yellow
    New-AzureRmResourceGroupDeployment -Name "js-onpremise-dns-vnet-deployment" `
        -ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName -TemplateUri $virtualNetworkTemplate.AbsoluteUri `
        -TemplateParameterFile $onpremiseVirtualNetworkDnsParametersFile

	#7 js-onpremise-adds-forest-deployment
    Write-Host "Creating Account Forest ADDS forest..." -ForegroundColor Yellow
    New-AzureRmResourceGroupDeployment -Name "js-onpremise-adds-forest-deployment" `
        -ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineExtensionsTemplate.AbsoluteUri -TemplateParameterFile $onpremiseCreateAddsForestExtensionParametersFile

	#8 js-onpremise-adds-dc-deployment
     Write-Host "Creating Account Forest ADDS domain controller..." -ForegroundColor Yellow
    New-AzureRmResourceGroupDeployment -Name "js-onpremise-adds-dc-deployment" `
        -ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineExtensionsTemplate.AbsoluteUri -TemplateParameterFile $onpremiseAddAddsDomainControllerExtensionParametersFile

	#9 js-onpremise-adds-adc-deployment
    Write-Host "Join Account Forest AD Connect servers to Domain......" -ForegroundColor Yellow
    New-AzureRmResourceGroupDeployment -Name "js-onpremise-adds-adc-deployment" `
        -ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineExtensionsTemplate.AbsoluteUri -TemplateParameterFile $onpremisADCJoinDomainExtensionParametersFile

	#10 js-onpremise-ping-deployment
    Write-Host "Join Account Forest Ping servers to Domain......" -ForegroundColor Yellow
    New-AzureRmResourceGroupDeployment -Name "js-onpremise-adds-ping-deployment" `
        -ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineExtensionsTemplate.AbsoluteUri -TemplateParameterFile $onpremisPingJoinDomainExtensionParametersFile

	#11 js-onpremise-wks-deployment
    Write-Host "Join Account Forest workstations to Domain......" -ForegroundColor Yellow
    New-AzureRmResourceGroupDeployment -Name "js-onpremise-adds-wks-deployment" `
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


	$onpremiseNetworkResourceGroupName = "ds-onpremise-rg"

	# Azure Resource Forest Onpremise Deployments
	#1 ds-onpremise-vnet-deployment
    $onpremiseNetworkResourceGroup = New-AzureRmResourceGroup -Name $onpremiseNetworkResourceGroupName -Location $Location
    Write-Host "Creating Resource Forest onpremise virtual network..." -ForegroundColor Yellow
    New-AzureRmResourceGroupDeployment -Name "ds-onpremise-vnet-deployment" `
        -ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName -TemplateUri $virtualNetworkTemplate.AbsoluteUri `
        -TemplateParameterFile $onpremiseVirtualNetworkParametersFile

	#2 ds-onpremise-ex-deployment
    Write-Host "Deploying Resource Forest Exchange servers..." -ForegroundColor Yellow
    New-AzureRmResourceGroupDeployment -Name "ds-onpremise-ex-deployment" `
		-ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineTemplate.AbsoluteUri -TemplateParameterFile $azureEXVirtualMachinesParametersFile

	#3 ds-onpremise-sp-deployment
    Write-Host "Deploying Resource Forest SharePoint servers..." -ForegroundColor Yellow
    New-AzureRmResourceGroupDeployment -Name "ds-onpremise-sp-deployment" `
		-ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineTemplate.AbsoluteUri -TemplateParameterFile $azureSPVirtualMachinesParametersFile

	#4 ds-onpremise-sfb-deployment
    Write-Host "Deploying Resource Forest Skype servers..." -ForegroundColor Yellow
    New-AzureRmResourceGroupDeployment -Name "ds-onpremise-sfb-deployment" `
		-ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineTemplate.AbsoluteUri -TemplateParameterFile $azureSFBVirtualMachinesParametersFile

	#5 ds-onpremise-adds-deployment
    Write-Host "Deploying Resource Forest ADDS servers..." -ForegroundColor Yellow
    New-AzureRmResourceGroupDeployment -Name "ds-onpremise-adds-deployment" `
        -ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineTemplate.AbsoluteUri -TemplateParameterFile $onpremiseADDSVirtualMachinesParametersFile

	#6 ds-onpremise-dns-vnet-deployment
    # Remove the Azure DNS entry since the forest will create a DNS forwarding entry.
    Write-Host "Updating Resource Forest virtual network DNS servers..." -ForegroundColor Yellow
    New-AzureRmResourceGroupDeployment -Name "ds-onpremise-dns-vnet-deployment" `
        -ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName -TemplateUri $virtualNetworkTemplate.AbsoluteUri `
        -TemplateParameterFile $onpremiseVirtualNetworkDnsParametersFile

	#7 ds-onpremise-adds-forest-deployment
    Write-Host "Creating Resource Forest ADDS forest..." -ForegroundColor Yellow
    New-AzureRmResourceGroupDeployment -Name "ds-onpremise-adds-forest-deployment" `
        -ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineExtensionsTemplate.AbsoluteUri -TemplateParameterFile $onpremiseCreateAddsForestExtensionParametersFile

	#8 ds-onpremise-adds-dc-deployment
   Write-Host "Creating ADDS domain controller..." -ForegroundColor Yellow
   New-AzureRmResourceGroupDeployment -Name "ds-onpremise-adds-dc-deployment" `
        -ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineExtensionsTemplate.AbsoluteUri -TemplateParameterFile $onpremiseAddAddsDomainControllerExtensionParametersFile

	#9 ds-onpremise-adds-ex-deployment
    Write-Host "Join Resource Forest Exchange servers to Domain......" -ForegroundColor Yellow
    New-AzureRmResourceGroupDeployment -Name "ds-onpremise-adds-ex-deployment" `
        -ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineExtensionsTemplate.AbsoluteUri -TemplateParameterFile $onpremiseEXJoinDomainExtensionParametersFile

	#10 ds-onpremise-adds-sp-deployment
    Write-Host "Join Resource Forest SharePoint servers to Domain......" -ForegroundColor Yellow
    New-AzureRmResourceGroupDeployment -Name "ds-onpremise-adds-sp-deployment" `
        -ResourceGroupName $onpremiseNetworkResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineExtensionsTemplate.AbsoluteUri -TemplateParameterFile $onpremiseSPJoinDomainExtensionParametersFile

	#11 ds-onpremise-adds-sfb-deployment
    Write-Host "Join Resource Forest Skype servers to Domain......" -ForegroundColor Yellow
    New-AzureRmResourceGroupDeployment -Name "ds-onpremise-adds-sfb-deployment" `
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
