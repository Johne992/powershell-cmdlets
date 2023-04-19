# This Powershell CMDLET is intended to be used to quickly update role assignments on objects in Azure. 
# Development: testing if the redundant code here can be reduced. 
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

    # Update the role assignment using the ObjectId
        # Update role assignment for group
        $roleAssignment = Get-AzureADMSRoleAssignment -ObjectId $ObjectId -RoleDefinitionId $RoleDefinitionId -ErrorAction SilentlyContinue
        if ($roleAssignment) {
            $roleAssignment | ForEach-Object {
                Update-AzureADMSRoleAssignment -Id $_.Id -RoleDefinitionId $RoleDefinitionId
            }
        } else {
            New-AzureADMSRoleAssignment -ObjectId $ObjectId -RoleDefinitionId $RoleDefinitionId
        }
