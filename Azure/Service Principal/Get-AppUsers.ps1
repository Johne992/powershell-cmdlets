# Get Users and Groups assigned to Azure Data Lake Environments by pulling from the Unity Catalog SCIM
$filePath = Join-Path $PSScriptRoot "AzureDataLakeAssignments.csv"

Get-MgServicePrincipalAppRoleAssignedTo -ServicePrincipalId '' -all |
    Export-CSV -path $filePath -NoTypeInformation -Force
Import-CSV -Path $filePath
