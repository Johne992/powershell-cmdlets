<#
    Created for: Utility
    Created by:  John Lewis
    Created on:  2023-09-13
    Version:     1.0.0
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
            -Scope $ResourceId `
            -ErrorAction Stop
    }
}
