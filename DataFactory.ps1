#Create Data Factory, Set Diagnostics and create Self-Hosted IR within new Data Factory 
#Manually link self-hosted IR after running script

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
$LogAnalyticsWs = "resourceID"

#Set subscription context
write-host "Set context to subscription where new Data Factory will be created" -ForegroundColor Green
Set-AzContext -SubscriptionName $Subscription
$CurrentUser = Get-AzContext | Select-Object -ExpandProperty Account

#Create Data Factory
write-host "Creating new Data Factory" -ForegroundColor Green
$NewDataFactory = Set-AzDataFactoryV2 -ResourceGroupName $ResourceGroupName -Location $Location -Name $DataFactoryName -Tag @{CreatedBy=$CurrentUser.Id;CreatedDate=$CurrentDate;CostCenter=$CostCenter;NS_Location=$LocTag;NS_Environment=$EnvTag;NS_Application=$AppTag} -ErrorAction Stop

write-host "Sleep for 10 seconds..." -ForegroundColor Green
Start-Sleep -s 10

#Set Diagnostic Logs
write-host "Configuring diagnostic settings" -ForegroundColor Green
Set-AzDiagnosticSetting -ResourceId $NewDataFactory.DataFactoryId -Enabled $true -Category ActivityRuns,PipelineRuns,TriggerRuns,SandboxPipelineRuns,SandboxActivityRuns -Name "send to log analytics" -WorkspaceId $LogAnalyticsWs -ExportToResourceSpecific -ErrorAction Stop

write-host "1.ps1 script completed!" -ForegroundColor Blue



