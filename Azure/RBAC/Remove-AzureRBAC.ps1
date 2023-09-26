<#
    Created for: CATTSK0795592
    Created by:  John Lewis
    Created on:  2023-09-26
    Version:     1.0.0
    Purpose:     Remove Azure Role Based Access Control to a resource
    Param:       $Resources - A list of resources to remove access from
                 $Access - The role to be removed and the identity 
#>

. C:\Users\e51473a\Documents\code\WorkRepos\Infrastructure-Azure-Test\Security\Add-AzureRBAC.ps1

param(
    [Parameter(Mandatory = $true)]
    [list] $Resources,

    [Parameter(Mandatory = $true)]
    [hashtable] $Access

)

# Check for required modules
if (-not (Get-Module -ListAvailable Az.Resources)) {
    Write-Error "Az.Resources module not installed. Please install the module and try again."
    exit 1
}

function Get-ResourceId {
    param (
        [Parameter(Mandatory = $true)]
        [string] $Name
    )
    #Get Resource Id by name
    (Get-AzResource -Name $Name).ResourceId
}

try {
#Add Access
write-host "Removing Access from $Resources" -ForegroundColor Green
#check if list empty
if ($Resources.Count -eq 0) {
    Write-Warning "No access to remove"
    exit 0
}

#foreach group in access hashtable
foreach ($AccessGroup in $Access.GetEnumerator()) {
    #Get the object ID of the group
    $objectId = Get-ObjectId -Name $AccessGroup.Name
    $Access
    
    #Loop through each role in AccessGroup.Value and assign to the group
    foreach ($Resource in $Resources.GetEnumerator()) {
        $resourceId = Get-ResourceId -Name $Resource
        $Role
        Remove-AzRoleAssignment `
            -ObjectId $objectId `
            -scope $resourceId `
            -RoleDefinitionName $Role `
            -Force
    }
}
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
```