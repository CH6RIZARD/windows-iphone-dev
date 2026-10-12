#Requires -Version 5.1
# Moves the Windows paging file off C: to the internal drive with the most free space,
# with a fixed size of 1.5x RAM initial / 3x RAM maximum. Reboot required afterwards.

$ErrorActionPreference = 'Stop'
$MinFreeGB = 30
$LogPath   = Join-Path $env:ProgramData 'fix-pagefile.log'

# 1. Administrator check: pagefile settings live in HKLM and need elevation.
$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning 'This script must be run as Administrator. Right-click PowerShell > Run as administrator.'
    exit 1
}

Start-Transcript -Path $LogPath -Append | Out-Null   # Log everything to C:\ProgramData\fix-pagefile.log
try {
    # 2. Find a fixed, internal (non-USB) drive other than the system drive with >= 30 GB free.
    $systemDrive = $env:SystemDrive                                   # Usually "C:"
    $target = Get-Partition |
        Where-Object { $_.DriveLetter -and "$($_.DriveLetter):" -ne $systemDrive } |
        ForEach-Object {
            $disk = Get-Disk -Number $_.DiskNumber                    # Physical disk the partition lives on
            $vol  = Get-Volume -DriveLetter $_.DriveLetter            # Filesystem + free space
            [pscustomobject]@{
                Letter  = "$($_.DriveLetter):"
                BusType = "$($disk.BusType)"
                FreeGB  = [math]::Round($vol.SizeRemaining / 1GB, 1)
                FS      = $vol.FileSystem
                Type    = $vol.DriveType
            }
        } |
        Where-Object { $_.BusType -ne 'USB' -and $_.Type -eq 'Fixed' -and $_.FS -eq 'NTFS' -and $_.FreeGB -ge $MinFreeGB } |
        Sort-Object FreeGB -Descending |
        Select-Object -First 1

    if (-not $target) { throw "No internal NTFS drive (non-USB, not $systemDrive) with at least $MinFreeGB GB free was found." }
    Write-Host "[OK] Target drive: $($target.Letter) ($($target.BusType), $($target.FreeGB) GB free)" -ForegroundColor Green

    # 6. Size from installed RAM: initial = 1.5x, maximum = 3x (values in MB).
    $ramMB     = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1MB)
    $initialMB = [uint32][math]::Round($ramMB * 1.5)
    $maximumMB = [uint32][math]::Round($ramMB * 3)
    if (($maximumMB / 1024) -gt ($target.FreeGB - 5)) { throw "Max pagefile ($maximumMB MB) would leave under 5 GB free on $($target.Letter)." }
    Write-Host "[OK] RAM: $ramMB MB -> Initial $initialMB MB, Maximum $maximumMB MB"

    # 3. Turn off "Automatically manage paging file size for all drives" (the GUI checkbox).
    $cs = Get-CimInstance Win32_ComputerSystem
    if ($cs.AutomaticManagedPagefile) {
        Set-CimInstance -InputObject $cs -Property @{ AutomaticManagedPagefile = $false }
    }
    Write-Host '[OK] Automatic pagefile management disabled.'

    # 5. Create (or resize) the pagefile on the target drive FIRST, so the system is never left without one.
    $path     = "$($target.Letter)\pagefile.sys"
    $existing = Get-CimInstance Win32_PageFileSetting | Where-Object { $_.Name -ieq $path }
    if ($existing) {
        Set-CimInstance -InputObject $existing -Property @{ InitialSize = $initialMB; MaximumSize = $maximumMB }
    } else {
        New-CimInstance -ClassName Win32_PageFileSetting -Property @{
            Name = $path; InitialSize = $initialMB; MaximumSize = $maximumMB
        } | Out-Null
    }
    Write-Host "[OK] New pagefile configured: $path ($initialMB-$maximumMB MB)" -ForegroundColor Green

    # 4. Remove every other pagefile entry (C: included) so Windows stops reverting to the system drive.
    Get-CimInstance Win32_PageFileSetting | Where-Object { $_.Name -ine $path } | ForEach-Object {
        Write-Host "     Removing pagefile setting: $($_.Name)"
        Remove-CimInstance -InputObject $_
    }
    Write-Host '[OK] Old pagefile settings removed.'

    # Verify what Windows will actually read at boot.
    $reg = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management').PagingFiles
    Write-Host "     Registry PagingFiles = $reg"
    if ($reg -notmatch [regex]::Escape($path)) { throw 'Registry does not show the new pagefile; settings did not apply.' }

    Write-Host ''
    Write-Host '*** DONE. Reboot required to finish moving the paging file. ***' -ForegroundColor Yellow
    Write-Host "     (Log: $LogPath)"
    $exit = 0
}
catch {
    Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host '       No reboot needed; check the log and rerun.'
    $exit = 1
}
finally {
    Stop-Transcript | Out-Null
}
exit $exit
