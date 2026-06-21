# Changelog

## Version History

The script evolved through three development iterations (DevA → DevB → DevC) before consolidation into the master `Attestation_Review.ps1`.

---

## DevC (Current Master)

Final iteration. All fixes from DevA/DevB plus TestProfile system, extended hive coverage, and EnrollmentRejectedByService classification.

### Bug Fixes

| Fix ID | Description |
|--------|-------------|
| FIX 1 | Per-GUID stale verification — each enrollment GUID is individually checked for `EnrollmentType=6` or `manage.microsoft.com` discovery URL before deletion. Previous versions deleted all enrollment GUIDs unconditionally. |
| FIX 1b | `[int]` cast for `EnrollmentType` registry value. Registry DWORDs can surface as different types depending on how they were written; explicit cast prevents type mismatch in comparison. |
| FIX 2 | DeviceAuthStatus null guard. Previous condition `($deviceAuthStatus -and $deviceAuthStatus -ne "SUCCESS")` evaluated to `$false` when `$deviceAuthStatus` was `$null`, allowing cleanup to proceed on devices with unknown Entra auth state. Fixed to explicitly block on null/empty. |
| FIX 3 | EnrollmentBroken excluded from cleanup. MDM URL exists but recent errors detected — this is a sync failure, not a stale artifact problem. Artifact removal would destroy a potentially recoverable enrollment. Also removed `-Wait` from `DeviceEnroller.exe` `Start-Process` to avoid Intune Remediations timeout (default 60s). |
| FIX 4 | DeviceEnroller requires explicit `-RunDeviceEnroller` switch. Previous versions auto-triggered DeviceEnroller for certain classifications even without the switch. Changed to mandatory opt-in. |
| FIX 5 | `Get-ScheduledTask -TaskPath` does not support wildcards. Replaced with `Get-ScheduledTask | Where-Object` filter on `TaskPath`. |
| FIX 6 | Report fields: added `DomainJoined` and `TenantName` to output object. These were specified in the original design but missing from implementation. |
| FIX 7 | Blocking error code gate. Events containing `0x80180026` (device limit), `0x80180014` (enrollment restriction), `0x80180018` (no license), or `0x80280013` (network/access) now trigger `EnrollmentBlocked` classification, skipping all remediation. |

### New Features

| Feature | Description |
|---------|-------------|
| EnrollmentRejectedByService | New classification for HTTP 400 + AADEnrollAsync denial pattern. Derived from a real enrollment failure case where devices had enrollment GUIDs but local cleanup couldn't resolve service-side rejection. Requires Event 76 (`0x80190190`) AND Event 83 (`AADEnrollAsync` denied). |
| Extended hive coverage | Cleanup now covers 7 registry hives (added `OMADM\Sessions`, `OMADM\Logger`, `PolicyManager\Providers`, `EnterpriseResourceManager\Tracked`) in addition to the original 3 (`Enrollments`, `Enrollments\Status`, `OMADM\Accounts`). All GUID-scoped. |
| COM task-folder deletion | After `Unregister-ScheduledTask`, the empty `\Microsoft\Windows\EnterpriseMgmt\{GUID}` folder is removed via `Schedule.Service` COM `DeleteFolder`. Best-effort — failure is silently ignored. |
| Scoped cert removal | Intune MDM client certificates (`Cert:\LocalMachine\My`, issuer matching `Intune MDM` or `Microsoft Device Management Device CA`) are removed only in the `StaleEnrollmentSuspected` path, after backup. |
| TestProfile system | `-TestMode -TestProfile {Healthy|Stale|Rejected|MdmMissing}` overrides dsregcmd values and event signals after real collection to test classification paths. |
| GUID correlation diagnostics | Report includes cross-hive GUID comparison fields (e.g., `OmadmGuidsNotInEnrollment`, `StatusGuidsNotInEnrollment`) for diagnostic visibility. Does not affect classification or remediation. |

### Bug Fixes (DevC-specific)

| Fix | Description |
|-----|-------------|
| `$SUCCESS` typo | TestMode Healthy profile used variable `$SUCCESS` instead of string `"SUCCESS"` for DeviceAuthStatus override. |
| TestMode placement | TestMode override block was placed before dsregcmd extraction in DevB, meaning overrides were immediately clobbered by real values. Moved to after extraction in DevC. |

---

## DevB (Intermediate)

Introduced extended hive coverage and cert removal. Had a critical TestMode placement bug — the override block ran before dsregcmd extraction, so fabricated values were overwritten by real device state. This made TestMode non-functional for classification testing.

---

## DevA (Initial)

Original implementation with basic classification tree (HealthyManaged, StaleEnrollmentSuspected, EntraJoinedButMDMMissing, EnrollmentBroken, NeedsManualReview). Cleaned only 3 registry hives. No TestMode, no per-GUID validation, no blocking error gate, no service-side rejection detection.

---

## Backlogged

| Item | Status | Notes |
|------|--------|-------|
| Orphan Status/Logger GUID sweep | Not implemented | HYPERGAM2 testing found 78 orphan `Status`/`Logger` GUIDs with no parent `Enrollment` key. Determined to be benign (failed enrollment debris). Does not block new enrollment. May add as optional housekeeping in a future iteration. |
