#Input Parameters
$subscriptionName = "BCBSLA Test 1"
$resourceGroupName = "tstuscedxplatrg"
$rediscacheName = "tstuscememmobileredis"
$costCenter = "9016"
$sku = "Standard"
$size = "C1"
$redisVersion = "6"
$loganalyticsrg = "prduseaomsrg" # DO NOT CHANGE
$loganalyticsname = "prduseaomswsfe0cda9d4f" #DO NOT CHANGE
$logCategory = "ConnectedClientList" # DO NOT CHANGE
$location = "Central US"
$vnetrg = "tstuscenetrg"
$vnetname = "tstuscevnet01" 

# DO NOT CHANGE
$subnetname = "asesn01"
$dnsZoneName = "privatelink.redis.cache.windows.net"
$dnsResourceGroupName = "prduscepdnszrg"

Set-AzContext "BCBSLA HUB"
$loganalws = Get-AzOperationalInsightsWorkspace -Name $loganalyticsname -resourceGroupName $loganalyticsrg 

Set-AzContext -SubscriptionName $subscriptionName
$newCache = New-AzRedisCache -resourceGroupName $resourceGroupName -Name $rediscacheName -Location $location -Sku $sku -Size $size `
-RedisVersion $redisVersion `
-Tag @{ CreatedBy=((Get-AzContext | Select-Object -ExpandProperty Account).Id); 
    CreatedDate=(Get-Date -Format "yyyy.MM.dd-HH.mm.ss");
    CostCenter=$costCenter } 

#This takes 30 minutes to create. 
Start-Sleep -Seconds 1800 #TDO: $newCache.ProvisioningState = "Running" TO DO: wait based on the state


#Set-AzContext -SubscriptionName $subscriptionName
#$newCache = Get-AzRedisCache -resourceGroupName $resourceGroupName -Name $rediscacheName 

#Logs
 Set-AzDiagnosticSetting -ResourceId $newCache.Id -Enabled $true `
 -Category $logCategory -Name "send to loganalytics" -WorkspaceId $loganalws.ResourceId

   
#Create Private Endpoint
$privateEndpointConnection = New-AzPrivateLinkServiceConnection -Name ($rediscacheName + "plsconn") `
-PrivateLinkServiceId  $newCache.Id `
-GroupId "redisCache" 

$subnet = Get-AzVirtualNetwork -resourceGroupName $vnetrg -Name $vnetname | Select-Object -ExpandProperty subnets | Where-Object  {$_.Name -eq $subnetname}  

New-AzPrivateEndpoint   -resourceGroupName $resourceGroupName `
-Name ($rediscacheName + "pe") `
-Location $location `
-Subnet  $subnet `
-PrivateLinkServiceConnection $privateEndpointConnection

$privateEndpoint = Get-AzPrivateEndpoint -resourceGroupName $resourceGroupName -Name ($rediscacheName + "pe") 

#Integrate above created private endpoint with existing private DNS zone
Set-AzContext "BCBSLA HUB" #Change the subscription context to HUB becuase DNS private zone are located there.

New-AzPrivateDnsRecordSet   -ZoneName $dnsZoneName `
-resourceGroupName $dnsresourceGroupName `
-Name $rediscacheName `
-RecordType A `
-TTL 3600 `
-PrivateDnsRecords (New-AzPrivateDnsRecordConfig -IPv4Address $privateEndpoint.CustomDnsConfigs.IpAddresses)

#Set Firewall Rule:
Set-AzContext -SubscriptionName $subscriptionName
New-AzRedisCacheFirewallRule -Name $rediscacheName -RuleName "AZUSCE1" -StartIP "52.242.208.117" -EndIP "52.242.208.117"
New-AzRedisCacheFirewallRule -Name $rediscacheName -RuleName "AZUSCE2" -StartIP "52.158.213.200" -EndIP "52.158.213.200"
New-AzRedisCacheFirewallRule -Name $rediscacheName -RuleName "AZUSE21" -StartIP "52.232.225.139" -EndIP "52.232.225.139"
New-AzRedisCacheFirewallRule -Name $rediscacheName -RuleName "AZUSE22" -StartIP "52.177.165.205" -EndIP "52.177.165.205"
New-AzRedisCacheFirewallRule -Name $rediscacheName -RuleName "BTR" -StartIP "199.117.168.1" -EndIP "199.117.168.1"
New-AzRedisCacheFirewallRule -Name $rediscacheName -RuleName "SHV" -StartIP "216.206.24.1" -EndIP "216.206.24.1"



  