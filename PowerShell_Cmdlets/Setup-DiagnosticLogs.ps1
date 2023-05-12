#Login to Azure Account
Connect-AzAccount

$resourceGroupName = "myresourcegroup"
$logAnalyticsWorkspaceName = "myLogAnalyticsWorkspace"
$resourceNames = @(

)

$logAnalyticsWorkspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $resourceGroupName -Name $logAnalyticsWorkspaceName

#Loop through each resource name and create a diagnostic setting
foreach ($resourceName in $resourceNames){
    $resource = Get-AzResource -Name $resourceName -ErrorAction SilentlyContinue
    if ($resource){
        $resourceId = $resource.ResourceId
        $diagnosticSettings = Get-AzDiagnosticSetting -ResourceId $resourceId -ErrorAction SilentlyContinue
        if(!$diagnosticSettings){
            $diagnosticSettings = New-AzDiagnosticSetting -Name "All Logs and Metrics" -ResourceId $resourceId -WorkspaceId $logAnalyticsWorkspace.ResourceId 
        }
        Set-AzDiagnosticSetting -ResourceId $resourceId  -WorkspaceId $logAnalyticsWorkspace.ResourceId -EnableLog $true -EnableMetrics $true
    }
}