//
//  AttendanceDetailViewModel.swift
//  AppProduct
//
//  Created by euijjang97 on 5/6/26.
//

import Foundation

/// 단일 일정 출석 현황 상세 화면 ViewModel (Schedule V2)
///
/// `GET /api/v2/schedules/{id}/attendance` 호출 결과를 표시하고,
/// 상태 필터 칩으로 참여자 목록을 클라이언트 측에서 필터링합니다.
///
/// ## Edge Case (AC-E2)
/// 진입 후 일정이 삭제된 경우 (SCHEDULE-0009) `Loadable.failed` 에 명시적인 메시지를
/// 담아 "삭제된 일정" 표시 + Stack pop 버튼을 노출합니다.
///
/// - SeeAlso: ``AttendanceDetailView``
@Observable
final class AttendanceDetailViewModel {

    // MARK: - Property

    private var container: DIContainer
    private var errorHandler: ErrorHandler
    private var useCase: OperatorAttendanceUseCaseProtocol

    let scheduleId: Int

    /// 출석 현황 로드 상태
    private(set) var detailState: Loadable<ScheduleAttendanceInfo> = .idle

    /// 현재 선택된 필터 (`nil` = 전체)
    private(set) var selectedFilter: AttendanceStatusV2?

    let filterableStatuses: [AttendanceStatusV2] = AttendanceStatusV2.filterableCases

    /// 일정이 삭제됐는지 여부 (AC-E2 감지)
    private(set) var isScheduleDeleted: Bool = false

    // MARK: - Approval / Action

    /// AlertPrompt 상태 (승인/반려 확인, 에러 안내)
    var alertPrompt: AlertPrompt?

    /// 현재 처리 중인 멤버 ID Set (개별 행 ProgressView 표시용)
    private(set) var processingMemberIds: Set<Int> = []

    // MARK: - Location Sheet

    /// 위치 변경 시트 표시 여부
    var showLocationSheet: Bool = false

    /// 위치 변경 시트가 세션 정보 카드를 렌더링할 때 사용하는 Session 객체
    ///
    /// `OperatorLocationChangeSheetView` 가 요구하는 `selectedSession: Session?` 인터페이스 호환용.
    /// `ScheduleAttendanceInfo` 로드 전이면 `nil` 을 반환합니다.
    @MainActor
    var selectedSession: Session? {
        guard case .loaded(let info) = detailState else { return nil }
        let sessionInfo = SessionInfo(
            sessionId: SessionID(value: String(info.scheduleId)),
            icon: .Activity.profile,
            title: info.name,
            week: 0,
            startTime: info.startsAt,
            endTime: info.endsAt,
            location: {
                if let loc = info.location {
                    return Coordinate(latitude: loc.latitude, longitude: loc.longitude)
                }
                return Coordinate(latitude: 0, longitude: 0)
            }(),
            isAllDay: false
        )
        return Session(info: sessionInfo)
    }

    // MARK: - Polling

    private enum PollingConfig {
        static let intervalSeconds: Int = 15
    }

    // MARK: - Init

    init(
        container: DIContainer,
        errorHandler: ErrorHandler,
        useCase: OperatorAttendanceUseCaseProtocol,
        scheduleId: Int
    ) {
        self.container = container
        self.errorHandler = errorHandler
        self.useCase = useCase
        self.scheduleId = scheduleId
    }

    // MARK: - Fetch

    /// 단일 일정 출석 현황 조회
    @MainActor
    func fetch() async {
        detailState = .loading
        isScheduleDeleted = false
        do {
            let info = try await useCase.fetchAttendanceDetail(
                scheduleId: scheduleId,
                attendanceStatus: nil
            )
            detailState = .loaded(info)
        } catch let error as DomainError {
            detailState = .failed(.domain(error))
        } catch let error as RepositoryError {
            if case .serverError(let code, _) = error,
               code == "SCHEDULE-0009"
            {
                isScheduleDeleted = true
            }
            detailState = .failed(.unknown(message: error.localizedDescription))
        } catch {
            errorHandler.handle(error, context: ErrorContext(
                feature: "Activity",
                action: "fetchAttendanceDetail",
                retryAction: { [weak self] in
                    await self?.fetch()
                }
            ))
            detailState = .failed(.unknown(message: error.localizedDescription))
        }
    }

    // MARK: - Filter

    /// 필터 칩 탭 (클라이언트 측 필터링)
    func filterButtonTapped(_ status: AttendanceStatusV2) {
        if selectedFilter == status {
            selectedFilter = nil
        } else {
            selectedFilter = status
        }
    }

    /// 현재 필터를 적용한 참여자 목록
    var filteredParticipants: [ParticipantAttendance] {
        guard case .loaded(let info) = detailState else { return [] }
        guard let filter = selectedFilter else { return info.participants }
        return info.participants.filter { $0.attendanceStatus == filter }
    }

    // MARK: - Approval Actions

    /// 개별 승인 버튼 탭 (확인 AlertPrompt 표시)
    func approveButtonTapped(participant: ParticipantAttendance) {
        alertPrompt = AlertPrompt(
            title: "출석 승인",
            message: "\(participant.name)님의 출석을 승인하시겠습니까?",
            positiveBtnTitle: "승인",
            positiveBtnAction: { [weak self] in
                Task { await self?.decideAttendance(participant: participant, isApproved: true) }
            },
            negativeBtnTitle: "취소",
            negativeBtnAction: { [weak self] in self?.alertPrompt = nil }
        )
    }

    /// 개별 반려 버튼 탭 (확인 AlertPrompt 표시)
    func rejectButtonTapped(participant: ParticipantAttendance) {
        alertPrompt = AlertPrompt(
            title: "출석 반려",
            message: "\(participant.name)님의 출석을 반려하시겠습니까?",
            positiveBtnTitle: "반려",
            positiveBtnAction: { [weak self] in
                Task { await self?.decideAttendance(participant: participant, isApproved: false) }
            },
            negativeBtnTitle: "취소",
            negativeBtnAction: { [weak self] in self?.alertPrompt = nil },
            isPositiveBtnDestructive: true
        )
    }

    /// 확인 없이 즉시 승인 (사유 확인 AlertPrompt 내 "승인" 버튼)
    func approveDirectly(participant: ParticipantAttendance) {
        Task { await decideAttendance(participant: participant, isApproved: true) }
    }

    /// 확인 없이 즉시 반려 (사유 확인 AlertPrompt 내 "반려" 버튼)
    func rejectDirectly(participant: ParticipantAttendance) {
        Task { await decideAttendance(participant: participant, isApproved: false) }
    }

    /// 전체 승인 버튼 탭
    func approveAllButtonTapped() {
        alertPrompt = AlertPrompt(
            title: "전체 승인",
            message: "모든 승인 대기 출석을 승인하시겠습니까?",
            positiveBtnTitle: "전체 승인",
            positiveBtnAction: { [weak self] in
                Task { await self?.decideAllAttendances(isApproved: true) }
            },
            negativeBtnTitle: "취소",
            negativeBtnAction: { [weak self] in self?.alertPrompt = nil }
        )
    }

    /// 전체 반려 버튼 탭
    func rejectAllButtonTapped() {
        alertPrompt = AlertPrompt(
            title: "전체 거절",
            message: "모든 승인 대기 출석을 거절하시겠습니까?",
            positiveBtnTitle: "전체 거절",
            positiveBtnAction: { [weak self] in
                Task { await self?.decideAllAttendances(isApproved: false) }
            },
            negativeBtnTitle: "취소",
            negativeBtnAction: { [weak self] in self?.alertPrompt = nil },
            isPositiveBtnDestructive: true
        )
    }

    /// 선택 승인 버튼 탭
    func approveSelectedButtonTapped(participants: [ParticipantAttendance]) {
        guard !participants.isEmpty else { return }
        alertPrompt = AlertPrompt(
            title: "선택 승인",
            message: "\(participants.count)명의 출석을 승인하시겠습니까?",
            positiveBtnTitle: "승인",
            positiveBtnAction: { [weak self] in
                Task { await self?.decideSelectedAttendances(participants: participants, isApproved: true) }
            },
            negativeBtnTitle: "취소",
            negativeBtnAction: { [weak self] in self?.alertPrompt = nil }
        )
    }

    /// 선택 반려 버튼 탭
    func rejectSelectedButtonTapped(participants: [ParticipantAttendance]) {
        guard !participants.isEmpty else { return }
        alertPrompt = AlertPrompt(
            title: "선택 거절",
            message: "\(participants.count)명의 출석을 거절하시겠습니까?",
            positiveBtnTitle: "거절",
            positiveBtnAction: { [weak self] in
                Task { await self?.decideSelectedAttendances(
                    participants: participants, isApproved: false
                ) }
            },
            negativeBtnTitle: "취소",
            negativeBtnAction: { [weak self] in self?.alertPrompt = nil },
            isPositiveBtnDestructive: true
        )
    }

    // MARK: - Location

    /// 위치 변경 버튼 탭
    func locationButtonTapped() {
        showLocationSheet = true
    }

    /// 위치 변경 확인 액션 (OperatorLocationChangeSheetView 에서 호출)
    @MainActor
    func confirmLocationChange(to place: PlaceSearchInfo) async -> Bool {
        guard !place.name.isEmpty else {
            alertPrompt = AlertPrompt(
                title: "위치 변경 실패",
                message: "변경할 위치를 선택해 주세요.",
                positiveBtnTitle: "확인"
            )
            return false
        }

        let latitude = place.coordinate.latitude
        let longitude = place.coordinate.longitude

        guard latitude.isFinite, longitude.isFinite,
              (-90.0...90.0).contains(latitude),
              (-180.0...180.0).contains(longitude) else {
            alertPrompt = AlertPrompt(
                title: "위치 변경 실패",
                message: "유효한 위치 좌표를 선택해 주세요.",
                positiveBtnTitle: "확인"
            )
            return false
        }

        do {
            try await useCase.updateScheduleLocation(
                scheduleId: scheduleId,
                locationName: place.name,
                latitude: latitude,
                longitude: longitude
            )
            return true
        } catch {
            errorHandler.handle(error, context: ErrorContext(
                feature: "Activity",
                action: "updateScheduleLocation"
            ))
            return false
        }
    }

    // MARK: - Polling

    /// 배경 갱신 — 실패해도 기존 상태 유지
    @MainActor
    func refreshDetail() async {
        guard detailState.isComplete else { return }
        do {
            let info = try await useCase.fetchAttendanceDetail(
                scheduleId: scheduleId,
                attendanceStatus: nil
            )
            detailState = .loaded(info)
        } catch {
            // 배경 갱신 실패는 무시
        }
    }

    /// 진행 중인 일정일 때만 15초 폴링 루프.
    ///
    /// `.task` 모디파이어에서 호출하면 뷰 소멸 시 자동 취소됩니다.
    @MainActor
    func startPollingIfNeeded() async {
        guard detailState.isComplete else { return }

        while !Task.isCancelled {
            guard isCurrentlyActive else { return }
            try? await Task.sleep(for: .seconds(PollingConfig.intervalSeconds))
            guard !Task.isCancelled else { break }
            await refreshDetail()
        }
    }

    // MARK: - Private Decision

    @MainActor
    private func decideAttendance(
        participant: ParticipantAttendance,
        isApproved: Bool
    ) async {
        alertPrompt = nil
        let memberId = participant.memberId
        processingMemberIds.insert(memberId)
        defer { processingMemberIds.remove(memberId) }

        let decision = AttendanceDecisionInput(
            isApproved: isApproved,
            participantMemberId: memberId,
            reason: ""
        )

        do {
            _ = try await useCase.decideAttendances(
                scheduleId: scheduleId,
                decisions: [decision]
            )
            updateParticipant(memberId: memberId, isApproved: isApproved)
        } catch {
            await handleDecisionError(
                error,
                action: isApproved ? "approveAttendance" : "rejectAttendance"
            )
        }
    }

    @MainActor
    private func decideAllAttendances(isApproved: Bool) async {
        alertPrompt = nil
        guard case .loaded(let info) = detailState else { return }

        let pendingParticipants = info.participants.filter(\.attendanceStatus.isPending)
        guard !pendingParticipants.isEmpty else { return }

        let decisions = pendingParticipants.map {
            AttendanceDecisionInput(
                isApproved: isApproved,
                participantMemberId: $0.memberId,
                reason: ""
            )
        }

        do {
            _ = try await useCase.decideAttendances(
                scheduleId: scheduleId,
                decisions: decisions
            )
            updateAllPendingParticipants(isApproved: isApproved)
        } catch {
            await handleDecisionError(
                error,
                action: isApproved ? "approveAllAttendances" : "rejectAllAttendances"
            )
        }
    }

    @MainActor
    private func decideSelectedAttendances(
        participants: [ParticipantAttendance],
        isApproved: Bool
    ) async {
        alertPrompt = nil
        let decisions = participants.map {
            AttendanceDecisionInput(
                isApproved: isApproved,
                participantMemberId: $0.memberId,
                reason: ""
            )
        }

        do {
            _ = try await useCase.decideAttendances(
                scheduleId: scheduleId,
                decisions: decisions
            )
            for participant in participants {
                updateParticipant(memberId: participant.memberId, isApproved: isApproved)
            }
        } catch {
            await handleDecisionError(
                error,
                action: isApproved ? "approveSelectedAttendances" : "rejectSelectedAttendances"
            )
        }
    }

    // MARK: - Private Error

    @MainActor
    private func handleDecisionError(_ error: Error, action: String) async {
        if Self.isPermissionDenied(error) {
            alertPrompt = AlertPrompt(
                title: "권한이 없어요",
                message: "출석을 처리할 권한이 없습니다. 운영진 권한을 확인해 주세요.",
                positiveBtnTitle: "확인",
                positiveBtnAction: { [weak self] in self?.alertPrompt = nil }
            )
            await refreshDetail()
            return
        }
        errorHandler.handle(error, context: .init(
            feature: "Activity",
            action: action
        ))
    }

    private static func isPermissionDenied(_ error: Error) -> Bool {
        if let appError = error as? AppError, appError.isPermissionDenied {
            return true
        }
        if let networkError = error as? NetworkError,
           case .requestFailed(let status, _) = networkError,
           status == 403 {
            return true
        }
        return false
    }

    // MARK: - Private Optimistic Update

    /// 단건 낙관적 갱신: pending → present/absent
    private func updateParticipant(memberId: Int, isApproved: Bool) {
        guard case .loaded(var info) = detailState else { return }
        let newStatus: AttendanceStatusV2 = isApproved ? .present : .absent
        let updated = info.participants.map { p -> ParticipantAttendance in
            guard p.memberId == memberId, p.attendanceStatus.isPending else { return p }
            return ParticipantAttendance(
                memberId: p.memberId,
                name: p.name,
                nickname: p.nickname,
                profileImageUrl: p.profileImageUrl,
                schoolId: p.schoolId,
                schoolName: p.schoolName,
                attendanceStatus: newStatus,
                isLocationVerified: p.isLocationVerified,
                excuseReason: p.excuseReason
            )
        }
        info = ScheduleAttendanceInfo(
            scheduleId: info.scheduleId,
            name: info.name,
            description: info.description,
            startsAt: info.startsAt,
            endsAt: info.endsAt,
            location: info.location,
            isOnline: info.isOnline,
            authorMemberId: info.authorMemberId,
            attendancePolicy: info.attendancePolicy,
            tags: info.tags,
            participants: updated
        )
        detailState = .loaded(info)
        notifySharedSessionChange()
    }

    /// 전체 pending 낙관적 갱신
    private func updateAllPendingParticipants(isApproved: Bool) {
        guard case .loaded(var info) = detailState else { return }
        let newStatus: AttendanceStatusV2 = isApproved ? .present : .absent
        let updated = info.participants.map { p -> ParticipantAttendance in
            guard p.attendanceStatus.isPending else { return p }
            return ParticipantAttendance(
                memberId: p.memberId,
                name: p.name,
                nickname: p.nickname,
                profileImageUrl: p.profileImageUrl,
                schoolId: p.schoolId,
                schoolName: p.schoolName,
                attendanceStatus: newStatus,
                isLocationVerified: p.isLocationVerified,
                excuseReason: p.excuseReason
            )
        }
        info = ScheduleAttendanceInfo(
            scheduleId: info.scheduleId,
            name: info.name,
            description: info.description,
            startsAt: info.startsAt,
            endsAt: info.endsAt,
            location: info.location,
            isOnline: info.isOnline,
            authorMemberId: info.authorMemberId,
            attendancePolicy: info.attendancePolicy,
            tags: info.tags,
            participants: updated
        )
        detailState = .loaded(info)
        notifySharedSessionChange()
    }

    // MARK: - Private Helpers

    /// 일정이 현재 진행 중인지 여부 (KST 기준)
    private var isCurrentlyActive: Bool {
        guard case .loaded(let info) = detailState else { return false }
        let now = Date()
        return now >= info.startsAt && now <= info.endsAt
    }

    /// 챌린저 뷰 실시간 갱신을 위한 Notification 발송
    private func notifySharedSessionChange() {
        NotificationCenter.default.post(
            name: .attendanceStatusChanged,
            object: nil
        )
    }
}
