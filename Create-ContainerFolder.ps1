#Create and configure Blob Containers

#Set Variables - UPDATE FOR EACH ENVIRONMENT
$SubscriptionName = "BCBSLA Dev Data and Analytics"
$ResourceGroupName = "devuscedbxpilotrg"
$ADLSName = "devuscedbxpilotadls01"
$ContainerName = "devuscedbxpilotadls01"
$folderName = "folder1" #can add 
$AccessGroups = @(
    @{AAD_ID ="group"; Permissions = "rwx"},
    @{AAD_ID =""; Permissions = "rw-"},
    @{AAD_ID =""; Permissions = "r--"}
);

#replace AccessGroups 'AAD_ID' value with Azure AD Group Object ID
write-host "Replacing AccessGroups 'AAD_ID' value with Azure AD Group Object ID" -ForegroundColor Green
foreach ($group in $AccessGroups) {
    $group.AAD_ID = (Get-AzADGroup -SearchString $group.AAD_ID).Id
}


#Set subscription context
Set-AzContext -SubscriptionName $SubscriptionName

#Get Storage Account Context
$context = (Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $ADLSName).Context

#Create blob container folder if it doesn't exist
write-host "Creating $ContainerName\$folderName Blob Container Folder!" -ForegroundColor Green
if (Get-AzStorageContainer -Name "$ContainerName\$folderName" -Context $context -ErrorAction SilentlyContinue) {
    write-host "$ContainerName\$folderName Blob Container Folder already exists!" -ForegroundColor Yellow
} else {
    New-AzStorageContainer -Name "$ContainerName\$folderName" -Context $context -Permission Off -ErrorAction Stop
}


#Iterate over the array and set the ACL for each folder
foreach ($group in $AccessGroups) {
    write-host "Setting ACL for $($group.AAD_ID) to $($group.Permissions)" -ForegroundColor Green
    Set-AzStorageContainerAcl -Name "$ContainerName\$folderName" -Context $context -Group $group.AAD_ID -Permission $group.Permissions -ErrorAction Stop
}
