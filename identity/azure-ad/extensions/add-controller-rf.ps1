Configuration CreateDomainController {
    param
    #v1.4
    (
        [Parameter(Mandatory=$True)]
        [string]$AdminUser = "ds-admin",
        
        [Parameter(Mandatory=$True)]
        [string]$AdminPassword = "P@ssW0rd1234!",

        [Parameter(Mandatory=$True)]
        [string]$SafeModePassword = "P@ssW0rd1234!",

        [Parameter(Mandatory)]
        [string]$DomainName = "dmscon.com",

        [Parameter(Mandatory)]
        [string]$DomainNetbiosName = "dmscon",

        [Parameter(Mandatory)]
        [string]$PrimaryDcIpAddress = "193.200.0.4",

        [Int]$RetryCount=30,
        [Int]$RetryIntervalSec=60
    )

    $secSafeModePassword = ConvertTo-SecureString $SafeModePassword -AsPlainText -Force
    $secAdminPassword = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
    [System.Management.Automation.PSCredential]$AdminCreds = New-Object System.Management.Automation.PSCredential ("$DomainNetbiosName\$AdminUser", $secAdminPassword)
    [System.Management.Automation.PSCredential]$SafeModeAdminCreds = New-Object System.Management.Automation.PSCredential ("$DomainNetbiosName\$AdminUser", $secAdminPassword)
    
    
    Import-DscResource -ModuleName xStorage, xActiveDirectory, xNetworking, xPendingReboot

    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($AdminCreds.UserName)", $AdminCreds.Password)
    [System.Management.Automation.PSCredential ]$SafeDomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($SafeModeAdminCreds.UserName)", $SafeModeAdminCreds.Password)

    $Interface = Get-NetAdapter|Where-Object Name -Like "Ethernet*"|Select-Object -First 1
    $InterfaceAlias = $($Interface.Name)
    
    Node localhost
    {
        LocalConfigurationManager
        {            
            ActionAfterReboot = 'ContinueConfiguration'            
            ConfigurationMode = 'ApplyOnly'            
            RebootNodeIfNeeded = $true            
        } 

        xWaitforDisk Disk2
        {
            DiskId = 2
            RetryIntervalSec = 60
            RetryCount = 20
        }
        
        xDisk FVolume
        {
            DiskId = 2
            DriveLetter = 'F'
            FSLabel = 'Data'
            FSFormat = 'NTFS'
            DependsOn = '[xWaitForDisk]Disk2'
        }        

        WindowsFeature DNS 
        { 
            Ensure = "Present" 
            Name = "DNS"
            IncludeAllSubFeature = $true
        }

        WindowsFeature RSAT
        {
             Ensure = "Present"
             Name = "RSAT"
        }        

        WindowsFeature ADDSInstall 
        { 
            Ensure = "Present" 
            Name = "AD-Domain-Services"
            IncludeAllSubFeature = $true
        }

        # Allow this machine to find the PDC and its DNS server
        [ScriptBlock]$SetScript =
        {
            Set-DnsClientServerAddress -InterfaceAlias ("$InterfaceAlias") -ServerAddresses ("$PrimaryDcIpAddress")
        }

        Script SetDnsServerAddressToFindPDC
        {
            GetScript = {return @{}}
            TestScript = {return $false} # Always run the SetScript for this.
            SetScript = $SetScript.ToString().Replace('$PrimaryDcIpAddress', $PrimaryDcIpAddress).Replace('$InterfaceAlias', $InterfaceAlias)
        }
    
        xADDomainController SecondaryDC
        {
            DomainName = $DomainName
            DomainAdministratorCredential = $DomainCreds
            SafemodeAdministratorPassword = $SafeDomainCreds
            DatabasePath = "F:\Adds\NTDS"
            LogPath = "F:\Adds\NTDS"
            SysvolPath = "F:\Adds\SYSVOL"
            DependsOn = @("[Script]SetDnsServerAddressToFindPDC"), "[xWaitForDisk]Disk2","[WindowsFeature]ADDSInstall"
        }

        # Now make sure this computer uses itself as a DNS source
        xDnsServerAddress DnsServerAddress2
        {
            Address        = @('127.0.0.1', $PrimaryDcIpAddress)
            InterfaceAlias = $InterfaceAlias
            AddressFamily  = 'IPv4'
            DependsOn = "[xADDomainController]SecondaryDC"
        }

        xPendingReboot Reboot2
        { 
            Name = "RebootServer"
            DependsOn = "[xADDomainController]SecondaryDC"
        }

   }
}