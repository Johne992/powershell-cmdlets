<#
    Created for  Resource
    Created by:  John Lewis
    Created on:  2023-10-05
    Version:     1.0.0
    Purpose:     Create an Azure Data Bricks resource with public and private subnets
#>

#Set Variables
$SubscriptionName = ""
$ResourceGroupName = ""
$Location = "centralus"
$CostCenter = ""
$CurrentDate = get-date -Format "yyyy.MM.dd"
$NsgName = ""
$DatabricksName = "" 
$ADBManagedRGName = "databricks-rg-${DataBricksName}" #Make sure that last part matches the databricks name
$DataFactoryName = ""
$PubSubnetName = ""
$PubSubnetIP = ""
$PriSubnetName = ""
$PriSubnetIP = ""
$VNetResourceGroupName = ""
$VNetName = ""
$ADLSName = ""
$ADLSRGName = ""
$Loctag = ""
$EnvTag = ""
$AppTag = ""
$SNOWTag = ""
$LogAnalyticsWs = "/subscriptions/fe0cda9d-4f2d-45bb-9da4-c3b755c9dcef/resourcegroups/prduseaomsrg/providers/microsoft.operationalinsights/workspaces/prduseaomswsfe0cda9d4f"

# ****** Ensure Add-AzureRBAC.ps1 is in the same folder as this script ******
$Access = @{
    ""        = @("");
}


#Set subscription context
Set-AzContext -SubscriptionName $SubscriptionName
$CurrentUser = Get-AzContext | Select-Object -ExpandProperty Account

#Prep networking...
#Create NSG
write-host "Creating $NsgName Network Security Group" -ForegroundColor Green
$Nsg = New-AzNetworkSecurityGroup -Name $NsgName `
    -ResourceGroupName $VNetResourceGroupName `
    -Location $Location `
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

#*Create Delegation object and Subnets to add to the existing VNet
write-host "Creating custom $PubSubnetName and $PriSubnetName Subnets for Databricks!  This may take a few minutes" -ForegroundColor Green
#Create Delegation object
$Delegation = New-AzDelegation -Name ($DatabricksName + "del") -ServiceName "Microsoft.Databricks/workspaces"

#Create Subnets to add to the VNet and Enable Service Endpoints
$VNet = Get-AzVirtualNetwork -ResourceGroupName $VNetResourceGroupName -Name $VNetName
Add-AzVirtualNetworkSubnetConfig `
    -Name $PubSubnetName `
    -VirtualNetwork $VNet `
    -AddressPrefix $PubSubnetIP `
    -Delegation $delegation `
    -NetworkSecurityGroup $Nsg `
    -ServiceEndpoint "Microsoft.Storage" | Set-AzVirtualNetwork `
    -ErrorAction Stop
Add-AzVirtualNetworkSubnetConfig `
    -Name $PriSubnetName `
    -VirtualNetwork $VNet `
    -AddressPrefix $PriSubnetIP `
    -Delegation $delegation `
    -NetworkSecurityGroup $Nsg `
    -ServiceEndpoint "Microsoft.Storage" | Set-AzVirtualNetwork `
    -ErrorAction Stop

#Create Databricks
write-host "Creating $DatabricksName Databricks workspace!  This may take a few minutes" -ForegroundColor Green
$NewDataBricks = New-AzDatabricksWorkspace `
    -Name $DatabricksName `
    -ResourceGroupName $ResourceGroupName `
    -Location $Location `
    -VirtualNetworkId $VNet.Id `
    -PrivateSubnetName $PriSubnetName `
    -PublicSubnetName $PubSubnetName `
    -Sku premium `
    -ManagedResourceGroupName $ADBManagedRGName `
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
write-host "Enabling Diagnostics on $DatabricksName" -ForegroundColor Green
$log = @()
$categories = Get-AzDiagnosticSettingCategory -ResourceId $NewDataBricks.Id
$categories | ForEach-Object { if ($_.CategoryType -eq "Log") { $log += New-AzDiagnosticSettingLogSettingsObject -Enabled $true -Category $_.Name -RetentionPolicyDay 7 -RetentionPolicyEnabled $true } }
New-AzDiagnosticSetting -Name 'send to log analtics workspace' `
    -ResourceId $NewDataBricks.Id `
    -WorkspaceId $LogAnalyticsWs `
    -Log $log `
    -Metric $metric


#Add Databricks subnets to ADLS firewall...
write-host "Adding Databricks Subnets to $ADLSName firewall" -ForegroundColor Green
$Subnet1 = Get-AzVirtualNetwork -ResourceGroupName $VNetResourceGroupName -Name $VNetName | Select-Object -ExpandProperty subnets | Where-Object { $_.Name -eq $PubSubnetName }
Add-AzStorageAccountNetworkRule -ResourceGroupName $ADLSRGName -Name $ADLSName -VirtualNetworkResourceId $Subnet1.Id -ErrorAction Stop
$Subnet2 = Get-AzVirtualNetwork -ResourceGroupName $VNetResourceGroupName -Name $VNetName | Select-Object -ExpandProperty subnets | Where-Object { $_.Name -eq $PriSubnetName }
Add-AzStorageAccountNetworkRule -ResourceGroupName $ADLSRGName -Name $ADLSName -VirtualNetworkResourceId $Subnet2.Id -ErrorAction Stop

#Call Add-AzureRBAC to add access to the resource
& "$PSSCriptRoot\Add-AzureRBAC.ps1" -ResourceId $NewDataBricks.Id -Access $Access

write-host "$DataBricksName.ps1 script completed!" -ForegroundColor Blue

#Open the page of the resource in the portal
Start-Process "https://portal.azure.com/#resource/$($NewDataBricks.Id)"