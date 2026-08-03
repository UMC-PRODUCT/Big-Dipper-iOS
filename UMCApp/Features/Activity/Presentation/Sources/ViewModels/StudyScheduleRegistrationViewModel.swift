//
//  StudyScheduleRegistrationViewModel.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 6/27/26.
//

import ActivityDomain
import Foundation
import HomeDomain
import UMCFoundation

/// 스터디 일정 등록 화면의 상태를 관리하는 뷰 모델
///
/// 스터디명·주차 커리큘럼·일시·장소·출석 정책을 입력받아 일정을 등록합니다.
/// 주차 커리큘럼 옵션과 참여자(멘토 + 스터디원) 목록을 서버에서 조회하고,
/// 출석 정책 시각의 단조 증가/일정 범위를 인라인 검증합니다.
///
/// 등록은 서버 계약상 두 단계입니다.
/// 1. 본인을 뺀 참여자 + 출석 정책으로 일정을 생성해 `scheduleId` 를 받습니다.
/// 2. 그 `scheduleId` 를 스터디 그룹·주차 커리큘럼에 연결합니다.
///
/// 2단계가 실패하면 ``alertPrompt`` 로 재시도/취소를 묻고, 취소를 고르면 1단계 일정을
/// 베스트 에포트로 삭제해 고아 일정을 남기지 않습니다.
@MainActor
@Observable
final class StudyScheduleRegistrationViewModel {

    // MARK: - Dependency

    private let studyMembersUseCase: FetchStudyMembersUseCaseProtocol
    private let studyRepository: StudyRepositoryProtocol
    private let registerScheduleUseCase: RegisterStudyScheduleUseCaseProtocol
    private let errorHandler: ErrorHandler
    private let studyGroupId: String
    private let currentMemberId: String?

    // MARK: - Property

    /// 스터디명 (초기값은 스터디 그룹 이름)
    var studyName: String

    /// 선택된 장소 이름
    ///
    /// `StudyScheduleRegistrationView` 의 `PlaceSelectView` 가 선택 결과를 여기에 반영합니다.
    var placeName: String = ""

    /// 선택된 장소 주소
    ///
    /// 등록 페이로드에는 실리지 않고 장소 선택 UI 의 부제로만 표시됩니다. 그럼에도 뷰가 아닌
    /// 여기에 두는 이유는, 장소 선택 상태를 뷰와 뷰모델이 나눠 가지면 비대면 전환처럼
    /// 뷰모델만 아는 사건에서 두 벌이 어긋나기 때문입니다. 선택 상태의 단일 소유자를
    /// 뷰모델로 두어 ``inPersonModeToggleChanged(to:)`` 한 번으로 전부 비워집니다.
    var placeAddress: String = ""

    /// 선택된 장소 좌표
    ///
    /// 출석 지오펜스의 중심이 되는 값이라 대면 일정에서는 필수입니다. 좌표 없이 이름만으로
    /// 등록하면 (0, 0) 을 기준으로 하는 지오펜스가 생겨 GPS 출석이 성립하지 않으므로,
    /// ``canSubmit`` 이 좌표를 요구합니다.
    var placeCoordinate: Coordinate?

    /// 비대면 일정 여부
    ///
    /// `true` 이면 장소 입력을 비우고, 등록 시 장소 없이 전송합니다.
    var isOnline: Bool = false

    /// 2단계(그룹 연결) 실패 시 재시도/취소 다이얼로그
    var alertPrompt: AlertPrompt?

    /// 등록 요청이 진행 중인지 여부
    ///
    /// 등록은 일정을 **생성**하는 mutation 이라 중복 실행되면 같은 일정이 두 개 만들어집니다.
    /// 버튼 연타나 재시도 중첩을 막기 위해 진행 중에는 새 요청을 받지 않습니다.
    private(set) var isSubmitting: Bool = false

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

    // MARK: - Computed Property

    /// 등록 버튼 활성화 여부
    var canSubmit: Bool {
        !studyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (isOnline || hasResolvedPlace)
            && !studyGroupId.isEmpty
            && endDate >= startDate
            && selectedWeeklyOption != nil
            && attendancePolicyError == nil
    }

    /// 대면 일정에 필요한 장소 정보(이름 + 좌표)가 모두 갖춰졌는지
    private var hasResolvedPlace: Bool {
        !placeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && placeCoordinate != nil
    }

    // MARK: - Init

    /// - Parameters:
    ///   - studyName: 스터디 그룹 이름 (초기값)
    ///   - studyGroupId: 스터디 그룹 식별자 (서버 응답 String ID)
    ///   - studyMembersUseCase: 스터디 그룹 멤버 조회 UseCase
    ///   - studyRepository: 주차 커리큘럼 옵션 조회 Repository
    ///   - registerScheduleUseCase: 일정 생성·연결·롤백 UseCase
    ///   - errorHandler: 전역 에러 핸들러 (1단계 생성 실패 알림용)
    ///   - currentMemberId: 본인 멤버 ID — 참여자 목록에서 제외 (기본값은 저장된 값)
    init(
        studyName: String,
        studyGroupId: String,
        studyMembersUseCase: FetchStudyMembersUseCaseProtocol,
        studyRepository: StudyRepositoryProtocol,
        registerScheduleUseCase: RegisterStudyScheduleUseCaseProtocol,
        errorHandler: ErrorHandler,
        currentMemberId: String? = AppStorageKey.memberIdString()
    ) {
        self.studyName = studyName
        self.studyGroupId = studyGroupId
        self.studyMembersUseCase = studyMembersUseCase
        self.studyRepository = studyRepository
        self.registerScheduleUseCase = registerScheduleUseCase
        self.errorHandler = errorHandler
        self.currentMemberId = currentMemberId
        prefillAttendancePolicyIfNeeded()
    }

    // MARK: - Loading

    /// 스터디 그룹 멤버(멘토 + 스터디원)를 조회해 본인을 제외하고 보관합니다.
    ///
    /// 화면이 `.task` 로 호출하므로 빠른 이탈·탭 전환에서 `CancellationError` 또는
    /// `URLError(.cancelled)` 가 던져집니다. 취소는 실패가 아니라 "안 하기로 한 것" 이라
    /// 이전 상태로 되돌리고 에러 UI 를 띄우지 않습니다. 두 타입 판별은 형제 ViewModel 과
    /// 같은 canonical 헬퍼 `Error.isCancellation` 에 위임합니다.
    func loadParticipantMembers() async {
        if case .loading = participantsState { return }
        let previousState = participantsState
        participantsState = .loading
        do {
            let allMembers = try await studyMembersUseCase
                .fetchStudyGroupMembers(groupId: studyGroupId)
            let filtered = currentMemberId.map { selfId in
                allMembers.filter { $0.memberID != selfId }
            } ?? allMembers
            participantMembers = filtered
            participantsState = .loaded(filtered)
        } catch let error where error.isCancellation {
            participantsState = previousState
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
    ///
    /// ``loadParticipantMembers()`` 와 같은 이유로 `CancellationError` 등 취소는 실패가 아니라
    /// 이전 상태 롤백으로 처리합니다.
    func loadWeeklyOptions() async {
        if case .loading = weeklyOptionsState { return }
        let previousState = weeklyOptionsState
        weeklyOptionsState = .loading
        do {
            let options = try await studyRepository.fetchWeeklyCurriculumOptions()
            weeklyOptions = options
            weeklyOptionsState = .loaded(options)
            if selectedWeeklyOption == nil {
                selectedWeeklyOption = options.first
            }
        } catch let error where error.isCancellation {
            weeklyOptionsState = previousState
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

    /// 장소 선택 결과를 반영합니다.
    ///
    /// 이름이 비면 "선택 해제" 로 보고 좌표까지 함께 비웁니다. 이름만 지우고 좌표를 남기면
    /// 화면에는 장소가 없는데 페이로드에는 (0, 0) 같은 지오펜스 중심이 실릴 수 있습니다.
    ///
    /// - Parameters:
    ///   - name: 선택한 장소 이름
    ///   - address: 선택한 장소 주소 (표시 전용)
    ///   - coordinate: 선택한 장소 좌표
    func placeSelectionChanged(name: String, address: String, coordinate: Coordinate) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            placeName = ""
            placeAddress = ""
            placeCoordinate = nil
            return
        }
        placeName = name
        placeAddress = address
        placeCoordinate = coordinate
    }

    /// 대면/비대면 전환 토글 변경을 처리합니다.
    ///
    /// 비대면으로 전환 시 장소 입력을 초기화합니다.
    func inPersonModeToggleChanged(to isInPerson: Bool) {
        isOnline = !isInPerson
        if isOnline {
            placeName = ""
            placeAddress = ""
            placeCoordinate = nil
        }
    }

    /// 스케줄 등록 실행 (2단계)
    ///
    /// - Returns: 두 단계가 모두 성공한 경우에만 `true`
    func submitSchedule() async -> Bool {
        guard !isSubmitting else { return false }
        guard canSubmit, let weeklyOption = selectedWeeklyOption else { return false }

        isSubmitting = true
        defer { isSubmitting = false }

        let scheduleId: String
        do {
            scheduleId = try await registerScheduleUseCase.createSchedule(makeScheduleRequest())
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

    /// 1단계 일정 생성 페이로드를 구성합니다.
    ///
    /// - 본인은 참여자에서 제외합니다 (``participantMembers`` 가 이미 걸러진 목록).
    /// - 멤버 식별자가 없는 항목은 서버가 참여자로 받을 수 없어 제외합니다.
    /// - 태그는 스터디 일정 고정입니다.
    /// - 출석 정책은 자동 prefill 또는 사용자가 고친 세 시각으로 구성합니다.
    private func makeScheduleRequest() -> ScheduleCreationRequest {
        let location = placeCoordinate.map { coordinate in
            ScheduleLocation(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                locationName: placeName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        return ScheduleCreationRequest(
            name: studyName.trimmingCharacters(in: .whitespacesAndNewlines),
            startsAt: startDate,
            endsAt: endDate,
            location: isOnline ? nil : location,
            participantMemberIds: participantMembers.compactMap(\.memberID),
            tags: [ScheduleIconCategory.study.rawValue],
            attendancePolicy: ScheduleAttendancePolicy(
                checkInStartAt: attendanceCheckInStartAt,
                onTimeEndAt: attendanceOnTimeEndAt,
                lateEndAt: attendanceLateEndAt
            )
        )
    }

    /// 2단계 — 스터디 그룹/주차 커리큘럼 연결.
    ///
    /// 실패하면 재시도/취소를 묻습니다. 여기서 곧바로 롤백하지 않는 이유는, 재시도로 살릴 수
    /// 있는 일시적 실패에서 이미 만든 일정을 지워버리면 사용자가 처음부터 다시 입력해야 하기
    /// 때문입니다.
    private func linkSchedule(
        scheduleId: String,
        weeklyCurriculumId: String
    ) async -> Bool {
        do {
            try await registerScheduleUseCase.linkStudyGroupSchedule(
                scheduleId: scheduleId,
                studyGroupId: studyGroupId,
                weeklyCurriculumId: weeklyCurriculumId
            )
            return true
        } catch {
            presentLinkFailureAlert(
                scheduleId: scheduleId,
                weeklyCurriculumId: weeklyCurriculumId
            )
            return false
        }
    }

    private func presentLinkFailureAlert(
        scheduleId: String,
        weeklyCurriculumId: String
    ) {
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

    /// 베스트 에포트 롤백 — 실패해도 사용자 흐름을 막지 않습니다.
    private func rollbackSchedule(scheduleId: String) async {
        try? await registerScheduleUseCase.deleteSchedule(scheduleId: scheduleId)
    }
}
