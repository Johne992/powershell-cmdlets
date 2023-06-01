# create an azure logic app using powershell with its required app service plan and required storage account in the same resource group and apply tags and log analytics workspace workspace
# 
# This is draft, trying to determine what specific parameters are needed to complete the storage account connection necessary
#
#Set Variables - UPDATE FOR EACH ENVIRONMENT
$Subscription = "Sub 1"
$Location = "centralus"
$CostCenter = "xxxx"
$CurrentDate = get-date -Format "yyyy.MM.dd:HH.mm.ss"
$ResourceGroupName = "resourgegroup"
$LogicAppName = "logicapp"
$AppServicePlanName = "appserviceplan01"
$StorageAccountName = "storageaccountname"
$LocTag = "USCE - Central US"
$EnvTag = "TST - Test"
$AppTag = "APP - Application"
$SNOWTag = "REQ0000001"
$LogAnalyticsWs = "resourceID here"

#Set subscription context
write-host "Set context to subscription where new Logic App will be created" -ForegroundColor Green
Set-AzContext -SubscriptionName $Subscription
$CurrentUser = Get-AzContext | Select-Object -ExpandProperty Account

#Create App Service Plan
write-host "Creating new App Service Plan" -ForegroundColor Green
New-AzAppServicePlan -ResourceGroupName $ResourceGroupName -Name $AppServicePlanName -Location $Location -Tier "Standard" -Tag @{CreatedBy=$CurrentUser.Id;CreatedDate=$CurrentDate;CostCenter=$CostCenter;NS_Location=$LocTag;NS_Environment=$EnvTag;NS_Application=$AppTag;SNOWRequest=$SNOWTag}

#Create Storage Account
write-host "Creating new Storage Account" -ForegroundColor Green
New-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -Location $Location -SkuName "Standard_LRS" -Kind "StorageV2" -Tag @{CreatedBy=$CurrentUser.Id;CreatedDate=$CurrentDate;CostCenter=$CostCenter;NS_Location=$LocTag;NS_Environment=$EnvTag;NS_Application=$AppTag;SNOWRequest=$SNOWTag}
# get storage account key
$StorageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName).Value[0]

#Create Logic App
write-host "Creating new Logic App" -ForegroundColor Green
New-AzLogicApp -ResourceGroupName $ResourceGroupName -Location $Location -Name $LogicAppName -State "Enabled" -LogAnalyticsWorkspaceResourceId $LogAnalyticsWs -Tag @{CreatedBy=$CurrentUser.Id;CreatedDate=$CurrentDate;CostCenter=$CostCenter;NS_Location=$LocTag;NS_Environment=$EnvTag;NS_Application=$AppTag;SNOWRequest=$SNOWTag}
#Assign storage account key to App Settings
write-host "Assigning storage account key to Logic App App Settings" -ForegroundColor Green
Set-AzLogicApp -ResourceGroupName $ResourceGroupName -Name $LogicAppName -AppServicePlan $AppServicePlanName -State "Enabled" -LogAnalyticsWorkspaceResourceId $LogAnalyticsWs -Tag @{CreatedBy=$CurrentUser.Id;CreatedDate=$CurrentDate;CostCenter=$CostCenter;NS_Location=$LocTag;NS_Environment=$EnvTag;NS_Application=$AppTag;SNOWRequest=$SNOWTag} -AzureStorageAccountKey $StorageAccountKey

