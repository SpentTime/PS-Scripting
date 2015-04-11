
$WINCAP      = "Windows Caption"
$SP          = "Service Pack"
$MAKE        = "Manufacturer"
$SERIAL      = "Serial Number"
$DOMAIN      = "Active Directory Domain"
$LOCALADMINS = "Local Administrators"
$VOLUMES     = "Windows Disks"
$HPARRAY     = "HP Smart Array Logical Drives"
$HPCACHE     = "HP Physical Write Cache"
$HPRATIO     = "HP Array Rebuild Priority Ratio"
$IPINFO      = "IP Info"
$ROUTE       = "Route Table"                                      

$serverList = @()
$serverDownList = @()
$serverInfo = @{} 


function Get-Info{

	$WINCAP      = "Windows Caption"
	$SP          = "Service Pack"
	$MAKE        = "Manufacturer"
	$SERIAL      = "Serial Number"
	$DOMAIN      = "Active Directory Domain"
	$LOCALADMINS = "Local Administrators"
	$VOLUMES     = "Windows Disks"
	$HPARRAY     = "HP Smart Array Logical Drives"
	$HPCACHE     = "HP Physical Write Cache"
	$HPRATIO     = "HP Array Rebuild Priority Ratio"
	$IPINFO      = "IP Info"
	$ROUTE       = "Route Table"

    $info = @{} 		# Will return all info as a hash table
	$buffer = $null		# For working with objects for which to extract multiple strings
	$hpArrayPath = $null    # Will hold path to HPACUCLI.exe
	$hpBuffer = $null	
	$pathA, $pathB = "C:\Program Files (x86)", "C:\Program Files" # for looking for HPACUCLI.exe


	$wmiBuffer          = Get-CimInstance -NameSpace root\cimv2 -ClassName Win32_OperatingSystem
	$info[$WINCAP]      = $wmiBuffer.Caption
	$info[$SP]          = $wmiBuffer.ServicePackMajorVersion

	$buffer             = Get-CimInstance -NameSpace root\cimv2 -ClassName Win32_BIOS
	$info[$MAKE]        = $buffer.Manufacturer
	$info[$SERIAL]      = $buffer.SerialNumber

	$info[$MSASSET]     = $null #Still need to see if there is even a way to get this.

	$info[$DOMAIN]      = (Get-CimInstance -Namespace root\cimv2 -ClassName Win32_ComputerSystem).Domain
	
    $info[$VOLUMES]     = (Get-CimInstance -NameSpace root\cimv2 -ClassName Win32_LogicalDisk) 
       
	$info[$LOCALADMINS] = (net localgroup administrators)

	$info[$HPARRAY]	    = $null
	
	# if the system is an HP, grab the HPACU info.
	if ($info[$MAKE] -eq "HP"){ 
        #code to find HPACUCLI copied from colleague Krista Berry, (modified)
        $hpArrayPath = (Get-ChildItem -Path $pathA, $pathB -Recurse | Where-Object {$_.PSIsContainer -eq $true -and $_.Name -match "hpssacli"}).FullName #| select FullName
        If($hpArrayPath -ne $null)
            {$hpArrayPath += "\bin\hpssacli.exe"}
        If($hpArrayPath -eq $null)
        {
            $hpArrayPath = (Get-ChildItem -Path $pathA, $pathB -Recurse | Where-Object {$_.PSIsContainer -eq $true -and $_.Name -match "hpacucli"}).FullName #| select FullName
            $hpArrayPath += "\bin\hpacucli.exe"
        }
    		
		$buffer = & $hpArrayPath " ctrl all show detail"
		
		$info[$HPCACHE] = ($buffer | Where-Object {$_ -match "Drive Write Cache:"})
		$info[$HPRATIO] = ($buffer | Where-Object {$_ -match "Cache Ratio:"})
		$info[$HPARRAY] = & $hpArrayPath " ctrl all show config"
	}


	$info[$IPINFO]         = (ipconfig /all)
	$info[$ROUTE]          = (route print)

	$info
}
    

#Main###############################################

#Determine if string or file argument.  End script if no argument was provided.wr
if ($args.Length -eq 1 -and $args[0].EndsWith(".txt"))
{
    if(Test-Path $args[0])
    {
        $serverList = Get-Content $args[0]
    }
    else
    {
        Write-Host "File not found"
        Exit
    }
}
elseif ($args.Length -eq 0)
{
    Write-Host "SYNTAX"
    Write-Host "`tthruWMI.ps1 `"Server Name`""
    Write-Host "`tthruWMI.ps1 `"Server1`" `"Server2`" `"Server3`" ..."
    Write-Host "`tthruWMI.ps1 <TextFile>"
    Exit
}
else
{
    $serverList = $args
}



$cred = Get-Credential


foreach ($server in $serverList)
{$serverInfo[$server] = Invoke-Command -Credential $cred -ComputerName $server -ScriptBlock ${Function:Get-Info}}

foreach ($server in $serverList){
    if(-not (Test-Path ".\Saved QC")){New-Item -ItemType Directory ".\Saved QC"}
    Set-Content -Path ".\Saved QC\$server.txt" -Value "$server********"
    Add-Content -Path ".\Saved QC\$server.txt" -Value "$WINCAP`:"
    Add-Content -Path ".\Saved QC\$server.txt" -Value $serverInfo[$server][$WINCAP]
    Add-Content -Path ".\Saved QC\$server.txt" -Value "$SP`:"
    Add-Content -Path ".\Saved QC\$server.txt" -Value $serverInfo[$server][$SP]
    Add-Content -Path ".\Saved QC\$server.txt" -Value "$MAKE`:"
    Add-Content -Path ".\Saved QC\$server.txt" -Value $serverInfo[$server][$MSASSET]
    Add-Content -Path ".\Saved QC\$server.txt" -Value "$SERIAL"
    Add-Content -Path ".\Saved QC\$server.txt" -Value $serverInfo[$server][$SERIAL]
    Add-Content -Path ".\Saved QC\$server.txt" -Value "$DOMAIN"
    Add-Content -Path ".\Saved QC\$server.txt" -Value $serverInfo[$server][$DOMAIN]
    Add-Content -Path ".\Saved QC\$server.txt" -Value "$LOCALADMINS"
    Add-Content -Path ".\Saved QC\$server.txt" -Value $serverInfo[$server][$LOCALADMINS]
    Add-Content -Path ".\Saved QC\$server.txt" -Value "$VOLUMES"
    Add-Content -Path ".\Saved QC\$server.txt" -Value $serverInfo[$server][$VOLUMES]
    Add-Content -Path ".\Saved QC\$server.txt" -Value "$HPARRAY"
    Add-Content -Path ".\Saved QC\$server.txt" -Value $serverInfo[$server][$HPARRAY]
    Add-Content -Path ".\Saved QC\$server.txt" -Value "$HPCACHE"
    Add-Content -Path ".\Saved QC\$server.txt" -Value $serverInfo[$server][$HPCACHE]
    Add-Content -Path ".\Saved QC\$server.txt" -Value "$HPRATIO"
    Add-Content -Path ".\Saved QC\$server.txt" -Value $serverInfo[$server][$AV]
    Add-Content -Path ".\Saved QC\$server.txt" -Value "$IPINFO"
    Add-Content -Path ".\Saved QC\$server.txt" -Value $serverInfo[$server][$IPINFO]
    Add-Content -Path ".\Saved QC\$server.txt" -Value "$ROUTE"
    Add-Content -Path ".\Saved QC\$server.txt" -Value $serverInfo[$server][$ROUTE]
}

