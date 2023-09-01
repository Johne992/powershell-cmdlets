#Create Data Factory, Set Diagnostics and create Self-Hosted IR within new Data Factory 
#Manually link self-hosted IR after running script

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
    [string] $AzResourcePrefix
)

#Generate Dafactory Name
$DataFactoryName = "${AzResourcePrefix}uscebay${AzResourceBase}df01"

#Set Variables
$CurrentDate = get-date -Format "yyyy.MM.dd:HH.mm.ss"
$LogAnalyticsWs = "/subscriptions/fe0cda9d-4f2d-45bb-9da4-c3b755c9dcef/resourcegroups/prduseaomsrg/providers/microsoft.operationalinsights/workspaces/prduseaomswsfe0cda9d4f"
$Access = @{
    "$AzADPrefix Big Data Admin"        = @("Custom - Data Factory Operator", "Monitoring Contributor");
    "$AzADPrefix $AzADBase Bay Admin"   = @("Custom - Data Factory Operator");
    "$AzADPrefix $AzADBase Bay Support" = @("Custom - Data Factory Operator");
    "$AzADPrefix $AzADBase Bay Devs"    = @("Custom - Data Factory Operator");
    "$AzADPrefix $AzADBase Bay QA"      = @("Custom - Data Factory Operator");
    "$AzADPrefix $AzADBase Bay Analyst" = @("Custom - Data Factory Operator");
    "${AzSPNPrefix}DEXDEVOPS"           = @("Custom - Data Factory Operator", "Contributor");
}


#Set subscription context
write-host "Set context to subscription where new Data Factory will be created" -ForegroundColor Green
Set-AzContext -SubscriptionName $SubscriptionName
$CurrentUser = Get-AzContext | Select-Object -ExpandProperty Account

#Create Data Factory
write-host "Creating new Data Factory" -ForegroundColor Green
$NewDataFactory = Set-AzDataFactoryV2 `
    -ResourceGroupName $ResourceGroupName `
    -Location $Location `
    -Name $DataFactoryName `
    -Tag @{
    CreatedBy      = $CurrentUser.Id;
    CreatedDate    = $CurrentDate;
    CostCenter     = $CostCenter;
    NS_Location    = $LocTag;
    NS_Environment = $EnvTag;
    NS_Application = $AppTag
    SNOWRequest    = $SNOWTag
} `
    -ErrorAction Stop
write-host "Sleep for 10 seconds..." -ForegroundColor Green
Start-Sleep -s 10

#Set Diagnostic Logs
write-host "Configuring diagnostic settings" -ForegroundColor Green
$log = @()
$categories = Get-AzDiagnosticSettingCategory -ResourceId $NewDataFactory.DataFactoryId
$categories | ForEach-Object { if ($_.CategoryType -eq "Log") { $log += New-AzDiagnosticSettingLogSettingsObject -Enabled $true -Category $_.Name -RetentionPolicyDay 7 -RetentionPolicyEnabled $true } }
New-AzDiagnosticSetting -Name 'send to log analtics workspace' `
    -ResourceId $NewDataFactory.DataFactoryId `
    -WorkspaceId $LogAnalyticsWs `
    -Log $log `
    -Metric $metric


#Add Access to Data Factory
write-host "Assigning Access to $DataFactoryName" -ForegroundColor Green
foreach ($AccessGroup in $Access.GetEnumerator()) {
    #Check if group or azure ad object
    if ($AccessGroup.Name -like "*DEXDEVOPS*") {
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
            -Scope $NewDataFactory.DataFactoryId `
            -ErrorAction Stop
    }
}

write-host "$DataFactoryName-1.ps1 script completed!" -ForegroundColor Blue

#Open the page of the resource in the portal
Start-Process "https://portal.azure.com/#resource/$($NewDataFactory.Id)"
