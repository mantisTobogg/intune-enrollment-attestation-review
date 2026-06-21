# ============================================================================
# .Attestation_Review.ps1
# Remediate stale enrollment candidates and run DeviceEnroller where eligible
# FYI: `Set-ExecutionPolicy Bypass -Scope CurrentUser -Force`
# ============================================================================
# OPTIONAL ARGUMENT FLAGS: 
# .Attestation_Review.ps1 -Remediate -RunDeviceEnroller
# ============================================================================
# ============================================================================
# CLASS
# $Remediate     : 활성화 시 정리 작업 실행 (기본값: 탐지만 수행함)
# $RunDeviceEnroller : 활성화 시 DeviceEnroller.exe 실행 (Remediate와 별개 스위치; e.g., "-Remediate" Flag 추가필수임) 
# $RecentHours   : 이벤트 로그 조회 범위 (기본 72시간)
# $BackupRoot    : 레지스트리 백업 저장 루트 경로
# $TestMode      : 활성화 시 dsregcmd 값을 하드코딩하여 분류 경로 테스트 가능
# $TestProfile   : TestMode 시 시뮬레이션 대상 분류 프로파일 (기본: Stale)
#   - Healthy    : HealthyManaged 경로 → 정리 스킵 확인용
#   - Stale      : StaleEnrollmentSuspected 경로 → GUID 정리 + DeviceEnroller 경로 확인용
#   - Rejected   : EnrollmentRejectedByService 경로 → 서비스 측 거부 시 정리 차단 확인용
#   - MdmMissing : EntraJoinedButMDMMissing 경로 → GUID 없는 미등록 단말 case 반영
# ============================================================================
param(
    [switch]$Remediate,
    [switch]$RunDeviceEnroller,
    [switch]$TestMode,
    [ValidateSet("Healthy","Stale","Rejected","MdmMissing")]
    [string]$TestProfile = "Stale",
    [int]$RecentHours = 72,
    [string]$BackupRoot = "C:\ProgramData\IntuneEnrollmentRepair"
)
$ErrorActionPreference = "Stop"

# ============================================================================
# 관리자 context로 실행 중인지 확인
# 함수 호출 값 = Bool (True or False)
# False시: 아래 Test-Admin 호출 블록에서 throw
# In this case the script will stop executing and display the message "Run this script as Administrator."
# ============================================================================
function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($id)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
# ============================================================================
# dsregcmd IO 및 정규식 key:val 분류
# dsregcmd /status 출력을 줄 단위로 읽어 "Key : Value" 형식을 ordered hashtable conversion 진행
# parsable via: $dsreg["AzureAdJoined"], $dsreg["MdmUrl"] 
# ============================================================================
function Get-DsRegStatus {
    $raw = & dsregcmd /status 2>$null
    $result = [ordered]@{}
    foreach ($line in $raw) {
        if ($line -match "^\s*([^:]+?)\s*:\s*(.*?)\s*$") {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            $result[$key] = $value
        }
    }
    return $result
}
# ============================================================================
# GUID 키와 일치하는 하위 폴더 이름 목록 출력 + 레지스트리 경로 아래의 GUID 형식을 받도록 정규식 check
# 출력값: GUID 문자열 배열 (없으면 empty)
# ============================================================================
function Get-GuidSubKeys {
    param([string]$Path)

    if (-not (Test-Path $Path)) { return @() }

    Get-ChildItem -Path $Path -ErrorAction SilentlyContinue |
        Where-Object { $_.PSChildName -match "^\{?[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}\}?$" } |
        Select-Object -ExpandProperty PSChildName
}
# ============================================================================
# GUID 문자열 비교용 정규식 
# ----------------------------------------------------------------------------
# Registry provider / task path / export source에 따라 GUID casing 또는 brace
# 포함 여부가 달라질 수 있으므로, 진단용 비교 전에 같은 형태로 정규화한다.
# 이 함수는 classification/remediation 판단에는 사용하지 않고 report visibility purpose
# ============================================================================
function Normalize-GuidList {
    param([string[]]$Guids)

    return @(
        $Guids |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            ForEach-Object { $_.Trim("{}").ToUpperInvariant() } |
            Sort-Object -Unique
    )
}
# ============================================================================
# EnterpriseMgmt 스케줄된 작업 목록 조회
# ============================================================================
# FIX 5: -TaskPath 파라미터는 와일드카드를 지원하지 않으므로 Where-Object 필터로 대체
# 작업이 없거나 오류 시 빈 배열 출력 
# ============================================================================
function Get-EnterpriseMgmtTasks {
    try {
        Get-ScheduledTask -ErrorAction SilentlyContinue |
            Where-Object { $_.TaskPath -like "\Microsoft\Windows\EnterpriseMgmt\*" }
    }
    catch {
        @()
    }
}

# ============================================================================
# EnterpriseMgmt 스케줄 작업 "폴더" 삭제
# ----------------------------------------------------------------------------
# Unregister-ScheduledTask는 작업(task)만 제거하고 빈 폴더
# \Microsoft\Windows\EnterpriseMgmt\{GUID} 는 남길 수 있음.
# schedule.service COM 객체의 DeleteFolder로 폴더 자체를 제거 
# GUID별로 호출하며, 폴더가 없거나 비어있지 않으면 조용히 스킵.
# ============================================================================
function Remove-EnterpriseMgmtTaskFolder {
    param([string]$Guid)

    try {
        $schedule = New-Object -ComObject "Schedule.Service"
        $schedule.Connect()
        $root = $schedule.GetFolder("\Microsoft\Windows\EnterpriseMgmt")
        # DeleteFolder는 대상 폴더에 하위 작업이 남아 있으면 실패하므로
        # 반드시 Unregister-ScheduledTask 이후에 호출되어야 한다.
        $root.DeleteFolder($Guid, $null)
    }
    catch {
        # 폴더 부재 / 잔여 작업 존재 / COM 접근 실패는 무시 (best-effort)
    }
    finally {
        if ($schedule) {
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($schedule) | Out-Null
        }
    }
}
# ============================================================================
# 이벤트 로그에서 MDM 관련 오류 수집
# 대상 로그: DeviceManagement-Enterprise-Diagnostics-Provider/Admin, User Device Registration/Admin
# ============================================================================
# Level -le 3 = Warning/Error/Critical, 특정 이벤트 ID 포함
# 출력값: 이벤트 객체 배열
# NEW: Event 83(AADEnrollAsync 실패) 및 90/91(Discovery) 포함 — 아래 분류 로직에서 사용
function Get-RecentMdmErrors {
    param([int]$Hours)

    $since = (Get-Date).AddHours(-1 * $Hours)
    $logs = @(
        "Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Admin",
        "Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Enrollment",
        "Microsoft-Windows-User Device Registration/Admin"
    )

    $events = foreach ($log in $logs) {
        try {
            Get-WinEvent -FilterHashtable @{ LogName = $log; StartTime = $since } -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.Level -le 3 -or
                    $_.Id -in @(75,76,83,90,91,201,202,204,205,304,305,307,404,809,820)
                } |
                Select-Object TimeCreated, LogName, Id, LevelDisplayName, ProviderName, Message
        }
        catch {
            @()
        }
    }

    return @($events)
}
# ============================================================================
# 레지스트리 경로를 .reg 파일로 내보내기 (백업)
# reg.exe export 사용 — HKLM\ 형식 경로 필요 (HKLM:\ 아님)
# 경로: C:\ProgramData\IntuneEnrollmentRepair\YYYYMMDD_HHMMSS\<파일명>.reg
# ============================================================================
function Export-RegKey {
    param(
        [string]$RegPath,
        [string]$OutFile
    )

    & reg.exe export $RegPath $OutFile /y | Out-Null
}

# 레지스트리 하위 키 전체 삭제 (재귀)
# Test-Path 확인 후 삭제 — 존재하지 않으면 스킵
function Remove-RegSubKey {
    param([string]$Path)

    if (Test-Path $Path) {
        Remove-Item -Path $Path -Recurse -Force
    }
}

# Test-Admin 실패 시  종료
if (-not (Test-Admin)) {
    throw "Run this script as Administrator."
}

# ============================================================================
# 변수 (Variables Pre-defined for the script) 
# ============================================================================
# 실행 타임스탬프 및 백업 디렉토리 생성
# 백업 경로 예: C:\ProgramData\IntuneEnrollmentRepair\20250608_143022
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $BackupRoot $timestamp
New-Item -Path $backupDir -ItemType Directory -Force | Out-Null

# dsregcmd 결과 수집
$dsreg = Get-DsRegStatus

# 검사 대상 레지스트리 경로 정의
$enrollPath = "HKLM:\SOFTWARE\Microsoft\Enrollments"
$statusPath = "HKLM:\SOFTWARE\Microsoft\Enrollments\Status"
$omadmPath  = "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts"

# ============================================================================
# GUID-scoped 정리 대상 
# ----------------------------------------------------------------------------
# 기존 스크립트는 Enrollments / Enrollments\Status / OMADM\Accounts 3곳만 정리.
# 부분 정리로 인해 OMADM\Sessions, OMADM\Logger 등 연관 상태가 잔존하면
# 이후 등록 과정 중 이슈 발생 할 수 있으니 정리 진행 필요.
#
# 주의: 아래 경로는 모두 "부모 경로"이며, 실제 삭제는 GUID 하위 키에 한해서만 수행.
# PolicyManager\Providers, EnterpriseResourceManager\Tracked 는 GUID 하위 키 구조이므로
# Get-GuidSubKeys / Remove-RegSubKey 패턴을 그대로 적용 가능.
# ============================================================================
$omadmSessionsPath = "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Sessions"
$omadmLoggerPath   = "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Logger"
$policyProvPath    = "HKLM:\SOFTWARE\Microsoft\PolicyManager\Providers"
$trackedPath       = "HKLM:\SOFTWARE\Microsoft\EnterpriseResourceManager\Tracked"

# 각 경로의 GUID 목록, 스케줄 작업, 이벤트 로그 수집
$enrollmentGuids   = @(Get-GuidSubKeys $enrollPath)
$statusGuids       = @(Get-GuidSubKeys $statusPath)
$omadmGuids        = @(Get-GuidSubKeys $omadmPath)
$omadmSessionGuids = @(Get-GuidSubKeys $omadmSessionsPath)
$omadmLoggerGuids  = @(Get-GuidSubKeys $omadmLoggerPath)
$policyProvGuids   = @(Get-GuidSubKeys $policyProvPath)
$trackedGuids      = @(Get-GuidSubKeys $trackedPath)
$tasks             = @(Get-EnterpriseMgmtTasks)
$events            = @(Get-RecentMdmErrors -Hours $RecentHours)

# ============================================================================
# GUID correlation diagnostics
# ----------------------------------------------------------------------------
# 출력되는 리포트 구성 요소. 
# stale/active 여부를 단정하거나 remediation eligibility에 영향 없음.
# ============================================================================
$normalizedEnrollmentGuids   = Normalize-GuidList $enrollmentGuids
$normalizedStatusGuids       = Normalize-GuidList $statusGuids
$normalizedOmadmGuids        = Normalize-GuidList $omadmGuids
$normalizedOmadmSessionGuids = Normalize-GuidList $omadmSessionGuids
$normalizedOmadmLoggerGuids  = Normalize-GuidList $omadmLoggerGuids
$normalizedPolicyProvGuids   = Normalize-GuidList $policyProvGuids
$normalizedTrackedGuids      = Normalize-GuidList $trackedGuids

$omadmGuidsInEnrollment = @(
    $normalizedOmadmGuids | Where-Object { $_ -in $normalizedEnrollmentGuids }
)

$enrollmentGuidsNotInOmadm = @(
    $normalizedEnrollmentGuids | Where-Object { $_ -notin $normalizedOmadmGuids }
)

$omadmGuidsNotInEnrollment = @(
    $normalizedOmadmGuids | Where-Object { $_ -notin $normalizedEnrollmentGuids }
)

$statusGuidsNotInEnrollment = @(
    $normalizedStatusGuids | Where-Object { $_ -notin $normalizedEnrollmentGuids }
)

$omadmSessionGuidsNotInEnrollment = @(
    $normalizedOmadmSessionGuids | Where-Object { $_ -notin $normalizedEnrollmentGuids }
)

$omadmLoggerGuidsNotInEnrollment = @(
    $normalizedOmadmLoggerGuids | Where-Object { $_ -notin $normalizedEnrollmentGuids }
)

$policyProvGuidsNotInEnrollment = @(
    $normalizedPolicyProvGuids | Where-Object { $_ -notin $normalizedEnrollmentGuids }
)

$trackedGuidsNotInEnrollment = @(
    $normalizedTrackedGuids | Where-Object { $_ -notin $normalizedEnrollmentGuids }
)

# dsregcmd 출력값에서 핵심 필드 추출
$azureAdJoined    = $dsreg["AzureAdJoined"]
$workplaceJoined  = $dsreg["WorkplaceJoined"]
$deviceAuthStatus = $dsreg["DeviceAuthStatus"]
$mdmUrl           = $dsreg["MdmUrl"]
# FIX 6: Output 누락 필드 추가 — 스펙에 명시된 DomainJoined, TenantName 포함
$domainJoined     = $dsreg["DomainJoined"]
$tenantName       = $dsreg["TenantName"]

# MDM URL 존재 여부 bool화
$mdmUrlPresent = -not [string]::IsNullOrWhiteSpace($mdmUrl)

# ============================================================================
# TestMode: dsregcmd 출력값을 하드코딩 오버라이드
# ----------------------------------------------------------------------------
# 실제 dsregcmd / 이벤트 로그 수집을 진행 한 후, 그 위에 fabricated 값으로 덮어씀. 
# PROD 동작에 영향 없음 — -TestMode 스위치 없으면 이 블록 전체 스킵됨. 
# ============================================================================
if ($TestMode) {
    Write-Host "[TestMode] Profile: $TestProfile — dsregcmd/event overrides active" -ForegroundColor Yellow

    # 모든 프로파일 공통: Entra Joined 디바이스 시뮬레이션
    $azureAdJoined    = "YES"
    $deviceAuthStatus = "SUCCESS"
    $domainJoined     = "NO"
    $workplaceJoined  = "NO"
    $tenantName       = "Gamtoso"

    switch ($TestProfile) {
        "Healthy" {
            # HealthyManaged 경로 → -Remediate 시 "Skipped: HealthyManaged" 출력 확인용
            $mdmUrl        = "https://enrollment.manage.microsoft.com/enrollmentserver/discovery.svc"
            $mdmUrlPresent = $true
        }
        "Stale" {
            # StaleEnrollmentSuspected 경로 → GUID 정리 동작 확인용
            # MdmUrl 없음 + enrollmentGuids 존재(DEADBEEF seed) = stale 조건 충족
            $mdmUrl        = ""
            $mdmUrlPresent = $false
        }
        "Rejected" {
            # EnrollmentRejectedByService 경로 → 서비스 측 거부 시 정리 차단 확인용
            # MdmUrl 없음 + 400/83 신호 강제 주입 (아래 별도 블록에서 처리)
            $mdmUrl        = ""
            $mdmUrlPresent = $false
        }
        "MdmMissing" {
            # EntraJoinedButMDMMissing 경로 → GUID 없는 미등록 단말 시뮬레이션
            # 이 프로파일은 DEADBEEF seed를 제거한 상태에서 실행해야 정확한 결과
            $mdmUrl        = ""
            $mdmUrlPresent = $false
        }
    }
}

$enterpriseTaskCount = @($tasks).Count
$recentErrorCount    = @($events).Count

# FIX 7: 차단 오류 코드 필터링
# 0x80180026 = 디바이스 한도 초과
# 0x80180014 = 등록 제한 (Enrollment Restriction)
# 0x80180018 = MDM 라이선스 없음
# 0x80280013 = 네트워크/접근 오류
# 이 오류가 있으면 레지스트리 정리는 의미 없음 — 선행 조건 해결 필요
$blockingErrorCount = @(
    $events | Where-Object { $_.Message -match "0x80180026|0x80180014|0x80180018|0x80280013" }
).Count

# ============================================================================
# NEW: 서비스 측 거부(HTTP 400) 신호 탐지
# ----------------------------------------------------------------------------
# - Event 76 "Auto MDM Enroll: ... Failed (Bad request (400))" = 0x80190190
# - Event 83 "AADEnrollAsync Failure (Access is denied.)"
# 이 두 신호가 함께 나타나면, Discovery는 성공하나 등록 요청을 서비스가 거부하는 상태로
# 로컬 아티팩트 정리(StaleEnrollment 경로)로는 해결이 안된다는 점을 고려하여 별도의 Tenant 설정 이슈로 보임. 
# 원인은 디바이스 객체 상태 / 등록 제한 / 사용자당 디바이스 한도 / 라이선스 등 서비스 측
# ============================================================================
# 주의: 위 $blockingErrorCount(0x801800xx 계열)와 별개 신호다.
# 관측된 거부는 0x801800xx가 아니라 0x80190190(HTTP 400)으로 표면화되었으므로,
# 기존 GateKepping 방법으로 해당 상태 파악 안됨. 
# ============================================================================
$has400Reject = @(
    $events | Where-Object { $_.Id -eq 76 -and $_.Message -match "0x80190190|Bad request \(400\)" }
).Count -gt 0

$hasAadEnrollDenied = @(
    $events | Where-Object { $_.Id -eq 83 -and $_.Message -match "Access is denied|AADEnrollAsync" }
).Count -gt 0

# ============================================================================
# TestMode (Rejected 전용): 서비스 측 거부 신호 fabrication
# ----------------------------------------------------------------------------
# $has400Reject / $hasAadEnrollDenied 는 실제 이벤트 로그에서 반영 한 후 fabrication 진행
# Rejected 외 프로파일에서는 실제 이벤트 로그 값이 그대로 유지됨
# ============================================================================
if ($TestMode -and $TestProfile -eq "Rejected") {
    $has400Reject       = $true
    $hasAadEnrollDenied = $true
}

# ============================================================================
# 디바이스 분류 로직
# dsregcmd 출력값 + 레지스트리 GUID 수 + 스케줄 작업 수 + evtx error 바탕으로 confidence-level 정의
# ----------------------------------------------------------------------------
# 우선순위:
#   EnrollmentBlocked > EnrollmentRejectedByService > HealthyManaged >
#   StaleEnrollmentSuspected > EntraJoinedButMDMMissing > EnrollmentBroken > NeedsManualReview
# ============================================================================
$classification     = "NeedsManualReview"
$recommendedAction  = "Collect diagnostics and review manually."

if ($blockingErrorCount -gt 0) {
    # 라이선스/제한/디바이스 한도 오류 감지 시 — 정리 불필요, 선행 조건 해결 필요
    $classification    = "EnrollmentBlocked"
    $recommendedAction = "Skip remediation. Resolve licensing, restriction, or device limit issues first."
}
# ============================================================================
# 서비스 측 거부 (HTTP 400 + AADEnrollAsync Access denied)
# blockingError 다음, HealthyManaged 보다 먼저 평가
# "Entra 가입됨 + 등록 GUID 잔존" 상태가 Stale로 오분류되어 정리 리스크 방지
# ----------------------------------------------------------------------------
elseif ($has400Reject -and $hasAadEnrollDenied) {
    $classification    = "EnrollmentRejectedByService"
    $recommendedAction = "Do NOT clean local artifacts. Discovery succeeds but the service rejects the enrollment request (HTTP 400 + AADEnrollAsync access denied). Verify the Entra device object (existence / stale duplicates), Intune enrollment restrictions, per-user device cap, and the user's Intune license/MDM scope before any further action."
}
elseif ($azureAdJoined -eq "YES" -and $mdmUrlPresent -and $omadmGuids.Count -gt 0 -and $enterpriseTaskCount -gt 0) {
    # Entra 가입 + MDM URL + OMADM GUID + 스케줄 작업 모두 존재 = 정상 관리 단말
    $classification    = "HealthyManaged"
    $recommendedAction = "No remediation."
}
elseif ($azureAdJoined -eq "YES" -and -not $mdmUrlPresent -and $enrollmentGuids.Count -gt 0) {
    # Entra 가입 + MDM URL 없음 + 등록 GUID 잔존 = 오래된 등록 아티팩트 가능성 있음
    $classification    = "StaleEnrollmentSuspected"
    $recommendedAction = "Backup stale enrollment state, remove stale GUID artifacts, then run DeviceEnroller."
}
elseif ($azureAdJoined -eq "YES" -and -not $mdmUrlPresent) {
    # Entra 가입 + MDM URL 없음 + 등록 GUID 없음 = MDM 등록 미완
    $classification    = "EntraJoinedButMDMMissing"
    $recommendedAction = "Run DeviceEnroller and verify MDM enrollment."
}
elseif ($azureAdJoined -eq "YES" -and $mdmUrlPresent -and $recentErrorCount -gt 0) {
    # Entra 가입 + MDM URL 존재 + 최근 오류 = 등록은 있으나 체크인/동기화 실패
    $classification    = "EnrollmentBroken"
    $recommendedAction = "Try sync first. If unresolved, collect diagnostics and review cleanup eligibility."
}
# ============================================================================
# 최종 Output 객체 구성
# FIX 6: DomainJoined, TenantName, MdmUrl (실제 값) 추가
# NEW: Has400Reject / HasAadEnrollDenied 신호 노출 (분류 근거 리뷰용)
# ----------------------------------------------------------------------------
$result = [ordered]@{
    ComputerName             = $env:COMPUTERNAME
    Time                     = (Get-Date).ToString("s")
    DomainJoined             = $domainJoined
    AzureAdJoined            = $azureAdJoined
    WorkplaceJoined          = $workplaceJoined
    TenantName               = $tenantName
    DeviceAuthStatus         = $deviceAuthStatus
    MdmUrl                   = $mdmUrl
    MdmUrlPresent            = $mdmUrlPresent
    EnrollmentGuidCount      = $enrollmentGuids.Count
    EnrollmentGuids          = ($enrollmentGuids -join ";")
    StatusGuidCount          = $statusGuids.Count
    StatusGuids              = ($statusGuids -join ";")
    OmadmGuidCount           = $omadmGuids.Count
    OmadmGuids               = ($omadmGuids -join ";")
    OmadmSessionGuidCount    = $omadmSessionGuids.Count
    OmadmSessionGuids        = ($omadmSessionGuids -join ";")
    OmadmLoggerGuidCount     = $omadmLoggerGuids.Count
    OmadmLoggerGuids         = ($omadmLoggerGuids -join ";")
    PolicyProviderGuidCount  = $policyProvGuids.Count
    PolicyProviderGuids      = ($policyProvGuids -join ";")
    TrackedGuidCount         = $trackedGuids.Count
    TrackedGuids             = ($trackedGuids -join ";")
    OmadmGuidsInEnrollmentCount        = $omadmGuidsInEnrollment.Count
    OmadmGuidsInEnrollment             = ($omadmGuidsInEnrollment -join ";")
    EnrollmentGuidsNotInOmadmCount     = $enrollmentGuidsNotInOmadm.Count
    EnrollmentGuidsNotInOmadm          = ($enrollmentGuidsNotInOmadm -join ";")
    OmadmGuidsNotInEnrollmentCount     = $omadmGuidsNotInEnrollment.Count
    OmadmGuidsNotInEnrollment          = ($omadmGuidsNotInEnrollment -join ";")
    StatusGuidsNotInEnrollmentCount    = $statusGuidsNotInEnrollment.Count
    StatusGuidsNotInEnrollment         = ($statusGuidsNotInEnrollment -join ";")
    OmadmSessionGuidsNotInEnrollmentCount = $omadmSessionGuidsNotInEnrollment.Count
    OmadmSessionGuidsNotInEnrollment      = ($omadmSessionGuidsNotInEnrollment -join ";")
    OmadmLoggerGuidsNotInEnrollmentCount  = $omadmLoggerGuidsNotInEnrollment.Count
    OmadmLoggerGuidsNotInEnrollment       = ($omadmLoggerGuidsNotInEnrollment -join ";")
    PolicyProviderGuidsNotInEnrollmentCount = $policyProvGuidsNotInEnrollment.Count
    PolicyProviderGuidsNotInEnrollment      = ($policyProvGuidsNotInEnrollment -join ";")
    TrackedGuidsNotInEnrollmentCount      = $trackedGuidsNotInEnrollment.Count
    TrackedGuidsNotInEnrollment           = ($trackedGuidsNotInEnrollment -join ";")
    EnterpriseMgmtTaskCount  = $enterpriseTaskCount
    RecentErrorCount         = $recentErrorCount
    BlockingErrorCount       = $blockingErrorCount
    Has400Reject             = $has400Reject
    HasAadEnrollDenied       = $hasAadEnrollDenied
    Classification           = $classification
    RecommendedAction        = $recommendedAction
    BackupDir                = $backupDir
    RemediationAttempted     = $false
    RemediationResult        = "Not run"
}
# ============================================================================
# 감지 결과를 JSON 및 텍스트로 저장 (정리 실행 전 스냅샷)
# ----------------------------------------------------------------------------
$result | ConvertTo-Json -Depth 4 |
    Out-File (Join-Path $backupDir "detection-result.json") -Encoding UTF8
$result.GetEnumerator() | ForEach-Object {
    "{0}={1}" -f $_.Key, $_.Value
} | Out-File (Join-Path $backupDir "detection-result.txt") -Encoding UTF8

# ----------------------------------------------------------------------------
# MAIN — 정리 실행 블록
# $Remediate 스위치가 없으면 이 블록 전체 스킵 (감지 전용 모드)
# ----------------------------------------------------------------------------
if ($Remediate) {

    # FIX 3 / FIX 7: HealthyManaged 및 EnrollmentBlocked는 정리 불필요 — 스킵
    if ($classification -in @("HealthyManaged", "EnrollmentBlocked")) {
        $result.RemediationResult = "Skipped: $classification."
    }
    # ------------------------------------------------------------------------
    # EnrollmentRejectedByService 는 로컬 정리 대상에서 제외
    # 로컬 아티팩트가 정상이어도 서비스가 400으로 거부하는 상태이므로,
    # 정리/DeviceEnroller 재실행은 동일 거부를 재현할 뿐이다 (실제 케이스 확인).
    # ------------------------------------------------------------------------
    elseif ($classification -eq "EnrollmentRejectedByService") {
        $result.RemediationResult = "Skipped: service-side rejection (HTTP 400 + AADEnrollAsync denied). Local cleanup cannot resolve this. Verify Entra device object / enrollment restriction / device cap / license first."
    }
    # ------------------------------------------------------------------------
    # FIX 2: DeviceAuthStatus null 가드 수정
    # 이전 버전: ($deviceAuthStatus -and $deviceAuthStatus -ne "SUCCESS")
    # → $deviceAuthStatus가 null이면 조건이 false가 되어 정리 진행됨 (버그)
    # 수정: null/공백이거나 SUCCESS가 아닌 경우 모두 차단
    # Entra ID 인증 상태가 불명확하면 레지스트리 정리보다 Entra 재가입이 선행되어야 함
    # ------------------------------------------------------------------------
    elseif ([string]::IsNullOrWhiteSpace($deviceAuthStatus) -or $deviceAuthStatus -ne "SUCCESS") {
        $result.RemediationResult = "Skipped: DeviceAuthStatus is missing or not SUCCESS. Resolve Entra join state first."
    }
    # ------------------------------------------------------------------------
    # FIX 3: EnrollmentBroken은 MDM URL이 있고 체크인 오류 중 — 아티팩트 정리 대상 아님
    # 권장 조치: Sync 먼저 시도 후 수동 검토
    # ------------------------------------------------------------------------
    elseif ($classification -eq "EnrollmentBroken") {
        $result.RemediationResult = "Skipped cleanup: EnrollmentBroken requires sync attempt first, not artifact removal."
    }
    elseif ($classification -in @("StaleEnrollmentSuspected", "EntraJoinedButMDMMissing")) {
        $result.RemediationAttempted = $true

        # ------------------------------------------------------------------------
        # 정리 전 레지스트리 전체 백업
        # reg.exe export는 HKLM\ 형식 사용 (HKLM:\ 아님)
        # NEW: 확장된 hive도 함께 백업 (PolicyManager / EnterpriseResourceManager)
        # ------------------------------------------------------------------------
        Export-RegKey "HKLM\SOFTWARE\Microsoft\Enrollments" (Join-Path $backupDir "Enrollments.reg")
        Export-RegKey "HKLM\SOFTWARE\Microsoft\Provisioning\OMADM" (Join-Path $backupDir "OMADM.reg")
        Export-RegKey "HKLM\SOFTWARE\Microsoft\PolicyManager\Providers" (Join-Path $backupDir "PolicyManager-Providers.reg")
        Export-RegKey "HKLM\SOFTWARE\Microsoft\EnterpriseResourceManager\Tracked" (Join-Path $backupDir "ERM-Tracked.reg")

        # ------------------------------------------------------------------------
        # StaleEnrollmentSuspected 전용 정리 블록
        # EntraJoinedButMDMMissing은 등록 GUID 자체가 없으므로 이 블록 스킵
        # ------------------------------------------------------------------------
        if ($classification -eq "StaleEnrollmentSuspected") {
            foreach ($guid in $enrollmentGuids) {
                $guidKey   = Join-Path $enrollPath $guid
                $statusKey = Join-Path $statusPath $guid

                # ----------------------------------------------------------------------------
                # FIX 1: GUID별 스테일 여부 개별 검증 (이전: 모든 GUID 삭제)
                # EnrollmentType = 6 : MDM 등록 타입 (Intune 현대 등록)
                # DiscoveryServiceFullURL이 manage.microsoft.com 포함 = Intune 엔드포인트
                # 두 조건 중 하나라도 해당하면 Intune MDM 아티팩트로 판단하여 삭제 대상
                # 해당 없으면 스킵 — 알 수 없는 GUID는 건드리지 않음
                # ----------------------------------------------------------------------------
                $enrollmentType = (Get-ItemProperty -Path $guidKey -Name "EnrollmentType" -ErrorAction SilentlyContinue).EnrollmentType
                $discoveryUrl   = (Get-ItemProperty -Path $guidKey -Name "DiscoveryServiceFullURL" -ErrorAction SilentlyContinue).DiscoveryServiceFullURL

                # FIX 1b: [int] 캐스팅으로 레지스트리 DWORD vs regex 이슈 방지
                if ([int]$enrollmentType -eq 6 -or $discoveryUrl -match "manage\.microsoft\.com") {
                    Remove-RegSubKey -Path $guidKey
                    Remove-RegSubKey -Path $statusKey
                    Remove-RegSubKey -Path (Join-Path $omadmPath $guid)

                    # ----------------------------------------------------------------
                    # OMADM\Sessions, OMADM\Logger, PolicyManager\Providers,
                    # EnterpriseResourceManager\Tracked 의 동일 GUID 하위 키 제거.
                    # 부분 정리로 인한 잔존 상태(다음 등록 흐름 방해)를 예방한다.
                    # 모두 GUID-scoped — 다른 GUID나 비-GUID 키는 제외하도록.
                    # ----------------------------------------------------------------
                    Remove-RegSubKey -Path (Join-Path $omadmSessionsPath $guid)
                    Remove-RegSubKey -Path (Join-Path $omadmLoggerPath $guid)
                    Remove-RegSubKey -Path (Join-Path $policyProvPath $guid)
                    Remove-RegSubKey -Path (Join-Path $trackedPath $guid)

                    # 해당 GUID와 연결된 EnterpriseMgmt 스케줄 작업 삭제
                    foreach ($task in $tasks) {
                        $taskIdentity = "$($task.TaskPath)$($task.TaskName)"
                        if ($taskIdentity -match [regex]::Escape($guid)) {
                            Unregister-ScheduledTask -TaskPath $task.TaskPath -TaskName $task.TaskName -Confirm:$false -ErrorAction SilentlyContinue
                        }
                    }
                    # ----------------------------------------------------------------------------
                    # 작업 제거 후 남은 빈 EnterpriseMgmt\{GUID} 폴더 삭제
                    # 반드시 Unregister-ScheduledTask 이후 호출 (잔여 작업 있으면 DeleteFolder 실패)
                    # ----------------------------------------------------------------------------
                    Remove-EnterpriseMgmtTaskFolder -Guid $guid
                    # ----------------------------------------------------------------
                    # 이전 등록의 Intune 클라이언트 인증서 제거. 
                    # Issuer가 "Intune MDM" 또는 "Microsoft Device Management Device Certificate Authority"인 인증서 가 맞는지 확인.
                    # ----------------------------------------------------------------------------
                    # 의미: 한 번이라도 등록되었던 단말을 재등록할 때, 잔존(lingering) 클라이언트
                    #           인증서가 다음 등록을 방해할 수 있으므로 제거한다.
                    # ----------------------------------------------------------------------------
                    # 범위 한정: StaleEnrollmentSuspected 경로에서만, 백업 이후에만 수행.
                    #            미등록(EntraJoinedButMDMMissing) 단말은 해당 인증서가 없어 no-op이므로
                    #            이 블록에 도달하지 않는다(상위 if로 분리됨).
                    # ----------------------------------------------------------------------------
                    # 주의: 정상 등록 단말에 잘못 실행되면 멀쩡한 등록의 인증서를 제거할 수 있으므로
                    #       반드시 stale로 분류·확정된 단말에 한해서만 수행 필수
                    # ----------------------------------------------------------------
                    Get-ChildItem -Path Cert:\LocalMachine\My -ErrorAction SilentlyContinue |
                        Where-Object {
                            $_.Issuer -match "Intune MDM" -or
                            $_.Issuer -match "Microsoft Device Management Device CA"
                        } |
                        Remove-Item -ErrorAction SilentlyContinue
                }
            }
        }

        # ============================================================================
        # FIX 4: DeviceEnroller 실행은 -RunDeviceEnroller 스위치 명시 시에만 실행
        # 이전 버전: ($RunDeviceEnroller -or $classification -in @(...)) 로직으로
        # -RunDeviceEnroller 없이도 특정 분류에서 자동 실행됨 (의도치 않은 동작)
        # 수정: -RunDeviceEnroller 스위치가 있어야만 실행되도록 기본값 (명시적 opt-in)
        # ============================================================================
        if ($RunDeviceEnroller) {
            # ----------------------------------------------------------------------------
            # FIX 3 (DeviceEnroller): -Wait 제거
            # DeviceEnroller.exe /c /AutoEnrollMDM 얌전히 완료 대기 할 것 (30~90초) 
            # Intune Remediations 스크립트 타임아웃(기본 60초)에 걸릴 위험
            # 프로세스 시작만 트리거하고 스크립트 수행 
            # ----------------------------------------------------------------------------
            $deviceEnroller = Join-Path $env:SystemRoot "System32\DeviceEnroller.exe"
            Start-Process -FilePath $deviceEnroller -ArgumentList "/c /AutoEnrollMDM" -WindowStyle Hidden
            $result.RemediationResult = "Cleanup completed and DeviceEnroller triggered (non-blocking). Re-check after sync interval."
        }
        else {
            # ----------------------------------------------------------------------------
            # FIX (메시지): EntraJoinedButMDMMissing의 경우 실제 정리 작업이 없으므로 메시지 구분
            # ----------------------------------------------------------------------------
            if ($classification -eq "EntraJoinedButMDMMissing") {
                $result.RemediationResult = "No artifact cleanup needed for this classification. DeviceEnroller NOT run (switch not specified)."
            }
            else {
                $result.RemediationResult = "Artifact cleanup completed. DeviceEnroller NOT run (switch not specified)."
            }
        }
    }
    else {
        $result.RemediationResult = "Skipped: classification not eligible for automatic remediation."
    }
    # ============================================================================
    # 정리 실행 후 최종 결과를 별도 JSON으로 저장됨. (detection-result.json은 정리 전 상태 스냅샷 참고)
    # FIX 4 (오류 처리): try/catch로 감싸 정리 도중 실패해도 결과 JSON은 기록 하도록 구성 
    # ============================================================================
    try {
        $result | ConvertTo-Json -Depth 4 |
            Out-File (Join-Path $backupDir "remediation-result.json") -Encoding UTF8
    }
    catch {
        # 결과 저장 실패 시 오류 내용을 별도 파일에 기록
        "Remediation result write failed: $_" |
            Out-File (Join-Path $backupDir "remediation-write-error.txt") -Encoding UTF8
    }
}
# ============================================================================
# 결과 출력 (콘솔 또는 Intune stdout 캡처용)
# CLI 측에서 단말 분석 결과 확인 한 후, 이후 "-Remediate -RunDeviceEnroller" 플래그로 작업 실행 여부 결정 하면 됨. 
# ============================================================================
$result