# Run from the repository root in an elevated PowerShell session.
# This validates that switch combinations do not remediate a HealthyManaged device.

$root = "C:\ProgramData\IntuneEnrollmentRepair-SwitchTest"

.\Attestation_Review.ps1 -BackupRoot $root
.\Attestation_Review.ps1 -RunDeviceEnroller -BackupRoot $root
.\Attestation_Review.ps1 -Remediate -BackupRoot $root
.\Attestation_Review.ps1 -Remediate -RunDeviceEnroller -BackupRoot $root
