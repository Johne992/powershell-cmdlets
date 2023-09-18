<#
--It is vital you read this before running this script as you can destroy your ACLs if you are not careful.--
When you update an ACL, you modify the ACL instead of replacing the ACL. For example, you can add a new security principal
to the ACL without affecting other security principals listed in the ACL. To replace the ACL instead of update it, you must 
Set ACLs on the storage item. If you want to update a default ACL entry, use the -DefaultScope parameter when you run the 
Set-AzDataLakeGen2ItemAclObject command.

Service Principals count as users for ACL purposes.

v0.1 - 2023-08-18 - Initial working script there is an issue reading some of the azure ad groups and service principals some still has to be applied manually. 
v0.2 - 2023-08-30 - Parameterized Script for Flexibility
#>

param(
    [Parameter()]
    [string] $SubscriptionName,

    [Parameter()]
    [string] $ResourceGroupName,

    [Parameter()]
    [string] $ADLSName,

    [Parameter()]
    [string] $AzADPrefix,

    [Parameter()]
    [string] $AzADBase,

    [Parameter()]
    [string] $AzSPNPrefix,

    [Parameter()]
    [string] $AzSPNBase,

    [Parameter()]
    [string] $AzResourcePrefix,

    [Parameter()]
    [string] $AzResourceBase
)

$containersAndACLs = @(
    @{
        ContainerName = "${AzResourceBase}_container";
        IsNew         = $true; #If this is a new container, set this to true
        ACLs          = @(
            @{Id = "${AzSPNPrefix}${AzSPNBase}"; Role = "rwx"; DefaultRole = "rwx"; Type = "user"; Recursive = $true },
            @{Id = "${AzADPrefix} ${AzADBase} "; Role = "r-x"; DefaultRole = ""; Type = "group"; Recursive = $false }
        );
        Directories   = @( #Specify directories and their ACLs
            @{
                DirectoryName = "${AzResourceBase}_directory";
                ACLS          = @(
                    @{Id = "${AzSPNPrefix}${AzSPNBase}"; Role = "rwx"; DefaultRole = "rwx"; Type = "user"; Recursive = $true },
                    @{Id = "${AzADPrefix} ${AzADBase} "; Role = "r-x"; DefaultRole = ""; Type = "group"; Recursive = $false }
                )
            }
            @{
                DirectoryName = "${AzResourceBase}_curated";
                ACLs          = @(
                    @{Id = "${AzSPNPrefix}${AzSPNBase}"; Role = "rwx"; DefaultRole = "rwx"; Type = "user"; Recursive = $true },
                    @{Id = "${AzADPrefix} ${AzADBase} "; Role = "r-x"; DefaultRole = ""; Type = "group"; Recursive = $false }
                )
            }
        )
    }
    @{
        ContainerName = "container1";
        IsNew         = $false; #If this is a new container, set this to true
        ACLs          = @(
            @{Id = "${AzSPNPrefix}${AzSPNBase}"; Role = "rwx"; DefaultRole = "rwx"; Type = "user"; Recursive = $true },
            @{Id = "${AzADPrefix} ${AzADBase} "; Role = "r-x"; DefaultRole = ""; Type = "group"; Recursive = $false }
        );
        Directories   = @(
            @{
                DirectoryName = "${AzResourceBase}";
                ACLs          = @(
                    @{Id = "${AzSPNPrefix}${AzSPNBase}"; Role = "rwx"; DefaultRole = "rwx"; Type = "user"; Recursive = $true },
                    @{Id = "${AzADPrefix} ${AzADBase} "; Role = "r-x"; DefaultRole = ""; Type = "group"; Recursive = $false }
                )
            }
        )
    }
)

#Set subscription context
Set-AzContext -SubscriptionName $SubscriptionName
$ctx = New-AzStorageContext -StorageAccountName $ADLSName -UseConnectedAccount

#replace AccessGroups 'AAD_ID' value with Azure AD Group Object ID
write-host "Replacing AccessGroups 'AAD_ID' value with Azure AD Group Object ID" -ForegroundColor Green


#foreach container in containers and acls create the container, set the acls if acls have default also set default acls, create the directories and set the acls or update the acls if acls have default also set default acls and create the directories and set the acls
foreach ($container in $containersAndACLs) {
    $ContainerName = $container.ContainerName
    $ContainerACL = $container.ACLs
    $ContainerDirectories = $container.Directories
    $ContainerIsNew = $container.IsNew

    #Create the container if it does not exist
    if ($ContainerIsNew) {
        New-AzStorageContainer -Context $ctx -Name $ContainerName
    }

    #replace AccessGroups 'AAD_ID' value with Azure AD Group Object ID
    write-host "Replacing Azure AD Entity 'AAD_ID' value with Azure AD Group Object ID" -ForegroundColor Green
    foreach ($entry in $ContainerACL) {
        if (Get-AzADGroup -SearchString $entry.Id) {
            $entry.Id = (Get-AzADGroup -SearchString $entry.Id).Id
        }
        elseif (Get-AzADServicePrincipal -DisplayName $entry.Id) {
            $entry.Id = (Get-AzADApplication -DisplayName $entry.Id).Id
        }
        else {
            write-host "AAD_ID not found for $($entry.Id)" -ForegroundColor Red
        }
    }

    #Set the container ACLs
    $currentACL = (Get-AzDataLakeGen2Item -Context $ctx -FileSystem $ContainerName).ACL
    foreach ($entry in $ContainerACL) {
        #if defaultrole is not null, set the default acl
        if ($entry.DefaultRole) {
            $currentACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType $entry.Type -EntityId $entry.Id -Permission $entry.DefaultRole -DefaultScope -InputObject $currentACL
            #if the directory is recursive, set the acl recursively
            if ($entry.Recursive) {
                Update-AzDataLakeGen2AclRecursive -Context $ctx -FileSystem $ContainerName -Acl $currentACL
            }
            else {
                Update-AzDataLakeGen2Item -Context $ctx -FileSystem $ContainerName -Acl $currentACL
            }
        }
        #set the acl    
        $currentACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType $entry.Type -EntityId $entry.Id -Permission $entry.Role -InputObject $currentACL
        #if the directory is recursive, set the acl recursively
        if ($entry.Recursive) {
            Update-AzDataLakeGen2AclRecursive -Context $ctx -FileSystem $ContainerName -Acl $currentACL
        }
        else {
            Update-AzDataLakeGen2Item -Context $ctx -FileSystem $ContainerName -Acl $currentACL
        }
    }
    #Update-AzDataLakeGen2Item -Context $ctx -FileSystem $ContainerName -Acl $currentACL

    #If there are no directories, skip the directory creation
    if ($ContainerDirectories) {

        #Create the directories and set the ACLs
        foreach ($directory in $ContainerDirectories) {
            $NewDirectory = $directory.DirectoryName
            $NewDirectoryACL = $directory.ACLs

            #Create the directory if it does not exist
            New-AzDataLakeGen2Item -Context $ctx -FileSystem $ContainerName -Path $NewDirectory -Directory

            #replace AccessGroups 'AAD_ID' value with Azure AD Group Object ID
            write-host "Replacing Azure AD Entity 'AAD_ID' value with Azure AD Group Object ID" -ForegroundColor Green
            foreach ($entry in $NewDirectoryACL) {
                #if entry.Id length is greater thhan 35 skip it
                if ($entry.Id.Length -gt 35) {
                    continue
                }
                if ($entry.Type -eq "group") {
                    $entry.Id = (Get-AzADGroup -SearchString $entry.Id).Id
                }
                elseif ($entry.Type -eq "user") {
                    $entry.Id = (Get-AzADServicePrincipal -DisplayName $entry.Id).Id
                }
                else {
                    write-host "AAD_ID not found for $($entry.Id)" -ForegroundColor Red
                }
            }

            #Set the directory ACLs
            $currentACL = (Get-AzDataLakeGen2Item -Context $ctx -FileSystem $ContainerName -Path $NewDirectory).ACL
            foreach ($entry in $NewDirectoryACL) {
                #display current entry
                $entry
                #if defaultrole is not null, set the default acl
                if ($entry.DefaultRole) {
                    $currentACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType $entry.Type -EntityId $entry.Id -Permission $entry.DefaultRole -DefaultScope -InputObject $currentACL
                    #if the directory is recursive, set the acl recursively
                    if ($entry.Recursive) {
                        Update-AzDataLakeGen2AclRecursive -Context $ctx -FileSystem $ContainerName -Path $NewDirectory -Acl $currentACL
                    }
                    else {
                        Update-AzDataLakeGen2Item -Context $ctx -FileSystem $ContainerName -Path $NewDirectory -Acl $currentACL
                    }
                }
                #set the acl    
                $currentACL = Set-AzDataLakeGen2ItemAclObject -AccessControlType $entry.Type -EntityId $entry.Id -Permission $entry.Role -InputObject $currentACL
                #if the directory is recursive, set the acl recursively
                if ($entry.Recursive) {
                    Update-AzDataLakeGen2AclRecursive -Context $ctx -FileSystem $ContainerName -Path $NewDirectory -Acl $currentACL 
                }
                else {
                    Update-AzDataLakeGen2Item -Context $ctx -FileSystem $ContainerName -Path $NewDirectory -Acl $currentACL 
                }
            }
        
        }
    }
}
