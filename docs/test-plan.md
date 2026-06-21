# Test Plan

## TestProfile System

The `-TestMode -TestProfile` parameter system allows classification path testing on any Windows device by overriding dsregcmd values with hardcoded test data. Real device state is still collected first — TestMode overlays fabricated values after extraction, so the classification logic and remediation gates execute identically to production.

## Profiles

### Healthy

**Simulates:** A properly Entra-joined, Intune-managed device.

**Overrides:**
- `AzureAdJoined = YES`
- `DeviceAuthStatus = SUCCESS`
- `MdmUrl = https://enrollment.manage.microsoft.com/enrollmentserver/discovery.svc`
- `MdmUrlPresent = $true`

**Expected classification:** `HealthyManaged`

**Test cases:**

| Flags | Expected Outcome |
|-------|------------------|
| Detection only | Classification = HealthyManaged, no cleanup |
| `-Remediate` | RemediationResult = "Skipped: HealthyManaged." |
| `-Remediate -RunDeviceEnroller` | RemediationResult = "Skipped: HealthyManaged." (DeviceEnroller NOT triggered) |

---

### Stale

**Simulates:** An Entra-joined device with leftover enrollment GUIDs but no active MDM URL.

**Overrides:**
- `AzureAdJoined = YES`
- `DeviceAuthStatus = SUCCESS`
- `MdmUrl = ""` (empty)
- `MdmUrlPresent = $false`

**Prerequisites:** Seed registry GUIDs must exist (run `TestCaseConfigC.ps1` to create DEADBEEF and other seed GUIDs).

**Expected classification:** `StaleEnrollmentSuspected`

**Test cases:**

| Flags | Expected Outcome |
|-------|------------------|
| Detection only | Classification = StaleEnrollmentSuspected, no cleanup |
| `-Remediate` | Seed GUIDs cleaned from all 7 hives + tasks + certs. RemediationResult = "Artifact cleanup completed..." |
| `-Remediate -RunDeviceEnroller` | Cleanup + DeviceEnroller triggered (non-blocking) |

**Post-remediation verification:**
- Seed GUID subkeys removed from Enrollments, Status, OMADM (Accounts/Sessions/Logger), PolicyManager\Providers, EnterpriseResourceManager\Tracked
- EnterpriseMgmt scheduled tasks for seed GUIDs removed
- EnterpriseMgmt task folders for seed GUIDs removed
- Registry backups (`.reg` files) created in backup directory
- Run `ResetConfig_REGKEY.ps1` to re-seed before next test run

---

### Rejected

**Simulates:** A device where Intune enrollment discovery succeeds but the service rejects the enrollment request (HTTP 400).

**Overrides:**
- `AzureAdJoined = YES`
- `DeviceAuthStatus = SUCCESS`
- `MdmUrl = ""` (empty)
- `MdmUrlPresent = $false`
- `$has400Reject = $true` (fabricated)
- `$hasAadEnrollDenied = $true` (fabricated)

**Expected classification:** `EnrollmentRejectedByService`

**Test cases:**

| Flags | Expected Outcome |
|-------|------------------|
| Detection only | Classification = EnrollmentRejectedByService |
| `-Remediate` | RemediationResult = "Skipped: service-side rejection..." (no cleanup performed) |

**Key validation:** Even though seed GUIDs may be present (which would normally match StaleEnrollmentSuspected), the service-side rejection signals take priority and block all cleanup.

---

### MdmMissing

**Simulates:** An Entra-joined device that never completed MDM enrollment.

**Overrides:**
- `AzureAdJoined = YES`
- `DeviceAuthStatus = SUCCESS`
- `MdmUrl = ""` (empty)
- `MdmUrlPresent = $false`

**Prerequisites:** Run `ResetConfig_REGKEY.ps1` first to remove seed GUIDs. If seed GUIDs are present, the device will classify as `StaleEnrollmentSuspected` instead.

**Expected classification:** `EntraJoinedButMDMMissing` (when no enrollment GUIDs present) or `StaleEnrollmentSuspected` (when seed GUIDs remain — this is expected behavior, not a bug)

**Test cases:**

| Flags | Expected Outcome |
|-------|------------------|
| Detection only (no seed GUIDs) | Classification = EntraJoinedButMDMMissing |
| Detection only (seed GUIDs present) | Classification = StaleEnrollmentSuspected |

---

## Test Environment Setup

### Seeding (TestCaseConfigC.ps1)

Creates registry GUIDs under the enrollment hives to simulate stale enrollment artifacts. Seeds include:
- A DEADBEEF-pattern GUID with `EnrollmentType=6` and `DiscoveryServiceFullURL` matching `manage.microsoft.com`
- Additional GUIDs for cross-hive correlation testing

### Reset (ResetConfig_REGKEY.ps1)

Removes all seed GUIDs created by the config script. Run between test iterations to restore a clean state.

### Execution Order

```
1. Run TestCaseConfigC.ps1          (seed GUIDs)
2. Run Attestation_Review.ps1 -TestMode -TestProfile Stale          (detection)
3. Run Attestation_Review.ps1 -TestMode -TestProfile Stale -Remediate  (cleanup)
4. Run ResetConfig_REGKEY.ps1       (reset seeds)
5. Run Attestation_Review.ps1 -TestMode -TestProfile MdmMissing     (verify no-GUID path)
6. Run TestCaseConfigC.ps1          (re-seed)
7. Run Attestation_Review.ps1 -TestMode -TestProfile Rejected -Remediate  (verify rejection gate)
8. Run Attestation_Review.ps1 -TestMode -TestProfile Healthy         (verify skip)
```

---

## Test Results Summary

### DESKTOP-BEOI6P3

| Profile | Flags | Classification | Outcome |
|---------|-------|---------------|---------|
| Stale | Detection only | StaleEnrollmentSuspected | PASS |
| Stale | `-Remediate` | StaleEnrollmentSuspected | PASS — cleaned DEADBEEF + 697258CB GUIDs |
| Rejected | `-Remediate` | EnrollmentRejectedByService | PASS — refused cleanup |
| Healthy | Detection only | HealthyManaged | PASS — skipped |
| MdmMissing | Detection only | StaleEnrollmentSuspected | Expected — seed GUIDs were present |

### HYPERGAM2

| Profile | Flags | Classification | Outcome |
|---------|-------|---------------|---------|
| Stale | `-Remediate` | StaleEnrollmentSuspected | PASS — cleanup completed |
| Healthy | Detection only | HealthyManaged | PASS — skipped |

**HYPERGAM2 observation:** 78 orphan Status/Logger GUIDs detected (failed enrollment debris with no parent Enrollment key). Determined to be benign — does not block new enrollment. Orphan sweep not implemented (backlogged).
