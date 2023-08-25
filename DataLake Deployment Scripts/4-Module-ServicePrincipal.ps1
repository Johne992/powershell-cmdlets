#Set Variables
$keyvaultName = ""
$ServicePrincipalsInfo = @{
    "Service Principal Name"  = "Key vault secret name";
}

#Start Logging
# Start-Transcript -Path ".\Deploy-$ResourceGroup-$(get-date -Format "yyyy-MM-dd")" -Append


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

    #Open Service Principal page in Azure Portal
    Start-Process "https://portal.azure.com/#blade/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/Overview/$($sp.ApplicationId)"
}

#End Logging
# Stop-Transcript