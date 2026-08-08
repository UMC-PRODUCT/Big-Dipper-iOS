//
//  ScheduleRegistrationViewModel.swift
//  HomePresentation
//
//  Created by euijjang97 on 1/22/26.
//

import CoreDI
import Foundation
import HomeDomain
import SwiftData
import UMCFoundation

/// 일정 등록/수정 화면의 상태를 관리하는 뷰 모델.
///
/// 생성과 수정을 한 폼으로 다룬다. 수정 모드는 ``applyPrefill(from:roadAddress:)`` 로 진입
/// 시점 스냅샷을 만들어 두고, 스냅샷과 달라진 게 있을 때만 저장 버튼을 연다.
///
/// `isAllDay` 는 서버 필드가 아니라 폼 토글이며, 송신 시점에 KST 자정 / 23:59:59.999 로
/// 정규화된다.
@MainActor
@Observable
final class ScheduleRegistrationViewModel {

    // MARK: - Dependency

    private let generateScheduleUseCase: GenerateScheduleUseCaseProtocol
    private let updateScheduleUseCase: UpdateScheduleUseCaseProtocol
    private let classifyScheduleUseCase: ClassifyScheduleUseCaseProtocol

    /// 전역 에러 핸들러. 뷰가 Environment 값을 넘겨준다.
    var errorHandler: ErrorHandler?

    /// AI 일일 토큰 사용량 기록용 컨텍스트. 뷰가 Environment 값을 넘겨준다.
    var modelContext: ModelContext?

    // MARK: - Constants

    private enum Constants {
        static let defaultStartOffset: TimeInterval = 3_600
        static let defaultDuration: TimeInterval = 3_600
        /// 일정 시작 기준 체크인 오픈 시각 오프셋
        static let checkInLeadTime: TimeInterval = -20 * 60
        /// 일정 시작 기준 지각 인정 마감 오프셋
        static let lateGraceTime: TimeInterval = 60 * 60
        static let startedScheduleMessage = "이미 시작된 일정은 수정할 수 없습니다."
        /// 시작된 일정 수정을 거부하는 서버 에러 코드
        static let startedScheduleCode = "SCHEDULE-0028"
    }

    // MARK: - Property

    var title: String = ""
    var memo: String = ""
    var isAllDay: Bool = false
    var isOnline: Bool = false

    var startDate: Date = .now.addingTimeInterval(Constants.defaultStartOffset)
    var endDate: Date = .now.addingTimeInterval(
        Constants.defaultStartOffset + Constants.defaultDuration
    )

    /// 선택된 장소. 이름과 좌표를 함께 들고 있어 부분적으로 어긋난 상태가 생기지 않는다.
    private(set) var placeLocation: ScheduleLocation?

    /// 선택된 장소의 주소. 서버로 보내지 않고 장소 선택 UI 의 부제로만 쓴다.
    private(set) var placeAddress: String = ""

    private(set) var tags: [ScheduleIconCategory] = []

    /// 사용자가 태그를 직접 조정했는지 여부. `true` 면 제목 기반 자동 추천이 덮어쓰지 않는다.
    private(set) var isTagManuallyOverridden: Bool = false

    /// 생성/수정 요청 상태. 툴바 로딩 표시와 성공 시 화면 닫기를 함께 제어한다.
    private(set) var submitState: Loadable<Bool> = .idle

    /// 화면 내 인라인 에러 메시지 (시작된 일정 수정 차단 등)
    private(set) var inlineErrorMessage: String?

    var alertPrompt: AlertPrompt?

    // MARK: - Attendance Policy Property

    var isAttendanceRequired: Bool = false
    var attendanceCheckInStartAt: Date = .now
    var attendanceOnTimeEndAt: Date = .now
    var attendanceLateEndAt: Date = .now

    /// 출석 정책 인라인 검증 메시지. `nil` 이면 통과.
    private(set) var attendancePolicyErrorMessage: String?

    /// 사용자가 출석 정책 시각을 직접 수정한 적이 있는지 여부 (자동 prefill 차단용)
    private var isAttendancePolicyDirty: Bool = false

    /// 수정 모드 진입 시점의 출석 필수 여부 (PATCH 전환 플래그 산출용)
    private var initialIsAttendanceRequired: Bool = false

    // MARK: - AI Autofill Property

    var aiRawInput: String = ""
    var aiAutofillState: Loadable<Bool> = .idle

    /// 당일 누적 AI 토큰 사용량 (SwiftData 에서 복원)
    var aiCumulativeUsedTokens: Int = 0

    // MARK: - Edit Mode Property

    private(set) var editingScheduleId: String?

    /// 수정 모드 진입 시점의 일정 시작 시각 (이미 시작된 일정 가드용)
    private var editingStartsAt: Date?

    private var initialEditSnapshot: EditFormSnapshot?

    // MARK: - Computed Property

    /// 필수 입력이 모두 채워졌는지 여부. 비대면 일정은 장소 검증을 건너뛴다.
    var canSubmit: Bool {
        guard !trimmedTitle.isEmpty, !sanitizedTags.isEmpty else { return false }
        guard attendancePolicyErrorMessage == nil else { return false }
        return isOnline || hasValidPlace
    }

    /// 대면 일정에 필요한 장소 정보(이름 + 실좌표)가 모두 갖춰졌는지.
    ///
    /// AI 자동완성은 이름만 제안하고 좌표를 (0, 0) 으로 남기므로, 좌표까지 확정되기 전에는
    /// 제출을 막아 (0, 0) 기준 지오펜스가 만들어지는 것을 방지한다.
    var hasValidPlace: Bool {
        guard let placeLocation else { return false }
        let name = placeLocation.locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }

        let latitude = placeLocation.latitude
        let longitude = placeLocation.longitude
        guard latitude.isFinite, longitude.isFinite else { return false }
        guard (-90.0...90.0).contains(latitude), (-180.0...180.0).contains(longitude) else {
            return false
        }
        return !(latitude == 0 && longitude == 0)
    }

    /// 수정 모드에서 진입 시점 대비 변경 사항이 있는지 여부.
    var hasChangesInEditMode: Bool {
        guard let initialEditSnapshot else { return true }
        return initialEditSnapshot != currentEditSnapshot
    }

    /// 이미 시작된 일정인지 여부 (수정 모드 가드용).
    var isEditingStartedSchedule: Bool {
        guard let editingStartsAt else { return false }
        return Date() >= editingStartsAt
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var sanitizedTags: [ScheduleIconCategory] {
        tags.filter { !$0.isDeprecated }
    }

    /// 송신용 시작 시각 — 하루 종일이면 KST 자정으로 정규화
    private var effectiveStartsAt: Date {
        isAllDay ? startDate.kstStartOfDay : startDate
    }

    /// 송신용 종료 시각 — 하루 종일이면 KST 23:59:59.999 로 정규화
    private var effectiveEndsAt: Date {
        isAllDay ? endDate.kstEndOfDay : endDate
    }

    /// 송신용 장소 — 비대면이면 `nil`
    private var submitLocation: ScheduleLocation? {
        isOnline ? nil : placeLocation
    }

    /// 송신용 출석 정책 — 토글 OFF 또는 하루 종일이면 `nil`
    private var submitAttendancePolicy: ScheduleAttendancePolicy? {
        guard isAttendanceRequired, !isAllDay else { return nil }
        return ScheduleAttendancePolicy(
            checkInStartAt: attendanceCheckInStartAt,
            onTimeEndAt: attendanceOnTimeEndAt,
            lateEndAt: attendanceLateEndAt
        )
    }

    /// 수정 모드 PATCH 의 출석 필수 전환 플래그. 변화가 없으면 `nil` 로 필드를 빼 기존 상태를 둔다.
    private var attendanceRequiredTransitionFlag: Bool? {
        initialIsAttendanceRequired == isAttendanceRequired ? nil : isAttendanceRequired
    }

    /// 수정 모드 PATCH 의 대면/비대면 전환 플래그. 변화가 없으면 `nil`.
    private var isOnlineTransitionFlag: Bool? {
        guard let initialEditSnapshot else { return nil }
        return initialEditSnapshot.isOnline == isOnline ? nil : isOnline
    }

    // MARK: - Init

    init(container: DIContainer) {
        generateScheduleUseCase = container.resolve(GenerateScheduleUseCaseProtocol.self)
        updateScheduleUseCase = container.resolve(UpdateScheduleUseCaseProtocol.self)
        classifyScheduleUseCase = container.resolve(ClassifyScheduleUseCaseProtocol.self)
        prefillAttendancePolicyIfNeeded()
    }

    // MARK: - Prefill

    /// 일정 상세를 폼에 반영하고 변경 감지용 초기 스냅샷을 만든다.
    ///
    /// - Parameters:
    ///   - detail: 수정 대상 일정
    ///   - roadAddress: 장소 부제로 우선 노출할 도로명 주소
    func applyPrefill(from detail: ScheduleDetailData, roadAddress: String? = nil) {
        editingScheduleId = detail.scheduleId
        editingStartsAt = detail.startsAt
        title = detail.name
        memo = detail.description
        isAllDay = detail.isAllDay
        isOnline = detail.isOnline
        startDate = detail.startsAt
        endDate = detail.endsAt
        placeLocation = detail.location
        placeAddress = roadAddress ?? detail.location?.locationName ?? ""
        tags = detail.tags.compactMap(Self.scheduleTag(from:))
        isTagManuallyOverridden = !tags.isEmpty

        // ponytail: 참여자 선택은 SelectedChallengerView 가 ActivityPresentation internal 이라
        // 제외 — 공용 승격 후 결선. 수정 시 participantMemberIds 는 nil 로 보내 서버 값을 보존한다.

        if let policy = detail.attendancePolicy {
            isAttendanceRequired = true
            attendanceCheckInStartAt = policy.checkInStartAt
            attendanceOnTimeEndAt = policy.onTimeEndAt
            attendanceLateEndAt = policy.lateEndAt
            isAttendancePolicyDirty = true
        }
        initialIsAttendanceRequired = isAttendanceRequired

        prefillAttendancePolicyIfNeeded()
        initialEditSnapshot = currentEditSnapshot
    }

    /// 서버 태그 문자열을 ``ScheduleIconCategory`` 로 매핑한다.
    ///
    /// rawValue 직접 매핑 → 대문자 매핑 → 한글 매핑 순으로 시도하고, 신규 입력에 쓰지 않는
    /// 레거시 카테고리는 걸러낸다.
    private static func scheduleTag(from raw: String) -> ScheduleIconCategory? {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let matched = ScheduleIconCategory(rawValue: normalized)
            ?? ScheduleIconCategory(rawValue: normalized.uppercased())
            ?? ScheduleIconCategory.selectableCases.first { $0.korean == normalized }
        guard let matched, !matched.isDeprecated else { return nil }
        return matched
    }

    // MARK: - Input Function

    /// 제목 변경 시 자동 태그 추천을 반영한다.
    ///
    /// 사용자가 태그를 직접 고른 뒤에는 추천이 선택을 덮어쓰지 않는다. 분류는 비동기라 결과가
    /// 돌아왔을 때 제목이 이미 바뀌었으면 버린다.
    func titleDidChange(to newTitle: String) async {
        title = newTitle

        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            if !isTagManuallyOverridden {
                tags.removeAll()
            }
            return
        }
        guard !isTagManuallyOverridden else { return }

        let suggested = await classifyScheduleUseCase.execute(title: trimmed)

        guard !isTagManuallyOverridden, trimmedTitle == trimmed else { return }
        tags = [suggested]
    }

    /// 태그 선택을 사용자 입력으로 반영한다.
    ///
    /// 사용자가 태그를 모두 비우면 이후 제목 변경 시 자동 추천이 다시 동작한다.
    func updateTagsFromUser(_ newTags: [ScheduleIconCategory]) {
        let sanitized = Array(Set(newTags.filter { !$0.isDeprecated }))
            .sorted { $0.rawValue < $1.rawValue }
        guard tags != sanitized else { return }

        tags = sanitized
        isTagManuallyOverridden = !sanitized.isEmpty
    }

    /// 장소 선택 결과를 반영한다.
    ///
    /// 이름이 비면 "선택 해제" 로 보고 좌표까지 함께 비운다. 이름만 지우고 좌표를 남기면 화면에는
    /// 장소가 없는데 페이로드에는 좌표가 실린다.
    func placeSelectionChanged(
        name: String,
        address: String,
        latitude: Double,
        longitude: Double
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            clearPlaceSelection()
            return
        }
        placeLocation = ScheduleLocation(
            latitude: latitude,
            longitude: longitude,
            locationName: trimmedName
        )
        placeAddress = address
    }

    /// 대면/비대면 토글 변경을 처리한다. 비대면으로 바꾸면 장소를 비운다.
    func inPersonModeToggleChanged(to isInPerson: Bool) {
        isOnline = !isInPerson
        if isOnline {
            clearPlaceSelection()
        }
    }

    private func clearPlaceSelection() {
        placeLocation = nil
        placeAddress = ""
    }

    /// 시작 시각 변경 처리 — 종료가 앞서면 함께 밀고 출석 정책 기본값을 다시 계산한다.
    func startDateChanged() {
        if endDate < startDate {
            endDate = startDate
        }
        prefillAttendancePolicyIfNeeded()
    }

    /// 종료 시각 변경 처리 — 시작보다 앞서면 시작 시각으로 되돌린다.
    func endDateChanged() {
        if endDate < startDate {
            endDate = startDate
        }
        validateAttendancePolicy()
    }

    // MARK: - Attendance Policy Function

    /// 일정 시작 시각을 기준으로 출석 정책 기본값을 채운다.
    ///
    /// 사용자가 한 번이라도 시각을 직접 고쳤거나 하루 종일 일정이면 값은 건드리지 않는다. 다만
    /// 검증은 일정 시작/종료에 의존하므로 건너뛰는 경우에도 항상 갱신한다.
    func prefillAttendancePolicyIfNeeded() {
        defer { validateAttendancePolicy() }
        guard !isAttendancePolicyDirty, !isAllDay else { return }

        attendanceCheckInStartAt = startDate.addingTimeInterval(Constants.checkInLeadTime)
        attendanceOnTimeEndAt = startDate
        attendanceLateEndAt = startDate.addingTimeInterval(Constants.lateGraceTime)
    }

    /// 출석 정책 시각 변경 시 dirty 표시 + 검증을 갱신한다.
    func attendanceTimesChanged() {
        isAttendancePolicyDirty = true
        validateAttendancePolicy()
    }

    /// 출석 필수 토글 변경 진입점.
    ///
    /// 기존에 출석이 필수였던 일정을 OFF 로 되돌릴 때만 확인 다이얼로그를 띄운다. 서버가 이
    /// 전환에서 기존 출석 데이터를 지우기 때문이다.
    func attendanceToggleChanged(to newValue: Bool) {
        guard !newValue, initialIsAttendanceRequired else {
            applyAttendanceToggle(to: newValue)
            return
        }
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
    }

    /// 출석 필수 토글을 실제로 적용한다.
    ///
    /// OFF → ON 은 정책을 새로 부여하려는 의도이므로 이전 dirty 표시를 버리고 일정 시각 기준
    /// 기본값으로 다시 채운다.
    private func applyAttendanceToggle(to newValue: Bool) {
        isAttendanceRequired = newValue
        if newValue {
            isAttendancePolicyDirty = false
        }
        prefillAttendancePolicyIfNeeded()
    }

    /// 출석 정책 세 시각의 순서와 일정 범위 정합성을 검증한다.
    private func validateAttendancePolicy() {
        guard isAttendanceRequired, !isAllDay else {
            attendancePolicyErrorMessage = nil
            return
        }
        guard attendanceCheckInStartAt < attendanceOnTimeEndAt else {
            attendancePolicyErrorMessage = "출석 시작은 출석 인정 마감보다 빨라야 합니다."
            return
        }
        guard attendanceOnTimeEndAt < attendanceLateEndAt else {
            attendancePolicyErrorMessage = "출석 인정 마감은 지각 인정 마감보다 빨라야 합니다."
            return
        }
        guard attendanceCheckInStartAt < startDate else {
            attendancePolicyErrorMessage = "출석 시작은 일정 시작보다 빨라야 합니다."
            return
        }
        guard attendanceLateEndAt <= endDate else {
            attendancePolicyErrorMessage = "지각 인정 마감은 일정 종료 시각을 넘을 수 없습니다."
            return
        }
        attendancePolicyErrorMessage = nil
    }

    // MARK: - Submit Function

    /// 일정을 새로 생성한다.
    func submitSchedule() async {
        guard !submitState.isLoading else { return }
        validateAttendancePolicy()
        guard attendancePolicyErrorMessage == nil else { return }

        submitState = .loading
        inlineErrorMessage = nil

        let request = ScheduleCreationRequest(
            name: trimmedTitle,
            description: memo,
            startsAt: effectiveStartsAt,
            endsAt: effectiveEndsAt,
            location: submitLocation,
            // ponytail: 참여자 선택은 SelectedChallengerView 가 ActivityPresentation internal
            // 이라 제외 — 공용 승격 후 결선.
            participantMemberIds: [],
            tags: sanitizedTags.map(\.rawValue),
            attendancePolicy: submitAttendancePolicy
        )

        do {
            try await generateScheduleUseCase.execute(request: request)
            submitState = .loaded(true)
        } catch {
            submitState = .idle
            errorHandler?.handle(error, context: ErrorContext(
                feature: "Home",
                action: "submitSchedule",
                retryAction: { [weak self] in
                    await self?.submitSchedule()
                }
            ))
        }
    }

    /// 일정을 수정한다.
    ///
    /// 이미 시작된 일정은 클라이언트에서 먼저 막고, 서버가 `SCHEDULE-0028` 로 거부하는 경우도
    /// 흐름을 끊지 않고 인라인 메시지로 알린다.
    func updateSchedule() async {
        guard let scheduleId = editingScheduleId, !submitState.isLoading else { return }

        guard !isEditingStartedSchedule else {
            inlineErrorMessage = Constants.startedScheduleMessage
            return
        }

        validateAttendancePolicy()
        guard attendancePolicyErrorMessage == nil else { return }

        submitState = .loading
        inlineErrorMessage = nil

        let request = ScheduleUpdateRequest(
            name: trimmedTitle,
            description: memo,
            startsAt: effectiveStartsAt,
            endsAt: effectiveEndsAt,
            location: submitLocation,
            // ponytail: 참여자 선택 UI 를 이식하지 않아 nil(변경 없음)로 서버 값을 보존한다.
            participantMemberIds: nil,
            tags: sanitizedTags.map(\.rawValue),
            attendancePolicy: submitAttendancePolicy,
            isOnline: isOnlineTransitionFlag,
            isAttendanceRequired: attendanceRequiredTransitionFlag
        )

        do {
            try await updateScheduleUseCase.execute(scheduleId: scheduleId, request: request)
            submitState = .loaded(true)
        } catch let error as RepositoryError where error.code == Constants.startedScheduleCode {
            submitState = .idle
            inlineErrorMessage = Constants.startedScheduleMessage
        } catch {
            submitState = .idle
            errorHandler?.handle(error, context: ErrorContext(
                feature: "Home",
                action: "updateSchedule",
                retryAction: { [weak self] in
                    await self?.updateSchedule()
                }
            ))
        }
    }

    // MARK: - Edit Snapshot

    private var currentEditSnapshot: EditFormSnapshot {
        EditFormSnapshot(
            title: title,
            placeName: placeLocation?.locationName ?? "",
            placeAddress: placeAddress,
            latitude: placeLocation?.latitude ?? 0,
            longitude: placeLocation?.longitude ?? 0,
            isAllDay: isAllDay,
            isOnline: isOnline,
            startDate: startDate,
            endDate: endDate,
            memo: memo,
            tags: sanitizedTags.map(\.rawValue).sorted(),
            isAttendanceRequired: isAttendanceRequired,
            checkInStartAt: attendanceCheckInStartAt,
            onTimeEndAt: attendanceOnTimeEndAt,
            lateEndAt: attendanceLateEndAt
        )
    }

    /// 수정 모드에서 변경 감지에 쓰는 폼 상태 스냅샷
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
        let tags: [String]
        let isAttendanceRequired: Bool
        let checkInStartAt: Date
        let onTimeEndAt: Date
        let lateEndAt: Date
    }
}
