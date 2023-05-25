#Create Azure Windows Server 2019 Datacenter Gen 2 VM
# Parameters passed...
#.\createwindows19vm.ps1 -sub "BCBSLA Hub" -VMName "ser-prod-azbsrt" -ResourceGroupName "prdusceaddsrg" -VNetResourceGroupName "prduscenetrg" -SubnetName "trusn01" -VMSize "Standard_D4s_v3" -LocationName "centralus" -CostCenter "0824"
#.\createwindows19vm.ps1 -sub "BCBSLA Prod 2" -VMName "ser-prod-azladc" -ResourceGroupName "prdusceaddsrg" -VNetResourceGroupName "prduscenetrg" -SubnetName "dmzsn01" -VMSize "Standard_D4s_v3" -LocationName "centralus" -CostCenter "0824"

param
(
    [Parameter (Mandatory= $true)]
    [ValidateSet("BCBSLA Dev 1","BCBSLA Test 1","BCBSLA Prod 1","BCBSLA Hub","BCBSLA Prod 2")]
    [String] $sub,
    [Parameter (Mandatory= $true)]
    [String] $VMName,
    [Parameter (Mandatory= $true)]
    [String] $ResourceGroupName,
    [Parameter (Mandatory= $true)]
    [String] $VNetResourceGroupName,
    [Parameter (Mandatory= $true)]
    [ValidateSet("appsn01","sqlsn01","dmzsn01","dmzsn02","trusn01","ctxsn01","zcasn01")]
    [String] $SubnetName,
    [Parameter (Mandatory= $true)]
    [ValidateSet("Standard_DS3_v2","Standard_DS4_v2","Standard_D2s_v3","Standard_D4s_v3","Standard_D2s_v4","Standard_D4s_v4")]
    [String] $VMSize,
    [Parameter (Mandatory= $true)]
    [ValidateSet("centralus","eastus2")]
    [String] $LocationName,
    [Parameter (Mandatory= $true)]
    [String] $CostCenter
)

#Set subscription context
Set-AzContext -SubscriptionName $sub

# Initialize
$ComputerName = $VMName


#Building a credential object:
$UserName = 'e51473oa'
$Password = ')kb$9iprHW7u'| ConvertTo-SecureString -Force -AsPlainText
$Credential = New-Object PSCredential($UserName,$Password)

#Create VM Object
#**Comment or Uncomment ZONE**
$VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize -Zone 1
$VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $ComputerName -Credential $Credential
$VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' -Skus '2019-datacenter-gensecond' -Version "latest"
$OSDiskName = $VMName + '_osdisk'
$VirtualMachine = Set-AzVMOSDisk -VM $VirtualMachine -Name $OSDiskName -CreateOption FromImage

#Add data disk to VM Object
#Pick storage type Premium SSD or Standard SSD
$storageType = 'Premium_LRS'
#$storageType = 'StandardSSD_LRS'
$storageDiskSize = '256'
$dataDiskName = $VMName + '_datadisk0'
#**Comment or Uncomment ZONE**
$diskConfig = New-AzDiskConfig -SkuName $storageType -Location $LocationName -CreateOption Empty -DiskSizeGB $storageDiskSize -Zone 1
$dataDisk0 = New-AzDisk -DiskName $dataDiskName -Disk $diskConfig -ResourceGroupName $ResourceGroupName
$VirtualMachine = Add-AzVMDataDisk -VM $VirtualMachine -Name $dataDiskName -CreateOption Attach -ManagedDiskId $dataDisk0.Id -Lun 0

#Build Network Objects
$subnetId = Get-AzVirtualNetwork -ResourceGroupName $VNetResourceGroupName | Select-Object -ExpandProperty Subnets| Where-Object {$_.Name -eq $SubnetName } | Select-Object -ExpandProperty Id
$NICName = $VMName + '_nic'
$NIC = New-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -Location $LocationName -SubnetId $subnetId -EnableAcceleratedNetworking
$VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id

#Boot Diagnostics
#Get first 10 digits of subscription id
$subid = get-azsubscription -SubscriptionName $sub
$newsubid = out-string -InputObject $subid.id
$newsubid2 = $newsubid -replace '-', ''

#Determine environment based on subscription name
if ($sub -like "*dev*") {$subenv = "dev"}
    elseif ($sub -like "*test*") {$subenv = "tst"}
    else {$subenv = "prd"}
#Get location
if ($LocationName -eq "centralus") {$subloc = "usce"}
    elseif ($LocationName -eq "eastus2") {$subloc = "use2"}

#Set Boot Diagnostics 
$bootrg = $subenv + $subloc + "diagrg"
$bootsa = $subenv + $subloc + "log" + $newsubid2.Substring(0,10)
$VirtualMachine = Set-AzVMBootDiagnostic -VM $VirtualMachine -Enable -ResourceGroupName $bootrg -StorageAccountName $bootsa

#Create VM
New-AzVM -ResourceGroupName $ResourceGroupName -Location $LocationName -VM $VirtualMachine -LicenseType "Windows_Server" -DisableBginfoExtension -Verbose

#Tag VM resources
$currentuser = Get-AzContext
$currentdate = get-date -Format "yyyy.MM.dd:HH.mm.ss"
$vmostags = @{CreatedBy=$currentuser.Account;CreatedDate=$currentdate;CostCenter=$CostCenter;OSVer="Server 2019"}
$tags = @{CreatedBy=$currentuser.Account;CreatedDate=$currentdate;CostCenter=$CostCenter}
$vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName
Set-AzResource -ResourceId $vm.Id -Tag $vmostags -Force
$vmos = Get-AzDisk -DiskName $OSDiskName
Set-AzResource -ResourceId $vmos.Id -Tag $vmostags -Force
$data = Get-AzDisk -DiskName $dataDiskName
Set-AzResource -ResourceId $data.Id -Tag $tags -Force
$vmnic = Get-AzNetworkInterface -Name $NICName
Set-AzResource -ResourceId $vmnic.Id -Tag $tags -Force