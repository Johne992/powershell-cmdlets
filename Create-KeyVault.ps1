#Create and configure Key Vault.  Permissions assigned in separate script or manually
#v2.0.1 - made more readable and added access hash, typo corrected
#v2.1.0 - 2023.08.16 corrected errors and updated networking, diagnostics, and RBAC
#Set Variables - UPDATE FOR EACH ENVIRONMENT
$SubscriptionName = "SUBSCRIPTION NAME GOES HERE"
$Location = "centralus"
$CostCenter = "xxxx"
$CurrentDate = get-date -Format "yyyy.MM.dd:HH.mm.ss"
$KVResourceGroupName = "rg"
$KeyVaultName = "kv01"
$LocTag = "USCE - Central US"
$EnvTag = "PROD - Production"
$LogAnalyticsWs = "resourceID"
$Access = @{
    "AzureAd-Object" = @("Key Vault Administrator", "Key Vault Reader")
}
$vnetResourceGroup = "rg"
$vnetName = "vnet01"
$subnetName = "sn01"

#Set subscription context
Set-AzContext -SubscriptionName $SubscriptionName
$CurrentUser = Get-AzContext | Select-Object -ExpandProperty Account

#Firewall Settings
#Get the subnet ID
$subnetId = (Get-AzVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork (Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $vnetResourceGroup)).Id


$IPAddresses = @("x.x.x.x") 
$RuleSet = New-AzKeyVaultNetworkRuleSetObject -DefaultAction Deny -Bypass AzureServices -VirtualNetworkResourceId $subnetId -IpAddressRange $IPAddresses

#Create Key Vault
write-host "Creating $KeyVaultName Key Vault!" -ForegroundColor Green
$NewKeyVault = New-AzKeyVault -Name $KeyVaultName `
    -ResourceGroupName $KVResourceGroupName `
    -Location $Location `
    -NetworkRuleSet $RuleSet `
    -EnabledForTemplateDeployment `
    -Tag @{
    CreatedBy   = $CurrentUser.Id;
    CreatedDate = $CurrentDate;
    CostCenter  = $CostCenter;
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
    if ($AccessGroup.Name -like "*") {
        #Get the object ID of the group
        $AccessGroup.Name = (Get-AzADGroup -SearchString $AccessGroup.Name).Id

    }
    elseif ($AccessGroup.Name -like "*") {
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

rite-host "$KeyVaulName.ps1 script completed" -ForegroundColor Blue

#Open the page of the resource in the portal
Start-Process "https://portal.azure.com/#resource/$($NewKeyVault.ResourceId)"