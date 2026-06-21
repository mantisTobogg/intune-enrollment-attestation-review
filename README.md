# Intune Enrollment Attestation Review

A PowerShell script for **detecting, classifying, and optionally remediating** stale or broken Intune MDM enrollment state on Entra ID Joined Windows devices.

---

## Purpose

This repository provides a practical review and recovery aid for Windows devices whose Intune MDM enrollment state may be stale, incomplete, or inconsistent after Entra join or enrollment attempts.

The script is designed to be used first as a **read-only attestation tool**. It collects device registration state, enrollment registry evidence, scheduled task state, and recent MDM-related event log signals, then classifies the device into a small set of actionable outcomes. Optional remediation exists for carefully validated stale-enrollment cases, but detection-only review should always come first.

The goal is not to replace normal Intune or Entra troubleshooting. The goal is to make local enrollment evidence easier to inspect, classify, and pilot safely before any cleanup is attempted.

---

## Table of Contents

- [Purpose](#purpose)
- [Default Behavior - Detection Only](#default-behavior---detection-only)
- [Usage](#usage)
- [Output](#output)
- [Detection-Only Test Expectations](#detection-only-test-expectations)
- [Device Classifications](#device-classifications)
- [Functions](#functions)
- [Remediation Logic](#remediation-logic)
- [Recommended Rollout](#recommended-rollout)
- [TestMode](#testmode)
- [Legal Disclaimer](#legal-disclaimer)
- [License](#license)

---

## Default Behavior - Detection Only

**This script makes no changes to any system by default.**

Running the script without any switches is a fully read-only operation. It collects state information, writes a report, and exits. Nothing in the registry, scheduled tasks, or enrollment state is touched.

Remediation capabilities exist in the codebase but are gated behind explicit opt-in switches (`-Remediate`, `-RunDeviceEnroller`) that are **not present in the default invocation**. These switches should only be used after a detection-only pilot has been reviewed and classifications have been validated against known devices in your environment.

The default and recommended first-run mode is **detection and classification only**.

---

## Usage

```powershell
# Detection only (no changes made)
.\Attestation_Review.ps1

# Detection + remediation of stale enrollment artifacts
.\Attestation_Review.ps1 -Remediate

# Detection + remediation + trigger MDM re-enrollment
.\Attestation_Review.ps1 -Remediate -RunDeviceEnroller

# TestMode — simulate classification paths on a test device
.\Attestation_Review.ps1 -TestMode -TestProfile Stale
.\Attestation_Review.ps1 -TestMode -TestProfile Stale -Remediate
.\Attestation_Review.ps1 -TestMode -TestProfile Healthy
.\Attestation_Review.ps1 -TestMode -TestProfile Rejected -Remediate
.\Attestation_Review.ps1 -TestMode -TestProfile MdmMissing
```

**Parameters**

| Parameter            | Type       | Default                                 | Description                                                                           |
| -------------------- | ---------- | --------------------------------------- | ------------------------------------------------------------------------------------- |
| `-Remediate`         | Switch     | Off                                     | Enables artifact cleanup. Without this, the script is read-only.                      |
| `-RunDeviceEnroller` | Switch     | Off                                     | Triggers `DeviceEnroller.exe /c /AutoEnrollMDM` after eligible remediation. Requires `-Remediate`. |
| `-TestMode`          | Switch     | Off                                     | Overrides dsregcmd values with hardcoded test data after real collection. Enables classification path testing without a real device state. |
| `-TestProfile`       | String     | `Stale`                                 | Which classification path to simulate when `-TestMode` is active. Valid values: `Healthy`, `Stale`, `Rejected`, `MdmMissing`. |
| `-RecentHours`       | Int        | `72`                                    | How far back to query MDM and Device Registration event logs.                         |
| `-BackupRoot`        | String     | `C:\ProgramData\IntuneEnrollmentRepair` | Root path for timestamped backup directories and output reports.                      |

---

## Output

Every run writes to a timestamped folder under `BackupRoot` (e.g. `C:\ProgramData\IntuneEnrollmentRepair\20250608_143022\`):

| File                          | Description                                                                                   |
| ----------------------------- | --------------------------------------------------------------------------------------------- |
| `detection-result.json`       | Full detection snapshot — device state, GUID counts, classification, recommended action.      |
| `detection-result.txt`        | Same data in flat key=value format.                                                           |
| `remediation-result.json`     | Written only when `-Remediate` is used. Contains the final remediation outcome.               |
| `Enrollments.reg`             | Registry backup of `HKLM\SOFTWARE\Microsoft\Enrollments` (written before any cleanup).        |
| `OMADM.reg`                   | Registry backup of `HKLM\SOFTWARE\Microsoft\Provisioning\OMADM` (written before any cleanup). |
| `PolicyManager-Providers.reg` | Registry backup of `HKLM\SOFTWARE\Microsoft\PolicyManager\Providers` (written before cleanup). |
| `ERM-Tracked.reg`             | Registry backup of `HKLM\SOFTWARE\Microsoft\EnterpriseResourceManager\Tracked` (written before cleanup). |
| `remediation-write-error.txt` | Written only if the result JSON fails to save after remediation.                              |

The detection report also includes GUID correlation fields. These fields are diagnostic evidence only; they improve review visibility but do not change classification or remediation behavior.

| Field family | Meaning |
| ------------ | ------- |
| `OmadmGuidsInEnrollment*` | OMADM account GUIDs that also appear under `Enrollments`. |
| `EnrollmentGuidsNotInOmadm*` | Enrollment GUIDs with no matching OMADM account GUID. |
| `OmadmGuidsNotInEnrollment*` | OMADM account GUIDs with no matching enrollment GUID. |
| `StatusGuidsNotInEnrollment*` | `Enrollments\Status` GUIDs with no matching enrollment GUID. |
| `OmadmSessionGuidsNotInEnrollment*` | OMADM session GUIDs with no matching enrollment GUID. |
| `OmadmLoggerGuidsNotInEnrollment*` | OMADM logger GUIDs with no matching enrollment GUID. |
| `PolicyProviderGuidsNotInEnrollment*` | PolicyManager provider GUIDs with no matching enrollment GUID. |
| `TrackedGuidsNotInEnrollment*` | EnterpriseResourceManager tracked GUIDs with no matching enrollment GUID. |

`*Count` fields provide the number of matching GUIDs, and the paired field contains a semicolon-delimited GUID list.

---

## Detection-Only Test Expectations

Running the script without switches:

```powershell
.\Attestation_Review.ps1
```

requires Administrator or SYSTEM context. If the script is not elevated, it stops with:

```text
Run this script as Administrator.
```

In detection-only mode, the script:

- Creates a timestamped output folder, for example `C:\ProgramData\IntuneEnrollmentRepair\yyyyMMdd_HHmmss\`
- Runs `dsregcmd /status`
- Reads registry GUIDs from:
  - `HKLM:\SOFTWARE\Microsoft\Enrollments`
  - `HKLM:\SOFTWARE\Microsoft\Enrollments\Status`
  - `HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts`
  - `HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Sessions`
  - `HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Logger`
  - `HKLM:\SOFTWARE\Microsoft\PolicyManager\Providers`
  - `HKLM:\SOFTWARE\Microsoft\EnterpriseResourceManager\Tracked`
- Enumerates EnterpriseMgmt scheduled tasks
- Reads recent MDM / device registration event logs for the last `72` hours by default
- Writes `detection-result.json`
- Writes `detection-result.txt`
- Prints the `$result` object to console/stdout

No `.reg` backup files should be created in detection-only mode. Registry backups are created only inside the `if ($Remediate)` block.

On a healthy Entra joined and Intune-managed device, the expected output is generally:

```text
AzureAdJoined=YES
MdmUrlPresent=True
OmadmGuidCount > 0
EnterpriseMgmtTaskCount > 0
Classification=HealthyManaged
RemediationAttempted=False
RemediationResult=Not run
```

For this healthy state, the expected operational outcome is:

- Do not run cleanup.
- Do not remove registry keys, scheduled tasks, or certificates.
- Treat extra `EnrollmentGuidsNotInOmadm` values as review evidence only, not proof of stale enrollment.
- Use the GUID correlation fields to understand the local enrollment shape, not to override the classification by themselves.

If the classification is not `HealthyManaged`, read `RecommendedAction` before deciding on remediation:

- `EnrollmentBlocked` means prerequisite issues such as licensing, enrollment restrictions, device limit, or network/access failures should be resolved first.
- `EnrollmentRejectedByService` means local cleanup is not expected to help; review Entra device object state, Intune enrollment restrictions, user/device limits, license, and MDM scope.
- `StaleEnrollmentSuspected` is the only classification intended for stale artifact cleanup review, and remediation should still be piloted carefully.
- `EntraJoinedButMDMMissing` usually means there is no local stale artifact cleanup to perform; review auto-enrollment prerequisites and test DeviceEnroller only when appropriate.
- `EnrollmentBroken` means MDM URL exists but recent errors were detected; try sync and review event evidence before considering any cleanup.
- `NeedsManualReview` means the collected evidence does not match a safe known pattern.

The console table is useful for a quick check, but PowerShell may truncate long GUID lists or display ellipses/encoding artifacts. Use `detection-result.json` for exact review and copy/paste of full GUID values:

```powershell
Get-Content "C:\ProgramData\IntuneEnrollmentRepair\<timestamp>\detection-result.json" -Raw
```

Two classification details are worth watching during pilot testing:

- If recent event logs contain both the HTTP 400 signal and the AADEnrollAsync denied signal, the script may classify the device as `EnrollmentRejectedByService` even if the device currently appears managed. That check runs before `HealthyManaged`.
- If the device is structurally healthy but has recent MDM warnings or errors, it can still classify as `HealthyManaged` as long as MDM URL, OMADM GUIDs, and EnterpriseMgmt tasks exist. Recent non-blocking errors do not downgrade a structurally healthy enrollment.

---

## Device Classifications

| Classification                 | Meaning                                                                                                                     | Remediation Behavior                                                                            |
| ------------------------------ | --------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `EnrollmentBlocked`            | Blocking error codes detected in event logs (licensing, device limit, enrollment restriction, network).                     | Skipped. Prerequisite issues must be resolved before any remediation is meaningful.              |
| `EnrollmentRejectedByService`  | Event logs show HTTP 400 / `0x80190190` enrollment rejection plus AADEnrollAsync access denied signals.                     | Skipped. Local cleanup is not expected to resolve service-side rejection.                        |
| `HealthyManaged`               | Entra joined, MDM URL present, OMADM GUIDs and EnterpriseMgmt tasks all present.                                            | Skipped.                                                                                        |
| `StaleEnrollmentSuspected`     | Entra joined, no MDM URL, but enrollment GUIDs are present. Suggests leftover artifacts from a previous broken enrollment.  | Eligible stale GUID artifacts cleaned up. DeviceEnroller triggered only if `-RunDeviceEnroller` is specified. |
| `EntraJoinedButMDMMissing`     | Entra joined, no MDM URL, no enrollment GUIDs. MDM registration never completed.                                            | No artifact cleanup expected. DeviceEnroller triggered only if `-RunDeviceEnroller` is specified. |
| `EnrollmentBroken`             | Entra joined, MDM URL present, but recent MDM/registration errors detected.                                                 | Skipped - sync should be attempted first. Artifact cleanup not appropriate here.                 |
| `NeedsManualReview`            | Device state does not match any of the above patterns.                                                                      | Skipped. Manual diagnostics required.                                                           |

---

## Functions

### `Test-Admin`

Checks whether the script is running under an Administrator or SYSTEM security context.
Returns a boolean. The script throws immediately if this returns false — several operations (registry writes, scheduled task removal) require elevation.

---

### `Get-DsRegStatus`

Runs `dsregcmd /status` and parses the output into an ordered hashtable of `Key = Value` pairs.

Key fields consumed downstream:

| dsregcmd field     | Used for                                      |
| ------------------ | --------------------------------------------- |
| `AzureAdJoined`    | Primary join state check                      |
| `WorkplaceJoined`  | Recorded in report                            |
| `DomainJoined`     | Recorded in report                            |
| `DeviceAuthStatus` | Remediation gate — must be `SUCCESS`          |
| `TenantName`       | Recorded in report                            |
| `MdmUrl`           | Determines whether MDM registration is active |

---

### `Get-GuidSubKeys`

Accepts a registry path and returns a list of subkey names that match the GUID format (`xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`).

Called against registry paths that use GUID-named subkeys, including:

- `HKLM:\SOFTWARE\Microsoft\Enrollments` — primary enrollment records
- `HKLM:\SOFTWARE\Microsoft\Enrollments\Status` — enrollment status records
- `HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts` — OMADM client accounts
- `HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Sessions` — OMADM session state
- `HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Logger` — OMADM logger state
- `HKLM:\SOFTWARE\Microsoft\PolicyManager\Providers` — policy provider state
- `HKLM:\SOFTWARE\Microsoft\EnterpriseResourceManager\Tracked` — tracked enterprise resource state

Returns an empty array if the path does not exist or contains no GUID-named keys.

---

### `Get-EnterpriseMgmtTasks`

Retrieves all scheduled tasks under `\Microsoft\Windows\EnterpriseMgmt\` using a `Where-Object` filter.

> Note: `Get-ScheduledTask -TaskPath` does not support wildcards. The function enumerates all tasks and filters by path string to avoid this limitation.

Returns an empty array if no tasks are found or if the Task Scheduler service is unavailable.

---

### `Remove-EnterpriseMgmtTaskFolder`

Deletes the empty `\Microsoft\Windows\EnterpriseMgmt\{GUID}` scheduled task folder after tasks have been unregistered.

Uses the `Schedule.Service` COM object's `DeleteFolder` method because `Unregister-ScheduledTask` only removes tasks, not the parent folder. The COM object is released in a `finally` block. Failures (folder absent, non-empty, COM access denied) are silently ignored — this is a best-effort cleanup.

Must be called **after** `Unregister-ScheduledTask` for the same GUID, since `DeleteFolder` fails if child tasks still exist.

---

### `Normalize-GuidList`

Strips braces, uppercases, deduplicates, and sorts a list of GUID strings for diagnostic comparison.

Used exclusively for GUID correlation fields in the detection report (e.g., `OmadmGuidsNotInEnrollment`). Does not affect classification or remediation eligibility — report visibility only.

---

### `Get-RecentMdmErrors`

Queries Windows event logs for errors, warnings, and known MDM event IDs within the lookback window (`-RecentHours`, default 72h):

- `Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Admin`
- `Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Enrollment`
- `Microsoft-Windows-User Device Registration/Admin`

Events are included if `Level -le 3` (Critical / Error / Warning) or if the Event ID matches a known MDM-relevant set: `75, 76, 83, 90, 91, 201, 202, 204, 205, 304, 305, 307, 404, 809, 820`.

The total count feeds into classification. A sub-filter also checks event `Message` text for blocking error codes:

| Error code   | Meaning                           |
| ------------ | --------------------------------- |
| `0x80180026` | Device limit exceeded             |
| `0x80180014` | Enrollment restriction applied    |
| `0x80180018` | No Intune license assigned        |
| `0x80280013` | Network / endpoint access failure |

If any blocking errors are found, the device is classified as `EnrollmentBlocked` and all remediation is skipped.

The script also detects a separate service-side rejection pattern:

- Event `76` with `0x80190190` or `Bad request (400)`
- Event `83` with `Access is denied` or `AADEnrollAsync`

When both are present, the device is classified as `EnrollmentRejectedByService`. This is treated as a tenant/service-side issue, not a local stale-artifact cleanup candidate.

---

### `Export-RegKey`

Wraps `reg.exe export` to back up a registry path to a `.reg` file before any modifications are made.

Called for:

- `HKLM\SOFTWARE\Microsoft\Enrollments` → `Enrollments.reg`
- `HKLM\SOFTWARE\Microsoft\Provisioning\OMADM` → `OMADM.reg`
- `HKLM\SOFTWARE\Microsoft\PolicyManager\Providers` → `PolicyManager-Providers.reg`
- `HKLM\SOFTWARE\Microsoft\EnterpriseResourceManager\Tracked` → `ERM-Tracked.reg`

Uses `reg.exe` syntax (backslash paths, no `HKLM:\` prefix) and overwrites any existing backup file (`/y`).

---

### `Remove-RegSubKey`

Deletes a single registry subkey and all of its children (`Remove-Item -Recurse -Force`).

Checks `Test-Path` first — if the key does not exist, the function exits silently. Called per-GUID during stale artifact cleanup.

---

## Remediation Logic

Remediation only runs when `-Remediate` is specified. The following gates are checked in order — the first match wins:

1. **Classification is `HealthyManaged` or `EnrollmentBlocked`** → Skip.
2. **Classification is `EnrollmentRejectedByService`** → Skip. Resolve service-side or tenant-side causes first.
3. **`DeviceAuthStatus` is missing or not `SUCCESS`** → Skip. Entra join health must be resolved first.
4. **Classification is `EnrollmentBroken`** → Skip artifact cleanup. Attempt a manual sync via Company Portal or `deviceenroller.exe /o`.
5. **Classification is `StaleEnrollmentSuspected` or `EntraJoinedButMDMMissing`** → Proceed.

For `StaleEnrollmentSuspected`, each enrollment GUID is individually validated before deletion:

- `EnrollmentType = 6` (MDM modern enrollment), **or**
- `DiscoveryServiceFullURL` contains `manage.microsoft.com`

Only GUIDs matching at least one condition are removed. Unknown GUIDs are left untouched.

Matching GUID keys are removed from:

- `HKLM:\SOFTWARE\Microsoft\Enrollments\<GUID>`
- `HKLM:\SOFTWARE\Microsoft\Enrollments\Status\<GUID>`
- `HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts\<GUID>`
- `HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Sessions\<GUID>`
- `HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Logger\<GUID>`
- `HKLM:\SOFTWARE\Microsoft\PolicyManager\Providers\<GUID>`
- `HKLM:\SOFTWARE\Microsoft\EnterpriseResourceManager\Tracked\<GUID>`
- Any `EnterpriseMgmt` scheduled task whose path contains the GUID
- The empty `\Microsoft\Windows\EnterpriseMgmt\<GUID>` scheduled task folder, where possible

For `StaleEnrollmentSuspected`, the script also removes local machine certificates from `Cert:\LocalMachine\My` where the issuer matches `Intune MDM` or `Microsoft Device Management Device CA`.

> Important: certificate removal is broad and is not backed up by the script. Only use remediation after validating the classification in your environment.

`DeviceEnroller.exe /c /AutoEnrollMDM` is triggered only when `-RunDeviceEnroller` is explicitly passed. It runs non-blocking (`Start-Process` without `-Wait`) to avoid script timeout in Intune Remediations deployments.

---

## Recommended Rollout

1. Run in detection-only mode across a pilot group.
2. Review `detection-result.json` output — validate classifications against known good and known broken devices.
   
3. Detection results are stored under `C:\ProgramData\IntuneEnrollmentRepair\{YYYYMMDD_HHMMSS}\`. For example:

   ```powershell
   Get-Content "C:\ProgramData\IntuneEnrollmentRepair\20260619_091921\detection-result.json" -Raw
   ```
4. Run with `-Remediate` on a small subset of `StaleEnrollmentSuspected` devices.
5. Confirm Intune registration, MDM value, last check-in, and compliance state after remediation.
6. Expand only after classification accuracy is validated in your environment.


---

## TestMode

The `-TestMode` switch enables classification path testing on any device by overriding dsregcmd values with hardcoded test data. Real dsregcmd output and event logs are still collected first — TestMode overlays fabricated values on top, so the script exercises the same code paths as production.

**How it works:**

All profiles set `AzureAdJoined=YES`, `DeviceAuthStatus=SUCCESS`, `DomainJoined=NO`, `WorkplaceJoined=NO`, and `TenantName=Gamtoso`. The `MdmUrl` and event signal overrides vary by profile:

| Profile      | MdmUrl | Event Overrides | Expected Classification        |
| ------------ | ------ | --------------- | ------------------------------- |
| `Healthy`    | Set    | None            | `HealthyManaged`                |
| `Stale`      | Empty  | None            | `StaleEnrollmentSuspected`      |
| `Rejected`   | Empty  | `$has400Reject` + `$hasAadEnrollDenied` forced true | `EnrollmentRejectedByService` |
| `MdmMissing` | Empty  | None            | `EntraJoinedButMDMMissing` (if no seed GUIDs) or `StaleEnrollmentSuspected` (if seed GUIDs present) |

**Test environment setup:**

The `TestCaseConfigC.ps1` script seeds registry GUIDs (e.g., `DEADBEEF-...`) for the `Stale` profile. The `ResetConfig_REGKEY.ps1` script removes those seeds between test runs. For the `MdmMissing` profile, run the reset script first so no enrollment GUIDs are present.

TestMode overrides are placed after dsregcmd extraction and before classification, so the classification logic and remediation gates are exercised identically to production. The `-Remediate` switch works normally in TestMode — on a test device with seeded GUIDs, `Stale -Remediate` will actually clean the seed artifacts.

---

## Legal Disclaimer

**THIS SCRIPT IS NOT AN OFFICIAL MICROSOFT PRODUCT AND IS NOT ENDORSED, SUPPORTED, OR WARRANTED BY MICROSOFT CORPORATION IN ANY WAY.**

This script is an independent, community-developed tool provided strictly for informational and diagnostic purposes. It is not affiliated with, derived from, or approved by any Microsoft product team, support organisation, or official channel.

**Use of this script is entirely at your own risk.** The author(s) make no representations or warranties of any kind, express or implied, regarding the accuracy, completeness, reliability, suitability, or availability of this script for any purpose. This includes but is not limited to:

- Any modification to registry keys, scheduled tasks, or enrollment state that may result from use of the remediation switches
- Any unintended side effects on device management, compliance state, or Entra ID / Intune registration
- Any data loss, service interruption, or configuration change resulting from use of this script

**Before enabling any remediation mode:**

- Review all detection output and classifications manually
- Validate against known healthy and known broken devices in your environment
- Test in a controlled pilot group before any broader deployment
- Ensure appropriate change management and rollback procedures are in place

This script does not constitute advice, guidance, or a recommended practice from Microsoft. Any decision to run it in a production environment is made solely at the discretion and responsibility of the operator.

---

## License

MIT License

Copyright (c) 2025

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

---
