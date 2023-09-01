#Create and configure Key Vault.  Permissions assigned in separate script or manually

#Set Variables - UPDATE FOR EACH ENVIRONMENT
$SubscriptionName = ""
$Location = ""
$CostCenter = ""
$CurrentDate = get-date -Format "yyyy.MM.dd"
$KVResourceGroupName = ""
$KeyVaultName = ""
$LocTag = ""
$EnvTag = ""
$AppTag = ""
$SNOWTag = ""
$LogAnalyticsWs = ""
$Access = @{

}
$vnetResourceGroup = ""
$vnetName = ""
$subnetName = ""

#Start Logging
# Start-Transcript -Path "C:\Temp\Deploy-$ResourceGroup-$(get-date -Format "yyyy-MM-dd")" -Append


#Set subscription context
Set-AzContext -SubscriptionName $SubscriptionName
$CurrentUser = Get-AzContext | Select-Object -ExpandProperty Account

#Firewall Settings
#Get the subnet ID
$subnetId = (Get-AzVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork (Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $vnetResourceGroup)).Id

#Ip Addresses
$IPAddresses = @("x.x.x.0/24")
$RuleSet = New-AzKeyVaultNetworkRuleSetObject -DefaultAction Deny -Bypass AzureServices -VirtualNetworkResourceId $subnetId -IpAddressRange $IPAddresses

#Create Key Vault
write-host "Creating $KeyVaultName Key Vault!" -ForegroundColor Green
$NewKeyVault = New-AzKeyVault -Name $KeyVaultName `
    -ResourceGroupName $KVResourceGroupName `
    -Location $Location `
    -NetworkRuleSet $RuleSet `
    -EnabledForTemplateDeployment `
    -EnableRbacAuthorization `
    -Tag @{
    CreatedBy      = $CurrentUser.Id;
    CreatedDate    = $CurrentDate;
    CostCenter     = $CostCenter;
    NS_Location    = $LocTag;
    NS_Environment = $EnvTag;
    NS_Application = $AppTag;
    SNOWRequest    = $SNOWTag
} `
    -ErrorAction Stop

#Add diagnostic settings
write-host "Enabling Diagnostics on $KeyVaultName" -ForegroundColor Green
$log = @()
$categories = Get-AzDiagnosticSettingCategory -ResourceId $NewKeyVault.ResourceId
$categories | ForEach-Object { if ($_.CategoryType -eq "Log") { $log += New-AzDiagnosticSettingLogSettingsObject -Enabled $true -Category $_.Name -RetentionPolicyDay 7 -RetentionPolicyEnabled $true } }
New-AzDiagnosticSetting -Name 'send to log analtics workspace' `
    -ResourceId $NewKeyVault.ResourceId `
    -WorkspaceId $LogAnalyticsWs `
    -Log $log `
    -Metric $metric


#Add Access
write-host "Assigning Access to $KeyVaultName" -ForegroundColor Green
foreach ($AccessGroup in $Access.GetEnumerator()) {
    #Check if group or azure ad object
    if ($AccessGroup.Name -like "*AzProd.DnA*") {
        #Get the object ID of the group
        $AccessGroup.Name = (Get-AzADGroup -SearchString $AccessGroup.Name).Id

    }
    elseif ($AccessGroup.Name -like "e*oa@lahsic.com") {
        #Get the object id of the user
        $AccessGroup.Name = (Get-AzADUser -UserPrincipalName $AccessGroup.Name).Id
    }
    else {
        #Get the object ID of the azure ad object
        $AccessGroup.Name = (Get-AzADServicePrincipal -SearchString $AccessGroup.Name).Id
    }
    $Access
    #Loop through each role in AccessGroup.Value and assign to the group

    foreach ($Role in $AccessGroup.Value) {
        $Role
        New-AzRoleAssignment `
            -ObjectId $AccessGroup.Name `
            -RoleDefinitionName $Role `
            -Scope $NewKeyVault.ResourceId `
            -ErrorAction Stop
    }
}

#copy bigdataadmin secret from another keyvault
write-host "Copying bigdataadmin secret from another keyvault" -ForegroundColor Green
$Secret = Get-AzKeyVaultSecret -VaultName "prdusceitproviderkv01" -Name "AKV-BIGDATAADMINADB01-SPN-Write-secret"
Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name "AKV-BIGDATAADMINADB01-SPN-Write-secret" -SecretValue $Secret.SecretValue -ErrorAction Stop


write-host "$KeyVaulName.ps1 script completed" -ForegroundColor Blue
$KeyVaultName

#End Logging
# Stop-Transcript