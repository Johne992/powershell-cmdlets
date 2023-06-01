#Create and configure Blob Container directories. Please create the container first if it doesn't exist

#Set Variables - UPDATE FOR EACH ENVIRONMENT
$SubscriptionName = "subscription name"
$ResourceGroupName = "resource group name"
$ADLSName = "adls name"
$ContainerName = "container name"
$FolderNames = @("folder/")
$AccessGroups = @(
    @{AAD_ID ="object name"; Permissions = "rwx"; AccessControlType ="Group"}
);

#replace AccessGroups 'AAD_ID' value with Azure AD Group Object ID
write-host "Replacing AccessGroups 'AAD_ID' value with Azure AD Group Object ID" -ForegroundColor Green
foreach ($group in $AccessGroups) {
    if(Get-AzADGroup -SearchString $group.AAD_ID){
        $group.AAD_ID = (Get-AzADGroup -SearchString $group.AAD_ID).Id
    } elseif (Get-AzADApplication -DisplayName $group.AAD_ID){
        $group.AAD_ID = (Get-AzADApplication -DisplayName $group.AAD_ID).Id
    } else {
        write-host "AAD_ID not found for $group.AAD_ID" -ForegroundColor Red
    }
}
$AccessGroups


#Set subscription context
Set-AzContext -SubscriptionName $SubscriptionName

#Get Storage Account Context
$context = (Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $ADLSName).Context

#Iterate over the array and build an ACL Object
write-host "Iterate over the array and build an ACL Object" -ForegroundColor Green
foreach ($groups in $AccessGroups) {
    foreach ($folderName in $FolderNames){
        #Get the existing acls
        $acl = (Get-AzDataLakeGen2Item -Context $context -FileSystem $ContainerName -Path $folderName).ACL 
        #Please note that default ACLs and the actual entity ACLs are two separate things and must be set seprately as shown below
        $acl = Set-AzDataLakeGen2ItemAclObject -AccessControlType $group.AccessControlType -EntityId $group.AAD_ID -Permission $group.Permissions -InputObject $acl  -ErrorAction Stop
       #Update-AzDataLakeGen2Item -Context $context -FileSystem $ContainerName -Path $folderName -Acl $acl -ErrorAction Stop
        $acl = Set-AzDataLakeGen2ItemAclObject -AccessControlType $group.AccessControlType -EntityId $group.AAD_ID -Permission $group.Permissions -DefaultScope -InputObject $acl  -ErrorAction Stop
        Update-AzDataLakeGen2Item -Context $context -FileSystem $ContainerName -Path $folderName -Acl $acl -ErrorAction Stop
    }
}
$acl
#Update-AzDataLakeGen2Item -Context $context -FileSystem $ContainerName -Path $folderName -Acl $acl -ErrorAction Stop