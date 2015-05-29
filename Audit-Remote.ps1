

if ($args.Length -eq 1 -and $args[0].EndsWith(".txt"))
{
    if(Test-Path $args[0])
    {
        $deviceList = Get-Content $args[0]
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
    Write-Host "`Audit-Remote.ps1 `"Server Name`""
    Write-Host "`Audit-Remote.ps1 `"Server1`" `"Server2`" `"Server3`" ..."
    Write-Host "`Audit-Remote.ps1 <TextFile>"
    Exit
}
else
{
    $deviceList = $args
}

$deviceSerial = $null
$deviceAsset = $null

Set-Content -Path ".\audit.csv" -Value "Name,Asset,Serial"

$ErrorActionPreference = "Stop"  #This is to make sure all exceptions are caught.
                                 #Without this, the upcomming try/catch block doesn't work  


#this gathers asset tag and serial information for provided servers, and then adds them to the CSV file.
foreach($device in $deviceList)
{
    try
    {
    $deviceAsset = Get-CimInstance -Namespace root/CIMV2 -ClassName Win32_SystemEnclosure -ComputerName $device
    $deviceAsset = $deviceAsset.SMBIOSAssetTag
    $deviceSerial = Get-CimInstance -Namespace root/CIMV2 -ClassName Win32_BIOS -ComputerName $device
    $deviceSerial = $deviceSerial.SerialNumber
    }
    catch [Microsoft.Management.Infrastructure.CimException]
    {
    $deviceAsset = "Cannot connect"
    $deviceSerial = "Cannot connect"
    }
    catch
    {
    write-host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    write-host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally
    {
    Add-Content -Path ".\audit.csv" -Value "$device,$deviceAsset,$deviceSerial"
    $deviceAsset = $null
    $deviceSerial = $null
    }
}

& ".\audit.csv"