# TestCondition requires Registry Values Configuration
# Admin Auth is Required. 
# FYI: `Set-ExecutionPolicy Bypass -Scope CurrentUser -Force`
# ==================================================================
# Stale, Fake GUID creation
# ==================================================================
# Detection only — should classify as StaleEnrollmentSuspected
# `.\IntuneEnrollmentRepair.ps1 -TestMode`

# Remediation — should backup then delete DEADBEEF from all hives
# `.\IntuneEnrollmentRepair.ps1 -TestMode -Remediate`

# Full — should also trigger DeviceEnroller (will fail on Home, but tests the path)
# `.\IntuneEnrollmentRepair.ps1 -TestMode -Remediate -RunDeviceEnroller`
#
# ==================================================================
$testGuid = "DEADBEEF-1234-5678-9ABC-DEF012345678"
$testPath = "HKLM:\SOFTWARE\Microsoft\Enrollments\$testGuid"
New-Item -Path $testPath -Force
Set-ItemProperty -Path $testPath -Name "EnrollmentType" -Value 6 -Type DWord
Set-ItemProperty -Path $testPath -Name "DiscoveryServiceFullURL" -Value "https://enrollment.manage.microsoft.com/enrollmentserver/discovery.svc"
Set-ItemProperty -Path $testPath -Name "UPN" -Value "test@contoso.com"
Set-ItemProperty -Path $testPath -Name "ProviderID" -Value "MS DM Server"

# Also seed OMADM to test extended hive cleanup
New-Item -Path "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts\$testGuid" -Force
New-Item -Path "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Sessions\$testGuid" -Force
New-Item -Path "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Logger\$testGuid" -Force

