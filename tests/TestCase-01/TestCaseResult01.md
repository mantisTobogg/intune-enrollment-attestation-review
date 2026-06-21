Testing Results: 


# TESTCASE (Switch Testing Results) 
# Detection only â€” should classify as StaleEnrollmentSuspected
# .\Attestation_DevB.ps1 -TestMode

---

```pwsh
PS C:\Users\SystemAdministrator\Downloads\intune-enrollment-attestation-review> notepad .\TestCaseConfig.ps1
PS C:\Users\SystemAdministrator\Downloads\intune-enrollment-attestation-review> .\Attestation_DevB.ps1 -TestMode
[TestMode] Dsregcmd values fabrication for -Remediate case testing purposes

Name                           Value
----                           -----
ComputerName                   DESKTOP-BEOI6P3
Time                           2026-06-20T16:09:51
DomainJoined                   NO
AzureAdJoined                  YES
WorkplaceJoined                NO
TenantName                     Gamtoso
DeviceAuthStatus               SUCCESS
MdmUrl                         https://enrollment.manage.microsoft.com/enrollmentserver/discovery.svc
MdmUrlPresent                  True
EnrollmentGuidCount            36
EnrollmentGuids                0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;132979AB-E4E8-4B45-A24B-8813CB398907;18DCFFD4-37D6â€¦
StatusGuidCount                2
StatusGuids                    0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;697258CB-5C4D-4851-B5C9-FDD4B060E4EE
OmadmGuidCount                 3
OmadmGuids                     0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;697258CB-5C4D-4851-B5C9-FDD4B060E4EE;DEADBEEF-1234â€¦
OmadmSessionGuidCount          3
OmadmSessionGuids              0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;697258CB-5C4D-4851-B5C9-FDD4B060E4EE;DEADBEEF-1234â€¦
OmadmLoggerGuidCount           3
OmadmLoggerGuids               0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;697258CB-5C4D-4851-B5C9-FDD4B060E4EE;DEADBEEF-1234â€¦
PolicyProviderGuidCount        8
PolicyProviderGuids            1e05dd5d-a022-46c5-963c-b20de341170f;2648BF76-DA4B-409A-BFFA-6AF111C298A5;697258CB-5C4Dâ€¦
TrackedGuidCount               2
TrackedGuids                   0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;697258CB-5C4D-4851-B5C9-FDD4B060E4EE
OmadmGuidsInEnrollmentCount    3
OmadmGuidsInEnrollment         0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;697258CB-5C4D-4851-B5C9-FDD4B060E4EE;DEADBEEF-1234â€¦
EnrollmentGuidsNotInOmadmCount 33
EnrollmentGuidsNotInOmadm      132979AB-E4E8-4B45-A24B-8813CB398907;18DCFFD4-37D6-4BC6-87E0-4266FDBB8E49;1E05DD5D-A022â€¦
OmadmGuidsNotInEnrollmentCount 0
OmadmGuidsNotInEnrollment
StatusGuidsNotInEnrollmentCouâ€¦ 0
StatusGuidsNotInEnrollment
OmadmSessionGuidsNotInEnrollmâ€¦ 0
OmadmSessionGuidsNotInEnrollmâ€¦
OmadmLoggerGuidsNotInEnrollmeâ€¦ 0
OmadmLoggerGuidsNotInEnrollmeâ€¦
PolicyProviderGuidsNotInEnrolâ€¦ 0
PolicyProviderGuidsNotInEnrolâ€¦
TrackedGuidsNotInEnrollmentCoâ€¦ 0
TrackedGuidsNotInEnrollment
EnterpriseMgmtTaskCount        32
RecentErrorCount               154
BlockingErrorCount             0
Has400Reject                   False
HasAadEnrollDenied             False
Classification                 HealthyManaged
RecommendedAction              No remediation.
BackupDir                      C:\ProgramData\IntuneEnrollmentRepair\20260620_160949
RemediationAttempted           False
RemediationResult              Not run
```

---


# TESTCASE 
# Remediation â€” should backup then delete DEADBEEF from all hives
# .\Attestation_DevB.ps1 -TestMode -Remediate

```pwsh
PS C:\Users\SystemAdministrator\Downloads\intune-enrollment-attestation-review> .\Attestation_DevB.ps1 -TestMode -Remediate
[TestMode] Dsregcmd values fabrication for -Remediate case testing purposes

Name                           Value
----                           -----
ComputerName                   DESKTOP-BEOI6P3
Time                           2026-06-20T16:12:50
DomainJoined                   NO
AzureAdJoined                  YES
WorkplaceJoined                NO
TenantName                     Gamtoso
DeviceAuthStatus               SUCCESS
MdmUrl                         https://enrollment.manage.microsoft.com/enrollmentserver/discovery.svc
MdmUrlPresent                  True
EnrollmentGuidCount            36
EnrollmentGuids                0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;132979AB-E4E8-4B45-A24B-8813CB398907;18DCFFD4-37D6â€¦
StatusGuidCount                2
StatusGuids                    0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;697258CB-5C4D-4851-B5C9-FDD4B060E4EE
OmadmGuidCount                 3
OmadmGuids                     0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;697258CB-5C4D-4851-B5C9-FDD4B060E4EE;DEADBEEF-1234â€¦
OmadmSessionGuidCount          3
OmadmSessionGuids              0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;697258CB-5C4D-4851-B5C9-FDD4B060E4EE;DEADBEEF-1234â€¦
OmadmLoggerGuidCount           3
OmadmLoggerGuids               0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;697258CB-5C4D-4851-B5C9-FDD4B060E4EE;DEADBEEF-1234â€¦
PolicyProviderGuidCount        8
PolicyProviderGuids            1e05dd5d-a022-46c5-963c-b20de341170f;2648BF76-DA4B-409A-BFFA-6AF111C298A5;697258CB-5C4Dâ€¦
TrackedGuidCount               2
TrackedGuids                   0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;697258CB-5C4D-4851-B5C9-FDD4B060E4EE
OmadmGuidsInEnrollmentCount    3
OmadmGuidsInEnrollment         0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;697258CB-5C4D-4851-B5C9-FDD4B060E4EE;DEADBEEF-1234â€¦
EnrollmentGuidsNotInOmadmCount 33
EnrollmentGuidsNotInOmadm      132979AB-E4E8-4B45-A24B-8813CB398907;18DCFFD4-37D6-4BC6-87E0-4266FDBB8E49;1E05DD5D-A022â€¦
OmadmGuidsNotInEnrollmentCount 0
OmadmGuidsNotInEnrollment
StatusGuidsNotInEnrollmentCouâ€¦ 0
StatusGuidsNotInEnrollment
OmadmSessionGuidsNotInEnrollmâ€¦ 0
OmadmSessionGuidsNotInEnrollmâ€¦
OmadmLoggerGuidsNotInEnrollmeâ€¦ 0
OmadmLoggerGuidsNotInEnrollmeâ€¦
PolicyProviderGuidsNotInEnrolâ€¦ 0
PolicyProviderGuidsNotInEnrolâ€¦
TrackedGuidsNotInEnrollmentCoâ€¦ 0
TrackedGuidsNotInEnrollment
EnterpriseMgmtTaskCount        32
RecentErrorCount               155
BlockingErrorCount             0
Has400Reject                   False
HasAadEnrollDenied             False
Classification                 HealthyManaged
RecommendedAction              No remediation.
BackupDir                      C:\ProgramData\IntuneEnrollmentRepair\20260620_161249
RemediationAttempted           False
RemediationResult              Skipped: HealthyManaged.
```


---

# TESTCASE 
# Full â€” should also trigger DeviceEnroller (will fail on Home, but tests the path)
# .\Attestation_DevB.ps1 -TestMode -Remediate -RunDeviceEnroller


---

```pwsh
PS C:\Users\SystemAdministrator\Downloads\intune-enrollment-attestation-review> .\Attestation_DevB.ps1 -TestMode -Remediate -RunDeviceEnroller
[TestMode] Dsregcmd values fabrication for -Remediate case testing purposes

Name                           Value
----                           -----
ComputerName                   DESKTOP-BEOI6P3
Time                           2026-06-20T16:14:41
DomainJoined                   NO
AzureAdJoined                  YES
WorkplaceJoined                NO
TenantName                     Gamtoso
DeviceAuthStatus               SUCCESS
MdmUrl                         https://enrollment.manage.microsoft.com/enrollmentserver/discovery.svc
MdmUrlPresent                  True
EnrollmentGuidCount            36
EnrollmentGuids                0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;132979AB-E4E8-4B45-A24B-8813CB398907;18DCFFD4-37D6â€¦
StatusGuidCount                2
StatusGuids                    0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;697258CB-5C4D-4851-B5C9-FDD4B060E4EE
OmadmGuidCount                 3
OmadmGuids                     0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;697258CB-5C4D-4851-B5C9-FDD4B060E4EE;DEADBEEF-1234â€¦
OmadmSessionGuidCount          3
OmadmSessionGuids              0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;697258CB-5C4D-4851-B5C9-FDD4B060E4EE;DEADBEEF-1234â€¦
OmadmLoggerGuidCount           3
OmadmLoggerGuids               0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;697258CB-5C4D-4851-B5C9-FDD4B060E4EE;DEADBEEF-1234â€¦
PolicyProviderGuidCount        8
PolicyProviderGuids            1e05dd5d-a022-46c5-963c-b20de341170f;2648BF76-DA4B-409A-BFFA-6AF111C298A5;697258CB-5C4Dâ€¦
TrackedGuidCount               2
TrackedGuids                   0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;697258CB-5C4D-4851-B5C9-FDD4B060E4EE
OmadmGuidsInEnrollmentCount    3
OmadmGuidsInEnrollment         0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;697258CB-5C4D-4851-B5C9-FDD4B060E4EE;DEADBEEF-1234â€¦
EnrollmentGuidsNotInOmadmCount 33
EnrollmentGuidsNotInOmadm      132979AB-E4E8-4B45-A24B-8813CB398907;18DCFFD4-37D6-4BC6-87E0-4266FDBB8E49;1E05DD5D-A022â€¦
OmadmGuidsNotInEnrollmentCount 0
OmadmGuidsNotInEnrollment
StatusGuidsNotInEnrollmentCouâ€¦ 0
StatusGuidsNotInEnrollment
OmadmSessionGuidsNotInEnrollmâ€¦ 0
OmadmSessionGuidsNotInEnrollmâ€¦
OmadmLoggerGuidsNotInEnrollmeâ€¦ 0
OmadmLoggerGuidsNotInEnrollmeâ€¦
PolicyProviderGuidsNotInEnrolâ€¦ 0
PolicyProviderGuidsNotInEnrolâ€¦
TrackedGuidsNotInEnrollmentCoâ€¦ 0
TrackedGuidsNotInEnrollment
EnterpriseMgmtTaskCount        32
RecentErrorCount               155
BlockingErrorCount             0
Has400Reject                   False
HasAadEnrollDenied             False
Classification                 HealthyManaged
RecommendedAction              No remediation.
BackupDir                      C:\ProgramData\IntuneEnrollmentRepair\20260620_161439
RemediationAttempted           False
RemediationResult              Skipped: HealthyManaged.

```

## VERDICT: Failure


All three classified as HealthyManaged and skipped ¿ TestMode override is too healthy. 
TestMode sets:
  AzureAdJoined    = YES  ¿
  DeviceAuthStatus = SUCCESS  ¿
  MdmUrl           = https://enrollment.manage.microsoft.com/...  ¿ this is the problem
  MdmUrlPresent    = True

Real registry on this box has:
  OmadmGuidCount          = 3
  EnterpriseMgmtTaskCount = 32

Classification logic:
  AzureAdJoined=YES + MdmUrlPresent=True + OmadmGuids>0 + Tasks>0
  ¿ HealthyManaged  ¿ every time, all three runs
The HealthyManaged gate fires before anything else gets a chance. 
