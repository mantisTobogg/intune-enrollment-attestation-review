# TEST CASE 02/C RESULTS

## TestMode Switch Results

```pwsh
PS C:\Users\SystemAdministrator\Downloads\intune-enrollment-attestation-review> .\Attestation_DevC.ps1 -TestMode
[TestMode] Profile: Stale — dsregcmd/event overrides active

Name                           Value
----                           -----
ComputerName                   DESKTOP-BEOI6P3
Time                           2026-06-20T17:23:40
DomainJoined                   NO
AzureAdJoined                  YES
WorkplaceJoined                NO
TenantName                     Gamtoso
DeviceAuthStatus               SUCCESS
MdmUrl
MdmUrlPresent                  False
EnrollmentGuidCount            36
EnrollmentGuids                0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;132979AB-E4E8-4B45-A24B-8813CB398907;18DCFFD4-37D6…
StatusGuidCount                2
StatusGuids                    0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;697258CB-5C4D-4851-B5C9-FDD4B060E4EE
OmadmGuidCount                 3
OmadmGuids                     0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;697258CB-5C4D-4851-B5C9-FDD4B060E4EE;DEADBEEF-1234…
OmadmSessionGuidCount          3
OmadmSessionGuids              0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;697258CB-5C4D-4851-B5C9-FDD4B060E4EE;DEADBEEF-1234…
OmadmLoggerGuidCount           3
OmadmLoggerGuids               0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;697258CB-5C4D-4851-B5C9-FDD4B060E4EE;DEADBEEF-1234…
PolicyProviderGuidCount        8
PolicyProviderGuids            1e05dd5d-a022-46c5-963c-b20de341170f;2648BF76-DA4B-409A-BFFA-6AF111C298A5;697258CB-5C4D…
TrackedGuidCount               2
TrackedGuids                   0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;697258CB-5C4D-4851-B5C9-FDD4B060E4EE
OmadmGuidsInEnrollmentCount    3
OmadmGuidsInEnrollment         0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;697258CB-5C4D-4851-B5C9-FDD4B060E4EE;DEADBEEF-1234…
EnrollmentGuidsNotInOmadmCount 33
EnrollmentGuidsNotInOmadm      132979AB-E4E8-4B45-A24B-8813CB398907;18DCFFD4-37D6-4BC6-87E0-4266FDBB8E49;1E05DD5D-A022…
OmadmGuidsNotInEnrollmentCount 0
OmadmGuidsNotInEnrollment
StatusGuidsNotInEnrollmentCou… 0
StatusGuidsNotInEnrollment
OmadmSessionGuidsNotInEnrollm… 0
OmadmSessionGuidsNotInEnrollm…
OmadmLoggerGuidsNotInEnrollme… 0
OmadmLoggerGuidsNotInEnrollme…
PolicyProviderGuidsNotInEnrol… 0
PolicyProviderGuidsNotInEnrol…
TrackedGuidsNotInEnrollmentCo… 0
TrackedGuidsNotInEnrollment
EnterpriseMgmtTaskCount        32
RecentErrorCount               157
BlockingErrorCount             0
Has400Reject                   False
HasAadEnrollDenied             False
Classification                 StaleEnrollmentSuspected
RecommendedAction              Backup stale enrollment state, remove stale GUID artifacts, then run DeviceEnroller.
BackupDir                      C:\ProgramData\IntuneEnrollmentRepair\20260620_172338
RemediationAttempted           False
RemediationResult              Not run
```

---

## TestMode Remediation Run: 1

### Expected: Stale + remediate — should backup + delete DEADBEEF from all hives

```pwsh
PS C:\Users\SystemAdministrator\Downloads\intune-enrollment-attestation-review> .\Attestation_DevC.ps1 -TestMode -TestProfile Stale -Remediate
[TestMode] Profile: Stale — dsregcmd/event overrides active

Name                           Value
----                           -----
ComputerName                   DESKTOP-BEOI6P3
Time                           2026-06-20T17:28:33
DomainJoined                   NO
AzureAdJoined                  YES
WorkplaceJoined                NO
TenantName                     Gamtoso
DeviceAuthStatus               SUCCESS
MdmUrl
MdmUrlPresent                  False
EnrollmentGuidCount            36
EnrollmentGuids                0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;132979AB-E4E8-4B45-A24B-8813CB398907;18DCFFD4-37D6-4BC6-87E0-4266FDBB8E49;1E05DD5D-A022-46C5-963C-B2…
StatusGuidCount                2
StatusGuids                    0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;697258CB-5C4D-4851-B5C9-FDD4B060E4EE
OmadmGuidCount                 3
OmadmGuids                     0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;697258CB-5C4D-4851-B5C9-FDD4B060E4EE;DEADBEEF-1234-5678-9ABC-DEF012345678
OmadmSessionGuidCount          3
OmadmSessionGuids              0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;697258CB-5C4D-4851-B5C9-FDD4B060E4EE;DEADBEEF-1234-5678-9ABC-DEF012345678
OmadmLoggerGuidCount           3
OmadmLoggerGuids               0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;697258CB-5C4D-4851-B5C9-FDD4B060E4EE;DEADBEEF-1234-5678-9ABC-DEF012345678
PolicyProviderGuidCount        8
PolicyProviderGuids            1e05dd5d-a022-46c5-963c-b20de341170f;2648BF76-DA4B-409A-BFFA-6AF111C298A5;697258CB-5C4D-4851-B5C9-FDD4B060E4EE;8d196d7f-3eef-48ad-8bea-be…
TrackedGuidCount               2
TrackedGuids                   0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;697258CB-5C4D-4851-B5C9-FDD4B060E4EE
OmadmGuidsInEnrollmentCount    3
OmadmGuidsInEnrollment         0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;697258CB-5C4D-4851-B5C9-FDD4B060E4EE;DEADBEEF-1234-5678-9ABC-DEF012345678
EnrollmentGuidsNotInOmadmCount 33
EnrollmentGuidsNotInOmadm      132979AB-E4E8-4B45-A24B-8813CB398907;18DCFFD4-37D6-4BC6-87E0-4266FDBB8E49;1E05DD5D-A022-46C5-963C-B20DE341170F;23CB517F-5073-4E96-A202-7F…
OmadmGuidsNotInEnrollmentCount 0
OmadmGuidsNotInEnrollment
StatusGuidsNotInEnrollmentCou… 0
StatusGuidsNotInEnrollment
OmadmSessionGuidsNotInEnrollm… 0
OmadmSessionGuidsNotInEnrollm…
OmadmLoggerGuidsNotInEnrollme… 0
OmadmLoggerGuidsNotInEnrollme…
PolicyProviderGuidsNotInEnrol… 0
PolicyProviderGuidsNotInEnrol…
TrackedGuidsNotInEnrollmentCo… 0
TrackedGuidsNotInEnrollment
EnterpriseMgmtTaskCount        32
RecentErrorCount               160
BlockingErrorCount             0
Has400Reject                   False
HasAadEnrollDenied             False
Classification                 StaleEnrollmentSuspected
RecommendedAction              Backup stale enrollment state, remove stale GUID artifacts, then run DeviceEnroller.
BackupDir                      C:\ProgramData\IntuneEnrollmentRepair\20260620_172831
RemediationAttempted           True
RemediationResult              Artifact cleanup completed. DeviceEnroller NOT run (switch not specified).
```

---

## TestMode Remediation Run: 2 Reject Switch active

### `.\Attestation_DevC.ps1 -TestMode -TestProfile Rejected -Remediate`

```pwsh

Name                           Value
----                           -----
ComputerName                   DESKTOP-BEOI6P3
Time                           2026-06-20T17:26:04
DomainJoined                   NO
AzureAdJoined                  YES
WorkplaceJoined                NO
TenantName                     Gamtoso
DeviceAuthStatus               SUCCESS
MdmUrl                         
MdmUrlPresent                  False
EnrollmentGuidCount            36
EnrollmentGuids                0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;132979AB-E4E8-4B45-A24B-8813CB398907;18DCFFD4-37D6-ΓÇª
StatusGuidCount                2
StatusGuids                    0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;697258CB-5C4D-4851-B5C9-FDD4B060E4EE
OmadmGuidCount                 3
OmadmGuids                     0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;697258CB-5C4D-4851-B5C9-FDD4B060E4EE;DEADBEEF-1234-ΓÇª
OmadmSessionGuidCount          3
OmadmSessionGuids              0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;697258CB-5C4D-4851-B5C9-FDD4B060E4EE;DEADBEEF-1234-ΓÇª
OmadmLoggerGuidCount           3
OmadmLoggerGuids               0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;697258CB-5C4D-4851-B5C9-FDD4B060E4EE;DEADBEEF-1234-ΓÇª
PolicyProviderGuidCount        8
PolicyProviderGuids            1e05dd5d-a022-46c5-963c-b20de341170f;2648BF76-DA4B-409A-BFFA-6AF111C298A5;697258CB-5C4D-ΓÇª
TrackedGuidCount               2
TrackedGuids                   0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;697258CB-5C4D-4851-B5C9-FDD4B060E4EE
OmadmGuidsInEnrollmentCount    3
OmadmGuidsInEnrollment         0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;697258CB-5C4D-4851-B5C9-FDD4B060E4EE;DEADBEEF-1234-ΓÇª
EnrollmentGuidsNotInOmadmCount 33
EnrollmentGuidsNotInOmadm      132979AB-E4E8-4B45-A24B-8813CB398907;18DCFFD4-37D6-4BC6-87E0-4266FDBB8E49;1E05DD5D-A022-ΓÇª
OmadmGuidsNotInEnrollmentCount 0
OmadmGuidsNotInEnrollment      
StatusGuidsNotInEnrollmentCouΓÇª 0
StatusGuidsNotInEnrollment     
OmadmSessionGuidsNotInEnrollmΓÇª 0
OmadmSessionGuidsNotInEnrollmΓÇª 
OmadmLoggerGuidsNotInEnrollmeΓÇª 0
OmadmLoggerGuidsNotInEnrollmeΓÇª 
PolicyProviderGuidsNotInEnrolΓÇª 0
PolicyProviderGuidsNotInEnrolΓÇª 
TrackedGuidsNotInEnrollmentCoΓÇª 0
TrackedGuidsNotInEnrollment    
EnterpriseMgmtTaskCount        32
RecentErrorCount               159
BlockingErrorCount             0
Has400Reject                   True
HasAadEnrollDenied             True
Classification                 EnrollmentRejectedByService
RecommendedAction              Do NOT clean local artifacts. Discovery succeeds but the service rejects the enrollment ΓÇª
BackupDir                      C:\ProgramData\IntuneEnrollmentRepair\20260620_172602
RemediationAttempted           False
RemediationResult              Skipped: service-side rejection (HTTP 400 + AADEnrollAsync denied). Local cleanup cannotΓÇª
```

---

## TestMode Remediation Run: 3

### Expected: Healthy — should classify HealthyManaged, skip

```pwsh
PS C:\Users\SystemAdministrator\Downloads\intune-enrollment-attestation-review> .\Attestation_DevC.ps1 -TestMode -TestProfile Healthy
[TestMode] Profile: Healthy — dsregcmd/event overrides active

Name                           Value
----                           -----
ComputerName                   DESKTOP-BEOI6P3
Time                           2026-06-20T17:30:17
DomainJoined                   NO
AzureAdJoined                  YES
WorkplaceJoined                NO
TenantName                     Gamtoso
DeviceAuthStatus               SUCCESS
MdmUrl                         https://enrollment.manage.microsoft.com/enrollmentserver/discovery.svc
MdmUrlPresent                  True
EnrollmentGuidCount            34
EnrollmentGuids                0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;132979AB-E4E8-4B45-A24B-8813CB398907;18DCFFD4-37D6-4BC6-87E0-4266FDBB8E49;1E05DD5D-A022-46C5-963C-B2…
StatusGuidCount                1
StatusGuids                    0A745E67-0B8C-4D3A-B183-D1063BB5CFBD
OmadmGuidCount                 1
OmadmGuids                     0A745E67-0B8C-4D3A-B183-D1063BB5CFBD
OmadmSessionGuidCount          1
OmadmSessionGuids              0A745E67-0B8C-4D3A-B183-D1063BB5CFBD
OmadmLoggerGuidCount           1
OmadmLoggerGuids               0A745E67-0B8C-4D3A-B183-D1063BB5CFBD
PolicyProviderGuidCount        7
PolicyProviderGuids            1e05dd5d-a022-46c5-963c-b20de341170f;2648BF76-DA4B-409A-BFFA-6AF111C298A5;8d196d7f-3eef-48ad-8bea-be749f12d3ad;8fb7d64e-70fc-4f9d-89ee-d4…
TrackedGuidCount               1
TrackedGuids                   0A745E67-0B8C-4D3A-B183-D1063BB5CFBD
OmadmGuidsInEnrollmentCount    1
OmadmGuidsInEnrollment         0A745E67-0B8C-4D3A-B183-D1063BB5CFBD
EnrollmentGuidsNotInOmadmCount 33
EnrollmentGuidsNotInOmadm      132979AB-E4E8-4B45-A24B-8813CB398907;18DCFFD4-37D6-4BC6-87E0-4266FDBB8E49;1E05DD5D-A022-46C5-963C-B20DE341170F;23CB517F-5073-4E96-A202-7F…
OmadmGuidsNotInEnrollmentCount 0
OmadmGuidsNotInEnrollment
StatusGuidsNotInEnrollmentCou… 0
StatusGuidsNotInEnrollment
OmadmSessionGuidsNotInEnrollm… 0
OmadmSessionGuidsNotInEnrollm…
OmadmLoggerGuidsNotInEnrollme… 0
OmadmLoggerGuidsNotInEnrollme…
PolicyProviderGuidsNotInEnrol… 0
PolicyProviderGuidsNotInEnrol…
TrackedGuidsNotInEnrollmentCo… 0
TrackedGuidsNotInEnrollment
EnterpriseMgmtTaskCount        16
RecentErrorCount               160
BlockingErrorCount             0
Has400Reject                   False
HasAadEnrollDenied             False
Classification                 HealthyManaged
RecommendedAction              No remediation.
BackupDir                      C:\ProgramData\IntuneEnrollmentRepair\20260620_173015
RemediationAttempted           False
RemediationResult              Not run
```

---

## TestMode Remediation Run: 4

### MdmMissing — remove DEADBEEF seed first, then should classify EntraJoinedButMDMMissing

```pwsh
PS C:\Users\SystemAdministrator\Downloads\intune-enrollment-attestation-review> .\Attestation_DevC.ps1 -TestMode -TestProfile MdmMissing
[TestMode] Profile: MdmMissing — dsregcmd/event overrides active

Name                           Value
----                           -----
ComputerName                   DESKTOP-BEOI6P3
Time                           2026-06-20T17:31:23
DomainJoined                   NO
AzureAdJoined                  YES
WorkplaceJoined                NO
TenantName                     Gamtoso
DeviceAuthStatus               SUCCESS
MdmUrl
MdmUrlPresent                  False
EnrollmentGuidCount            34
EnrollmentGuids                0A745E67-0B8C-4D3A-B183-D1063BB5CFBD;132979AB-E4E8-4B45-A24B-8813CB398907;18DCFFD4-37D6-4BC6-87E0-4266FDBB8E49;1E05DD5D-A022-46C5-963C-B2…
StatusGuidCount                1
StatusGuids                    0A745E67-0B8C-4D3A-B183-D1063BB5CFBD
OmadmGuidCount                 1
OmadmGuids                     0A745E67-0B8C-4D3A-B183-D1063BB5CFBD
OmadmSessionGuidCount          1
OmadmSessionGuids              0A745E67-0B8C-4D3A-B183-D1063BB5CFBD
OmadmLoggerGuidCount           1
OmadmLoggerGuids               0A745E67-0B8C-4D3A-B183-D1063BB5CFBD
PolicyProviderGuidCount        7
PolicyProviderGuids            1e05dd5d-a022-46c5-963c-b20de341170f;2648BF76-DA4B-409A-BFFA-6AF111C298A5;8d196d7f-3eef-48ad-8bea-be749f12d3ad;8fb7d64e-70fc-4f9d-89ee-d4…
TrackedGuidCount               1
TrackedGuids                   0A745E67-0B8C-4D3A-B183-D1063BB5CFBD
OmadmGuidsInEnrollmentCount    1
OmadmGuidsInEnrollment         0A745E67-0B8C-4D3A-B183-D1063BB5CFBD
EnrollmentGuidsNotInOmadmCount 33
EnrollmentGuidsNotInOmadm      132979AB-E4E8-4B45-A24B-8813CB398907;18DCFFD4-37D6-4BC6-87E0-4266FDBB8E49;1E05DD5D-A022-46C5-963C-B20DE341170F;23CB517F-5073-4E96-A202-7F…
OmadmGuidsNotInEnrollmentCount 0
OmadmGuidsNotInEnrollment
StatusGuidsNotInEnrollmentCou… 0
StatusGuidsNotInEnrollment
OmadmSessionGuidsNotInEnrollm… 0
OmadmSessionGuidsNotInEnrollm…
OmadmLoggerGuidsNotInEnrollme… 0
OmadmLoggerGuidsNotInEnrollme…
PolicyProviderGuidsNotInEnrol… 0
PolicyProviderGuidsNotInEnrol…
TrackedGuidsNotInEnrollmentCo… 0
TrackedGuidsNotInEnrollment
EnterpriseMgmtTaskCount        16
RecentErrorCount               162
BlockingErrorCount             0
Has400Reject                   False
HasAadEnrollDenied             False
Classification                 StaleEnrollmentSuspected
RecommendedAction              Backup stale enrollment state, remove stale GUID artifacts, then run DeviceEnroller.
BackupDir                      C:\ProgramData\IntuneEnrollmentRepair\20260620_173122
RemediationAttempted           False
RemediationResult              Not run
```

## VERDICT

### TIMELINE (Reset was not initiated but results still stand)

Run 1 (Stale, detection only)     → DEADBEEF + 697258CB still present
Run 2 (Stale -Remediate)          → script ACTUALLY DELETED both
Run 3 (Rejected -Remediate)       → DEADBEEF already gone, but Rejected override fired anyway
Run 4 (Healthy)                   → DEADBEEF already gone, Healthy override fired anyway
Run 5 (MdmMissing)                → DEADBEEF already gone, 697258CB gone too
