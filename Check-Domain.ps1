#check domain of list of windows machines
$servers = Get-Content "C:\directory\Data\serverlist.txt"
foreach ($server in $servers) {
    $server
    $domain = (Get-WmiObject Win32_ComputerSystem -ComputerName $server).Domain
    $domain
    if ($domain -eq "lahsic.com") {
        write-host "Domain is domain1" -ForegroundColor Green
        #add to output file
        Add-Content -Path "C:\directory\Data\Data\domain.txt" -Value $server
    }
    else {
        write-host "Domain is not lahsic.com" -ForegroundColor Red
        #add to output file
        Add-Content -Path "C:\directory\Data\Data\other-domain.txt" -Value $server
    }
}
```