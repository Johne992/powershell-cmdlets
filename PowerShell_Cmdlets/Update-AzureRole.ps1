# This Powershell CMDLET is intended to be used to quickly update role assignments on objects in Azure. 
#Sample call:
#
# PS > Update-AzureRole -Scope 'Resource' -ObjectId '12345678-1234-5678-1234-567890abcdef' -RoleName 'Contributor' -RoleDefinitionId 'b24988ac-6180-41a0-ab88-20f7382dd24c'
#
function Update-AzureRole {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Resource','Subscription','ResourceGroup')]
        [string]$Scope,

        [Parameter(Mandatory = $true)]
        [string]$ObjectId,

        [Parameter(Mandatory = $true)]
        [string]$RoleName,
        
        [Parameter(Mandatory = $true)]
        [string]$RoleDefinitionId
    )

    #Authenticate to Azure AD
    Connect-AzureAD

    # Check if the specificed Object ID is a group, user or serviceprincipal / managed identity
    $isGroup = $false
    $isUser = $false
    $isServicePrincipal = $false

    try {
        $group = Get-AzureADGroup -ObjectId $ObjectId
        $isGroup = $true
    } catch {
        try{
            $user = Get-AzureADUser -ObjectId -ErrorAction Stop
            $isUser = $true
        } catch {
            $ServicePrincipal = Get-AzureADServicePrincipal -ObjectId $ObjectId -ErrorAction Stop
            $isServicePrincipal = $true
        }
    }

    # Update the role assignment based on the object type
    if($isGroup){
        # Update role assignment for group
        $roleAssignment = Get-AzureADMSRoleAssignment -ObjectId $group.ObjectId -RoleDefinitionId $RoleDefinitionId -ErrorAction SilentlyContinue
        if ($roleAssignment) {
            $roleAssignment | ForEach-Object {
                Update-AzureADMSRoleAssignment -Id $_.Id -RoleDefinitionId $RoleDefinitionId
            }
        } else {
            New-AzureADMSRoleAssignment -ObjectId $group.ObjectId -RoleDefinitionId $RoleDefinitionId
        }
    } elseif ($isUser) {
        # Update role assignment for user
        $roleAssignment = Get-AzureADMSRoleAssignment -ObjectId $group.ObjectId -RoleDefinitionId $RoleDefinitionId -ErrorAction SilentlyContinue
        if ($roleAssignment) {
            $roleAssignment | ForEach-Object {
                Update-AzureADMSRoleAssignment -Id $_.Id -RoleDefinitionId $RoleDefinitionId
            }
        } else {
            New-AzureADMSRoleAssignment -ObjectId $user.ObjectId -RoleDefinitionId $RoleDefinitionId
        }
    } else {
        # Upate role assignment for service principal / managed identity
        $roleAssignment = Get-AzureADMSRoleAssignment -ObjectId $group.ObjectId -RoleDefinitionId $RoleDefinitionId -ErrorAction SilentlyContinue
        if ($roleAssignment) {
            $roleAssignment | ForEach-Object {
                Update-AzureADMSRoleAssignment -Id $_.Id -RoleDefinitionId $RoleDefinitionId
            }
        } else {
            New-AzureADMSRoleAssignment -ObjectId $ServicePrincipal.ObjectId -RoleDefinitionId $RoleDefinitionId
        }
    }



}