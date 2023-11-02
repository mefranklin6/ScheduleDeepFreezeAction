Param(
    [Parameter(Mandatory=$true)]
    [string]$PC,

    [Parameter(Mandatory=$true)]
    [string]$DesiredState,

    [Parameter()]
    [string]$LogLocation = "C:\Temp\$PC-DeepFreeze.txt",

    [Parameter(Mandatory = $true)]
    [string]$EncryptedPasswordLocation
)



function Log ($message) {
    $LogTime = Get-Date -DisplayHint Time
    $LogTime = $LogTime.ToString()
    Write-Output $message
    $LogStr = "$LogTime  -  $PC  -  $message"
    $LogStr | Out-File "$LogLocation" -Append
    }


$Success = $null

function Quit {
    $script:Success = $false
    Log "DeepFreezeActionResult: $Success"
    Exit
}


$StateOptions = @('Frozen', 'Thawed', 'Thawed and Locked')
if (!($DesiredState -in $StateOptions)) {
    Log "FATAL: $DesiredState is not a valid state"
    Log "Valid States are '$StateOptions'"
    Quit
}

$loadedEncryptedPassword = Get-Content -Path 'C:\DeepFreezePassword.txt'
$loadedSecureString = ConvertTo-SecureString -String $loadedEncryptedPassword
$DFPassword = (New-Object PSCredential "user", $loadedSecureString).GetNetworkCredential().Password



$ClearToProceede = $false

if (!(Test-Connection -ComputerName $PC -Count 1)){
    Log "FATAL: $PC is not online or wrong name!"
    Quit
}

$LoggedInUser = $null
$LoggedInUser = Get-CimInstance -Class win32_computersystem -ComputerName $PC | Select-Object username
$LoggedInUser = $LoggedInUser -split '\\'
$LoggedInUser = $LoggedInUser[1] -replace '}'


if ($LoggedInUser -eq '') {
    Log "INFO: No one is logged in to $PC"
    $ClearToProceede = $true
}
elseif ($null -eq $LoggedInUser) {
    Log 'FATAL: Can not find logged-in user'
    Quit
}
elseif ($LoggedInUser -like 'SC-*') {
    Log "INFO: Generic Account $LoggedInUser logged-in to $PC"
}
else {
    Log "WARNING: Real User Account $LoggedInUser Logged in to $PC"
}


function GetRunningProcess ($process_name) {
    Invoke-Command -ComputerName $PC -ScriptBlock {
        try {
            Get-Process $using:process_name -ErrorAction Stop
        }
        catch {
            $false
        }
    }
}


if ($ClearToProceede -ne $true) {
    
    $Chrome = GetRunningProcess 'Chrome'
    $Firefox = GetRunningProcess 'Firefox'
    $Edge = GetRunningProcess 'Edge'
    $PowerPoint = GetRunningProcess 'POWERPNT'
    $Teams = GetRunningProcess 'Teams'
    $Zoom = GetRunningProcess 'Zoom'

    $ProcessList = @(
        $Chrome, 
        $Firefox, 
        $Edge, 
        $PowerPoint, 
        $Teams, 
        $Zoom
    )

    foreach ($Process in $ProcessList) {
        if ($Process) {
            Log "FATAL: Something is Running! $PC May Be In Use! Stopping!"
            Quit
        }
    }
}


$DFStatus =
Invoke-Command -ComputerName $PC -ScriptBlock {
    (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Faronics\Deep Freeze 6\" -Name "DF Status")."DF Status"
}

if ($DFStatus -eq $DesiredState) {
    Log "ERROR: $PC is already $DFstatus"
    Quit
}


#### Send DF Commands ####
$CommandLookupTable = @{
                    'Frozen' = '/BOOTFROZEN';
                    'Thawed' = '/BOOTTHAWED';
                    'Thawed and Locked' = '/BOOTTHAWEDNOINPUT'            
}

$Command = $CommandLookupTable[$DesiredState]

Log "INFO: Sending Command: $Command"
Log "INFO: Console may show an error when PC Reboots. This is normal"

Invoke-Command -ComputerName "$PC" -ScriptBlock{
    C:\Windows\SysWOW64\.\DFC.exe "$using:DFPassword" "$using:Command"
} # Command will hang while PC prepares to reboot, 
# then will raise OpenError as connection is lost during the reboot


Log "INFO: Starting Sleep to wait for reboot"
Start-Sleep -Seconds 60


$TestAttempts = 0
function TestOnlineRecurse {
    if (!(Test-Connection -ComputerName $PC -Count 1)) {
        Log "WARNING: $PC not detected online.  Will try again in 15 seconds"
        $script:TestAttempts += 1
        Log "INFO: Ping Attempt $script:TestAttempts of 5"
        if ($script:TestAttempts -lt 5) {
            Start-Sleep -Seconds 15
            TestOnlineRecurse
        }
        else {
            Log "FATAL: $PC did not come back online"
            Quit
        }
    }
}
TestOnlineRecurse


#### Verify DF Status ####

$DFStatus =
Invoke-Command -ComputerName $PC -ScriptBlock {
    (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Faronics\Deep Freeze 6\" -Name "DF Status")."DF Status"
}

if ($DFStatus -eq $DesiredState) {
    $Success = $true
    Log "INFO: Sucessfully rebooted $DFStatus"
}
else {
    $Success = $false
    Log "WARNING: Could not verify operation.  State is $DFStatus, Desired State is $DesiredState"
    Log "WARNING: Check DF install package on $PC.  Failure is usually due to an outdated DF Install which has an old password"
    Log 'INFO: PC must be frozen first in order to boot into Thawed or Thawed and Locked states'
}

Log "DeepFreezeActionResult: $Success"
