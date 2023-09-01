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
    [string] $AzSPNPrefix
)

$Access = @{
    "${AzADPrefix} Big Data Admin"                      = @("Storage Blob Data Reader", "Storage Account Contributor", "Reader");
    "${AzADPrefix} ${AzADBase} Bay Admin"               = @("Reader");
    "${AzADPrefix} ${AzADBase} Bay Support"             = @("Reader");
    "${AzADPrefix} ${AzADBase} Bay Devs"                = @("Reader");
    "${AzADPrefix} ${AzADBase} Storage Structured Read" = @("Reader");
    "${AzADPrefix} ${AzADBase} Bay QA"                  = @("Reader");
    "${AzADPrefix} ${AzADBase} Bay Analyst"             = @("Reader");
    "${AzSPNPrefix}DEXDEVOPS"                           = @("Contributor");
}

#Set subscription context
Set-AzContext -SubscriptionName $SubscriptionName

#get the datalake storage account
$ADLS = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $ADLSName

#Add Access to Data Factory
write-host "Assigning Access to $DataFactoryName" -ForegroundColor Green
foreach ($AccessGroup in $Access.GetEnumerator()) {
    #Check if group or azure ad object
    if ($AccessGroup.Name -like "*DEXDEVOPS*") {
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
            -Scope $ADLS.Id `
            -ErrorAction Stop
    }
}