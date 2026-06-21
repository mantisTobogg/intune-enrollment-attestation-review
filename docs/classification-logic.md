# Classification Logic

## Overview

The script classifies each device into exactly one category based on dsregcmd output, registry GUID presence, scheduled task state, and event log signals. Classifications are evaluated in priority order — the first match wins.

## Decision Tree

```
1. blockingErrorCount > 0?
   └─ YES → EnrollmentBlocked
   └─ NO  ↓

2. has400Reject AND hasAadEnrollDenied?
   └─ YES → EnrollmentRejectedByService
   └─ NO  ↓

3. AzureAdJoined=YES AND MdmUrl present AND OMADM GUIDs > 0 AND EnterpriseMgmt tasks > 0?
   └─ YES → HealthyManaged
   └─ NO  ↓

4. AzureAdJoined=YES AND MdmUrl absent AND enrollment GUIDs > 0?
   └─ YES → StaleEnrollmentSuspected
   └─ NO  ↓

5. AzureAdJoined=YES AND MdmUrl absent (and no enrollment GUIDs)?
   └─ YES → EntraJoinedButMDMMissing
   └─ NO  ↓

6. AzureAdJoined=YES AND MdmUrl present AND recentErrorCount > 0?
   └─ YES → EnrollmentBroken
   └─ NO  ↓

7. Fallback → NeedsManualReview
```

## Classification Details

### EnrollmentBlocked (Priority 1)

**Trigger:** Event log messages contain any of: `0x80180026` (device limit), `0x80180014` (enrollment restriction), `0x80180018` (no license), `0x80280013` (network/access).

**Rationale:** These are prerequisite failures. Local registry cleanup cannot resolve licensing, restriction, or infrastructure issues.

**Remediation:** Skipped unconditionally.

### EnrollmentRejectedByService (Priority 2)

**Trigger:** Event 76 contains `0x80190190` or `Bad request (400)` AND Event 83 contains `Access is denied` or `AADEnrollAsync`.

**Rationale:** Discovery succeeds (device can reach the enrollment endpoint) but the enrollment request itself is rejected by the service with HTTP 400. This pattern was first observed in the CJ OliveNetworks case — devices had enrollment GUIDs present, which would normally match `StaleEnrollmentSuspected`, but local cleanup repeatedly failed to resolve the issue because the rejection was server-side.

**Remediation:** Skipped unconditionally. Recommended actions: verify Entra device object state (existence, stale duplicates), Intune enrollment restrictions, per-user device cap, user's Intune license, and MDM scope assignment.

**Priority placement:** Evaluated before `HealthyManaged` to prevent devices with both healthy-looking local state AND service-side rejection signals from being classified as healthy. The service-side rejection takes precedence.

### HealthyManaged (Priority 3)

**Trigger:** `AzureAdJoined=YES` + MDM URL present + at least one OMADM account GUID + at least one EnterpriseMgmt scheduled task.

**Rationale:** All four indicators of active Intune management are present. Recent non-blocking MDM errors do not downgrade this classification — the structural indicators take precedence.

**Remediation:** Skipped unconditionally.

### StaleEnrollmentSuspected (Priority 4)

**Trigger:** `AzureAdJoined=YES` + MDM URL absent + enrollment GUIDs present.

**Rationale:** The device is Entra joined but has no active MDM URL, yet enrollment registry keys still exist. These are likely leftover artifacts from a previous enrollment that was interrupted, failed, or was removed server-side without local cleanup.

**Remediation:** Eligible for GUID-scoped artifact cleanup. Each enrollment GUID is individually validated — only GUIDs with `EnrollmentType=6` (MDM modern enrollment) or `DiscoveryServiceFullURL` matching `manage.microsoft.com` are removed. Unknown GUIDs are preserved.

### EntraJoinedButMDMMissing (Priority 5)

**Trigger:** `AzureAdJoined=YES` + MDM URL absent + no enrollment GUIDs.

**Rationale:** The device completed Entra join but MDM enrollment never happened or left no local artifacts. There is nothing to clean up.

**Remediation:** Registry backup is taken (defensive), but no GUID cleanup is performed. DeviceEnroller is triggered only if `-RunDeviceEnroller` is explicitly specified.

### EnrollmentBroken (Priority 6)

**Trigger:** `AzureAdJoined=YES` + MDM URL present + recent MDM errors detected.

**Rationale:** The enrollment infrastructure is present (MDM URL exists) but recent event logs show errors. This suggests a check-in or sync failure, not a stale artifact problem. Cleaning registry keys would destroy an existing enrollment that might be recoverable through sync.

**Remediation:** Skipped. Recommended first step is manual sync via Company Portal or `deviceenroller.exe /o`.

### NeedsManualReview (Priority 7 — fallback)

**Trigger:** None of the above patterns matched.

**Rationale:** The collected evidence does not fit any recognized pattern. Manual diagnostic review is required.

**Remediation:** Skipped.

## Remediation Safety Gates

Even when classification allows remediation, additional gates apply:

1. **DeviceAuthStatus check:** If `DeviceAuthStatus` is null, empty, or not `SUCCESS`, remediation is skipped. Entra join health must be resolved before touching enrollment artifacts.

2. **GUID-level validation:** Each enrollment GUID is individually checked for `EnrollmentType=6` or `manage.microsoft.com` discovery URL. GUIDs that don't match either condition are left untouched.

3. **Registry backup:** Full registry export of all target hives is performed before any deletion.

4. **Certificate scope:** Intune MDM client certificates are removed only in the `StaleEnrollmentSuspected` path, never for other classifications.

5. **DeviceEnroller opt-in:** `DeviceEnroller.exe` is only triggered when `-RunDeviceEnroller` is explicitly passed. It runs non-blocking to avoid Intune Remediations timeout.
