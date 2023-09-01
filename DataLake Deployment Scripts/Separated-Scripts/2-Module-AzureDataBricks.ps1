#Create and configure Azure Databricks workspace on custom VNet. Permissions NOT assigned in this script

#Need custom Az PowerShell module -> Install-Module -Name Az.Databricks -AllowPrerelease

#ADLS must be created prior to running this script (use the ADLS SCRIPT!)! Or you must use an existing ADLS if requested
#Assumes VNET already exists

#Set Variables - UPDATE FOR EACH ENVIRONMENT
$SubscriptionName = ""
$Location = ""
$CostCenter = ""
$CurrentDate = get-date -Format "yyyy.MM.dd"
$ResourceGroupName = "" #Please enter the name of the resource group for the Azure Databricks
$ResourceGroupName2 = "" #Enter the name of the resource group for the ADLS that you are deploying or using
$ADLSName = "" #Enter the name of the adls you want to use
$VNetResourceGroupName = ""
$VNetName = ""
$PubSubnetName = ""
$PubSubnetIP = ""
$PriSubnetName = ""
$PriSubnetIP = ""
$NsgName = ""
$DatabricksName = "" 
$ADBManagedRGName = "" #Make sure that last part matches the databricks name
$LocTag = ""
$EnvTag = ""
$AppTag = ""
$SNOWTag = ""
$Access = @{
    "" = @("");
}

#Start Logging
# Start-Transcript -Path ".\Deploy-$ResourceGroup-$(get-date -Format "yyyy-MM-dd")" -Append

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
Add-AzStorageAccountNetworkRule -ResourceGroupName $ResourceGroupName2 -Name $ADLSName -VirtualNetworkResourceId $Subnet1.Id -ErrorAction Stop
$Subnet2 = Get-AzVirtualNetwork -ResourceGroupName $VNetResourceGroupName -Name $VNetName | Select-Object -ExpandProperty subnets | Where-Object { $_.Name -eq $PriSubnetName }
Add-AzStorageAccountNetworkRule -ResourceGroupName $ResourceGroupName2 -Name $ADLSName -VirtualNetworkResourceId $Subnet2.Id -ErrorAction Stop

#Add Access
write-host "Assigning Access to $DataBricksName" -ForegroundColor Green
foreach ($AccessGroup in $Access.GetEnumerator()) {
    #Check if group or azure ad object
    if ($AccessGroup.Name -like "*DEVOPS*") {
        #Get the object ID of the azure ad object
        $AccessGroup.Name = (Get-AzADServicePrincipal -SearchString $AccessGroup.Name).Id
    }
    else {
        #Get the object ID of the group
        $AccessGroup.Name = (Get-AzADGroup -SearchString $AccessGroup.Name).Id
    }
    $Access
    #Loop through each role in AccessGroup.Value and assign to the group

    foreach ($Role in $AccessGroup.Value) {
        $Role
        New-AzRoleAssignment `
            -ObjectId $AccessGroup.Name `
            -RoleDefinitionName $Role `
            -Scope $NewDataBricks.Id `
            -ErrorAction Stop
    }
}

write-host "$DataBricksName.ps1 script completed!" -ForegroundColor Blue
$DataBricksName

#End Logging
# Stop-Transcript