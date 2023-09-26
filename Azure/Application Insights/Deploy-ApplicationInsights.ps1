<#
    Created by:  John Lewis
    Created on:  2023-09-26
    Version:     1.0.0
    Purpose:     Deploy application insights with ARM and configure diagnostics
    Dependencies: ARM Template, Add-AzureRBAC.ps1
#>

#Import modules
. ..\RBAC\Add-AzureRBAC.ps1

$SubscriptionName = "SUBSCRIPTION NAME GOES HERE"
$Location = "centralus"
$CostCenter = "xxxx"
$CurrentDate = get-date -Format "yyyy.MM.dd:HH.mm.ss"
$AIResourceGroupName = "rg"
$AppInsightsName = "kv01"
$LogAnalyticsWs = "resourceID"
$LocTag = ""
$EnvTag = ""
$AppTag = ""
$SNOWTag = ""
$Access = @{
    "AzureAd-Object" = @("Application Insights Component Contributor")
}

#Set subscription context
Set-AzContext -SubscriptionName $SubscriptionName

#Deploy the ARM Template
$parameters = @{
    "location" = $Location
    "costCenter" = $CostCenter
    "currentDate" = $CurrentDate
    "appInsightsName" = $AppInsightsName
    "logAnalyticsWs" = $LogAnalyticsWs
    "loctag" = $LocTag
    "envtag" = $EnvTag
    "SNOWtag" = $SNOWTag
    "apptag" = $AppTag
}

New-AzResourceGroupDeployment `
    -Name "AppInsightsDeployment - $SNOWTag" `
    -ResourceGroupName $AIResourceGroupName `
    -TemplateFile "..\..\..\ARM_Templates\Application-Insights.json" `
    -TemplateParameterObject $parameters `
    -Verbose

#Get the new App Insights resource
$NewAppInsights = Get-AzApplicationInsights `
    -ResourceGroupName $AIResourceGroupName `
    -Name $AppInsightsName

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
# Use the Add-AzureRBAC function to assign permissions
Add-AzureRBAC `
    -ResourceId $NewAppInsights.ResourceId `
    -Access $Access `
    -ErrorAction Stop

write-host "Application-Insights.ps1 script completed" -ForegroundColor Blue