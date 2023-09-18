#Create Data Factory, Set Diagnostics and create Self-Hosted IR within new Data Factory 
#Manually link self-hosted IR after running script
# v1.0.0 - 2023.05.03 - Created by: John Lewis
# v2.0.0 - 2023.08.16 - Updated diagnostic settings, access control and added tags - Created by: John Lewis 

#Set Variables - UPDATE FOR EACH ENVIRONMENT
$Subscription = "sub"
$Location = "centralus"
$CostCenter = "xxxx"
$CurrentDate = get-date -Format "yyyy.MM.dd:HH.mm.ss"
$ResourceGroupName = "rg"
$DataFactoryName = "adb01"
#$DataFactoryIRName = "Self-Hosted-IR"
$LocTag = "USCE - Central US"
$EnvTag = "PROD - Production"
$AppTag = "APP - Application"
$SNOWTag = "REQXXXX"
$LogAnalyticsWs = "resourceID"

#Set subscription context
write-host "Set context to subscription where new Data Factory will be created" -ForegroundColor Green
Set-AzContext -SubscriptionName $Subscription
$CurrentUser = Get-AzContext | Select-Object -ExpandProperty Account

#Create Data Factory
write-host "Creating new Data Factory" -ForegroundColor Green
$NewDataFactory = Set-AzDataFactoryV2 `
    -ResourceGroupName $ResourceGroupName `
    -Location $Location `
    -Name $DataFactoryName `
    -Tag @{
    CreatedBy      = $CurrentUser.Id;
    CreatedDate    = $CurrentDate;
    CostCenter     = $CostCenter;
    NS_Location    = $LocTag;
    NS_Environment = $EnvTag;
    NS_Application = $AppTag
    SNOWRequest    = $SNOWTag
} `
    -ErrorAction Stop
write-host "Sleep for 10 seconds..." -ForegroundColor Green
Start-Sleep -s 10

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
            -Scope $NewDataFactory.DataFactoryId `
            -ErrorAction Stop
    }
}

write-host "$DataFactoryName-1.ps1 script completed!" -ForegroundColor Blue

#Open the page of the resource in the portal
Start-Process "https://portal.azure.com/#resource/$($NewDataFactory.ResourceId)"


