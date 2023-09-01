param(
    [Parameter()]
    [string] $AzSPNPrefix,

    [Parameter()]
    [string] $AzSPNBase,

    [Parameter()]
    [string] $AzResourceBase,

    [Parameter()]
    [string] $AzResourcePrefix
)

#Set Variables
$keyvaultName = "${AzResourcePrefix}${AzResourceBase}"
$ServicePrincipalsInfo = @{
    "${AzSPNPrefix}${AzSPNBase}" = "AKV-ITCLINICALADB01-SPN-Read-secret";
}

#for each Serviceprincipal in serviceprincipalsinfo create a new service principal, export the secret to a file and store the secret in keyvault
foreach ($ServicePrincipal in $ServicePrincipalsInfo.GetEnumerator()) {
    #create an azure service principal
    $endDate = (Get-Date).AddYears(2)
    $sp = New-AzADServicePrincipal -DisplayName $ServicePrincipal.Key -EndDate $endDate

    #Set secret to expire in 2 years and export secret text to file named $ServicePrincipalName-secret.txt
    $sp.PasswordCredentials.SecretText | Out-File -FilePath "$($ServicePrincipal.Key)-secret.txt"

    #store secret in keyvault
    $secret = ConvertTo-SecureString -String $sp.PasswordCredentials.SecretText -AsPlainText -Force
    Set-AzKeyVaultSecret `
        -VaultName $keyvaultName `
        -Name $ServicePrincipal.Value `
        -SecretValue $secret `
        -ContentType $ServicePrincipal.Name

    #Store Secret in Thycotic Secret Server
    # need to talk to matthew gill about this

}
