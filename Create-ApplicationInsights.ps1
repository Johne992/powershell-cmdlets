#Create and configure App Insights.
#v1.0.0 - made more readable and added access hash
#Set Variables - UPDATE FOR EACH ENVIRONMENT
$SubscriptionName = "SUBSCRIPTION NAME GOES HERE"
$Location = "centralus"
$CostCenter = "xxxx"
$CurrentDate = get-date -Format "yyyy.MM.dd:HH.mm.ss"
$AIResourceGroupName = "rg"
$AppInsightsName = "kv01"
$LogAnalyticsWs = "resourceID"
$Access = @{
    "AzureAd-Object" = @("Application Insights Component Contributor")
}

#Set subscription context
Set-AzContext -SubscriptionName $SubscriptionName
$CurrentUser = Get-AzContext | Select-Object -ExpandProperty Account

#Create Application Insights
write-host "Creating $AppInsightsName Application Insights!" -ForegroundColor Green
$NewAppInsights = New-AzApplicationInsights -Name $AppInsightsName `
-ResourceGroupName $AIResourceGroupName `
-Location $Location `
-WorkspaceResourceId $LogAnalyticsWs `
-EnabledForTemplateDeployment `
-Tag @{
    CreatedBy=$CurrentUser.Id;
    CreatedDate=$CurrentDate;
    CostCenter=$CostCenter;
    } `
-ErrorAction Stop

#Configure Diagnostic settings
write-host "Enabling Diagnostics on $AppInsightsName" -ForegroundColor Green
Set-AzDiagnosticSetting `
 -ResourceId $NewAppInsights.ResourceId `
 -Enabled $true `
 -Category AuditEvent `
 -Name "send to log analytics" `
 -WorkspaceId $LogAnalyticsWs `
 -ErrorAction Stop

#Assign RBAC permissions to Application Insights
write-host "Assigning RBAC permissions to $AppInsightsName" -ForegroundColor Green
foreach ($AccessGroup in $Access.GetEnumerator()) {

    #Get the object ID of the group
    $AccessGroup.Name = (Get-AzADGroup -SearchString $AccessGroup.Name)
    $AccessGroup.Value
    foreach ($Role in $AccessGroup.Value) {
        $Role
        New-AzRoleAssignment `
        -ObjectId $AccessGroup.Name.Id `
        -RoleDefinitionName $Role `
        -Scope $NewAppInsights.ResourceId `
        -ErrorAction Stop
    }
}

write-host "Application-Insights.ps1 script completed" -ForegroundColor Blue