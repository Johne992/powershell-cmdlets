<#
    Created by:  John Lewis
    Created on:  2023-09-14
    Version:     1.0.1
    Purpose:     Create Multiple Service Principals, made distinct from storing in keyvault
#>

#Set Variables
$ServicePrincipalsInfo = @(
    "Service Principal Name"
)

#Start transcript with date and time in current file path
$outputPath = Join-Path -Path $PSScriptRoot -ChildPath "Create-ServicePrincipal-$(get-date -Format "yyyy-MM-dd").txt"
Start-Transcript -Path $outputpath


#for each Serviceprincipal in serviceprincipalsinfo create a new service principal, export the secret to a file and store the secret in keyvault
foreach ($ServicePrincipal in $ServicePrincipalsInfo.GetEnumerator()) {
    #create an azure service principal
    $endDate = (Get-Date).AddYears(2)
    $sp = New-AzADServicePrincipal -DisplayName $ServicePrincipal.Key -EndDate $endDate

    #Set secret to expire in 2 years and export secret text to file named $ServicePrincipalName-secret.txt
    $secretPath = Join-Path -Path $PSScriptRoot -ChildPath "$($ServicePrincipal)-secret.txt"
    $sp.PasswordCredentials.SecretText | Out-File -FilePath $secretPath


}

Stop-Transcript
