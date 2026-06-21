# ===========================================================
# TEST CASE CONFIGURATION PARMETERS:
# FYI: `Set-ExecutionPolicy Bypass -Scope CurrentUser -Force`
# TO BE USED in conjunction with Attestation_DevC.ps1
# ===========================================================
# Stale path (default) — should classify StaleEnrollmentSuspected
.\Attestation_DevC.ps1 -TestMode

# Stale + remediate — should backup + delete DEADBEEF from all hives
.\Attestation_DevC.ps1 -TestMode -TestProfile Stale -Remediate

# Rejected — should classify EnrollmentRejectedByService, REFUSE cleanup
.\Attestation_DevC.ps1 -TestMode -TestProfile Rejected -Remediate

# Healthy — should classify HealthyManaged, skip
.\Attestation_DevC.ps1 -TestMode -TestProfile Healthy

# MdmMissing — remove DEADBEEF seed first, then should classify EntraJoinedButMDMMissing
.\Attestation_DevC.ps1 -TestMode -TestProfile MdmMissing