#Create and configure SQL Server and Database

#Set Variables - UPDATE FOR EACH ENVIRONMENT
$SubscriptionName = "SUBSCRIPTION NAME GOES HERE"
$Location = "centralus"
$CostCenter = "XXXX"
$CurrentDate = get-date -Format "yyyy.MM.dd:HH.mm.ss"
$ResourceGroupName = "rg"
$SQLServerName = "sql"
$DatabaseName = "db"
$SQLAdmin = "dbadmin"
$Password = "pw"
$VNetResourceGroupName = "netrg"
$VNetName = "vnet01"
$AADAdmin = "SQL AD Admin"
$VulnScanStorAcctName = "sa"
$BackupRetention = "14"
$LocTag = "USCE - Central US"
$EnvTag = "TST - Test"
$AppTag = "App - Application"


#Set subscription context
Set-AzContext -SubscriptionName $SubscriptionName
$CurrentUser = Get-AzContext | Select-Object -ExpandProperty Account

#Get asesn01 subnet info
$Subnet = Get-AzVirtualNetwork -ResourceGroupName $VNetResourceGroupName -Name $VNetName | Select-Object -ExpandProperty subnets | Where-Object  {$_.Name -eq "asesn01"}

# Create a SQL Server with a system wide unique server name
write-host "Creating $SQLServerName SQL Server! This may take a few minutes" -ForegroundColor Green
$NewSQLServer = New-AzSqlServer -ResourceGroupName $ResourceGroupName -ServerName $SQLServerName -Location $Location -SqlAdministratorCredentials $(New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $SQLAdmin, $(ConvertTo-SecureString -String $Password -AsPlainText -Force)) -Tags @{CreatedBy=$CurrentUser.Id;CreatedDate=$CurrentDate;CostCenter=$CostCenter;NS_Location=$LocTag;NS_Environment=$EnvTag;NS_Application=$AppTag} -AssignIdentity -ErrorAction Stop

#Set AAD Admin Group
write-host "Setting AAD Admin on $SQLServerName" -ForegroundColor Green
$ADGroup = Get-AzADGroup -DisplayName $AADAdmin
Set-AzSqlServerActiveDirectoryAdministrator -ObjectId $ADGroup.Id -DisplayName $AADAdmin -ResourceGroupName $ResourceGroupName -ServerName $SQLServerName

#Advanced data security
write-host "Enabling Advanced Data Security..." -ForegroundColor Green
Enable-AzSqlServerAdvancedDataSecurity -ResourceGroupName $ResourceGroupName -ServerName $SQLServerName -DoNotConfigureVulnerabilityAssessment

write-host "Updating Vulnerability Assessment Settings" -ForegroundColor Green
Update-AzSqlServerVulnerabilityAssessmentSetting -ResourceGroupName $ResourceGroupName -ServerName $SQLServerName -StorageAccountName $VulnScanStorAcctName -ScanResultsContainerName "vulnerability-assessment" -RecurringScansInterval Weekly -EmailAdmins $False -NotificationEmail "admins@system.com"

write-host "Updating Advanced Threat Protection Settings" -ForegroundColor Green
Update-AzSqlServerAdvancedThreatProtectionSetting -ResourceGroupName $ResourceGroupName -ServerName $SQLServerName -EmailAdmins $False -NotificationRecipientsEmails "admin@system.com"

# Create a server firewall rule that allows access from the specified IP range
write-host "Configuring firewall settings on $SQLServerName" -ForegroundColor Green
 New-AzSqlServerFirewallRule -ResourceGroupName $ResourceGroupName -ServerName $SQLServerName -AllowAllAzureIPs
 New-AzSqlServerFirewallRule -ResourceGroupName $ResourceGroupName -ServerName $SQLServerName -FirewallRuleName "myIP" -StartIpAddress "x.x.x.x" -EndIpAddress "x.x.x.x"


#Create Private Endpoint Connection for SQL Server
write-host "Creating Private Endpoint Connection for $SQLServerName SQL Server" -ForegroundColor Green
$PrivateEndpointConnection = New-AzPrivateLinkServiceConnection -Name ($SQLServerName + "plsconn") -PrivateLinkServiceId $NewSQLServer.ResourceId -GroupId "sqlServer" -ErrorAction Stop

write-host "Creating Private Endpoint for $SQLServerName SQL Server" -ForegroundColor Green
$privateEndpoint = New-AzPrivateEndpoint -ResourceGroupName $ResourceGroupName -Name ($SQLServerName + "pe") -Location $Location -Subnet $Subnet -PrivateLinkServiceConnection $PrivateEndpointConnection -Tag @{CreatedBy=$CurrentUser.Id;CreatedDate=$CurrentDate;CostCenter=$CostCenter;NS_Location=$LocTag;NS_Environment=$EnvTag;NS_Application=$AppTag}-ErrorAction Stop

#Auditing
#Getting ERROR here, but works when run after the script completes!! 
write-host "Enabling Auditing on $SQLServerName" -ForegroundColor Green   
Set-AzSqlServerAudit -ResourceGroupName $ResourceGroupName -ServerName $SQLServerName -LogAnalyticsTargetState Enabled -WorkspaceResourceId "resourceid"

# Create a blank database
write-host "Creating blank database named $DatabaseName" -ForegroundColor Green
New-AzSqlDatabase  -ResourceGroupName $ResourceGroupName -ServerName $SQLServerName -DatabaseName $DatabaseName -Edition "GeneralPurpose" -Vcore 8 -ComputeGeneration "Gen5" -ComputeModel Serverless -Tags @{CreatedBy=$CurrentUser.Id;CreatedDate=$CurrentDate;CostCenter=$CostCenter;NS_Location=$LocTag;NS_Environment=$EnvTag;NS_Application=$AppTag} -ErrorAction Stop

#Set PITR backup retention for database
write-host "Setting PITR backup retention on $DatabaseName" -ForegroundColor Green
Set-AzSqlDatabaseBackupShortTermRetentionPolicy -ResourceGroupName $ResourceGroupName -ServerName $SQLServerName -DatabaseName $DatabaseName -RetentionDays $BackupRetention

#Auditing for database  
write-host "Enabling Auditing on $DatabaseName" -ForegroundColor Green  
Set-AzSqlDatabaseAudit -ResourceGroupName $ResourceGroupName -ServerName $SQLServerName -DatabaseName $DatabaseName -LogAnalyticsTargetState Enabled -WorkspaceResourceId "resourceid"

#Integrate above created private endpoint with existing private DNS zone
write-host "Integrate private endpoint with private DNS zone in Hub" -ForegroundColor Green
Set-AzContext -SubscriptionName "sub" #Change the subscription context to HUB becuase DNS private zone are located there.
New-AzPrivateDnsRecordSet -ZoneName "privatelink.net" -ResourceGroupName "rg" -Name $SQLServerName -RecordType A -TTL 3600 -PrivateDnsRecords (New-AzPrivateDnsRecordConfig -IPv4Address $privateEndpoint.CustomDnsConfigs.IpAddresses)

write-host "Create-SQL.ps1 script completed" -ForegroundColor Blue