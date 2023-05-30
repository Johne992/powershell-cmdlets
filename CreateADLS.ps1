#Create and configure ADLS Gen 2. Permissions assigned in seperate script or manually

#Set Variables - UPDATE FOR EACH ENVIRONMENT
$SubscriptionName = "Sub"
$Location = "centralus"
$CostCenter = "XXX"
$CurrentDate = get-date -Format "yyyy.MM.dd:HH.mm.ss"
$ResourceGroupName = "rg"
$ADLSName = "adls01"
$VNetResourceGroupName = "rg"
$VNetName = "vnet01"
$LocTag = "USCE - Central US"
$EnvTag = "TST - Test"
$AppTag = "App- Application"

#DO NOT CHANGE
$LogAnalyticsWs = "resource ID" #DO NOT CHANGE

#Set subscription context
Set-AzContext -SubscriptionName $SubscriptionName
$CurrentUser = Get-AzContext | Select-Object -ExpandProperty Account

#Get asesn01 subnet info
$Subnet = Get-AzVirtualNetwork -ResourceGroupName $VNetResourceGroupName -Name $VNetName | Select-Object -ExpandProperty subnets | Where-Object  {$_.Name -eq "asesn01"}

#Create ADLS Gen 2
write-host "Creating $ADLSName Storage Account!" -ForegroundColor Green        
New-AzStorageAccount -ResourceGroupName $ResourceGroupName -AccountName $ADLSName -Location $Location -SkuName "Standard_RAGRS" -Kind StorageV2 -EnableHierarchicalNamespace $true -EnableHttpsTrafficOnly $true -AllowBlobPublicAccess $false -MinimumTlsVersion TLS1_2 -NetworkRuleSet (@{bypass="AzureServices";ipRules=(@{IPAddressOrRange="x.x.x.x";Action="allow"})}) -Tag @{CreatedBy=$CurrentUser.Id;CreatedDate=$CurrentDate;CostCenter=$CostCenter;NS_Location=$LocTag;NS_Environment=$EnvTag;NS_Application=$AppTag} -ErrorAction Stop

$NewADLS = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $ADLSName

#Enable ATP on Storage Account
write-host "Enabling Advanced Threat Protection on $ADLSName Storage Account" -ForegroundColor Green
Enable-AzSecurityAdvancedThreatProtection -ResourceId $NewADLS.Id 

<#Set Diagnostics (Classic)
#Need the storage account key to set logging for "Table", the others use OAuth...
write-host "Enabling Classic Diagnostics on $ADLSName Storage Account" -ForegroundColor Green
$ADLSKey1 = (Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -AccountName $ADLSName)| Where-Object {$_.KeyName -eq "key1"}
$ADLSContext = New-AzStorageContext -StorageAccountName $ADLSName -StorageAccountKey $ADLSKey1.Value
Set-AzStorageServiceLoggingProperty -ServiceType Blob -Context $ADLSContext -LoggingOperations All -PassThru -RetentionDays 365 -Version 2.0
Set-AzStorageServiceLoggingProperty -ServiceType Table -Context $ADLSContext -LoggingOperations All -PassThru -RetentionDays 365 -Version 1.0
Set-AzStorageServiceLoggingProperty -ServiceType Queue -Context $ADLSContext -LoggingOperations All -PassThru -RetentionDays 365 -Version 2.0
#>

#Set Diagnostic Logs (Preview)
write-host "Configuring diagnostic settings" -ForegroundColor Green
Set-AzDiagnosticSetting -ResourceId ($NewADLS.Id + "/blobServices/default") -Enabled $true -Category StorageRead,StorageWrite,StorageDelete -Name "send to log analytics" -WorkspaceId $LogAnalyticsWs -ExportToResourceSpecific -ErrorAction Stop

#Create Private Endpoint Connection for ADLS
write-host "Creating Private Endpoint Connection for $ADLSName Storage Account" -ForegroundColor Green
$PrivateEndpointConnection = New-AzPrivateLinkServiceConnection -Name ($ADLSName + "pe") -PrivateLinkServiceId $NewADLS.Id -GroupId "dfs" -ErrorAction Stop

$tags = @{CreatedBy=$CurrentUser.Id;CreatedDate=$CurrentDate;CostCenter=$CostCenter;NS_Location=$LocTag;NS_Environment=$EnvTag;NS_Application=$AppTag}

write-host "Creating Private Endpoint for $ADLSName Storage Account" -ForegroundColor Green
New-AzPrivateEndpoint -ResourceGroupName $ResourceGroupName -Name ($ADLSName + "pe") -Location $Location -Subnet $Subnet -PrivateLinkServiceConnection $PrivateEndpointConnection -Tag $tags -ErrorAction Stop

#Get Private Endpoint IP Address
$PeIp = Get-AzPrivateEndpoint -ResourceGroupName $ResourceGroupName -Name ($ADLSName + "pe") | Select-Object @{Name="IP"; Expression={$_.CustomDnsConfigs.IpAddresses}}
write-host "The Private IP Assigned is $PeIp" -ForegroundColor Green

#Switch to BCBSLA HUB to update existing Private DNS Zone
write-host "Change subscription context to HUB..." -ForegroundColor Green
Set-AzContext -SubscriptionName "BCBSLA HUB"

#Add new Private Endpoint to specified Private DNS Zone
write-host "Updating Private DNS Zone with new private IP" -ForegroundColor Green
New-AzPrivateDnsRecordSet -ZoneName "privatelink.dfs.core.windows.net" -ResourceGroupName "prduscepdnszrg" -Name $ADLSName -RecordType A -TTL 3600 -PrivateDnsRecords (New-AzPrivateDnsRecordConfig -IPv4Address $PeIp.IP)

write-host "PPM-ADLS-1.ps1 script completed" -ForegroundColor Blue