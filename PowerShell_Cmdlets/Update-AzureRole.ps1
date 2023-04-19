# Call the Set-AzureADRoleAssignment cmdlet with required parameters
# Set-AzureADRoleAssignment -ObjectId "<Azure AD Object ID>" -RoleDefinitionName "<Role Definition Name>" -ResourceGroupName "<Resource Group Name>" -ResourceType "<Resource Type>"

function Set-AzureADRoleAssignment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ObjectId,
        [Parameter(Mandatory = $true)]
        [string]$RoleDefinitionName,
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]$ResourceType
    )
    process {
        $scope = $null
        $subscriptionId = (Get-AzContext).Subscription.Id
        switch ($ResourceType) {
            "Resource" {
                $scope = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Resources/resourceGroups/$ResourceGroupName"
                break
            }
            "ResourceGroup" {
                $scope = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName"
                break
            }
            "Subscription" {
                $scope = "/subscriptions/$subscriptionId"
                break
            }
            default {
                Write-Error "Invalid ResourceType parameter value. Allowed values are 'Resource', 'ResourceGroup', or 'Subscription'."
                return
            }
        }
  
        $roleDefinition = Get-AzRoleDefinition -Name $RoleDefinitionName
        if ($roleDefinition -eq $null) {
            Write-Error "Role definition '$RoleDefinitionName' not found."
            return
        }
  
        $roleAssignment = New-AzRoleAssignment -ObjectId $ObjectId -RoleDefinitionName $roleDefinition.Name -Scope $scope
        if ($roleAssignment -eq $null) {
            Write-Error "Failed to create role assignment for Azure AD Object ID '$ObjectId' and Role Definition Name '$RoleDefinitionName'."
        } else {
            Write-Output "Role assignment created successfully for Azure AD Object ID '$ObjectId' and Role Definition Name '$RoleDefinitionName'."
        }
    }
  }