#Requires -Version 5.1
<#
.SYNOPSIS
    Collect a complete inventory of a local or remote Windows machine.
.DESCRIPTION
    Uses CIM (Get-CimInstance over WS-MAN) — the supported replacement for the
    deprecated Get-WmiObject/DCOM approach — to gather hardware, OS, CPU, BIOS,
    memory, disk, and network details, plus a quick check of common service
    ports. Returns a PSCustomObject so the data can be piped, formatted, sorted,
    or exported (Export-Csv / ConvertTo-Json) instead of only printed.
.PARAMETER ComputerName
    One or more target hosts. Defaults to the local machine.
.PARAMETER IgnorePing
    Collect data even if the host does not answer an ICMP ping.
.PARAMETER Credential
    Optional credential for remote CIM sessions.
.EXAMPLE
    .\Get-SystemInfo.ps1
.EXAMPLE
    .\Get-SystemInfo.ps1 -ComputerName SERVER01,SERVER02 | Format-List
.EXAMPLE
    .\Get-SystemInfo.ps1 -ComputerName SERVER01 | Export-Csv inventory.csv -NoTypeInformation
#>
[CmdletBinding()]
param(
    [Parameter(ValueFromPipeline = $true)]
    [string[]] $ComputerName = $env:COMPUTERNAME,

    [switch] $IgnorePing,

    [System.Management.Automation.PSCredential] $Credential
)

begin {
    function Convert-Bytes {
        param([double] $Bytes, [string] $Unit = 'GB')
        $divisor = switch ($Unit) { 'MB' { 1MB } 'GB' { 1GB } default { 1GB } }
        [Math]::Round($Bytes / $divisor, 2)
    }
}

process {
    foreach ($computer in $ComputerName) {

        $reachable = Test-Connection -ComputerName $computer -Count 1 -Quiet -ErrorAction SilentlyContinue

        # Resolve DNS without throwing on failure.
        $dnsAddresses = try {
            [System.Net.Dns]::GetHostAddresses($computer) | ForEach-Object { $_.IPAddressToString }
        } catch { @() }

        $info = [ordered]@{
            ComputerName   = $computer
            PingReply      = if ($reachable) { 'Yes' } else { 'No' }
            DnsAddresses   = if ($dnsAddresses) { $dnsAddresses -join ', ' } else { 'Could not resolve' }
        }

        if (-not $reachable -and -not $IgnorePing) {
            $info['Collected'] = 'No (no ping reply; use -IgnorePing to force)'
            [PSCustomObject]$info
            continue
        }

        # One CIM session per host, reused across queries. Falls back to DCOM
        # for legacy targets that don't speak WS-MAN.
        $sessionParams = @{ ComputerName = $computer; ErrorAction = 'Stop' }
        if ($Credential) { $sessionParams['Credential'] = $Credential }

        $session = $null
        try {
            $session = New-CimSession @sessionParams
        } catch {
            try {
                $opt = New-CimSessionOption -Protocol Dcom
                $session = New-CimSession @sessionParams -SessionOption $opt
            } catch {
                $info['Collected'] = "No (CIM session failed: $($_.Exception.Message))"
                [PSCustomObject]$info
                continue
            }
        }

        try {
            $cs = Get-CimInstance -CimSession $session -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
            if ($cs) {
                $info['Manufacturer'] = $cs.Manufacturer
                $info['Model']        = $cs.Model
                $info['LoggedOnUser'] = $cs.UserName
            }

            $os = Get-CimInstance -CimSession $session -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
            if ($os) {
                $info['OSName']        = $os.Caption
                $info['OSVersion']     = $os.Version
                $info['OSArch']        = $os.OSArchitecture
                $info['LastBootTime']  = $os.LastBootUpTime
                $info['InstallDate']   = $os.InstallDate
                $info['SystemDrive']   = $os.SystemDrive
                $total = $os.TotalVisibleMemorySize * 1KB
                $free  = $os.FreePhysicalMemory * 1KB
                $info['MemoryTotalGB'] = Convert-Bytes $total
                $info['MemoryFreeGB']  = Convert-Bytes $free
                $info['MemoryUsedGB']  = Convert-Bytes ($total - $free)
                if ($total -gt 0) {
                    $info['MemoryPercentFree'] = [Math]::Round(($free / $total) * 100, 1)
                }
            }

            $cpu = Get-CimInstance -CimSession $session -ClassName Win32_Processor -ErrorAction SilentlyContinue
            if ($cpu) {
                $info['CPUName']           = ($cpu | Select-Object -First 1).Name -replace '\s+', ' '
                $info['CPUCores']          = ($cpu | Measure-Object -Property NumberOfCores -Sum).Sum
                $info['CPULogicalProcs']   = ($cpu | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
                $info['CPUMaxClockMHz']    = ($cpu | Select-Object -First 1).MaxClockSpeed
            }

            $bios = Get-CimInstance -CimSession $session -ClassName Win32_BIOS -ErrorAction SilentlyContinue
            if ($bios) {
                $info['BIOSManufacturer'] = $bios.Manufacturer
                $info['BIOSVersion']      = $bios.SMBIOSBIOSVersion
                $info['BIOSSerial']       = $bios.SerialNumber
            }

            $disks = Get-CimInstance -CimSession $session -ClassName Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction SilentlyContinue
            foreach ($d in $disks) {
                $info["Disk $($d.DeviceID)"] = '{0} GB free of {1} GB' -f (Convert-Bytes $d.FreeSpace), (Convert-Bytes $d.Size)
            }

            $nics = Get-CimInstance -CimSession $session -ClassName Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=True' -ErrorAction SilentlyContinue
            $n = 0
            foreach ($nic in $nics) {
                $n++
                $info["NIC $n"] = '{0} (MAC: {1})' -f (($nic.IPAddress) -join ', '), $nic.MACAddress
            }

            # Quick TCP port check using the modern cmdlet.
            $ports = @{ 'SMB/RPC (139)' = 139; 'SMB (445)' = 445; 'RDP (3389)' = 3389; 'WinRM (5985)' = 5985 }
            foreach ($name in $ports.Keys) {
                $open = Test-NetConnection -ComputerName $computer -Port $ports[$name] -WarningAction SilentlyContinue -InformationLevel Quiet
                $info["Port $name"] = if ($open) { 'Open' } else { 'Closed/Filtered' }
            }
        }
        finally {
            if ($session) { Remove-CimSession $session }
        }

        [PSCustomObject]$info
    }
}
