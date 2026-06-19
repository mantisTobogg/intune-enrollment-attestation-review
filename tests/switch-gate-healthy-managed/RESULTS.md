# Switch Gate Test Results - HealthyManaged

Test date: 2026-06-19

Device under test:

```text
ComputerName=DESKTOP-BEOI6P3
AzureAdJoined=YES
DomainJoined=NO
WorkplaceJoined=NO
DeviceAuthStatus=SUCCESS
MdmUrlPresent=True
TenantName=Gamtoso
Classification=HealthyManaged
RecommendedAction=No remediation.
```

Test root:

```text
C:\ProgramData\IntuneEnrollmentRepair-SwitchTest
```

## Commands

```powershell
$root = "C:\ProgramData\IntuneEnrollmentRepair-SwitchTest"

.\Attestation_Review.ps1 -BackupRoot $root
.\Attestation_Review.ps1 -RunDeviceEnroller -BackupRoot $root
.\Attestation_Review.ps1 -Remediate -BackupRoot $root
.\Attestation_Review.ps1 -Remediate -RunDeviceEnroller -BackupRoot $root
```

## Observed Results

| Run | Timestamp | Switches | Classification | RemediationAttempted | RemediationResult |
| --- | --------- | -------- | -------------- | -------------------- | ----------------- |
| 1 | 2026-06-19T14:26:17 | `-BackupRoot` | `HealthyManaged` | `False` | `Not run` |
| 2 | 2026-06-19T14:26:19 | `-RunDeviceEnroller -BackupRoot` | `HealthyManaged` | `False` | `Not run` |
| 3 | 2026-06-19T14:26:21 | `-Remediate -BackupRoot` | `HealthyManaged` | `False` | `Skipped: HealthyManaged.` |
| 4 | 2026-06-19T14:26:23 | `-Remediate -RunDeviceEnroller -BackupRoot` | `HealthyManaged` | `False` | `Skipped: HealthyManaged.` |

## Key Evidence

```text
EnrollmentGuidCount=35
StatusGuidCount=2
OmadmGuidCount=2
OmadmSessionGuidCount=2
OmadmLoggerGuidCount=2
PolicyProviderGuidCount=8
TrackedGuidCount=2
OmadmGuidsInEnrollmentCount=2
EnrollmentGuidsNotInOmadmCount=33
OmadmGuidsNotInEnrollmentCount=0
StatusGuidsNotInEnrollmentCount=0
OmadmSessionGuidsNotInEnrollmentCount=0
OmadmLoggerGuidsNotInEnrollmentCount=0
PolicyProviderGuidsNotInEnrollmentCount=0
TrackedGuidsNotInEnrollmentCount=0
EnterpriseMgmtTaskCount=32
BlockingErrorCount=0
Has400Reject=False
HasAadEnrollDenied=False
```

## Expected Outcome Confirmation

The test passed for the HealthyManaged switch gate.

- Detection-only mode did not attempt remediation.
- `-RunDeviceEnroller` without `-Remediate` did not change behavior.
- `-Remediate` on a HealthyManaged device skipped cleanup.
- `-Remediate -RunDeviceEnroller` on a HealthyManaged device also skipped cleanup.
- GUID correlation fields were present and remained diagnostic-only.

For exact GUID values, use the generated `detection-result.json` files under the timestamped folders. The PowerShell console table may truncate long GUID lists.
