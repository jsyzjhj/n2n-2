# install path for edge
$binaryPath = "$env:ProgramFiles\n2n"

# function to install a service
Function Install-ServiceInstance($binaryName, $instanceName, $arguments, $depends)
{

# stop the service
if (Get-Service -Name $instanceName) {
    Stop-Service -Name $instanceName | Out-Null
    # a cmdlet is only available for PWSH 6+
    & "$env:SystemRoot\System32\sc.exe" delete $instanceName | Out-Null
} else {
    Write-Host -ForegroundColor Green "Could not find existing service '$instanceName', this is ok, if it was not installed."
}

# create a new program folder
if (!(Test-Path -Path "$binaryPath" -Type Container)) {
    New-Item -Type Directory -Path "$binaryPath" | Out-Null
}

# copy the edge executable
Try {
    Copy-Item "$binaryName" "$binaryPath\$binaryName"    
} Catch {
    Write-Host -ForegroundColor Red "$instanceName cannot be installed: $_"
    Return
}

# create a new service with manual startup type
if ($depends) {
    New-Service -Name $instanceName -BinaryPathName "$binaryPath\$binaryName" -StartupType Manual -DependsOn $depends | Out-Null
} else {
    New-Service -Name $instanceName -BinaryPathName "$binaryPath\$binaryName" -StartupType Manual | Out-Null
}

# create the registry key
if (!(Test-Path -Path "HKLM:\SOFTWARE\n2n" -PathType Container)) {
    New-Item -Type Directory -Path "HKLM:\SOFTWARE\n2n" | Out-Null
}

if (!(Test-Path -Path "HKLM:\SOFTWARE\n2n\$instanceName" -PathType Container)) {
    New-Item -Type Directory -Path "HKLM:\SOFTWARE\n2n\$instanceName" | Out-Null

}

# add or update the value in the registry key
New-ItemProperty -Path "HKLM:\SOFTWARE\n2n\$instanceName" -Name "Arguments" -PropertyType MultiString -Value $arguments -Force | Out-Null

# install application resource for event log messages (needed so eventlog actually display something)
$eventLog = "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\Application\$instanceName"
if (!(Test-Path -Path $eventLog -PathType Container)) {
    New-Item -Type Directory -Path $eventLog | Out-Null
}

New-ItemProperty -Path $eventLog -Name "EventMessageFile" -PropertyType String -Value "$binaryPath\$binaryName" -Force | Out-Null
New-ItemProperty -Path $eventLog -Name "TypesSupported" -PropertyType DWORD -Value 0x7 -Force | Out-Null

# start the service
#Start-Service $instanceName

Write-Host -ForegroundColor Green "$binaryName installed as service $instanceName"
} #end Function Install-ServiceInstance

# arguments for edge to be saved in the registry
# can be a string or a multistring (aka an array of strings).
# multistrings are required for parameters with spaces in them
$arguments_edge = @(
    "-a", "static:192.168.1.1",
    "-A", "fdf0::1/64",
    "-c", "x",
    "-l", "[::1]:4385",
    "-k", "x"
    "-b"
)

Install-ServiceInstance "edge.exe" "edge" $arguments_edge -depends "tap0901"
Install-ServiceInstance "supernode.exe" "supernode" @("-4", "-6", "-l", "4385")
