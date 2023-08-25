#Create Data Factory, Set Diagnostics and create Self-Hosted IR within new Data Factory 

#Set Variables - UPDATE FOR EACH ENVIRONMENT
$Subscription = ""
$Location = ""
$CostCenter = ""
$CurrentDate = get-date -Format "yyyy.MM.dd:HH.mm.ss"
$ResourceGroupName = ""
$DataFactoryName = ""
$LocTag = ""
$EnvTag = ""
$AppTag = ""
$SNOWTag = ""
$LogAnalyticsWs = ""
$Access = @{
    "" = @("");
}

#Start Logging
# Start-Transcript -Path ".\Deploy-$ResourceGroup-$(get-date -Format "yyyy-MM-dd")" -Append



#Set subscription context
write-host "Set context to subscription where new Data Factory will be created" -ForegroundColor Green
Set-AzContext -SubscriptionName $Subscription
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
            -Scope $NewDataFactory.DataFactoryId `
            -ErrorAction Stop
    }
}

write-host "$DataFactoryName-1.ps1 script completed!" -ForegroundColor Blue
$DataFactoryName

#End Logging
# Stop-Transcript