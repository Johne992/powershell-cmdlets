#This root script will eventually make the calls to run the modules and build the environment

#Start Logging
Start-Transcript -Path ".\Deploy-$ResourceGroup-$(get-date -Format "yyyy-MM-dd")" -Append

# Dot Sourcing
. ..\..\..\Utilities\Invoke-Script.ps1

############ Variable Section ############
#Set Variables
$SubscriptionName = ""
$Location = ""
$CostCenter = ""
$CurrentDate = get-date -Format "yyyy.MM.dd"
$LocTag = ""
$EnvTag = ""
$AppTag = ""
$SNOWTag = ""

#Help Generate Resource Names
if ($SubscriptionName -like "Prod") {
    $AzADPrefix = "AzProd"
    $AzSPNPrefix = "_PROD_"
    $AzResourcePrefix = "prd"

}
elseif ($SubscriptionName -like "Test") {
    $AzADPrefix = "AzTest"
    $AzSPNPrefix = "_TEST_"
    $AzResourcePrefix = "tst"

}
elseif ($SubscriptionName -like "POC") { 
    #POC is for Proof of concept and is a temporary subscription so dev is fine
    $AzADPrefix = "AzDev"
    $AzSPNPrefix = "_POC_"
    $AzResourcePrefix = "POC"

}
else {
    $AzADPrefix = "AzDev"
    $AzSPNPrefix = "_DEV_"
    $AzResourcePrefix = "dev"

}
   
#if latter half of subscription name is Data and Analytics, then append '.DNA' to the end of the resource group name
if ($SubscriptionName -like "*Data and Analytics") {
    $AzADPrefix += ".DNA"
}

$PubSubnetName = ""
$PubSubnetIP = ""
$PriSubnetName = ""
$PriSubnetIP = ""
$ADLSName = "${AzResourcePrefix}uscedexadls01"
$ADLSRGName = "${AzResourcePrefix}uscedex${AzResourceBase}rg"
$VNetResourceGroupName = "${AzResourcePrefix}uscevnetrg"
$VNetName = "${AzResourcePrefix}uscevnet01" #This may change depending on subscription
$AzResourceBase = ""
$AzADBase = ""
$AzSPNBase = ""
$ResourceGroupName = "${AzResourcePrefix}uscedex${AzResourceBase}rg"

######### End Variable Section #########

#Set subscription context
Set-AzContext -SubscriptionName $SubscriptionName
$CurrentUser = Get-AzContext | Select-Object -ExpandProperty Account

#0. Create Resource Group
$ResourceGroup = New-AzResourceGroup `
    -Name $ResourceGroupName `
    -Location $Location `
    -Tag @{
    CreatedDate    = $CurrentDate;
    CreatedBy      = $CurrentUser;
    CostCenter     = $CostCenter;
    NS_Location    = $LocTag;
    NS_Environment = $EnvTag;
    NS_Application = $AppTag;
    SNOWTag        = $SNOWTag
}

#1. Call the Module-AzureDataFactory.ps1 script
Invoke-Script -ScriptPath .\Module-DataFactory.ps1 `
    -ScriptArgs @{
    SubscriptionName  = $SubscriptionName;
    AzADPrefix        = $AzADPrefix;
    AzSPNPrefix       = $AzSPNPrefix;
    AzADBase          = $AzADBase;
    AzResourcePrefix  = $AzResourcePrefix;
    AzResourceBase    = $AzResourceBase;
    ResourceGroupName = $ResourceGroupName;
    ADLSName          = $ADLSName;
    ADLSRGName        = $ADLSRGName;
    Location          = $Location;
    CostCenter        = $CostCenter;
    LocTag            = $LocTag;
    EnvTag            = $EnvTag;
    AppTag            = $AppTag;
    SNOWTag           = $SNOWTag;
    CurrentUser       = $CurrentUser
}

#2. Call the Module-AzureDataBricks.ps1 script
Invoke-Script -ScriptPath .\Module-DataBricks.ps1 `
    -ScriptArgs @{
    SubscriptionName      = $SubscriptionName;
    AzADPrefix            = $AzADPrefix;
    AzSPNPrefix           = $AzSPNPrefix;
    AzSPNBase             = $AzSPNBase;
    AzADBase              = $AzADBase;
    AzResourcePrefix      = $AzResourcePrefix;
    AzResourceBase        = $AzResourceBase;
    ResourceGroupName     = $ResourceGroupName;
    PubSubnetName         = $PubSubnetName;
    PubSubnetIP           = $PubSubnetIP;
    PriSubnetName         = $PriSubnetName;
    PriSubnetIP           = $PriSubnetIP;
    VNetResourceGroupName = $VNetResourceGroupName;
    VNetName              = $VNetName;
    ADLSName              = $ADLSName;
    ADLSRGName            = $ADLSRGName;
    Location              = $Location;
    CostCenter            = $CostCenter;
    LocTag                = $LocTag;
    EnvTag                = $EnvTag;
    AppTag                = $AppTag;
    SNOWTag               = $SNOWTag;
    CurrentUser           = $CurrentUser
}

#3. Call the Module-KeyVault.ps1 script
Invoke-Script -ScriptPath .\Module-KeyVault.ps1 `
    -ScriptArgs @{
    SubscriptionName  = $SubscriptionName;
    AzADPrefix        = $AzADPrefix;
    AzSPNPrefix       = $AzSPNPrefix;
    AzADBase          = $AzADBase;
    AzResourcePrefix  = $AzResourcePrefix;
    AzResourceBase    = $AzResourceBase;
    ResourceGroupName = $ResourceGroupName;
    Location          = $Location;
    CostCenter        = $CostCenter;
    LocTag            = $LocTag;
    EnvTag            = $EnvTag;
    AppTag            = $AppTag;
    SNOWTag           = $SNOWTag;
    CurrentUser       = $CurrentUser
}

#4. Call the Module-ServicePrincipal.ps1 script
Invoke-Script -ScriptPath .\Module-ServicePrincipal.ps1 `
    -ScriptArgs @{
    SubscriptionName = $SubscriptionName;
    AzSPNPrefix      = $AzSPNPrefix;
    AzADBase         = $AzADBase;
    AzResourcePrefix = $AzResourcePrefix;
    AzResourceBase   = $AzResourceBase;
}

#5. Call the Module-DataLakeRBAC.ps1 script
Invoke-Script -ScriptPath .\Module-DataLakeRBAC.ps1 `
    -ScriptArgs @{
    SubscriptionName  = $SubscriptionName;
    AzADPrefix        = $AzADPrefix;
    AzSPNPrefix       = $AzSPNPrefix;
    AzADBase          = $AzADBase;
    AzResourcePrefix  = $AzResourcePrefix;
    AzResourceBase    = $AzResourceBase;
    ResourceGroupName = $ResourceGroupName;
    ADLSName          = $ADLSName;
}

#6. Call the Module-DataLakeContainers.ps1 script
Invoke-Script -ScriptPath .\Module-DataLakeContainers.ps1 `
    -ScriptArgs @{ 
    SubscriptionName  = $SubscriptionName;
    AzADPrefix        = $AzADPrefix;
    AzSPNPrefix       = $AzSPNPrefix;
    AzADBase          = $AzADBase;
    AzResourcePrefix  = $AzResourcePrefix;
    AzResourceBase    = $AzResourceBase;
    ResourceGroupName = $ResourceGroupName;
    ADLSName          = $ADLSName;
    CurrentUser       = $CurrentUser
}

Stop-Transcript