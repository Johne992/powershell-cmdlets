#This root script will eventually make the calls to run the modules and build the environment

#Set Variables - UPDATE FOR EACH ENVIRONMENT
$SubscriptionName = ""
$Location = ""
$CostCenter = ""
$CurrentDate = get-date -Format "yyyy.MM.dd"
$ResourceGroupName = ""
$LocTag = ""
$EnvTag = ""
$AppTag = ""
$SNOWTag = ""
$Access = @{
    "" = @("");
}

#Start Logging
# Start-Transcript -Path "C:\Temp\Deploy-$ResourceGroup-$(get-date -Format "yyyy-MM-dd")" -Append

#Set subscription context
Set-AzContext -SubscriptionName $SubscriptionName
$CurrentUser = Get-AzContext | Select-Object -ExpandProperty Account

#Create Resource Group
$ResourceGroup = New-AzResourceGroup `
    -Name $ResourceGroupName `
    -Location $Location `
    -Tag @{
    CreatedDate    = $CurrentDate;
    CreatedBy      = $CurrentUser;
    CostCenter     = $CostCenter;
    NS_Location    = $LocTag;
    NS_Environment = $EnvTag;
    NS_Application = $AppTag;
    SNOWTag        = $SNOWTag
}

#Add Access to Data Factory
write-host "Assigning Access to $ResourceGroup" -ForegroundColor Green
foreach ($AccessGroup in $Access.GetEnumerator()) {
    #Check if group or azure ad object
    if ($AccessGroup.Name -like "*DEVOPS*") {
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
            -Scope $ResourceGroup.Id `
            -ErrorAction Stop
    }
}

Write-Host "$ResourceGroup Deployed" -ForegroundColor Green
$ResourceGroup

#End Logging
# Stop-Transcript