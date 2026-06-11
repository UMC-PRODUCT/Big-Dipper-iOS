//
//  StudyScheduleRegistrationViewModel.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/10/26.
//

import Foundation

/// 스터디 일정 등록 화면의 상태를 관리하는 뷰 모델
///
/// V2 일정 API 마이그레이션에 따라 두 단계로 호출합니다.
/// 1. `POST /api/v2/schedules` 로 일반 일정 생성 (본인은 참여자에서 제외, 태그 `["STUDY"]` 자동, 출석 정책 필수)
/// 2. 받아온 `scheduleId` 를 `POST /api/v1/study-groups/schedules` 로 스터디 그룹·주차 커리큘럼에 연결
/// 2단계가 실패하면 ``alertPrompt`` 로 재시도/취소를 노출하고, 취소 시 1단계 일정을 베스트 에포트로 삭제합니다.
@Observable
final class StudyScheduleRegistrationViewModel {

    // MARK: - Dependency

    private let useCase: FetchStudyMembersUseCaseProtocol
    private let errorHandler: ErrorHandler
    private let studyGroupId: Int

    // MARK: - Property

    /// 선택된 장소
    var place: PlaceSearchInfo = .init(name: "", address: "", coordinate: .init(latitude: 0.0, longitude: 0.0))

    /// 비대면 일정 여부
    ///
    /// `true` 이면 송신 시 `location: nil` 로 전송하고, 장소 입력 필드를 숨깁니다.
    var isOnline: Bool = false

    /// 스터디명 (초기값은 스터디 그룹 이름)
    var studyName: String

    /// 시작 일시
    var startDate: Date = .now.addingTimeInterval(3600)

    /// 종료 일시
    var endDate: Date = .now.addingTimeInterval(7200)

    /// 주차 커리큘럼 옵션 목록 (서버 조회 결과)
    private(set) var weeklyOptions: [WeeklyCurriculumOption] = []

    /// 선택된 주차 커리큘럼
    var selectedWeeklyOption: WeeklyCurriculumOption?

    /// 주차 옵션 로딩 상태
    private(set) var weeklyOptionsState: Loadable<[WeeklyCurriculumOption]> = .idle

    /// 참여자 목록 (본인 제외 멘토 + 멤버)
    private(set) var participantMembers: [StudyGroupMember] = []

    /// 참여자 로딩 상태
    private(set) var participantsState: Loadable<[StudyGroupMember]> = .idle

    /// 2단계 실패 시 재시도/취소 다이얼로그
    var alertPrompt: AlertPrompt?

    // MARK: - DatePicker Toggle State

    /// 시작 날짜 DatePicker 표시 여부
    var showStartDatePicker = false
    /// 시작 시간 DatePicker 표시 여부
    var showStartTimePicker = false
    /// 종료 날짜 DatePicker 표시 여부
    var showEndDatePicker = false
    /// 종료 시간 DatePicker 표시 여부
    var showEndTimePicker = false

    // MARK: - Attendance Policy

    /// 체크인 시작 시각
    var attendanceCheckInStartAt: Date = .now
    /// 정시 출석 종료 시각
    var attendanceOnTimeEndAt: Date = .now
    /// 지각 종료 시각
    var attendanceLateEndAt: Date = .now

    /// 출석 정책 인라인 검증 에러
    private(set) var attendancePolicyError: AttendancePolicyError?

    /// 사용자가 출석 정책 시각을 직접 수정한 적이 있는지 여부 (자동 prefill 차단용)
    private var isAttendancePolicyDirty: Bool = false

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

    // MARK: - Computed Property

    /// 등록 버튼 활성화 여부
    var canSubmit: Bool {
        !studyName.trimmingCharacters(in: .whitespaces).isEmpty
            && (isOnline || !place.name.trimmingCharacters(in: .whitespaces).isEmpty)
            && studyGroupId > 0
            && endDate >= startDate
            && selectedWeeklyOption != nil
            && attendancePolicyError == nil
    }

    // MARK: - Init

    /// - Parameters:
    ///   - studyName: 스터디 그룹 이름 (초기값)
    ///   - studyGroupId: 스터디 그룹 식별자
    ///   - useCase: 스터디 관리 UseCase
    ///   - errorHandler: 전역 에러 핸들러
    init(
        studyName: String,
        studyGroupId: Int,
        useCase: FetchStudyMembersUseCaseProtocol,
        errorHandler: ErrorHandler
    ) {
        self.studyName = studyName
        self.studyGroupId = studyGroupId
        self.useCase = useCase
        self.errorHandler = errorHandler
        prefillAttendancePolicyIfNeeded()
    }

    /// 스터디 그룹 멤버(멘토 + 멤버)를 조회해 본인을 제외하고 `participantMembers` 에 저장합니다.
    @MainActor
    func loadParticipantMembers() async {
        if case .loading = participantsState { return }
        participantsState = .loading
        do {
            let allMembers = try await useCase.fetchStudyGroupMembers(groupId: studyGroupId)
            let myMemberId = AppStorageKey.legacyMemberIdInt()
            let filtered = myMemberId > 0
                ? allMembers.filter { $0.memberID != myMemberId }
                : allMembers
            participantMembers = filtered
            participantsState = .loaded(filtered)
        } catch let error as DomainError {
            participantsState = .failed(.domain(error))
        } catch let error as AppError {
            participantsState = .failed(error)
        } catch {
            participantsState = .failed(.unknown(message: error.localizedDescription))
        }
    }

    // MARK: - Attendance Policy Function

    /// 일정 시작 시각을 기준으로 출석 정책 기본값을 자동으로 채웁니다.
    ///
    /// 사용자가 한 번이라도 직접 시각을 수정한 경우(`isAttendancePolicyDirty == true`)에는 덮어쓰지 않습니다.
    func prefillAttendancePolicyIfNeeded() {
        // 일정 시작 시각에 의존하는 검증(checkInAfterScheduleStart)이 있으므로
        // prefill 을 건너뛰는 경우(dirty)에도 검증은 항상 갱신한다.
        defer { validateAttendancePolicy() }
        guard !isAttendancePolicyDirty else { return }
        let onTimeThreshold = TimeInterval(AttendanceGeofenceConstants.onTimeThresholdMinutes * 60)
        let lateThreshold = TimeInterval(AttendanceGeofenceConstants.lateThresholdMinutes * 60)
        attendanceCheckInStartAt = startDate.addingTimeInterval(-onTimeThreshold)
        attendanceOnTimeEndAt = startDate.addingTimeInterval(onTimeThreshold)
        attendanceLateEndAt = startDate.addingTimeInterval(lateThreshold)
    }

    /// 출석 정책 시각 변경 시 dirty 표시 + 검증을 갱신합니다.
    @MainActor
    func attendanceTimesChanged() {
        isAttendancePolicyDirty = true
        validateAttendancePolicy()
    }

    private func validateAttendancePolicy() {
        guard attendanceCheckInStartAt < attendanceOnTimeEndAt else {
            attendancePolicyError = .invalidOrder(.checkInVsOnTime)
            return
        }
        guard attendanceOnTimeEndAt < attendanceLateEndAt else {
            attendancePolicyError = .invalidOrder(.onTimeVsLate)
            return
        }
        guard attendanceCheckInStartAt < startDate else {
            attendancePolicyError = .checkInAfterScheduleStart
            return
        }
        attendancePolicyError = nil
    }

    // MARK: - Function

    /// 대면/비대면 전환 토글 변경을 처리합니다.
    ///
    /// 비대면으로 전환 시 장소 정보를 초기화합니다.
    func inPersonModeToggleChanged(to isInPerson: Bool) {
        isOnline = !isInPerson
        if isOnline {
            place = PlaceSearchInfo(
                name: "",
                address: "",
                coordinate: .init(latitude: 0.0, longitude: 0.0)
            )
        }
    }

    /// 주차 커리큘럼 옵션 목록을 서버에서 불러옵니다.
    @MainActor
    func loadWeeklyOptions() async {
        if case .loading = weeklyOptionsState { return }
        weeklyOptionsState = .loading
        do {
            let options = try await useCase.fetchWeeklyCurriculumOptions()
            weeklyOptions = options
            weeklyOptionsState = .loaded(options)
            if selectedWeeklyOption == nil {
                selectedWeeklyOption = options.first
            }
        } catch let error as DomainError {
            weeklyOptionsState = .failed(.domain(error))
        } catch let error as AppError {
            weeklyOptionsState = .failed(error)
        } catch {
            weeklyOptionsState = .failed(.unknown(message: error.localizedDescription))
        }
    }

    /// 스케줄 등록 실행 (2단계 V2 호출)
    /// - Returns: 두 단계 모두 성공한 경우에만 `true`
    @MainActor
    func submitSchedule() async -> Bool {
        guard canSubmit, let weeklyOption = selectedWeeklyOption else {
            return false
        }

        let request = makeScheduleRequest()

        let scheduleId: Int
        do {
            scheduleId = try await useCase.createStudySchedule(request: request)
        } catch {
            errorHandler.handle(error, context: ErrorContext(
                feature: "Activity",
                action: "createStudySchedule",
                retryAction: { [weak self] in
                    _ = await self?.submitSchedule()
                }
            ))
            return false
        }

        return await linkSchedule(
            scheduleId: scheduleId,
            weeklyCurriculumId: weeklyOption.weeklyCurriculumId
        )
    }

    // MARK: - Private

    /// 1단계 V2 일정 요청 페이로드를 구성합니다.
    ///
    /// - 본인은 참여자에서 제외 (이슈 #656 요구사항) → `participantMemberIds = []`
    /// - 태그는 `[.study]` 로 하드코딩
    /// - 출석 정책은 ViewModel 의 3개 시각(자동 prefill 또는 사용자 수동 입력)에서 구성
    private func makeScheduleRequest() -> GenerateScheduleRequetDTO {
        let policy = V2AttendancePolicyDTO(
            domain: AttendancePolicy(
                checkInStartAt: attendanceCheckInStartAt,
                onTimeEndAt: attendanceOnTimeEndAt,
                lateEndAt: attendanceLateEndAt
            )
        )

        let location: V2LocationDTO? = isOnline ? nil : V2LocationDTO(
            latitude: place.coordinate.latitude,
            longitude: place.coordinate.longitude,
            locationName: place.name.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        return GenerateScheduleRequetDTO(
            name: studyName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: "",
            startsAt: startDate,
            endsAt: endDate,
            location: location,
            participantMemberIds: participantMembers.compactMap(\.memberID),
            tags: [.study],
            attendancePolicy: policy
        )
    }

    /// 2단계 — 스터디 그룹/주차 커리큘럼 연결.
    /// 실패 시 `AlertPrompt` 로 재시도/취소를 묻고, 취소 시 1단계 일정을 베스트 에포트로 삭제합니다.
    @MainActor
    private func linkSchedule(
        scheduleId: Int,
        weeklyCurriculumId: Int
    ) async -> Bool {
        do {
            try await useCase.linkStudyGroupSchedule(
                scheduleId: scheduleId,
                studyGroupId: studyGroupId,
                weeklyCurriculumId: weeklyCurriculumId
            )
            return true
        } catch {
            await presentLinkFailureAlert(
                scheduleId: scheduleId,
                weeklyCurriculumId: weeklyCurriculumId
            )
            return false
        }
    }

    @MainActor
    private func presentLinkFailureAlert(
        scheduleId: Int,
        weeklyCurriculumId: Int
    ) async {
        alertPrompt = AlertPrompt(
            title: "스터디 일정 연결 실패",
            message: "일정은 생성됐지만 스터디 그룹과 연결하는 데 실패했어요.\n다시 시도하시겠어요?",
            positiveBtnTitle: "재시도",
            positiveBtnAction: { [weak self] in
                Task { @MainActor [weak self] in
                    _ = await self?.linkSchedule(
                        scheduleId: scheduleId,
                        weeklyCurriculumId: weeklyCurriculumId
                    )
                }
            },
            negativeBtnTitle: "취소",
            negativeBtnAction: { [weak self] in
                Task { @MainActor [weak self] in
                    await self?.rollbackSchedule(scheduleId: scheduleId)
                }
            }
        )
    }

    /// 베스트 에포트 롤백 — 실패해도 사용자에게 노출하지 않습니다.
    @MainActor
    private func rollbackSchedule(scheduleId: Int) async {
        do {
            try await useCase.deleteSchedule(scheduleId: scheduleId)
        } catch {
            // 베스트 에포트 — 실패해도 화면 흐름을 막지 않음
        }
    }
}
