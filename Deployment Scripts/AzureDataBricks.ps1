#Create and configure Azure Databricks workspace on custom VNet. Permissions NOT assigned in this script

#Need custom Az PowerShell module -> Install-Module -Name Az.Databricks -AllowPrerelease

#ADLS must be created prior to running this script (use the ADLS SCRIPT!)! Or you must use an existing ADLS if requested

#Set Variables - UPDATE FOR EACH ENVIRONMENT
$SubscriptionName = "BCBSLA Dev Data and Analytics"
$Location = "centralus"
$CostCenter = "1611"
$CurrentDate = get-date -Format "yyyy.MM.dd:HH.mm.ss"
$ResourceGroupName = "devuscedexeimextractsrg" #Please enter the name of the resource group for the Azure Databricks
$ResourceGroupName2 = "devuscedexanalyticsrg" #Enter the name of the resource group for the ADLS that you are deploying or using
$ADLSName = "devuscedexadls01" #Enter the name of the adls you want to use
$VNetResourceGroupName = "devuscenetrg"
$VNetName = "devuscevnet02"
$PubSubnetName = "eimebaypubsn01"
$PubSubnetIP = "10.240.93.0/26"
$PriSubnetName = "eimebaybayprivsn01"
$PriSubnetIP = "10.240.93.64/26"
$NsgName = "eimebay01nsg"
$DatabricksName = "devusceeimextractsadb01" 
$ADBManagedRGName = "databricks-rg-devusceeimextractsadb01" #Make sure that last part matches the databricks name
$LocTag = "USCE - Central US"
$EnvTag = "DEV - Development"

#Set subscription context
Set-AzContext -SubscriptionName $SubscriptionName
$CurrentUser = Get-AzContext | Select-Object -ExpandProperty Account

#Prep networking...
#Create NSG
write-host "Creating $NsgName Network Security Group" -ForegroundColor Green
$Nsg = New-AzNetworkSecurityGroup -Name $NsgName -ResourceGroupName $VNetResourceGroupName -Location $Location -Tag @{CreatedBy=$CurrentUser.Id;CreatedDate=$CurrentDate;CostCenter=$CostCenter;NS_Location=$LocTag;NS_Environment=$EnvTag;NS_Application=$AppTag} -ErrorAction Stop

#*Create Delegation object and Subnets to add to the existing VNet
write-host "Creating custom $PubSubnetName and $PriSubnetName Subnets for Databricks!  This may take a few minutes" -ForegroundColor Green
#Create Delegation object
$Delegation = New-AzDelegation -Name ($DatabricksName + "del") -ServiceName "Microsoft.Databricks/workspaces"

#Create Subnets to add to the VNet and Enable Service Endpoints
$VNet = Get-AzVirtualNetwork -ResourceGroupName $VNetResourceGroupName -Name $VNetName
Add-AzVirtualNetworkSubnetConfig -Name $PubSubnetName -VirtualNetwork $VNet -AddressPrefix $PubSubnetIP -Delegation $delegation -NetworkSecurityGroup $Nsg -ServiceEndpoint "Microsoft.Storage" | Set-AzVirtualNetwork -ErrorAction Stop
Add-AzVirtualNetworkSubnetConfig -Name $PriSubnetName -VirtualNetwork $VNet -AddressPrefix $PriSubnetIP -Delegation $delegation -NetworkSecurityGroup $Nsg -ServiceEndpoint "Microsoft.Storage" | Set-AzVirtualNetwork -ErrorAction Stop

#Create Databricks
write-host "Creating $DatabricksName Databricks workspace!  This may take a few minutes" -ForegroundColor Green
New-AzDatabricksWorkspace -Name $DatabricksName -ResourceGroupName $ResourceGroupName -Location $Location -VirtualNetworkId $VNet.Id -PrivateSubnetName $PriSubnetName -PublicSubnetName $PubSubnetName -Sku premium -ManagedResourceGroupName $ADBManagedRGName -Tag @{CreatedBy=$CurrentUser.Id;CreatedDate=$CurrentDate;CostCenter=$CostCenter;NS_Location=$LocTag;NS_Environment=$EnvTag;NS_Application=$AppTag} -ErrorAction Stop

#Add diagnostic settings
write-host "Enabling Diagnostics on $DatabricksName" -ForegroundColor Green
$Databricks = Get-AzDatabricksWorkspace -Name $DatabricksName -ResourceGroupName $ResourceGroupName
Set-AzDiagnosticSetting -ResourceId $Databricks.Id -Enabled $true -Name "send to log analytics" -WorkspaceId "/subscriptions/fe0cda9d-4f2d-45bb-9da4-c3b755c9dcef/resourcegroups/prduseaomsrg/providers/microsoft.operationalinsights/workspaces/prduseaomswsfe0cda9d4f" -ErrorAction Stop

#Add Databricks subnets to ADLS firewall...
write-host "Adding Databricks Subnets to $ADLSName firewall" -ForegroundColor Green
$Subnet1 = Get-AzVirtualNetwork -ResourceGroupName $VNetResourceGroupName -Name $VNetName | Select-Object -ExpandProperty subnets | Where-Object  {$_.Name -eq $PubSubnetName}
Add-AzStorageAccountNetworkRule -ResourceGroupName $ResourceGroupName2 -Name $ADLSName -VirtualNetworkResourceId $Subnet1.Id -ErrorAction Stop
$Subnet2 = Get-AzVirtualNetwork -ResourceGroupName $VNetResourceGroupName -Name $VNetName | Select-Object -ExpandProperty subnets | Where-Object  {$_.Name -eq $PriSubnetName}
Add-AzStorageAccountNetworkRule -ResourceGroupName $ResourceGroupName2 -Name $ADLSName -VirtualNetworkResourceId $Subnet2.Id -ErrorAction Stop

write-host "PPM-ADB-1.ps1 script completed!" -ForegroundColor Blue