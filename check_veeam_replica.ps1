# Script per monitorare i job di Replica Veeam
# CRITICAL se una replica fallisce
# WARNING se risultato con warning
# Compatibile con Icinga Agent / NetEye

$WarningPreference = 'SilentlyContinue'
$ErrorActionPreference = 'SilentlyContinue'
Import-Module Veeam.Backup.PowerShell -DisableNameChecking
$ErrorActionPreference = 'Stop'

[int]$globalstatus = 0
[string]$failedjobs = ""
[string]$warningjobs = ""
[int]$failed_count = 0
[int]$warning_count = 0
[int]$success_count = 0
[int]$disabled_count = 0
[int]$running_count = 0
[int]$total_count = 0

# Prendi tutti i job e filtra solo Replica
$alljobs = Get-VBRJob
$jobs = @($alljobs | Where-Object { $_.TypeToString -like "*Replica*" -or $_.JobType -eq "Replica" })

foreach ($job in $jobs) {
    $job_name = $job.Name
    $total_count++

    if (-not $job.IsScheduleEnabled) {
        $disabled_count++
        continue
    }

    $session = $null
    try { $session = $job.FindLastSession() } catch {}

    if ($session -eq $null) {
        $success_count++
        continue
    }

    $state = ""
    $result = ""
    try { $state = $session.State.ToString() } catch {}
    try { $result = $session.Result.ToString() } catch {}

    if ($state -eq "Working") {
        $running_count++
        continue
    }

    if ($result -eq "Failed") {
        $endTime = ""
        try { $endTime = $session.EndTime.ToString("dd/MM/yyyy HH:mm") } catch {}
        $failedjobs += "$job_name (ended: $endTime), "
        $failed_count++
        $globalstatus = 2
    }
    elseif ($result -eq "Warning") {
        $warningjobs += "$job_name, "
        $warning_count++
        if ($globalstatus -ne 2) { $globalstatus = 1 }
    }
    else {
        $success_count++
    }
}

$failedjobs = $failedjobs.TrimEnd(", ")
$warningjobs = $warningjobs.TrimEnd(", ")
$perfdata = "total=$total_count success=$success_count failed=$failed_count warning=$warning_count disabled=$disabled_count running=$running_count"

if ($total_count -eq 0) {
    Write-Host "UNKNOWN! No Veeam replica jobs found | $perfdata"
    exit 3
}
if ($globalstatus -eq 2) {
    Write-Host "CRITICAL! $failed_count replica job(s) FAILED: $failedjobs | $perfdata"
    exit 2
}
elseif ($globalstatus -eq 1) {
    Write-Host "WARNING! $warning_count replica job(s) with warnings: $warningjobs | $perfdata"
    exit 1
}
else {
    Write-Host "OK! All $success_count replica job(s) completed successfully ($disabled_count disabled) | $perfdata"
    exit 0
}
