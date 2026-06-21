# Script Overview

### Data collection (what the script reads)

- `dsregcmd /status` — AzureAdJoined, DomainJoined, WorkplaceJoined, DeviceAuthStatus, MdmUrl, TenantName
- Event logs (3 channels) — Admin, Enrollment, User Device Registration — filtered for Warning/Error/Critical + specific Event IDs (75, 76, 83, 90, 91, 201, 202, 204, 205, 304, 305, 307, 404, 809, 820) within a configurable time window (default 72hrs)
- Registry GUID inventory across 7 hives: Enrollments, Enrollments\Status, OMADM\Accounts, OMADM\Sessions, OMADM\Logger, PolicyManager\Providers, EnterpriseResourceManager\Tracked
- Scheduled tasks under `\Microsoft\Windows\EnterpriseMgmt\*`
- GUID cross-correlation diagnostics — which GUIDs exist in which hives, which are orphaned (e.g., OMADM GUID with no matching Enrollment GUID)

### Signal detection (what the script looks for)

- Blocking error codes in event messages — `0x80180026` (device cap), `0x80180014` (enrollment restriction), `0x80180018` (no MDM license), `0x80280013` (network/access)
- Service-side rejection signals — Event 76 containing `0x80190190` / "Bad request (400)" AND Event 83 containing "AADEnrollAsync" / "Access is denied" — the combination observed in a real enrollment failure case
- Per-GUID stale determination — checks each enrollment GUID's `EnrollmentType` (=6 for MDM) and `DiscoveryServiceFullURL` (contains `manage.microsoft.com`). Only GUIDs matching either criterion are treated as Intune artifacts eligible for cleanup. Unknown GUIDs are left untouched.

### Classification (the decision tree)

```text
Priority order (first match wins):

1. EnrollmentBlocked         — blocking error codes present → don't touch, fix licensing/restrictions first
2. EnrollmentRejectedByService — 400 + AADEnrollAsync denied → don't touch, check Entra object/caps/license
3. HealthyManaged            — Entra joined + MdmUrl + OMADM GUIDs + scheduled tasks all present → healthy
4. StaleEnrollmentSuspected  — Entra joined + no MdmUrl + enrollment GUIDs exist → stale artifacts
5. EntraJoinedButMDMMissing  — Entra joined + no MdmUrl + no enrollment GUIDs → never enrolled
6. EnrollmentBroken          — Entra joined + MdmUrl present + recent errors → enrolled but sync failing
7. NeedsManualReview         — anything else

TLDR: 

Step 1: Identify EnrollmentGUID         Get-GuidSubKeys + stale criteria check
Step 2: Delete Enrollments\{GUID}       Remove-RegSubKey per GUID
Step 3: Delete EnterpriseMgmt tasks     Unregister-ScheduledTask + COM DeleteFolder
Step 4: Delete Intune certificates      Cert:\LocalMachine\My Issuer match
Step 5: Trigger re-enrollment           DeviceEnroller.exe /c /AutoEnrollMDM
```

### Safety gates (what blocks remediation)

- `-Remediate` switch required — without it, detection-only, never touches anything
- `-RunDeviceEnroller` is a separate opt-in — cleanup alone doesn't auto-trigger enrollment
- HealthyManaged, EnrollmentBlocked, EnrollmentRejectedByService all hard-refuse cleanup even with `-Remediate`
- EnrollmentBroken refuses cleanup (sync first, not artifact removal)
- `DeviceAuthStatus` null/missing/not-SUCCESS blocks cleanup (fix Entra join state first)
- Admin privilege check at startup — throws if not elevated

Remediation (what it does when it actually cleans):

- Backs up first — `reg.exe export` of Enrollments, OMADM, PolicyManager\Providers, ERM\Tracked to timestamped folder under `C:\ProgramData\IntuneEnrollmentRepair\`
- GUID-scoped deletion across all 7 hives — only for GUIDs that passed the stale check
- Scheduled task removal — `Unregister-ScheduledTask` for matching GUID tasks
- Task folder cleanup — COM `Schedule.Service` `DeleteFolder` to remove the empty `EnterpriseMgmt\{GUID}` folder after task removal
- Intune client certificate removal — `Cert:\LocalMachine\My` entries with Issuer matching "Intune MDM" or "Microsoft Device Management Device CA" — only in the StaleEnrollmentSuspected path, only after backup
- DeviceEnroller trigger — `Start-Process DeviceEnroller.exe /c /AutoEnrollMDM` non-blocking (no `-Wait`, avoids Intune Remediations timeout)

### Output (what it produces)

- `detection-result.json` + `detection-result.txt` — pre-remediation snapshot
- `remediation-result.json` — post-remediation result (with try/catch so it writes even if cleanup partially failed)
- Console output of the full `$result` ordered hashtable (for Intune stdout capture)
- All `.reg` backup files in the timestamped backup folder

### Testing infrastructure

- `-TestMode` switch with `-TestProfile` (Healthy / Stale / Rejected / MdmMissing)
- dsregcmd overrides placed after real extraction (the `$SUCCESS` bug fix)
- Rejected profile injects `$has400Reject` / `$hasAadEnrollDenied` after real event computation
- Separate `TestCleanup.ps1` for resetting seed GUIDs between runs
