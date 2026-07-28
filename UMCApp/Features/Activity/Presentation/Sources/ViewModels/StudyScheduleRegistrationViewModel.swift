//
//  StudyScheduleRegistrationViewModel.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 6/27/26.
//

import ActivityDomain
import Foundation
import UMCFoundation

/// 스터디 일정 등록 화면의 상태를 관리하는 뷰 모델
///
/// 스터디명·주차 커리큘럼·일시·장소·출석 정책을 입력받아 일정을 등록합니다.
/// 주차 커리큘럼 옵션과 참여자(멘토 + 스터디원) 목록을 서버에서 조회하고,
/// 출석 정책 시각의 단조 증가/일정 범위를 인라인 검증합니다.
///
/// - Note: 실제 일정 등록은 Schedule 모듈 이식 후 결선됩니다. 1단계 일정 생성
///   (`POST /api/v2/schedules`)과 실패 롤백(일정 삭제)이 미이식 Schedule 도메인
///   소관이라 ``submitSchedule()`` 는 현재 스텁입니다 (`ChallengerAttendanceViewModel`
///   의 세션 로딩 스텁과 동일 패턴). 결선 시 본인 제외 참여자/출석 정책으로 일정을
///   생성해 `scheduleId` 를 얻고, 이미 이식된 그룹-일정 연결
///   (`linkStudyGroupSchedule`, step-2)로 연결합니다.
@MainActor
@Observable
final class StudyScheduleRegistrationViewModel {

    // MARK: - Dependency

    private let studyMembersUseCase: FetchStudyMembersUseCaseProtocol
    private let studyRepository: StudyRepositoryProtocol
    private let studyGroupId: String
    private let currentMemberId: String?

    // MARK: - Property

    /// 스터디명 (초기값은 스터디 그룹 이름)
    var studyName: String

    /// 선택된 장소 이름
    ///
    /// 장소 선택 UI(`PlaceSelectView`/`MapPlacePickerView`)와 좌표 모델(`PlaceSelection`)은
    /// CoreUIComponents로 이식이 완료되어 결선 준비가 되어 있습니다(#1018). 본 뷰모델의
    /// 실제 View 결선은 `StudyScheduleRegistrationView` 이식 이슈(#1014)에서 진행되며,
    /// 그 전까지는 입력 이름만 보관합니다.
    var placeName: String = ""

    /// 비대면 일정 여부
    ///
    /// `true` 이면 장소 입력을 비우고, 등록 시 장소 없이 전송할 예정입니다.
    var isOnline: Bool = false

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

    /// 참여자 목록 (본인 제외 멘토 + 스터디원)
    private(set) var participantMembers: [StudyGroupMember] = []

    /// 참여자 로딩 상태
    private(set) var participantsState: Loadable<[StudyGroupMember]> = .idle

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
        !studyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (isOnline || !placeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            && !studyGroupId.isEmpty
            && endDate >= startDate
            && selectedWeeklyOption != nil
            && attendancePolicyError == nil
    }

    // MARK: - Init

    /// - Parameters:
    ///   - studyName: 스터디 그룹 이름 (초기값)
    ///   - studyGroupId: 스터디 그룹 식별자 (서버 응답 String ID)
    ///   - studyMembersUseCase: 스터디 그룹 멤버 조회 UseCase
    ///   - studyRepository: 주차 커리큘럼 옵션 조회 및 그룹-일정 연결 Repository
    ///   - currentMemberId: 본인 멤버 ID — 참여자 목록에서 제외 (기본값은 저장된 값)
    init(
        studyName: String,
        studyGroupId: String,
        studyMembersUseCase: FetchStudyMembersUseCaseProtocol,
        studyRepository: StudyRepositoryProtocol,
        currentMemberId: String? = AppStorageKey.memberIdString()
    ) {
        self.studyName = studyName
        self.studyGroupId = studyGroupId
        self.studyMembersUseCase = studyMembersUseCase
        self.studyRepository = studyRepository
        self.currentMemberId = currentMemberId
        prefillAttendancePolicyIfNeeded()
    }

    // MARK: - Loading

    /// 스터디 그룹 멤버(멘토 + 스터디원)를 조회해 본인을 제외하고 보관합니다.
    func loadParticipantMembers() async {
        if case .loading = participantsState { return }
        participantsState = .loading
        do {
            let allMembers = try await studyMembersUseCase
                .fetchStudyGroupMembers(groupId: studyGroupId)
            let filtered = currentMemberId.map { selfId in
                allMembers.filter { $0.memberID != selfId }
            } ?? allMembers
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

    /// 주차 커리큘럼 옵션 목록을 서버에서 불러옵니다.
    ///
    /// 선택값이 아직 없으면 첫 옵션을 자동 선택합니다.
    func loadWeeklyOptions() async {
        if case .loading = weeklyOptionsState { return }
        weeklyOptionsState = .loading
        do {
            let options = try await studyRepository.fetchWeeklyCurriculumOptions()
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

    // MARK: - Attendance Policy Function

    /// 일정 시작 시각을 기준으로 출석 정책 기본값을 자동으로 채웁니다.
    ///
    /// 사용자가 한 번이라도 직접 시각을 수정한 경우에는 덮어쓰지 않습니다.
    /// 단, 일정 시작 시각에 의존하는 검증은 prefill 을 건너뛰는 경우에도 항상 갱신합니다.
    func prefillAttendancePolicyIfNeeded() {
        defer { validateAttendancePolicy() }
        guard !isAttendancePolicyDirty else { return }
        let onTimeThreshold = TimeInterval(AttendancePolicy.onTimeThresholdMinutes * 60)
        let lateThreshold = TimeInterval(AttendancePolicy.lateThresholdMinutes * 60)
        attendanceCheckInStartAt = startDate.addingTimeInterval(-onTimeThreshold)
        attendanceOnTimeEndAt = startDate.addingTimeInterval(onTimeThreshold)
        attendanceLateEndAt = startDate.addingTimeInterval(lateThreshold)
    }

    /// 출석 정책 시각 변경 시 dirty 표시 + 검증을 갱신합니다.
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
    /// 비대면으로 전환 시 장소 입력을 초기화합니다.
    func inPersonModeToggleChanged(to isInPerson: Bool) {
        isOnline = !isInPerson
        if isOnline {
            placeName = ""
        }
    }

    /// 스케줄 등록 실행
    /// - Returns: 등록 성공 여부
    func submitSchedule() async -> Bool {
        guard canSubmit else { return false }
        // TODO: Schedule 모듈 이식 후 일정 등록 2단계 결선 - [26.06.27] 이재원
        // — 1단계 일정 생성(POST /api/v2/schedules)과 실패 롤백(일정 삭제)이 미이식
        //   Schedule 도메인 소관. 결선 시: 본인 제외 참여자 + 출석 정책으로 일정 생성 →
        //   scheduleId 획득 → studyRepository.linkStudyGroupSchedule(step-2, 이식 완료)
        //   연결 → 실패 시 AlertPrompt 재시도/취소 + 롤백 + ErrorHandler 결선.
        return false
    }
}
