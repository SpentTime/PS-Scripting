function Check-WRM ($computer, $cred)
{
    $isGood = $true
    
    Try
    { 
        Test-WSMan -ComputerName $computer -ErrorAction SilentlyContinue
    }
    Finally
    {
        $isGood = $false
    }
    return $isGood
}

function Check-AccountExists ($computer, $accountName)
{
    $admin = Get-CimInstance -ComputerName $computer -Namespace root/CIMV2 -ClassName win32_group -Filter "Name='Administrators'"
    $admin = Get-CimAssociatedInstance $admin

    foreach ($i in $admin.name)
    {
        if ($i -eq $accountName)
        {
           return $true
        }
    }
    return $false
}

function Check-Password($computer, $accountName, $password)
{
    Add-Type -AssemblyName System.DirectoryServices.AccountManagement
    $testObj = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('machine',$computer)
    return $testObj.ValidateCredentials($accountName, $password)
}

function Change-Password($computer, $accountName, $password)
{
    $user = [adsi]"WinNT://$computer/$accountName,User"
    $user.SetPassword($password)
    $user.SetInfo()
}

function Rename-Administrator($computer, $accountName, $password)
{
    $user = [adsi]"WinNT://$computer/Administrator,User"
    $user.psbase.rename($accountName)
    $user.SetPassword($password)
    $user.SetInfo()
}

function Add-Account($computer, $accountName, $password)
{
    $cn = [adsi]"WinNT://$computer"
    $user = $cn.Create("User",$accountName)
    $user.SetPassword($password)
    $user.SetInfo()

    $group = [adsi]"WinNT://$computer/Administrators,group"
    $group.psbase.Invoke("Add",([adsi]"WinNT://$computer/$accountName").path)
    $group.setInfo()
}

$computers = $null
$badconnection = @()
$withAccount = @()
$withoutAccount = @()
$passwordPassed = @()
$passwordFailed = @()
$accountName = $null
$password = $null

$changePwd = $null
$renameAdmin = $null

[System.Collections.ArrayList]$computers = $computers
[System.Collections.ArrayList]$badconnection = $badconnection
[System.Collections.ArrayList]$withAccount = $withAccount
[System.Collections.ArrayList]$withoutAccount = $withoutAccount
[System.Collections.ArrayList]$passwordPassed = $passwordPassed
[System.Collections.ArrayList]$passwordFailed = $passwordFailed 

if ($args.Length -eq 1 -and $args[0].EndsWith(".txt"))
{
    if(Test-Path $args[0])
    {
        $computers = Get-Content $args[0]
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
    Write-Host "`.\Check-Account.ps1 `"Server Name`""
    Write-Host "`.\Check-Account.ps1 `"Server1`" `"Server2`" `"Server3`" ..."
    Write-Host "`.\Check-Account.ps1 <TextFile>"
    Exit
}
else
{
    $computers = $args
}

$accountName = Read-Host "Please enter the account name you are looking for"
$password = Read-Host "Please enter the password you are looking for"

Clear-Host

#Check for bad connections.  If bad, remove from main list.
for ($i = 0;$i -lt $computers.Count; $i++)
{
    if (-Not(Check-WRM $computers[$i] ))
    {
        $badconnection.Add($computers[$i])
        $computers.Remove($computers[$i])
    }
}

#Check which machines have the account and add the names to the appropiate array.
for ($i = 0;$i -lt $computers.Count; $i++)
{
    if (Check-AccountExists $computers[$i] $accountName )
    {
        $withAccount.Add($computers[$i])
    }
    else
    {
        $withoutAccount.Add($computers[$i])
    }
}

#Check that the password supplied earlier works on machines that have the account.
for ($i = 0;$i -lt $withAccount.Count; $i++)
{
    if(Check-Password $withAccount[$i] $accountName $password)
    {
        $passwordPassed.Add($withAccount[$i])
    }
    else
    {
        $passwordFailed.Add($withAccount[$i])
    }
}

#Change the password for machines that failed.
if ($passwordFailed.Count -gt 0)
{
    Write-Host "The following systems failed the password check:"
    Write-Host $passwordFailed

    $changePwd = Read-Host "Type 'y' if you would like to update the password for these servers"

    if ($changePwd -eq 'y')
    {
        for ($i = 0; $i -lt $passwordFailed.Count; $i++)
        {
            Change-Password $passwordFailed[$i] $accountName $password
        }
    }
}

#Either add account, or rename Administrator
if ($withoutAccount.Count -gt 0)
{
    Write-Host "The following do not have $accountName"
    Write-Host $withoutAccount

    $renameAdmin =  Read-Host "Type 'y' if you would like to rename Administrator on these machines,otherwise $accountName will simply be added"

    if ($renameAdmin -eq 'y')
    {
        for ($i = 0; $i -lt $withoutAccount.Count; $i++)
        {
            Rename-Administrator $withoutAccount[$i] $accountName $password
        }
    }
    else
    {
        for ($i = 0; $i -lt $withoutAccount.Count; $i++)
        {
            Add-Account $withoutAccount[$i] $accountName $password
        }
    }
}

#Report
Set-Content -Path ".\$accountName-Report.txt" -Value "Report for account $accountName"
Add-Content -Path ".\$accountName-Report.txt" -Value "`n`n`n"

if ($passwordPassed.Count -gt 0)
{
    Add-Content -Path ".\$accountName-Report.txt" -Value "Machines with $accountName and correct password:"
    for ($i = 0; $i -lt $passwordPassed.Count;$i++)
    {
        Add-Content -Path ".\$accountName-Report.txt" -Value $passwordPassed[$i]
    }
    
    Add-Content -Path ".\$accountName-Report.txt" -Value "`n`n`n"
}


if ($passwordFailed.Count -gt 0)
{
    Add-Content -Path ".\$accountName-Report.txt" -Value "Machines with $accountName but incorrect password:"
    for ($i = 0; $i -lt $passwordFailed.Count;$i++)
    {    
        Add-Content -Path ".\$accountName-Report.txt" -Value $passwordFailed[$i]
    }
    
    if ($changePwd -eq 'y') 
    { 
        Add-Content -Path ".\$accountName-Report.txt" -Value "The above machines now have the correct password."
    }
    Add-Content -Path ".\$accountName-Report.txt" -Value "`n`n`n"
}



if ($withoutAccount.Count -gt 0)
{
    Add-Content -Path ".\$accountName-Report.txt" -Value "Machines without $accountName :"
    for ($i = 0; $i -lt $withoutAccount.Count;$i++)
    {    
        Add-Content -Path ".\$accountName-Report.txt" -Value $withoutAccount[$i]
    }

    if ($renameAdmin -eq 'y')
    {
        Add-Content -Path ".\$accountName-Report.txt" -Value "Renamed 'Administrator' for the above machines."
    }
    else
    {
        Add-Content -Path ".\$accountName-Report.txt" -Value "Added $accountName for the above machines."
    }
Add-Content -Path ".\$accountName-Report.txt" -Value "`n`n`n"
}

if ($badconnection.Count -gt 0)
{
    Add-Content -Path ".\$accountName-Report.txt" -Value "Could not connect to the following: "
    for ($i = 0; $i -lt $badconnection.Count; $i++)
    {
        Add-Content -Path ".\$accountName-Report.txt" -Value $badconnection[$i]
    }
}

Clear-Host
Get-Content -Path ".\$accountName-Report.txt"
