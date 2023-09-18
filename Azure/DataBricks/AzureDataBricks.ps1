#Create and configure Azure Databricks workspace on custom VNet. Permissions NOT assigned in this script

#Need custom Az PowerShell module -> Install-Module -Name Az.Databricks -AllowPrerelease

#ADLS must be created prior to running this script (use the ADLS SCRIPT!)! Or you must use an existing ADLS if requested

#Set Variables - UPDATE FOR EACH ENVIRONMENT
$SubscriptionName = "SUBSCRIPTION NAME GOES HERE"
$Location = "centralus"
$CostCenter = "XXXX"
$CurrentDate = get-date -Format "yyyy.MM.dd:HH.mm.ss"
$ResourceGroupName = "ResourceGroup" #Please enter the name of the resource group for the Azure Databricks
$ResourceGroupName2 = "ResourceGroup" #Enter the name of the resource group for the ADLS that you are deploying or using
$ADLSName = "DeltaLakeStorage" #Enter the name of the adls you want to use
$VNetResourceGroupName = "ResourceGroup"
$VNetName = "VirtualNetworkName"
$PubSubnetName = "pubsn01"
$PubSubnetIP = "..../26"
$PriSubnetName = "privsn01"
$PriSubnetIP = "..../26"
$NsgName = "nsg"
$DatabricksName = "databricks" 
$ADBManagedRGName = "databricks-rg-databricks" #Make sure that last part matches the databricks name
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
Set-AzDiagnosticSetting -ResourceId $Databricks.Id -Enabled $true -Name "send to log analytics" -WorkspaceId "resourceid" -ErrorAction Stop

#Add Databricks subnets to ADLS firewall...
write-host "Adding Databricks Subnets to $ADLSName firewall" -ForegroundColor Green
$Subnet1 = Get-AzVirtualNetwork -ResourceGroupName $VNetResourceGroupName -Name $VNetName | Select-Object -ExpandProperty subnets | Where-Object  {$_.Name -eq $PubSubnetName}
Add-AzStorageAccountNetworkRule -ResourceGroupName $ResourceGroupName2 -Name $ADLSName -VirtualNetworkResourceId $Subnet1.Id -ErrorAction Stop
$Subnet2 = Get-AzVirtualNetwork -ResourceGroupName $VNetResourceGroupName -Name $VNetName | Select-Object -ExpandProperty subnets | Where-Object  {$_.Name -eq $PriSubnetName}
Add-AzStorageAccountNetworkRule -ResourceGroupName $ResourceGroupName2 -Name $ADLSName -VirtualNetworkResourceId $Subnet2.Id -ErrorAction Stop

write-host "1.ps1 script completed!" -ForegroundColor Blue