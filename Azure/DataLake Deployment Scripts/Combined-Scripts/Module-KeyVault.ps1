#Create and configure Key Vault.  Permissions assigned in separate script or manually

param(
    [Parameter()]
    [string] $Loctag,

    [Parameter()]
    [string] $EnvTag,

    [Parameter()]
    [string] $AppTag,

    [Parameter()]
    [string] $SNOWTag,

    [Parameter()]
    [string] $SubscriptionName,

    [Parameter()]
    [string] $ResourceGroupName,

    [Parameter()]
    [string] $Location,

    [Parameter()]
    [string] $CostCenter,

    [Parameter()]
    [string] $CurrentUser,

    [Parameter()]
    [string] $DataFactoryName,

    [Parameter()]
    [string] $AzADPrefix,

    [Parameter()]
    [string] $AzSPNPrefix,

    [Parameter()]
    [string] $AzADBase,

    [Parameter()]
    [string] $AzResourceBase,

    [Parameter()]
    [string] $AzResourcePrefix,

    [Parameter()]
    [string] $VNetResourceGroupName,

    [Parameter()]
    [string] $VNetName
)


#Set Variables - UPDATE FOR EACH ENVIRONMENT
$CurrentDate = get-date -Format "yyyy.MM.dd"
$KVResourceGroupName = "${AzResourcePrefix}uscedexkeyvaultrg"
$KeyVaultName = "${AzResourcePrefix}usceitclinicalkv01"
$LogAnalyticsWs = ""
$subnetName = "sn01"
$Access = @{
    "${AzADPrefix} "                    = @("Key Vault Contributor", "Key Vault Administrator");
    "${AzSPNPrefix}"                         = @("Key Vault Contributor", "Key Vault Administrator");
    "${AzResourcePrefix}${AzResourceBase}" = @("Key Vault Administrator");
    "$CurrentUser"                                    = @("Key Vault Administrator");
    
}

#Set subscription context
Set-AzContext -SubscriptionName $SubscriptionName
$CurrentUser = Get-AzContext | Select-Object -ExpandProperty Account

#Firewall Settings
#Get the subnet ID
$subnetId = (Get-AzVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork (Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $vnetResourceGroup)).Id

#Ip Addresses
$IPAddresses = @(
    "10.10.10.0/24")  #Shrevport, and Azure IPs
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

#copy  secret from another keyvault
write-host "Copying secret from another keyvault" -ForegroundColor Green
$Secret = Get-AzKeyVaultSecret -VaultName "KV01" -Name "secret01"
Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name "secret01" -SecretValue $Secret.SecretValue -ErrorAction Stop


write-host "$KeyVaulName.ps1 script completed" -ForegroundColor Blue
