#Create and configure Key Vault.  Permissions assigned in separate script or manually

#Set Variables - UPDATE FOR EACH ENVIRONMENT
$SubscriptionName = "BCBSLA Prod Data and Analytics"
$Location = "centralus"
$CostCenter = "1611"
$CurrentDate = get-date -Format "yyyy.MM.dd:HH.mm.ss"
$KVResourceGroupName = "prduscedexkeyvaultrg"
$KeyVaultName = "prdusceeimextractskv01"
$LocTag = "USCE - Central US"
$EnvTag = "PROD - Production"
$LogAnalyticsWs = "/subscriptions/fe0cda9d-4f2d-45bb-9da4-c3b755c9dcef/resourcegroups/prduseaomsrg/providers/microsoft.operationalinsights/workspaces/prduseaomswsfe0cda9d4f"


#Set subscription context
Set-AzContext -SubscriptionName $SubscriptionName
$CurrentUser = Get-AzContext | Select-Object -ExpandProperty Account

#Firewall Settings
$IPAddresses = @("199.117.168.1","66.248.253.0/24","52.242.208.117","52.158.213.200","52.232.225.139","52.177.165.205") #Baton Rouge, Shrevport, and Azure IPs
$RuleSet = New-AzKeyVaultNetworkRuleSetObject -DefaultAction Deny -Bypass AzureServices -IpAddressRange $IPAddresses

#Create Key Vault
write-host "Creating $KeyVaultName Key Vault!" -ForegroundColor Green
$NewKeyVault = New-AzKeyVault -Name $KeyVaultName -ResourceGroupName $KVResourceGroupName -Location $Location -NetworkRuleSet $RuleSet -EnabledForTemplateDeployment -Tag @{CreatedBy=$CurrentUser.Id;CreatedDate=$CurrentDate;CostCenter=$CostCenter;NS_Location=$LocTag;NS_Environment=$EnvTag;NS_Application=$AppTag} -ErrorAction Stop

#Configure Diagnostic settings
write-host "Enabling Diagnostics on $KeyVaultName" -ForegroundColor Green
Set-AzDiagnosticSetting -ResourceId $NewKeyVault.ResourceId -Enabled $true -Category AuditEvent -Name "send to log analytics" -WorkspaceId $LogAnalyticsWs -ErrorAction Stop

write-host "eime-kv.ps1 script completed" -ForegroundColor Blue