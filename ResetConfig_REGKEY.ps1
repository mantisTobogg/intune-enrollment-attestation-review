# ============================================================================
# TestCleanup.ps1 — Reset test environment for Attestation_DevC.ps1 re-run
# Run as Administrator before re-seeding DEADBEEF and retesting
# ============================================================================

# --- Step 1: Remove any leftover DEADBEEF seed keys across all hives ---
$testGuid = "DEADBEEF-1234-5678-9ABC-DEF012345678"

$paths = @(
    "HKLM:\SOFTWARE\Microsoft\Enrollments\$testGuid",
    "HKLM:\SOFTWARE\Microsoft\Enrollments\Status\$testGuid",
    "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts\$testGuid",
    "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Sessions\$testGuid",
    "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Logger\$testGuid",
    "HKLM:\SOFTWARE\Microsoft\PolicyManager\Providers\$testGuid",
    "HKLM:\SOFTWARE\Microsoft\EnterpriseResourceManager\Tracked\$testGuid"
)

Write-Host "`n[Cleanup] Removing leftover DEADBEEF keys..." -ForegroundColor Cyan
foreach ($p in $paths) {
    if (Test-Path $p) {
        Remove-Item -Path $p -Recurse -Force
        Write-Host "  REMOVED: $p" -ForegroundColor Yellow
    } else {
        Write-Host "  ABSENT:  $p" -ForegroundColor DarkGray
    }
}

# --- Step 2: Re-import customer registry data that got deleted by prior test runs ---
# If 697258CB or other real GUIDs were removed, restore them from the backup
$latestBackup = Get-ChildItem "C:\ProgramData\IntuneEnrollmentRepair" -Directory |
    Sort-Object Name -Descending |
    Select-Object -First 1

if ($latestBackup) {
    Write-Host "`n[Cleanup] Latest backup found: $($latestBackup.FullName)" -ForegroundColor Cyan
    $regFiles = Get-ChildItem $latestBackup.FullName -Filter "*.reg"

    if ($regFiles.Count -gt 0) {
        Write-Host "  Available .reg backups:" -ForegroundColor Cyan
        $regFiles | ForEach-Object { Write-Host "    - $($_.Name)" -ForegroundColor DarkGray }

        # Uncomment the lines below to actually restore. Left commented to avoid
        # blindly importing — review the backup contents first.
        # foreach ($reg in $regFiles) {
        #     Write-Host "  IMPORTING: $($reg.FullName)" -ForegroundColor Yellow
        #     & reg.exe import $reg.FullName 2>&1 | Out-Null
        # }
        # Write-Host "  Registry restore complete." -ForegroundColor Green

        Write-Host "`n  To restore, uncomment the import block above or run manually:" -ForegroundColor Yellow
        $regFiles | ForEach-Object {
            Write-Host "    reg.exe import `"$($_.FullName)`"" -ForegroundColor White
        }
    } else {
        Write-Host "  No .reg files found in backup directory." -ForegroundColor Red
    }
} else {
    Write-Host "`n[Cleanup] No backup directory found under C:\ProgramData\IntuneEnrollmentRepair" -ForegroundColor Red
}

# --- Step 3: Re-seed DEADBEEF test GUID with proper Intune-stale attributes ---
Write-Host "`n[Cleanup] Re-seeding DEADBEEF test GUID..." -ForegroundColor Cyan

# Enrollment key with values that match the stale detection criteria
# EnrollmentType=6 (MDM) + DiscoveryServiceFullURL containing manage.microsoft.com
New-Item -Path "HKLM:\SOFTWARE\Microsoft\Enrollments\$testGuid" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Enrollments\$testGuid" -Name "EnrollmentType" -Value 6 -Type DWord
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Enrollments\$testGuid" -Name "DiscoveryServiceFullURL" -Value "https://enrollment.manage.microsoft.com/enrollmentserver/discovery.svc"
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Enrollments\$testGuid" -Name "UPN" -Value "test@contoso.com"
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Enrollments\$testGuid" -Name "ProviderID" -Value "MS DM Server"
Write-Host "  SEEDED:  Enrollments\$testGuid" -ForegroundColor Green

# OMADM Accounts / Sessions / Logger — these are the extended hives
# that the previous partial-cleanup test proved need to be covered
New-Item -Path "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts\$testGuid" -Force | Out-Null
New-Item -Path "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Sessions\$testGuid" -Force | Out-Null
New-Item -Path "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Logger\$testGuid" -Force | Out-Null
Write-Host "  SEEDED:  OMADM\Accounts, Sessions, Logger\$testGuid" -ForegroundColor Green

# --- Step 4: Verify final state ---
Write-Host "`n[Verify] DEADBEEF key presence check:" -ForegroundColor Cyan
foreach ($p in $paths) {
    $exists = Test-Path $p
    $color = if ($exists) { "Green" } else { "Red" }
    $label = if ($exists) { "EXISTS" } else { "MISSING" }
    Write-Host "  $label : $p" -ForegroundColor $color
}

# Expected output after cleanup:
#   EXISTS  : Enrollments\DEADBEEF-...
#   MISSING : Enrollments\Status\DEADBEEF-...     (not seeded, created by enrollment only)
#   EXISTS  : OMADM\Accounts\DEADBEEF-...
#   EXISTS  : OMADM\Sessions\DEADBEEF-...
#   EXISTS  : OMADM\Logger\DEADBEEF-...
#   MISSING : PolicyManager\Providers\DEADBEEF-... (not seeded, created by policy push only)
#   MISSING : ERM\Tracked\DEADBEEF-...             (not seeded, created by enrollment only)

Write-Host "`n[Done] Ready for re-test. Run:" -ForegroundColor Cyan
Write-Host "  .\Attestation_DevC.ps1 -TestMode -TestProfile Stale -Remediate" -ForegroundColor White
Write-Host ""