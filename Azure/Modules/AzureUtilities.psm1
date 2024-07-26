<#
.SYNOPSIS
This module provides utility functions for working with Azure resources.

.DESCRIPTION
The Azure Utilities Module contains a collection of functions that simplify common tasks when working with Azure resources. It provides functions for managing virtual machines, storage accounts, networking, and more.

.NOTES
Author: John Lewis
Version: 1.5.3
Created: 01/18/2024
Updated: 07/25/2024
Function Updates:
- Add-AzRBAC: 2.0.2 Updated the function to use -UserprincipalName if DisplayName does not return an object ID.

.LINK
GitHub Repository: https://github.com/your-repo

.EXAMPLE
# Example usage of the module
Import-Module AzureUtilities
Azure-AddRBAC -SubscriptionName $SubscriptionName -ResourceGroupName $ResourceGroupName -ADLSName $ADLSName -Access $Access

#>


<#
.SYNOPSIS
Gets the object ID of a user, group, or service principal in Azure Active Directory.

.DESCRIPTION
The Get-ObjectId function gets the object ID of a user, group, or service principal in Azure Active Directory based on the Name parameter.
This function tries to identify the object type (user, group, service principal) in a sequential manner until it finds a match.

.PARAMETER Name
The name of the user, group, or service principal to get the object ID for.

.EXAMPLE
Get-ObjectId -Name "MyUserOrGroupOrServicePrincipal"

.NOTES
.NOTES
Version:        2.0.2
Author:         John Lewis
Creation Date:  2024-07-25
Purpose/Change: Updated the funciton to use -UserPrincipalName parameter if -DisplayName parameter does not return an object ID for a user.
#>
function Get-ObjectId {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ([string]::IsNullOrEmpty($Name) -or $Name.Length -lt 4) {
        Write-Error "Name parameter cannot be null, empty, or less than 4 characters."
        return
    }

    try {
        Write-Host "Getting object ID for $($Name)"
        # Try to get the object ID as a service principal or managed identity
        $ServicePrincipal = Get-AzADServicePrincipal -DisplayName $Name
        if ($ServicePrincipal -and $ServicePrincipal.Id) {
            Write-Host "$($Name) identified as a serviceprincipal or managed identity"
            return $ServicePrincipal.Id
        }
        else {
            $ServicePrincipal = Get-AzADServicePrincipal -ServicePrincipalName $Name
            if ($ServicePrincipal -and $ServicePrincipal.Id) {
                Write-Host "$($Name) identified as a serviceprincipal or managed identity"
                return $ServicePrincipal.Id
            }
        }

        # Try to get the object ID as a user
        $User = Get-AzADUser -DisplayName $Name
        if ($User -and $User.Id) {
            Write-Host "$($Name) identified as a user"
            return $User.Id
        }
        else {
            $User = Get-AzADUser -UserPrincipalName $Name
            if ($User -and $User.Id) {
                Write-Host "$($Name) identified as a user"
                return $User.Id
            }
        }

        # Try to get the object ID as a group
        $Group = Get-AzADGroup -DisplayName $Name
        if ($Group -and $Group.Id) {
            Write-Host "$($Name) identified as a group"
            return $Group.Id
        }

        Write-Host "$($Name) not identified as a user, group, serviceprincipal, or managed identity" -ForegroundColor Red
    }
    catch {
        Write-Error "Failed to get the object ID for $Name. Error: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
Sets the Azure context for a given subscription.

.DESCRIPTION
The Set-AzureContext function sets the Azure context for the subscription specified by the SubscriptionName parameter.

.PARAMETER SubscriptionName
The name of the subscription to set the Azure context for.

.EXAMPLE
Set-AzureContext -SubscriptionName "MySubscription"
#>
function Set-AzureContext {
    param (
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionName
    )

    if ([string]::IsNullOrEmpty($SubscriptionName)) {
        Write-Error "SubscriptionName parameter cannot be null or empty."
        return $false
    }

    try {
        # Check if a user is connected to an Azure account
        $context = Get-AzContext

        if ($null -eq $context) {
            Write-Host "No Azure account is connected. Please connect to an Azure account using Connect-AzAccount." -ForegroundColor Red
            return $false
        }

        # Set subscription context
        Set-AzContext -SubscriptionName $SubscriptionName

        return $true
    }
    catch {
        Write-Error "Failed to set the Azure context for subscription $SubscriptionName. Error: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
Adds Role-Based Access Control (RBAC) to a resource in Azure.

.DESCRIPTION
The Add-AzRBAC function assigns the specified access to the resource specified by the ResourceName parameter in the resource group specified by the ResourceGroupName parameter in the subscription specified by the SubscriptionName parameter.

.PARAMETER SubscriptionName
The name of the subscription where the resource is located.

.PARAMETER ResourceGroupName
The name of the resource group where the resource is located.

.PARAMETER ResourceName
The name of the resource to assign access to.

.PARAMETER Access
A hashtable where the keys are the names of the users, groups, or service principals to assign the roles to and the values are the names of the roles to assign.

.EXAMPLE
$access = @{
    "user@domain.com" = "Reader"
}
Add-AzRBAC -SubscriptionName "MySubscription" -ResourceGroupName "MyResourceGroup" -ResourceName "MyResource" -Access $access

.NOTES
Version:        3.2
Author:         John Lewis
Creation Date:  2024-05-01
Purpose/Change: Updated the function to assign the first target Id that does not contain '/components/' when target Id is an array.
#>
function Add-AzRBAC {
    param (
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionName,
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory = $false)]
        [string]$ResourceName,
        [Parameter(Mandatory = $true)]
        [hashtable]$Access
    )

    if ([string]::IsNullOrEmpty($SubscriptionName) -or [string]::IsNullOrEmpty($ResourceGroupName)) {
        Write-Error "SubscriptionName, ResourceGroupName, and ResourceName parameters cannot be null or empty."
        return
    }

    if ($Access.Count -eq 0) {
        Write-Warning "No access to assign"
        return
    }

    try {
        Write-Host "Setting Azure context for subscription $SubscriptionName"
        $contextSet = Set-AzureContext -SubscriptionName $SubscriptionName

        if (-not $contextSet) {
            Write-Host "Failed to set Azure context for subscription $SubscriptionName" -ForegroundColor Red
            return
        }

        if ([string]::IsNullOrEmpty($ResourceName)) {
            Write-Host "ResourceName parameter is null or empty. Adding Role Based Access to $ResourceGroupName"
            $resourceGroup = Get-AzResourceGroup -Name $ResourceGroupName
            Write-Host "Assigning access to $ResourceGroupName"
            $target = $resourceGroup
            $targetName = $ResourceGroupName
        }
        else {
            Write-Host "Getting resource $ResourceName in resource group $ResourceGroupName"
            $resource = Get-AzResource -ResourceGroupName $ResourceGroupName -Name $ResourceName
            Write-Host "Assigning access to $ResourceName"
            $target = $resource
            $targetName = $ResourceName
        }

        foreach ($AccessGroup in $Access.GetEnumerator()) {
            $ObjectId = Get-ObjectId -Name $AccessGroup.Name
            $ObjectId

            If ($null -eq $ObjectId) {
                Write-Host "Object ID not found for $($AccessGroup.Name)" -ForegroundColor Red
                continue
            }

            Write-Host "Assigning $($AccessGroup.Value) role to $($AccessGroup.Name) for resource $targetName"
            foreach ($Role in $AccessGroup.Value) {
                # Store the Id in a separate variable
                $targetId = if ($target.Id -is [System.Object[]]) { 
                    $target.Id | Where-Object { $_ -notlike '*/components/*' } | Select-Object -First 1
                }
                else { 
                    $target.Id 
                }

                # Check if the role is already assigned
                $existingRoleAssignment = Get-AzRoleAssignment -ObjectId $ObjectId -RoleDefinitionName $Role -Scope $targetId -ErrorAction SilentlyContinue
    
                if ($null -ne $existingRoleAssignment) {
                    Write-Host "Role $Role is already assigned to $($AccessGroup.Name) for resource $targetName"
                    continue
                }
    
                Write-Host "Assigning role $Role to $($AccessGroup.Name)"
                New-AzRoleAssignment -ObjectId $ObjectId -RoleDefinitionName $Role -Scope $targetId -ErrorAction Stop
            }
        }

        Write-Host "Successfully assigned access to $targetName"
    }
    catch {
        if ([string]::IsNullOrEmpty($ResourceName)) {
            Write-Error "Failed to assign access to $ResourceGroupName. Error: $($_.Exception.Message)"
        }
        else {
            Write-Error "Failed to assign access to $ResourceName. Error: $($_.Exception.Message)"
        }
    }
}

<#
.SYNOPSIS
Removes Role-Based Access Control (RBAC) from a resource in Azure.

.DESCRIPTION
The Remove-AzRBAC function removes the specified access from the resource specified by the ResourceName parameter in the resource group specified by the ResourceGroupName parameter in the subscription specified by the SubscriptionName parameter.

.PARAMETER SubscriptionName
The name of the subscription where the resource is located.

.PARAMETER ResourceGroupName
The name of the resource group where the resource is located.

.PARAMETER ResourceName
The name of the resource to remove access from.

.PARAMETER Access
A hashtable where the keys are the names of the users, groups, or service principals to remove the roles from and the values are the names of the roles to remove.

.EXAMPLE
$access = @{
    "user@domain.com" = "Reader"
}
Remove-AzRBAC -SubscriptionName "MySubscription" -ResourceGroupName "MyResourceGroup" -ResourceName "MyResource" -Access $access
#>
function Remove-AzRBAC {
    param (
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionName,
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]$ResourceName,
        [Parameter(Mandatory = $true)]
        [hashtable]$Access
    )

    if ([string]::IsNullOrEmpty($SubscriptionName) -or [string]::IsNullOrEmpty($ResourceGroupName) -or [string]::IsNullOrEmpty($ResourceName)) {
        Write-Error "SubscriptionName, ResourceGroupName, and ResourceName parameters cannot be null or empty."
        return
    }

    if ($Access.Count -eq 0) {
        Write-Warning "No access to remove"
        return
    }

    try {
        Write-Host "Setting Azure context for subscription $SubscriptionName"
        $contextSet = Set-AzureContext -SubscriptionName $SubscriptionName

        if (-not $contextSet) {
            return
        }

        Write-Host "Getting resource $ResourceName in resource group $ResourceGroupName"
        $resource = Get-AzResource -ResourceGroupName $ResourceGroupName -Name $ResourceName

        Write-Host "Removing Access from $ResourceName"
        foreach ($AccessGroup in $Access.GetEnumerator()) {
            $ObjectId = Get-ObjectId -Name $AccessGroup.Name
            $ObjectId
            
            If ($null -eq $ObjectId) {
                Write-Host "Object ID not found for $($AccessGroup.Name)" -ForegroundColor Red
                continue
            }



            Write-Host "Removing $($AccessGroup.Value) role from $($AccessGroup.Name) for resource $ResourceName"
            foreach ($Role in $AccessGroup.Value) {
                # Check if the role is already assigned
                $existingRoleAssignment = Get-AzRoleAssignment -ObjectId $ObjectId -RoleDefinitionName $Role -Scope $resource.Id -ErrorAction SilentlyContinue
    
                if ($null -eq $existingRoleAssignment) {
                    Write-Host "Role $Role is not assigned to $($AccessGroup.Name) for resource $ResourceName"
                    continue
                }
    
                Write-Host "Removing role $Role from $($AccessGroup.Name)"
                Remove-AzRoleAssignment -ObjectId $ObjectId -RoleDefinitionName $Role -Scope $resource.Id -ErrorAction Stop
            }
        }

        Write-Host "Successfully removed access from $ResourceName"
    }
    catch {
        Write-Error "Failed to remove access from $ResourceName. Error: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
This function checks for a certain role-based access permission.

.DESCRIPTION
This function checks if a specific Azure AD name has the necessary permissions for a given resource.

.PARAMETER AzureADName
The Azure AD name to check permissions for.

.PARAMETER Resource
The scope of the resource to check permissions on.

.EXAMPLE
Check-RolePermission -AzureADName "myAzureADName" -Resource "myResource"
#>
function Get-AzPermissions {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AzureADName,
        [Parameter(Mandatory = $true)]
        [string]$Resource
    )

    try {
        Write-Verbose "Retrieving object ID for Azure AD name: $AzureADName"
        $ObjectId = Get-ObjectId -Name $AzureADName

        Write-Verbose "Checking permissions for object ID: $ObjectId on resource: $Resource"
        $RolePermissions = Get-AzRoleAssignment -ObjectId $ObjectId -Scope $Resource -ErrorAction SilentlyContinue

        return $RolePermissions

    }
    catch {
        Write-Error "An error occurred while checking permissions: $_"
    }
}

<#
.SYNOPSIS
    Assigns a user to an Azure AD application. TESTING TESTING TESTING

.DESCRIPTION
    The Add-AzureADUserAppRoleAssignment function assigns a user to an Azure AD application. 
    The user is identified by their UPN, and the application is identified by its display name. 
    The function also accepts a list of access groups to assign to the user.

.PARAMETER User
    The UPN of the user to be assigned to the application.

.PARAMETER App
    The display name of the Azure AD application to which the user will be assigned.

.PARAMETER Access
    A list of access groups to assign to the user.

.EXAMPLE
    Add-AzureADUserAppRoleAssignment -User "user@domain.com" -App "My Azure App" -Access @("Group1", "Group2")

    This command assigns the user with the UPN user@domain.com to the Azure AD application named "My Azure App" and assigns the access groups "Group1" and "Group2" to the user.

.NOTES
    The function uses the AzureAD and Az modules to interact with Azure AD. 
    Make sure these modules are installed and available before running the function.
#>
function Add-SCIMAssignment {
    param (
        [Parameter(Mandatory = $true)]
        [string]$App,
        [Parameter(Mandatory = $true)]
        [array]$Access
    )

    if ([string]::IsNullOrEmpty($Access) -or [string]::IsNullOrEmpty($App)) {
        Write-Error "App and Access parameters cannot be null or empty."
        return
    }

    if ($Access.Count -eq 0) {
        Write-Warning "No access to assign"
        return
    }

    $servicePrincipal = Get-MgServicePrincipal -Filter "DisplayName eq '$App'"

    try {
        Write-Host "Assigning Access to User with UPN $User"
        foreach ($AccessGroup in $Access.GetEnumerator()) {
            $ObjectId = Get-ObjectId -Name $AccessGroup
            $ObjectId

            if ($null -eq $ObjectId) {
                Write-Host "Object ID not found for $($AccessGroup.Name)" -ForegroundColor Red
                continue
            }

            Write-Host "Assigning $AccessGroup to $App"
            New-MgUserAppRoleAssignment -UserId $ObjectId -ResourceId $servicePrincipal.Id -AppRoleID ([Guid]::Empty) -ErrorAction Stop
        }

        Write-Host "Successfully assigned access to $App"
    }
    catch {
        Write-Error "Failed to assign access to User with ID $UserId. Error: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Removes a user from an Azure AD application. TESTING TESTING TESTING

.DESCRIPTION
    The Remove-AzureADUserAppRoleAssignment function removes a user from an Azure AD application. 
    The user is identified by their UPN, and the application is identified by its display name. 
    The function also accepts a list of access groups from which the user will be removed.

.PARAMETER User
    The UPN of the user to be removed from the application.

.PARAMETER App
    The display name of the Azure AD application from which the user will be removed.

.PARAMETER Access
    A list of access groups from which the user will be removed.

.EXAMPLE
    Remove-AzureADUserAppRoleAssignment -User "user@domain.com" -App "My Azure App" -Access @("Group1", "Group2")

    This command removes the user with the UPN user@domain.com from the Azure AD application named "My Azure App" and removes the access groups "Group1" and "Group2" from the user.

.NOTES
    The function uses the AzureAD and Az modules to interact with Azure AD. 
    Make sure these modules are installed and available before running the function.
#>
function Remove-SCIMAssignment {
    param (
        [Parameter(Mandatory = $true)]
        [string]$App,
        [Parameter(Mandatory = $true)]
        [array]$Access
    )

    if ([string]::IsNullOrEmpty($Access) -or [string]::IsNullOrEmpty($App)) {
        Write-Error "App and Access parameters cannot be null or empty."
        return
    }

    if ($Access.Count -eq 0) {
        Write-Warning "No access to remove"
        return
    }

    $servicePrincipal = Get-MgServicePrincipal -Filter "DisplayName eq '$App'"

    try {
        Write-Host "Removing Access from User with UPN $User"
        foreach ($AccessGroup in $Access.GetEnumerator()) {
            $ObjectId = Get-ObjectId -Name $AccessGroup
            $ObjectId

            if ($null -eq $ObjectId) {
                Write-Host "Object ID not found for $($AccessGroup.Name)" -ForegroundColor Red
                continue
            }

            Write-Host "Removing $AccessGroup from $App"
            Remove-MgUserAppRoleAssignment -ObjectId $ObjectId -ResourceId $servicePrincipal.Id -ErrorAction Stop
        }

        Write-Host "Successfully assigned access to $App"
    }
    catch {
        Write-Error "Failed to remove access from User with UPN $User. Error: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
This function retrieves the scope of an Azure resource based on its name.

.DESCRIPTION
This function retrieves the scope of a specified Azure resource.

.PARAMETER ResourceName
The name of the Azure resource.

.EXAMPLE
Get-ResourceScope -ResourceName "myResource"
#>
function Get-ResourceScope {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ResourceName
    )

    try {
        Write-Verbose "Retrieving scope for Azure resource: $ResourceName"
        $resource = Get-AzResource | Where-Object { $_.Name -eq $ResourceName }

        if ($resource) {
            $scope = "/subscriptions/$($resource.SubscriptionId)/resourceGroups/$($resource.ResourceGroupName)/providers/$($resource.ResourceType)/$ResourceName"
            return $scope
        }
        else {
            Write-Error "Resource with name $ResourceName not found."
        }

    }
    catch {
        Write-Error "An error occurred while retrieving the resource's scope: $_"
    }
}

<#
.SYNOPSIS
This function sets the ACLs for a container. Called by Update-DirectoryACLs.

.DESCRIPTION
This function first checks if the container exists. If the container does not exist, it is created. Then, for each ACL, it checks if the ACL already exists in the current ACLs of the container. If the ACL does not exist, it is added.

.PARAMETER ContainerName
The name of the container.

.PARAMETER ACLs
An array of ACLs to be set for the container.

.PARAMETER Context
The Azure Storage Context.

.EXAMPLE
$ACLs = @(
    @{Id = "_PROD_ITCLINICALADB01"; Role = "rwx"; DefaultRole = "rwx"; Type = "user"; Recursive = $true },
    @{Id = "_PROD_ITCLINICALADB01B"; Role = "r-x"; DefaultRole = "r-x"; Type = "user"; Recursive = $true }
)

$Context = New-AzStorageContext -StorageAccountName "myStorageAccount" -UseConnectedAccount
Add-ContainerACLs -ContainerName "myContainer" -ACLs $ACLs -Context $Context

.NOTES
Version: 1.2.0
Date: 04/09/2024
Updates:
- Version 1.1.0: Updated the function to set the regular ACL first, then update it with the default ACL if it exists. 
   This ensures that the regular ACL is always set, and the default ACL is set if it exists. Also, the function now 
   sets the default scope correctly when setting the default ACL.
- Version 1.2.0: Updated the function to separate the ACLs into recursive and non-recursive categories. The function 
   now updates the ACLs after each loop iteration. This ensures that the ACLs are updated immediately after they are 
   set in each loop iteration.

.LINK
https://learn.microsoft.com/en-us/azure/storage/blobs/data-lake-storage-acl-powershell


.LINK
https://learn.microsoft.com/en-us/azure/storage/blobs/data-lake-storage-acl-powershell
#>
function Add-ContainerACLs {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ContainerName,
        [Parameter(Mandatory = $true)]
        [array]$ACLs,
        [Parameter(Mandatory = $true)]
        $Context
    )
    
    Write-Output "Checking if container exists"
    # Check if the container exists
    $containerExists = Get-AzStorageContainer -Context $Context -Name $ContainerName -ErrorAction SilentlyContinue

    # Create the container if it does not exist
    if (-not $containerExists) {
        Write-Output "Creating Container"
        New-AzDataLakeGen2Item -Context $Context -FileSystem $ContainerName -Directory
    }
    
    Write-Output "Container Exists!"

    foreach ($acl in $ACLs) {
        # If the ID is already in the format of an AAD ID, skip the rest of the loop
        if ($acl.Id -match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
            Write-Host "AAD_ID is already in the correct format: $($acl.Id)"
            continue
        }
        
        # Replace AccessGroups 'AAD_ID' value with Azure AD Group Object ID or Azure AD Application ID
        if (Get-AzADGroup -SearchString $acl.Id) {
            $acl.Id = (Get-AzADGroup -SearchString $acl.Id).Id

            Write-Host "AAD_ID is $($acl.Id)"
        }
        elseif (Get-AzADServicePrincipal -DisplayName $acl.Id) {
            $acl.Id = (Get-AzADApplication -DisplayName $acl.Id).Id

            Write-Host "AAD_ID is $($acl.Id)"
        }
        else {
            Write-Host "AAD_ID not found for $($acl.Id)" -ForegroundColor Red
        }
    }
    # Initialize two empty ACL objects to store recursive and non-recursive ACLs
    $recursiveACL = $null
    $normalACL = $null

    foreach ($acl in $ACLs) {
        # Get the existing ACLs
        $existing = Get-AzDataLakeGen2Item -Context $Context -FileSystem $ContainerName
        $existing.ACL

        # Check if the ACL already exists
        $aclExists = $existing.ACL | Where-Object { $_.EntityId -eq $acl.Id -and $_.AccessControlType -eq $acl.Type -and $_.Permission -eq $acl.Role }

        # Add the ACL if it does not exist
        if (-not $aclExists) {
            # Set the acl
            $currentACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType $acl.Type -EntityId $acl.Id -Permission $acl.Role -InputObject $existing.ACL

            # If defaultrole is not null, set the default acl
            if ($acl.DefaultRole) {
                $currentACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType $acl.Type -EntityId $acl.Id -Permission $acl.DefaultRole -DefaultScope -InputObject $currentACL
            }

            # Add the current ACL to the appropriate variable based on whether it's recursive or not
            if ($acl.Recursive) {
                $newRecursiveACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType $acl.Type -EntityId $acl.Id -Permission $acl.DefaultRole -InputObject $currentACL
                # Update the recursive ACLs if they exist
                if ($newRecursiveACL) {
                    $recursiveACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType $acl.Type -EntityId $acl.Id -Permission $acl.DefaultRole -DefaultScope -InputObject $newRecursiveACL
                }
            }
            else {
                $newNormalACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType $acl.Type -EntityId $acl.Id -Permission $acl.DefaultRole -InputObject $currentACL
                # Update the non-recursive ACLs if they exist
                if ($newNormalACL) {
                    $normalACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType $acl.Type -EntityId $acl.Id -Permission $acl.DefaultRole -InputObject $newNormalACL
                }
            }
        }

        # Update the recursive ACLs if they exist
        if ($recursiveACL) {
            Update-AzDataLakeGen2AclRecursive -Context $Context -FileSystem $ContainerName -Acl $recursiveACL
        }

        # Update the non-recursive ACLs if they exist
        if ($normalACL) {
            Update-AzDataLakeGen2Item -Context $Context -FileSystem $ContainerName -Acl $normalACL
        }
    }
}

<#
.SYNOPSIS
This function sets the ACLs for a directory. Called by Update-DirectoryACLs.

.DESCRIPTION
This function first checks if the directory exists. If the directory does not exist, it is created. Then, for each ACL, it checks if the ACL already exists in the current ACLs of the directory. If the ACL does not exist, it is added.

.PARAMETER ContainerName
The name of the container.

.PARAMETER DirectoryName
The name of the directory.

.PARAMETER ACLs
An array of ACLs to be set for the directory.

.PARAMETER Context
The Azure Storage Context.

.EXAMPLE
$ACLs = @(
    @{Id = "_PROD_ITCLINICALADB01"; Role = "rwx"; DefaultRole = "rwx"; Type = "user"; Recursive = $true },
    @{Id = "_PROD_ITCLINICALADB01B"; Role = "r-x"; DefaultRole = "r-x"; Type = "user"; Recursive = $true }
)

$Context = New-AzStorageContext -StorageAccountName "myStorageAccount" -UseConnectedAccount
Add-DirectoryACLs -ContainerName "myContainer" -DirectoryName "myDirectory" -ACLs $ACLs -Context $Context

.LINK
https://learn.microsoft.com/en-us/azure/storage/blobs/data-lake-storage-acl-powershell
#>
function Add-DirectoryACLs {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ContainerName,
        [Parameter(Mandatory = $true)]
        [string]$DirectoryName,
        [Parameter(Mandatory = $true)]
        [array]$ACLs,
        [Parameter(Mandatory = $true)]
        $Context
    )

    # Check if the directory exists
    $directoryExists = Get-AzDataLakeGen2Item -Context $Context -FileSystem $ContainerName -Path $DirectoryName -ErrorAction SilentlyContinue

    # Create the directory if it does not exist
    if (-not $directoryExists) {
        New-AzDataLakeGen2Item -Context $Context -FileSystem $ContainerName -Path $DirectoryName -Directory
    }

    foreach ($acl in $ACLs) {
        # If the ID is already in the format of an AAD ID, skip the rest of the loop
        if ($acl.Id -match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
            Write-Host "AAD_ID is already in the correct format: $($acl.Id)"
            continue
        }
        
        # Replace AccessGroups 'AAD_ID' value with Azure AD Group Object ID or Azure AD Application ID
        if (Get-AzADGroup -SearchString $acl.Id) {
            $acl.Id = (Get-AzADGroup -SearchString $acl.Id).Id

            Write-Host "AAD_ID is $($acl.Id)"
        }
        elseif (Get-AzADServicePrincipal -DisplayName $acl.Id) {
            $acl.Id = (Get-AzADApplication -DisplayName $acl.Id).Id

            Write-Host "AAD_ID is $($acl.Id)"
        }
        else {
            Write-Host "AAD_ID not found for $($acl.Id)" -ForegroundColor Red
        }
    }

    foreach ($acl in $ACLs) {
        # Get the existing ACLs
        $existing = Get-AzDataLakeGen2Item -Context $Context -FileSystem $ContainerName
        $existing.ACL

        # Check if the ACL already exists
        $aclExists = $existing.ACL | Where-Object { $_.EntityId -eq $acl.Id -and $_.AccessControlType -eq $acl.Type -and $_.Permission -eq $acl.Role }

        # Add the ACL if it does not exist
        if (-not $aclExists) {
            # If defaultrole is not null, set the default acl
            if ($acl.DefaultRole) {
                $currentACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType $acl.Type -EntityId $acl.Id -Permission $acl.DefaultRole -DefaultScope -InputObject $existing.ACL
                #if the directory is recursive, set the acl recursively
                if ($acl.Recursive) {
                    Update-AzDataLakeGen2AclRecursive -Context $Context -FileSystem $ContainerName -Acl $currentACL
                }
                else {
                    Update-AzDataLakeGen2Item -Context $Context -FileSystem $ContainerName -Acl $currentACL
                }

                # Set the acl
                $currentACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType $acl.Type -EntityId $acl.Id -Permission $acl.Role -InputObject $existing.ACL

                if ($acl.Recursive) {
                    Update-AzDataLakeGen2AclRecursive -Context $Context -FileSystem $ContainerName -Acl $currentACL
                }
                else {
                    Update-AzDataLakeGen2Item -Context $Context -FileSystem $ContainerName -Acl $currentACL
                }
            }
        }
    }
}


<#
.SYNOPSIS
This function removes the ACLs for a container.

.DESCRIPTION
This function first checks if the container exists. If the container does not exist, it is created. Then, for each ACL, it checks if the ACL already exists in the current ACLs of the container. If the ACL exists, it is removed.

.PARAMETER ContainerName
The name of the container.

.PARAMETER ACLs
An array of ACLs to be removed from the container.

.PARAMETER Context
The Azure Storage Context.

.EXAMPLE
$ACLs = @(
    @{Id = "_PROD_ITCLINICALADB01"; Role = "---"; DefaultRole = $True; Type = "user"; Recursive = $true },
    @{Id = "_PROD_ITCLINICALADB01B"; Role = "---"; DefaultRole = $False; Type = "user"; Recursive = $true }
)

$Context = New-AzStorageContext -StorageAccountName "myStorageAccount" -UseConnectedAccount
Remove-ContainerACLs -ContainerName "myContainer" -ACLs $ACLs -Context $Context

.NOTES
Version: 1.0.0
Date: 04/11/2024
This is the first version of the function out of beta.

.LINK
https://docs.microsoft.com/en-us/azure/storage/blobs/data-lake-storage-acl-powershell
#>
function Remove-ContainerACLs {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ContainerName,
        [Parameter(Mandatory = $true)]
        [array]$ACLs,
        [Parameter(Mandatory = $true)]
        $Context
    )

    Write-Output "Checking if container exists"
    # Check if the container exists
    $containerExists = Get-AzStorageContainer -Context $Context -Name $ContainerName -ErrorAction SilentlyContinue

    # Create the container if it does not exist
    if (-not $containerExists) {
        Write-Output "Creating Container"
        New-AzDataLakeGen2Item -Context $Context -FileSystem $ContainerName -Directory
    }

    Write-Output "Container Exists!"

    foreach ($acl in $ACLs) {
        # If the ID is already in the format of an AAD ID, skip the rest of the loop
        if ($acl.Id -match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
            Write-Host "AAD_ID is already in the correct format: $($acl.Id)"
            continue
        }

        # Replace AccessGroups 'AAD_ID' value with Azure AD Group Object ID or Azure AD Application ID
        if (Get-AzADGroup -SearchString $acl.Id) {
            $acl.Id = (Get-AzADGroup -SearchString $acl.Id).Id

            Write-Host "AAD_ID is $($acl.Id)"
        }
        elseif (Get-AzADServicePrincipal -DisplayName $acl.Id) {
            $acl.Id = (Get-AzADApplication -DisplayName $acl.Id).Id

            Write-Host "AAD_ID is $($acl.Id)"
        }
        else {
            Write-Host "AAD_ID not found for $($acl.Id)" -ForegroundColor Red
        }
    }

    # Initialize two empty ACL objects to store recursive and non-recursive ACLs
    $recursiveACL = $null

    foreach ($acl in $ACLs) {
        # Get the existing ACLs
        $existing = Get-AzDataLakeGen2Item -Context $Context -FileSystem $ContainerName
        $existing.ACL

        # Check if the ACL already exists
        # $aclExists = $existing.ACL | Where-Object { $_.EntityId -eq $acl.Id -and $_.AccessControlType -eq $acl.Type }
        $aclExists = $True

        # Remove the ACL if it exists
        if ($aclExists) {

            # Set the acl
            $currentACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType $acl.Type -EntityId $acl.Id -Permission $acl.Role 

            # If defaultrole is not null, set the default acl
            if ($acl.DefaultRole) {
                
                $currentACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType $acl.Type -EntityId $acl.Id -Permission $acl.DefaultRole -DefaultScope -InputObject $currentACL
        
            }

            # Add the current ACL to the appropriate variable 
            $newRecursiveACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType $acl.Type -EntityId $acl.Id -Permission $acl.DefaultRole -InputObject $currentACL
                
            # Update the recursive ACLs if they exist
            if ($newRecursiveACL -ne $recursiveACL) {
                $recursiveACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType $acl.Type -EntityId $acl.Id -Permission $acl.DefaultRole -DefaultScope -InputObject $newRecursiveACL
            }

               
        }
    }

    #Remove the ACLs
    Remove-AzDataLakeGen2AclRecursive -Context $Context -FileSystem $ContainerName -Acl $recursiveACL -ContinueOnFailure
}


<#
.SYNOPSIS
This function updates the ACLs for containers and directories. You must have storage blob data owner on the storage account to do use this function.

.DESCRIPTION
This function calls the Add-ContainerACLs and Add-DirectoryACLs functions for each container and directory in the ContainersAndACLs array.

.PARAMETER ContainersAndACLs
An array of containers and directories, each with a name and an array of ACLs.

.PARAMETER SubscriptionName
The name of the Azure subscription.

.PARAMETER StorageAccountName
The name of the Azure Storage Account.

.EXAMPLE
$ContainersAndACLs = @(
    @{
        ContainerName = "bay-itclinical";
        ACLs          = @(
            @{Id = "_PROD_ITCLINICALADB01"; Role = "rwx"; DefaultRole = "rwx"; Type = "user"; Recursive = $true },
            @{Id = "_PROD_ITCLINICALADB01B"; Role = "r-x"; DefaultRole = "r-x"; Type = "user"; Recursive = $true }
        );
        Directories   = @(
            @{
                DirectoryName = "itclinical_structured";
                ACLs          = @(
                    @{Id = "_PROD_ITCLINICALADB01"; Role = "rwx"; DefaultRole = "rwx"; Type = "user"; Recursive = $false },
                    @{Id = "_PROD_ITCLINICALADB01B"; Role = "r-x"; DefaultRole = "r-x"; Type = "user"; Recursive = $false }
                )
            }
        )
    }
)

Update-DataLakeACLs -ContainersAndACLs $ContainersAndACLs

.LINK
https://learn.microsoft.com/en-us/azure/storage/blobs/data-lake-storage-acl-powershell
#>
function Update-DataLakeACLs {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [array]$ContainersAndACLs,
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionName,
        [Parameter(Mandatory = $true)]
        [string]$StorageAccountName
    )

    # Set Context
    Set-AzureContext -SubscriptionName $SubscriptionName 
    $Context = New-AzStorageContext -StorageAccountName $StorageAccountName -UseConnectedAccount

    foreach ($container in $ContainersAndACLs) {
        Add-ContainerACLs -ContainerName $container.ContainerName -ACLs $container.ACLs -Context $Context
        #If directory in container update directory acls
        if ($Container.Directories) {
            foreach ($directory in $container.Directories) {
                Add-DirectoryACLs -ContainerName $container.ContainerName -DirectoryName $directory.DirectoryName -ACLs $directory.ACLS -Context $Context
            }
        }
    }
}


<#
.SYNOPSIS
This function updates the ACLs for all containers and directories.

.DESCRIPTION
This function gets a list of all containers and directories, and then calls the Add-ContainerACLs and Add-DirectoryACLs functions for each of them.

.PARAMETER ACLs
An array of ACLs to be set for all containers and directories. Ensure Recursive = $true on all ACLs to prevent unexpected behavior.

.PARAMETER SubscriptionName
The name of the Azure subscription.

.PARAMETER StorageAccountName
The name of the Azure Storage Account.

.EXAMPLE
$ACLs = @(
    @{Id = "_PROD_ITCLINICALADB01"; Role = "rwx"; DefaultRole = "rwx"; Type = "user"; Recursive = $true },
    @{Id = "_PROD_ITCLINICALADB01B"; Role = "r-x"; DefaultRole = "r-x"; Type = "user"; Recursive = $true }
)

Update-AllDataLakeACLs -ACLs $ACLs

.LINK
https://learn.microsoft.com/en-us/azure/storage/blobs/data-lake-storage-acl-powershell
#>
function Update-AllDataLakeACLs {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [array]$ACLs,
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionName,
        [Parameter(Mandatory = $true)]
        [string]$StorageAccountName
    )

    try {
        # Set Context
        Set-AzureContext -SubscriptionName $SubscriptionName
        $Context = New-AzStorageContext -StorageAccountName $StorageAccountName -UseConnectedAccount

        # Get all containers
        $containers = Get-AzDataLakeGen2FileSystem -Context $Context
        $containers
    }
    catch {
        Write-Output "Error setting context or getting containers: $_"
        return
    }


    # Check if user has Storage Blob Data Owner Role
    $Scope = Get-ResourceScope -ResourceName $StorageAccountName
    $username = Get-AzContext | Select-Object -ExpandProperty Account | Select-Object -ExpandProperty Id
    $Role = Get-AzPermissions -AzureADName $username -Resource $Scope
    if ($role.RoleDefinitionName -ne "Storage Blob Data Owner") {
        Write-Output "User does not have Storage Blob Data Owner Role, adding permission"
        $access = @{
            $username = "Storage Blob Data Owner"
        }
        Add-AzRBAC -SubscriptionName $SubscriptionName -ResourceGroupName $ResourceGroupName -ResourceName $StorageAccountName -Access $access
    }

    # Check if ACLs have Recursive set to true
    foreach ($ACL in $ACLs) {
        if ( $ACL.Recursive -ne $true ) {
            Write-Output "ACL does not have Recursive set to true: $($ACL.Id), exiting function"
            return
        }
    }

    Write-Output "ACL(s) have recurive set to true, passing to Add-ContainerACLs"

    # Apply on each container, directories not needed as acls have recursive true
    foreach ($container in $containers) {
        # Update ACLs for the container
        Add-ContainerACLs -ContainerName $container.Name -ACLs $ACLs -Context $Context
    }
}

<#
.SYNOPSIS
This function updates the secret for a given service principal, writes it to a file, and stores it in Key Vault.

.DESCRIPTION
This function retrieves a service principal by its display name, generates a new secret for it, writes the secret to a file in the same directory as the script, and stores the secret in a specified Key Vault. Secret Expires 2 years after creation.

.PARAMETER ServicePrincipalName
The display name of the Azure AD service principal.

.PARAMETER KeyvaultName
The name of the Azure Key Vault where the secret will be stored.

.PARAMETER SecretName
The name of the secret in Key Vault.

.EXAMPLE
Update-ServicePrincipalSecret -ServicePrincipalName "MyServicePrincipal" -KeyvaultName "MyKeyVault" -SecretName "MySecret"

#>
function Update-ServicePrincipalSecret {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ServicePrincipalName,
        [Parameter(Mandatory = $true)]
        [string]$KeyvaultName,
        [Parameter(Mandatory = $true)]
        [string]$SecretName
    )

    try {
        $servicePrincipal = Get-AzADServicePrincipal -DisplayName $ServicePrincipalName
        $servicePrincipal

        if ($servicePrincipal) {
            $endDate = (Get-Date).AddYears(2)
            Remove-AzADAppCredential -ApplicationId $servicePrincipal.AppId 
            $servicePrincipalSecret = New-AzADAppCredential -ApplicationId $servicePrincipal.AppId -EndDate $endDate -ErrorAction Stop
            $servicePrincipalSecret

            # Write the secret to a file
            #$servicePrincipalSecret.SecretText | Out-File -FilePath "$PSScriptRoot\$ServicePrincipalName-secret.txt"

            # Store the secret in Key Vault
            $secret = ConvertTo-SecureString -String $servicePrincipalSecret.SecretText -AsPlainText -Force
            Set-AzKeyVaultSecret -VaultName $KeyvaultName -Name $SecretName -SecretValue $secret -ContentType $ServicePrincipalName -Expires $endDate.AddDays(-10)
        }
        else {
            Write-Error "Service Principal with name $ServicePrincipalName not found."
        }
    }
    catch {
        Write-Error "An error occurred while updating the service principal's secrets: $_"
    }
}