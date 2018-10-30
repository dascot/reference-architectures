Configuration DomainTrust {
    param(
        [string]$remoteDomainName = "contoso.com",
        [Parameter(Mandatory=$true)][pscredential]$adminCreds
    )

    Node localhost
    {
        Script SetDomainTrust
        {
            GetScript = {return @{}}
            TestScript = {return $false} # Always run the SetScript for this.
            SetScript = {

                $remoteContext = New-Object -TypeName "System.DirectoryServices.ActiveDirectory.DirectoryContext" -ArgumentList @( "Domain", $using:remoteDomainName, $using:adminCreds.UserName, $using:adminCreds.Password)
                $remoteDomain = [System.DirectoryServices.ActiveDirectory.Domain]::GetDomain($remoteContext)
            
                $localDomain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain() 
                $localDomain.CreateTrustRelationship($remoteDomain,"Inbound")
            }
        }
    }
}