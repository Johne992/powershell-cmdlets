#Create and configure Key Vault.  Permissions assigned in separate script or manually

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


#Set subscription context
Set-AzContext -SubscriptionName $SubscriptionName
$CurrentUser = Get-AzContext | Select-Object -ExpandProperty Account

#Firewall Settings
$IPAddresses = @("x.x.x.x") 
$RuleSet = New-AzKeyVaultNetworkRuleSetObject -DefaultAction Deny -Bypass AzureServices -IpAddressRange $IPAddresses

#Create Key Vault
write-host "Creating $KeyVaultName Key Vault!" -ForegroundColor Green
$NewKeyVault = New-AzKeyVault -Name $KeyVaultName -ResourceGroupName $KVResourceGroupName -Location $Location -NetworkRuleSet $RuleSet -EnabledForTemplateDeployment -Tag @{CreatedBy=$CurrentUser.Id;CreatedDate=$CurrentDate;CostCenter=$CostCenter;NS_Location=$LocTag;NS_Environment=$EnvTag;NS_Application=$AppTag} -ErrorAction Stop

#Configure Diagnostic settings
write-host "Enabling Diagnostics on $KeyVaultName" -ForegroundColor Green
Set-AzDiagnosticSetting -ResourceId $NewKeyVault.ResourceId -Enabled $true -Category AuditEvent -Name "send to log analytics" -WorkspaceId $LogAnalyticsWs -ErrorAction Stop

write-host "kv.ps1 script completed" -ForegroundColor Blue