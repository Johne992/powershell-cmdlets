$SubscriptionName = "BCBSLA Prod Data and Analytics"
$ResourceGroupName = "prduscedexanalyticsrg"
$ADLSName = "prduscedexadls01" #Enter the name of the adls you want to use
$Access = @{
    "AzProd.DnA Big Data Admin"                      = @("Storage Blob Data Reader", "Storage Account Contributor","Reader");
    "AzProd.DnA IT Clinical Bay Admin"               = @("Reader");
    "AzProd.DnA IT Clinical Bay Support"             = @("Reader");
    "AzProd.DnA IT Clinical Bay Devs"                = @("Reader");
    "AzProd.DnA IT Clinical Storage Structured Read" = @("Reader");
    "AzProd.DnA IT Clinical Bay QA"                  = @("Reader");
    "AzProd.DnA IT Clinical Bay Analyst"             = @("Reader");
    "_PROD_DEXDEVOPS"                                = @("Contributor");
}

Start-Transcript -Path .\DataLakeContainers-$(get-date -Format "yyyy-MM-dd").txt

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

Stop-Transcript