#Create and configure Blob Container directories. Please create the container first if it doesn't exist

#Set Variables - UPDATE FOR EACH ENVIRONMENT
$SubscriptionName = "Subscription Name"
$ResourceGroupName = "Resource Group Name"
$ADLSName = "storage account name"
$ContainerName = "container name"
$folderName = "directory name" #can add \ to create subfolders
$AccessGroups = @(
    @{AAD_ID ="AzDev.DnA Storage Inbound ncct Reader"; Permissions = "r-x"},
    @{AAD_ID ="AzDev.DnA Storage Inbound ncct Writer"; Permissions = "rwx"}
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

#if azdatalakegen2item doesn't exist, create it
if (!(Get-AzDataLakeGen2Item -Context $context -FileSystem $ContainerName -Path $folderName -ErrorAction SilentlyContinue)) {
    write-host "Creating $folderName in $ContainerName" -ForegroundColor Green
    New-AzDataLakeGen2Item -Context $context -FileSystem $ContainerName -Path $folderName -Directory -ErrorAction Stop
}

#Iterate over the array and build an ACL Object
write-host "Iterate over the array and build an ACL Object" -ForegroundColor Green
foreach ($group in $AccessGroups) {
    #Please note that default ACLs and the actual entity ACLs are two separate things and must be set seprately as shown below
    $acl = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $group.AAD_ID -Permission $group.Permissions -DefaultScope  -ErrorAction Stop
    Update-AzDataLakeGen2Item -Context $context -FileSystem $ContainerName -Path $folderName -Acl $acl -ErrorAction Stop
    $acl = Set-AzDataLakeGen2ItemAclObject -AccessControlType group -EntityId $group.AAD_ID -Permission $group.Permissions -ErrorAction Stop
    Update-AzDataLakeGen2Item -Context $context -FileSystem $ContainerName -Path $folderName -Acl $acl -ErrorAction Stop
}
#Update-AzDataLakeGen2Item -Context $context -FileSystem $ContainerName -Path $folderName -Acl $acl -ErrorAction Stop