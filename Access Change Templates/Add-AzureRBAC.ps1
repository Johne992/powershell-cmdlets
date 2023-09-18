<#
    Created for: Utility
    Created by:  John Lewis
    Created on:  2023-09-13
    Version:     1.1.0
    Purpose:     Add Azure Role Based Access Control to a resource
    Param:       $ResourceId - The resource ID of the resource to add access to
                 $Access - A hashtable of groups and roles to assign to the resource 
                 Example: @{ "DEVOPS" = "Contributor"; "DEVOPS-Read" = "Reader" }   
#>

param(
    [Parameter(Mandatory = $true)]
    [string] $ResourceId,

    [Parameter(Mandatory = $true)]
    [hashtable] $Access

)

# Check for required modules
if (-not (Get-Module -ListAvailable Az.Resources)) {
    Write-Error "Az.Resources module not installed. Please install the module and try again."
    exit 1
}

function Get-ObjectId {
    param (
        [Parameter(Mandatory = $true)]
        [string] $Name
    )
    #Check if group or azure ad object
    if ($Name -like "*DEVOPS*") {
        #Get the object ID of the azure ad object
        $Name = (Get-AzADServicePrincipal -SearchString $Name).Id
    }
    else {
        #Get the object ID of the group
        $Name = (Get-AzADGroup -SearchString $Name).Id
    }
}

try {
#Add Access
write-host "Assigning Access to $(Get-AzResoruce -ResourceId $ResourceId).Name" -ForegroundColor Green
foreach ($AccessGroup in $Access.GetEnumerator()) {
    #Get the object ID of the group
    $objectId = Get-ObjectId -Name $AccessGroup.Name
    $Access
    #Loop through each role in AccessGroup.Value and assign to the group

    foreach ($Role in $AccessGroup.Value) {
        $Role
        New-AzRoleAssignment `
            -ObjectId $objectId `
            -RoleDefinitionName $Role `
            -Scope $ResourceId `
            -ErrorAction Stop
    }
}
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
```