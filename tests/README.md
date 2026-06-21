# Tests

Test iterations for the Attestation_Review.ps1 script. Each folder contains the dev branch script, test configuration, and results from that iteration.

## TestCase-01

First iteration (DevB). Introduced extended hive coverage but had a critical TestMode placement bug — overrides ran before dsregcmd extraction, making TestMode non-functional.

- `Attestation_DevB.ps1` — dev branch script
- `TestCaseConfig.ps1` — registry seed script
- `TestCaseResult01.md` — test results and observations

## TestCase-02

Second iteration (DevC). All fixes applied, TestProfile system functional, EnrollmentRejectedByService classification added. This is the version merged into master.

- `Attestation_DevC.ps1` — dev branch script (source of truth for the master merge)
- `TestCaseConfigC.ps1` — registry seed script (DEADBEEF + additional GUIDs)
- `ResetConfig_REGKEY.ps1` — removes seed GUIDs between test runs
- `TestCaseResult02.md` — test results summary
- `2026.06.21-TestConfigRunResultsFull/` — raw test run output (detection/remediation JSONs, registry backups)

## switch-gate-healthy-managed

Targeted test for the HealthyManaged classification switch gate — verifies that healthy devices are correctly identified and excluded from cleanup.

- `Invoke-SwitchGateTest.ps1` — test runner
- `RESULTS.md` — outcomes
