//
//  ScheduleRegistrationViewModel.swift
//  AppProduct
//
//  Created by euijjang97 on 1/22/26.
//

import Foundation
import SwiftData

/// 일정 등록 화면의 비즈니스 로직을 담당하는 뷰 모델입니다.
///
/// 제목, 장소, 시간, 참여자 등 일정 입력 폼의 상태를 관리합니다.
/// V2 API 마이그레이션에 따라 `isAllDay` 는 폼 토글로만 유지하며,
/// 송신 시점에 KST 자정/23:59:59.999 로 변환됩니다.
@Observable
class ScheduleRegistrationViewModel {
    // MARK: - Property

    /// 일정 생성 UseCase
    private let generateScheduleUseCase: GenerateScheduleUseCaseProtocol
    /// 일정 수정 UseCase
    private let updateScheduleUseCase: UpdateScheduleUseCaseProtocol
    /// 일정 제목 기반 태그 자동 추천 UseCase
    private let classifyScheduleUseCase: ClassifyScheduleUseCase
    /// 챌린저 검색 UseCase (수정 모드 참여자 조회용)
    private let searchChallengersUseCase: SearchChallengersUseCaseProtocol
    /// 일정 생성/수정 권한 조회 UseCase
    private let fetchScheduleCapabilitiesUseCase: FetchScheduleCapabilitiesUseCaseProtocol

    /// 전역 에러 핸들러 (실패 시 Alert 표시용)
    private let errorHandler: ErrorHandler

    /// 입력된 일정 제목
    var title: String = ""

    /// 선택된 장소 정보 (이름, 주소, 좌표)
    var place: PlaceSearchInfo = .init(name: "", address: "", coordinate: .init(latitude: 0.0, longitude: 0.0))

    /// 하루 종일 일정 여부 토글 상태 (송신 시 KST 자정/23:59:59.999 로 변환)
    var isAllDay: Bool = false

    /// 비대면 일정 여부 토글 상태
    ///
    /// `true` 이면 송신 시 `location: null` 로 전송되고, `false` 면 `place` 좌표가 사용됩니다.
    var isOnline: Bool = false

    /// 선택된 날짜 범위 (시작일~종료일)
    /// 기본값: 현재 시간 + 1시간부터 + 2시간까지
    var dataRange: DateRange = .init(startDate: .now.addingTimeInterval(3600), endDate: .now.addingTimeInterval(7200))

    /// 시작 날짜 DatePicker 표시 여부
    var showStartDatePicker: Bool = false

    /// 시작 시간 DatePicker 표시 여부
    var showStartTimePicker: Bool = false

    /// 종료 날짜 DatePicker 표시 여부
    var showEndDatePicker: Bool = false

    /// 종료 시간 DatePicker 표시 여부
    var showEndTimePicker: Bool = false

    /// 추가 메모 사항
    var memo: String = ""

    /// 선택된 참여자 목록
    var participatn: [ChallengerInfo] = .init()

    /// 선택된 카테고리 태그 목록
    var tag: [ScheduleIconCategory] = .init()

    /// 일정 생성/수정 API 상태 (툴바 로딩 + 성공 시 dismiss 제어)
    private(set) var submitState: Loadable<Bool> = .idle

    /// 인라인 에러 메시지 (예: 시작된 일정 수정 차단 SCHEDULE-0028)
    private(set) var inlineErrorMessage: String?

    /// 파괴적 작업 확인 다이얼로그 상태
    var alertPrompt: AlertPrompt?

    // MARK: - Attendance Policy

    /// 일정 생성/수정 권한 조회 상태
    private(set) var capabilitiesState: Loadable<ScheduleCapabilities> = .idle

    /// 출석 필수 일정 토글 상태
    var isAttendanceRequired: Bool = false

    /// 출석 체크인 시작 시각
    var attendanceCheckInStartAt: Date = .now

    /// 정시 출석 종료 시각 (= 지각 시작)
    var attendanceOnTimeEndAt: Date = .now

    /// 지각 종료 시각 (= 결석 시작)
    var attendanceLateEndAt: Date = .now

    /// 출석 정책 인라인 검증 에러
    private(set) var attendancePolicyError: AttendancePolicyError?

    /// 사용자가 출석 정책 시각을 직접 수정한 적이 있는지 여부 (자동 prefill 차단용)
    private var isAttendancePolicyDirty: Bool = false

    /// 수정 모드 진입 시점의 `isAttendanceRequired` 값 (PATCH 전환 플래그 산출용)
    private var initialIsAttendanceRequired: Bool = false

    /// 체크인 시작 날짜 DatePicker 표시 여부
    var showCheckInStartDatePicker: Bool = false
    /// 체크인 시작 시간 DatePicker 표시 여부
    var showCheckInStartTimePicker: Bool = false
    /// 정시 종료 날짜 DatePicker 표시 여부
    var showOnTimeEndDatePicker: Bool = false
    /// 정시 종료 시간 DatePicker 표시 여부
    var showOnTimeEndTimePicker: Bool = false
    /// 지각 종료 날짜 DatePicker 표시 여부
    var showLateEndDatePicker: Bool = false
    /// 지각 종료 시간 DatePicker 표시 여부
    var showLateEndTimePicker: Bool = false

    /// 장소를 포함한 필수 입력 충족 여부
    ///
    /// 비대면 일정(`isOnline == true`) 인 경우 장소 검증을 건너뜁니다.
    var canSubmit: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !tag.isEmpty else { return false }
        return isOnline || hasValidPlace
    }

    /// 수정 모드일 때 대상 일정 ID
    private(set) var editingScheduleId: Int?
    /// 수정 모드 초기 시작 시각 (이미 시작된 일정 가드용)
    private(set) var editingStartsAt: Date?
    /// 수정 모드에서 서버가 부착했던 출석 정책 (변경 추적 보조)
    private var editingAttendancePolicy: AttendancePolicy?
    /// 수정 모드 초기값 스냅샷
    private var initialEditSnapshot: EditFormSnapshot?
    /// 사용자가 태그를 직접 조정했는지 여부
    var isTagManuallyOverridden: Bool = false
    /// 수정 모드 프리필 시 서버에서 받은 참여자 멤버 ID 목록
    private var prefillMemberIds: Set<Int> = []

    // MARK: - AI Autofill Property

    /// SwiftData ModelContext (토큰 사용량 기록용). 뷰에서 주입합니다.
    var modelContext: ModelContext?

    /// AI 자동완성 자연어 입력 텍스트
    var aiRawInput: String = ""

    /// AI 자동완성 진행 상태
    var aiAutofillState: Loadable<Bool> = .idle

    // MARK: - Init

    convenience init(container: DIContainer, errorHandler: ErrorHandler) {
        let provider = container.resolve(HomeUseCaseProviding.self)
        self.init(
            generateScheduleUseCase: provider.generateScheduleUseCase,
            updateScheduleUseCase: provider.updateScheduleUseCase,
            classifyScheduleUseCase: provider.classifyScheduleUseCase,
            searchChallengersUseCase: provider.searchChallengersUseCase,
            fetchScheduleCapabilitiesUseCase: provider.fetchScheduleCapabilitiesUseCase,
            errorHandler: errorHandler
        )
    }

    init(
        generateScheduleUseCase: GenerateScheduleUseCaseProtocol,
        updateScheduleUseCase: UpdateScheduleUseCaseProtocol,
        classifyScheduleUseCase: ClassifyScheduleUseCase,
        searchChallengersUseCase: SearchChallengersUseCaseProtocol,
        fetchScheduleCapabilitiesUseCase: FetchScheduleCapabilitiesUseCaseProtocol,
        errorHandler: ErrorHandler
    ) {
        self.generateScheduleUseCase = generateScheduleUseCase
        self.updateScheduleUseCase = updateScheduleUseCase
        self.classifyScheduleUseCase = classifyScheduleUseCase
        self.searchChallengersUseCase = searchChallengersUseCase
        self.fetchScheduleCapabilitiesUseCase = fetchScheduleCapabilitiesUseCase
        self.errorHandler = errorHandler
    }

    // MARK: - Prefill

    /// 일정 상세 데이터를 기반으로 등록 폼을 프리필합니다.
    func applyPrefill(from detail: ScheduleDetailData, roadAddress: String?) {
        editingScheduleId = detail.scheduleId
        editingStartsAt = detail.startsAt
        editingAttendancePolicy = detail.attendancePolicy
        title = detail.name
        memo = detail.description
        isAllDay = detail.isAllDay
        isOnline = detail.isOnline
        dataRange = DateRange(startDate: detail.startsAt, endDate: detail.endsAt)
        if let location = detail.location {
            place = PlaceSearchInfo(
                name: location.locationName,
                address: roadAddress ?? location.locationName,
                coordinate: Coordinate(
                    latitude: location.latitude,
                    longitude: location.longitude
                )
            )
        } else {
            place = PlaceSearchInfo(
                name: "",
                address: "",
                coordinate: Coordinate(latitude: 0, longitude: 0)
            )
        }
        tag = detail.tags
            .compactMap(Self.mapScheduleTag)
            .filter { !$0.isDeprecated }
        isTagManuallyOverridden = !tag.isEmpty
        prefillMemberIds = Set(detail.participantMemberIds)

        if let policy = detail.attendancePolicy {
            isAttendanceRequired = true
            attendanceCheckInStartAt = policy.checkInStartAt
            attendanceOnTimeEndAt = policy.onTimeEndAt
            attendanceLateEndAt = policy.lateEndAt
            isAttendancePolicyDirty = true
        } else {
            isAttendanceRequired = false
        }
        initialIsAttendanceRequired = isAttendanceRequired

        initialEditSnapshot = currentEditSnapshot
    }

    /// 수정 모드에서 서버의 참여자 멤버 ID를 기반으로 챌린저 정보를 조회하여 참여자 목록을 채웁니다.
    @MainActor
    func fetchPrefillParticipants() async {
        guard !prefillMemberIds.isEmpty else { return }
        var remainingIds = prefillMemberIds
        var matched: [ChallengerInfo] = []
        var cursor: Int? = nil
        var hasNext = true

        while hasNext, !remainingIds.isEmpty {
            let query = ChallengerSearchRequestDTO(cursor: cursor)
            guard let (challengers, nextHasNext, nextCursor) = try? await searchChallengersUseCase.execute(query: query) else {
                break
            }
            for challenger in challengers {
                guard let challengerMemberId = Int(challenger.memberId),
                      remainingIds.contains(challengerMemberId) else {
                    continue
                }
                matched.append(challenger)
                remainingIds.remove(challengerMemberId)
            }
            hasNext = nextHasNext
            cursor = nextCursor
        }

        participatn = matched
        initialEditSnapshot = currentEditSnapshot
    }

    /// 서버 태그 문자열을 `ScheduleIconCategory`로 매핑합니다.
    ///
    /// rawValue 직접 매핑 → 대문자 변환 매핑 → 한글 매핑 순으로 시도합니다.
    nonisolated private static func mapScheduleTag(_ raw: String) -> ScheduleIconCategory? {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let direct = ScheduleIconCategory(rawValue: normalized) {
            return direct
        }
        if let upper = ScheduleIconCategory(rawValue: normalized.uppercased()) {
            return upper
        }
        switch normalized {
        case "리더십": return .leadership
        case "스터디": return .study
        case "회비": return .fee
        case "회의": return .meeting
        case "네트워킹": return .networking
        case "해커톤": return .hackathon
        case "프로젝트": return .project
        case "발표": return .presentation
        case "워크샵": return .workshop
        case "회고": return .review
        case "뒷풀이": return .celebration
        case "오리엔테이션": return .orientation
        case "테스트": return nil
        case "일반": return .general
        default: return nil
        }
    }

    // MARK: - Function

    /// 제목 변경 시 자동 태그 추천을 반영합니다.
    ///
    /// 사용자가 태그를 직접 변경한 이후에는 자동 추천이 기존 선택을 덮어쓰지 않습니다.
    @MainActor
    func titleDidChange(to newTitle: String) async {
        title = newTitle

        let trimmedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            if !isTagManuallyOverridden {
                tag.removeAll()
            }
            return
        }

        guard !isTagManuallyOverridden else {
            return
        }

        let suggestedTag = await classifyScheduleUseCase.execute(title: trimmedTitle)
        let latestTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        guard latestTitle == trimmedTitle else {
            return
        }
        guard !isTagManuallyOverridden else {
            return
        }

        tag = [suggestedTag]
    }

    /// 태그 선택을 사용자 입력으로 반영합니다.
    ///
    /// 사용자가 태그를 비우면 이후 제목 변경 시 자동 추천이 다시 동작합니다.
    func updateTagsFromUser(_ tags: [ScheduleIconCategory]) {
        let sanitized = Array(Set(tags.filter { !$0.isDeprecated })).sorted {
            $0.rawValue < $1.rawValue
        }

        if tag == sanitized {
            return
        }

        tag = sanitized
        isTagManuallyOverridden = !sanitized.isEmpty
    }

    // MARK: - Attendance Policy Function

    /// 일정 생성/수정 권한을 조회하여 출석 정책 섹션 노출 여부를 결정합니다.
    ///
    /// 호출 실패 시에는 안전 기본값으로 권한 미보유로 간주하여 섹션이 노출되지 않도록 합니다.
    @MainActor
    func loadCapabilities() async {
        capabilitiesState = .loading
        do {
            let capabilities = try await fetchScheduleCapabilitiesUseCase.execute()
            capabilitiesState = .loaded(capabilities)
            if !capabilities.canCreateAttendanceRequiredSchedule {
                isAttendanceRequired = false
            }
            prefillAttendancePolicyIfNeeded()
        } catch {
            capabilitiesState = .idle
            errorHandler.handle(error, context: ErrorContext(
                feature: "Home",
                action: "loadCapabilities"
            ))
        }
    }

    /// 일정 시작/종료 시각을 기준으로 출석 정책 기본값을 자동으로 채웁니다.
    ///
    /// - 일반 일정: `startsAt - 20분 / startsAt / startsAt + 60분`
    /// - 하루종일 일정: 출석 정책 섹션 자체를 비노출하므로 prefill 생략
    /// - 사용자가 한 번이라도 직접 시각을 수정한 경우(`isAttendancePolicyDirty == true`)에는 덮어쓰지 않습니다.
    func prefillAttendancePolicyIfNeeded() {
        guard !isAttendancePolicyDirty else { return }
        guard !isAllDay else { return }
        let startsAt = dataRange.startDate
        attendanceCheckInStartAt = startsAt.addingTimeInterval(-20 * 60)
        attendanceOnTimeEndAt = startsAt
        attendanceLateEndAt = startsAt.addingTimeInterval(60 * 60)
    }

    /// 사용자가 출석 정책 시각 중 하나라도 직접 수정했음을 기록합니다.
    ///
    /// 이후 일정 시작 시각이 변경되어도 자동 prefill 로 덮어쓰지 않습니다.
    func markAttendancePolicyDirty() {
        isAttendancePolicyDirty = true
    }

    /// 출석 필수 토글 변경 진입점.
    ///
    /// 수정 모드에서 기존에 출석이 필수였던 일정을 OFF 로 전환할 때만
    /// destructive AlertPrompt 를 띄워 사용자의 의도를 재확인합니다.
    /// 그 외 경우(생성 모드, 단순 ON, 기존 OFF → ON 등)는 즉시 반영합니다.
    @MainActor
    func attendanceToggleChanged(to newValue: Bool) {
        if !newValue, initialIsAttendanceRequired {
            alertPrompt = AlertPrompt(
                title: "출석 데이터 삭제",
                message: "출석 필수를 해제하면 기존 출석 데이터가 삭제됩니다. 계속하시겠습니까?",
                positiveBtnTitle: "해제",
                positiveBtnAction: { [weak self] in
                    self?.applyAttendanceToggle(to: false)
                },
                negativeBtnTitle: "취소",
                isPositiveBtnDestructive: true
            )
            return
        }
        applyAttendanceToggle(to: newValue)
    }

    /// 출석 필수 토글을 실제 적용합니다.
    ///
    /// OFF -> ON 전환은 사용자가 새로 정책을 부여하려는 명확한 의도이므로
    /// 이전 dirty 상태를 무효화하고 일정 시각 기준 기본값으로 채웁니다.
    @MainActor
    func applyAttendanceToggle(to newValue: Bool) {
        isAttendanceRequired = newValue
        if newValue {
            isAttendancePolicyDirty = false
            prefillAttendancePolicyIfNeeded()
        }
        attendancePolicyError = validateAttendancePolicy()
    }

    /// 출석 정책 입력 폼을 검증합니다.
    ///
    /// - Returns: 검증 위반이 있으면 ``AttendancePolicyError``, 없으면 `nil`
    private func validateAttendancePolicy() -> AttendancePolicyError? {
        guard isAttendanceRequired else { return nil }
        guard attendanceCheckInStartAt < attendanceOnTimeEndAt else {
            return .invalidOrder(.checkInVsOnTime)
        }
        guard attendanceOnTimeEndAt < attendanceLateEndAt else {
            return .invalidOrder(.onTimeVsLate)
        }
        guard attendanceLateEndAt <= dataRange.endDate else {
            return .lateExceedsEnd
        }
        return nil
    }

    /// 출석 정책 시각 변경 시 dirty 표시 + 검증을 갱신합니다.
    @MainActor
    func attendanceTimesChanged() {
        markAttendancePolicyDirty()
        attendancePolicyError = validateAttendancePolicy()
    }

    /// 송신용 출석 정책 DTO 를 생성합니다.
    ///
    /// 출석 토글이 OFF 이거나 하루종일 일정인 경우 `nil` 을 반환합니다.
    private func makeAttendancePolicyDTOForSubmit() -> V2AttendancePolicyDTO? {
        guard isAttendanceRequired, !isAllDay else { return nil }
        return V2AttendancePolicyDTO(
            domain: AttendancePolicy(
                checkInStartAt: attendanceCheckInStartAt,
                onTimeEndAt: attendanceOnTimeEndAt,
                lateEndAt: attendanceLateEndAt
            )
        )
    }

    /// 수정 모드에서 PATCH 송신용 `isAttendanceRequired` 전환 플래그를 산출합니다.
    ///
    /// 진입 시점 상태와 현재 토글값을 비교해 다음 규칙으로 결정합니다:
    /// - 변화 없음 → `nil` (필드 미송신, 백엔드 기존 상태 유지)
    /// - OFF → ON → `true` (`attendancePolicy` 필수 동반 송신)
    /// - ON → OFF → `false` (백엔드가 기존 출석 정책 자동 삭제)
    private var attendanceRequiredTransitionFlag: Bool? {
        if initialIsAttendanceRequired == isAttendanceRequired {
            return nil
        }
        return isAttendanceRequired
    }

    /// 수정 모드에서 PATCH 송신용 `attendancePolicy` 값을 산출합니다.
    ///
    /// - 토글 OFF: `nil` (필드 자체 미송신 — 전환 플래그 `false` 가 삭제 처리)
    /// - 토글 ON: 현재 폼의 3개 시각 DTO
    /// - 하루종일: `nil`
    private func makeAttendancePolicyDTOForUpdate() -> V2AttendancePolicyDTO? {
        guard isAttendanceRequired, !isAllDay else { return nil }
        return V2AttendancePolicyDTO(
            domain: AttendancePolicy(
                checkInStartAt: attendanceCheckInStartAt,
                onTimeEndAt: attendanceOnTimeEndAt,
                lateEndAt: attendanceLateEndAt
            )
        )
    }

    /// 일정을 서버에 생성합니다 (V2).
    @MainActor
    func submitSchedule() async {
        attendancePolicyError = validateAttendancePolicy()
        guard attendancePolicyError == nil else {
            submitState = .idle
            return
        }

        let memberIds = sanitizedParticipantMemberIds()
        if let overflowMessage = participantOverflowMessage(memberIds: memberIds) {
            submitState = .idle
            inlineErrorMessage = overflowMessage
            return
        }

        submitState = .loading
        inlineErrorMessage = nil
        let dto = GenerateScheduleRequetDTO(
            name: title,
            description: memo,
            startsAt: effectiveStartsAt,
            endsAt: effectiveEndsAt,
            location: locationDTOForSubmit(),
            participantMemberIds: memberIds,
            tags: sanitizedTags,
            attendancePolicy: makeAttendancePolicyDTOForSubmit()
        )
        do {
            try await generateScheduleUseCase.execute(schedule: dto)
            submitState = .loaded(true)
        } catch {
            submitState = .idle
            errorHandler.handle(error, context: ErrorContext(
                feature: "Home",
                action: "submitSchedule",
                retryAction: { [weak self] in
                    await self?.submitSchedule()
                }
            ))
        }
    }

    /// 수정 모드에서 초기값 대비 변경 사항이 있는지 확인합니다.
    var hasChangesInEditMode: Bool {
        guard initialEditSnapshot != nil else { return true }
        return initialEditSnapshot != currentEditSnapshot
    }

    /// 이미 시작된 일정인지 여부 (수정 모드 가드용)
    ///
    /// 수정 모드에서 진입 시점의 `editingStartsAt` 이 현재 시각 이전이면 `true`.
    var isEditingStartedSchedule: Bool {
        guard let editingStartsAt else { return false }
        return Date() >= editingStartsAt
    }

    /// 선택된 장소 정보가 실제 제출 가능한 상태인지 확인합니다.
    var hasValidPlace: Bool {
        let trimmedPlaceName = place.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let latitude = place.coordinate.latitude
        let longitude = place.coordinate.longitude

        guard !trimmedPlaceName.isEmpty else { return false }
        guard latitude.isFinite, longitude.isFinite else { return false }
        guard (-90.0...90.0).contains(latitude) else { return false }
        guard (-180.0...180.0).contains(longitude) else { return false }
        return !(latitude == 0 && longitude == 0)
    }

    /// 현재 폼 상태의 스냅샷을 생성합니다.
    private var currentEditSnapshot: EditFormSnapshot {
        EditFormSnapshot(
            title: title,
            placeName: place.name,
            placeAddress: place.address,
            latitude: place.coordinate.latitude,
            longitude: place.coordinate.longitude,
            isAllDay: isAllDay,
            isOnline: isOnline,
            startDate: dataRange.startDate,
            endDate: dataRange.endDate,
            memo: memo,
            participantMemberIds: sanitizedParticipantMemberIds(),
            tags: sanitizedTags.map(\.rawValue).sorted()
        )
    }

    /// 레거시 테스트 태그를 제거한 현재 태그 목록
    private var sanitizedTags: [ScheduleIconCategory] {
        tag.filter { !$0.isDeprecated }
    }

    /// 송신용 시작 시각 — 하루종일 토글이 켜져 있으면 KST 자정으로 정규화
    private var effectiveStartsAt: Date {
        isAllDay ? dataRange.startDate.kstStartOfDay : dataRange.startDate
    }

    /// 송신용 종료 시각 — 하루종일 토글이 켜져 있으면 KST 23:59:59.999 로 정규화
    private var effectiveEndsAt: Date {
        isAllDay ? dataRange.endDate.kstEndOfDay : dataRange.endDate
    }

    /// 참여자 수가 서버 측 한도(`ScheduleCapabilities.maxParticipantCount`)를 초과하면
    /// 인라인 메시지로 표시할 안내 문구를 반환합니다.
    ///
    /// - capabilities 가 아직 로드되지 않았거나 한도가 0 이하면 검사 생략(`nil`).
    /// - 본인 강제 포함 후의 최종 참여자 수를 기준으로 검증합니다.
    private func participantOverflowMessage(memberIds: [Int]) -> String? {
        guard case .loaded(let capabilities) = capabilitiesState else { return nil }
        let limit = capabilities.maxParticipantCount
        guard limit > 0 else { return nil }
        guard memberIds.count > limit else { return nil }
        return "최대 \(limit)명까지 초대할 수 있어요. 현재 \(memberIds.count)명이 선택되어 있습니다."
    }

    /// 본인 멤버 ID 를 강제 포함한 정렬된 참여자 ID 목록
    private func sanitizedParticipantMemberIds() -> [Int] {
        var memberIds = Array(Set(participatn.compactMap { Int($0.memberId) })).sorted()
        let myMemberId = AppStorageKey.legacyMemberIdInt()
        if myMemberId != 0, !memberIds.contains(myMemberId) {
            memberIds.append(myMemberId)
        }
        return memberIds
    }

    /// 대면/비대면 토글 변경 시 호출합니다.
    ///
    /// - Parameter isInPerson: `true` 이면 대면(`isOnline = false`), `false` 이면 비대면(`isOnline = true`).
    ///   비대면으로 전환할 때는 `place` 를 빈 값으로 초기화합니다.
    func inPersonModeToggleChanged(to isInPerson: Bool) {
        isOnline = !isInPerson
        if !isInPerson {
            place = PlaceSearchInfo(
                name: "",
                address: "",
                coordinate: Coordinate(latitude: 0.0, longitude: 0.0)
            )
        }
    }

    /// 송신용 location DTO — 비대면이면 `nil`, 그 외엔 현재 장소 좌표
    private func locationDTOForSubmit() -> V2LocationDTO? {
        guard !isOnline else { return nil }
        return V2LocationDTO(
            latitude: place.coordinate.latitude,
            longitude: place.coordinate.longitude,
            locationName: place.name
        )
    }

    /// 수정 모드에서 변경 감지를 위한 폼 상태 스냅샷
    private struct EditFormSnapshot: Equatable {
        let title: String
        let placeName: String
        let placeAddress: String
        let latitude: Double
        let longitude: Double
        let isAllDay: Bool
        let isOnline: Bool
        let startDate: Date
        let endDate: Date
        let memo: String
        let participantMemberIds: [Int]
        let tags: [String]
    }

    /// 일정을 서버에 수정합니다 (V2).
    ///
    /// 시작된 일정은 클라이언트 가드로 차단하며, 서버가 `SCHEDULE-0028` 로 거부할 경우
    /// `inlineErrorMessage` 를 통해 화면 내 메시지로 표시합니다.
    @MainActor
    func updateSchedule() async {
        guard let scheduleId = editingScheduleId else {
            return
        }

        if isEditingStartedSchedule {
            inlineErrorMessage = "이미 시작된 일정은 수정할 수 없습니다."
            return
        }

        attendancePolicyError = validateAttendancePolicy()
        guard attendancePolicyError == nil else {
            submitState = .idle
            return
        }

        let participantMemberIds: [Int]? = participatn.isEmpty ? nil : sanitizedParticipantMemberIds()
        if let memberIds = participantMemberIds,
           let overflowMessage = participantOverflowMessage(memberIds: memberIds) {
            submitState = .idle
            inlineErrorMessage = overflowMessage
            return
        }

        submitState = .loading
        inlineErrorMessage = nil

        let dto = UpdateScheduleRequestDTO(
            name: title,
            description: memo,
            startsAt: effectiveStartsAt,
            endsAt: effectiveEndsAt,
            location: locationDTOForSubmit(),
            participantMemberIds: participantMemberIds,
            tags: sanitizedTags,
            attendancePolicy: makeAttendancePolicyDTOForUpdate(),
            isOnline: isOnlineDiff,
            isAttendanceRequired: attendanceRequiredTransitionFlag
        )
        do {
            try await updateScheduleUseCase.execute(
                scheduleId: scheduleId,
                schedule: dto
            )
            submitState = .loaded(true)
        } catch let error as RepositoryError where error.code == "SCHEDULE-0028" {
            submitState = .idle
            inlineErrorMessage = "이미 시작된 일정은 수정할 수 없습니다."
        } catch {
            submitState = .idle
            errorHandler.handle(error, context: ErrorContext(
                feature: "Home",
                action: "updateSchedule",
                retryAction: { [weak self] in
                    await self?.updateSchedule()
                }
            ))
        }
    }

    /// 초기 스냅샷 대비 `isOnline` 토글이 변경되었는지 — 변경 시 명시 송신
    private var isOnlineDiff: Bool? {
        guard let initial = initialEditSnapshot else { return nil }
        return initial.isOnline == isOnline ? nil : isOnline
    }
}
