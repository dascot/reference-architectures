[CmdletBinding()]
Param(
	[string]$SafeModePassword = "P@ssW0rd1234!",
	[string]$DomainName = "af.com",
	[string]$DomainNetbiosName = "af"
)

$ErrorActionPreference = "Stop"

Initialize-Disk -Number 2 -PartitionStyle GPT
New-Partition -UseMaximumSize -DriveLetter F -DiskNumber 2
Format-Volume -DriveLetter F -Confirm:$false -FileSystem NTFS -force 

Install-windowsfeature -name AD-Domain-Services -IncludeAllSubFeature -IncludeManagementTools

Import-Module ADDSDeployment

$secSafeModePassword = ConvertTo-SecureString $SafeModePassword -AsPlainText -Force

Install-ADDSForest `
-SafeModeAdministratorPassword $secSafeModePassword `
-CreateDnsDelegation:$false `
-DatabasePath "F:\Adds\NTDS" `
-DomainMode "Win2012R2" `
-DomainName $DomainName `
-DomainNetbiosName $DomainNetbiosName `
-ForestMode "Win2012R2" `
-InstallDns:$true `
-LogPath "F:\Adds\NTDS" `
-NoRebootOnCompletion:$false `
-SysvolPath "F:\Adds\SYSVOL" `
-Force:$true
