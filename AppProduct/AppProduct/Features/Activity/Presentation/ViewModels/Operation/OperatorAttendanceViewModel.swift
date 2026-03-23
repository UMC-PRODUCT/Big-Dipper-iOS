//
//  OperatorAttendanceViewModel.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/5/26.
//

import Foundation
import SwiftUI

/// 운영진 출석 관리 ViewModel
///
/// 세션별 출석 현황 조회, 승인/반려 액션을 관리합니다.
@Observable
final class OperatorAttendanceViewModel {

    // MARK: - Property

    /// 승인 대기 명단 로드 결과
    enum PendingLoadResult {
        case loaded    // 멤버 1명 이상
        case empty     // 성공이지만 빈 배열
        case failed    // API 에러 또는 내부 상태 오류
    }

    /// 폴링 설정
    private enum PollingConfig {
        static let intervalSeconds: Int = 15
    }

    private var container: DIContainer
    private var errorHandler: ErrorHandler
    private var useCase: OperatorAttendanceUseCaseProtocol

    /// 세션 출석 현황 목록
    private(set) var sessionsState: Loadable<[OperatorSessionAttendance]> = .idle

    /// AlertPrompt 상태 (사유 확인, 승인/반려 확인)
    var alertPrompt: AlertPrompt?

    /// 위치 변경 시트 표시 여부
    var showLocationSheet: Bool = false

    /// 현재 선택된 세션 (위치 변경용)
    var selectedSession: Session?

    /// 현재 처리 중인 멤버 ID (해당 버튼만 ProgressView 표시)
    private(set) var processingMemberIds: Set<UUID> = []

    /// 진행 중인 세션이 하나라도 있는지 확인
    private var hasActiveSession: Bool {
        guard case .loaded(let sessions) = sessionsState
        else { return false }
        return sessions.contains { session in
            let status = OperatorSessionStatus.from(
                startTime: session.session.info.startTime,
                endTime: session.session.info.endTime
            )
            return status == .inProgress
        }
    }

    // MARK: - Init

    init(
        container: DIContainer,
        errorHandler: ErrorHandler,
        useCase: OperatorAttendanceUseCaseProtocol
    ) {
        self.container = container
        self.errorHandler = errorHandler
        self.useCase = useCase
    }

    // MARK: - Action

    /// 일정 목록 + pending 출석 조회
    ///
    /// `/api/v1/schedules` 응답을 기반으로 세션 목록을 구성합니다.
    @MainActor
    func fetchSessions() async {
        sessionsState = .loading
        var updatedSessions: [OperatorSessionAttendance] = []

        // 일정 목록 조회 (/api/v1/schedules)
        let statsList: [ScheduleAttendanceStats]
        do {
            statsList = try await useCase.fetchScheduleStats()
        } catch {
            sessionsState = .failed(.unknown(
                message: error.localizedDescription
            ))
            return
        }

        for stats in statsList {
            let session = Self.makeSession(from: stats)

            updatedSessions.append(OperatorSessionAttendance(
                serverID: String(stats.scheduleId),
                session: session,
                attendanceRate: stats.attendanceRate,
                attendedCount: stats.presentCount,
                totalCount: stats.totalCount,
                pendingCount: stats.pendingCount
            ))
        }

        sessionsState = .loaded(updatedSessions)
    }

    /// ScheduleAttendanceStats → Session 변환
    @MainActor
    private static func makeSession(
        from stats: ScheduleAttendanceStats
    ) -> Session {
        let startTime = ServerDateTimeConverter.parseUTCDateTimeOrTime(
            stats.startTime, utcDate: stats.date
        ) ?? Date()
        var endTime = ServerDateTimeConverter.parseUTCDateTimeOrTime(
            stats.endTime, utcDate: stats.date
        ) ?? Date()

        if endTime < startTime {
            endTime = Calendar.current.date(
                byAdding: .day, value: 1, to: endTime
            ) ?? endTime
        }

        return Session(
            info: SessionInfo(
                sessionId: SessionID(value: String(stats.scheduleId)),
                icon: .Activity.profile,
                title: stats.name,
                week: 0,
                startTime: startTime,
                endTime: endTime,
                location: Coordinate(latitude: 0, longitude: 0)
            )
        )
    }

    /// 승인 대기 명단 조회 (on-demand)
    ///
    /// `/api/v1/attendances/pending/{scheduleId}` 호출 후 해당 세션에 멤버 목록을 채웁니다.
    @MainActor
    func loadPendingMembers(for sessionId: UUID) async -> PendingLoadResult {
        guard case .loaded(var sessions) = sessionsState,
              let index = sessions.firstIndex(where: { $0.id == sessionId }),
              let scheduleId = Int(sessions[index].serverID ?? "")
        else { return .failed }

        do {
            let records = try await useCase.fetchPendingAttendances(
                scheduleId: scheduleId
            )
            let members = records.map { OperatorPendingMember(from: $0) }
            sessions[index] = sessions[index].copyWith(
                pendingMembers: members
            )
            sessionsState = .loaded(sessions)
            return members.isEmpty ? .empty : .loaded
        } catch {
            errorHandler.handle(error, context: .init(
                feature: "Activity",
                action: "loadPendingMembers"
            ))
            return .failed
        }
    }

    /// 위치 변경 버튼 탭
    func locationButtonTapped(session: Session) {
        selectedSession = session
        showLocationSheet = true
    }

    /// 위치 변경 확인 액션
    @MainActor
    func confirmLocationChange(to place: PlaceSearchInfo) async -> Bool {
        guard let selectedSession else {
            alertPrompt = AlertPrompt(
                title: "위치 변경 실패",
                message: "세션 정보를 찾을 수 없습니다.",
                positiveBtnTitle: "확인"
            )
            return false
        }

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

        guard let scheduleId = Int(selectedSession.id.value) else {
            alertPrompt = AlertPrompt(
                title: "위치 변경 실패",
                message: "유효하지 않은 세션 ID입니다.",
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

    /// 출석 사유 확인 버튼 탭
    func reasonButtonTapped(member: OperatorPendingMember) {
        guard let reason = member.reason else { return }

        alertPrompt = AlertPrompt(
            title: "출석 사유",
            message: reason,
            positiveBtnTitle: "확인",
            positiveBtnAction: { [weak self] in
                self?.alertPrompt = nil
            }
        )
    }

    /// 승인 버튼 탭
    func approveButtonTapped(member: OperatorPendingMember, sessionId: UUID) {
        alertPrompt = AlertPrompt(
            title: "출석 승인",
            message: "\(member.name)님의 출석을 승인하시겠습니까?",
            positiveBtnTitle: "승인",
            positiveBtnAction: { [weak self] in
                Task {
                    await self?.approveAttendance(memberId: member.id, sessionId: sessionId)
                }
            },
            negativeBtnTitle: "취소",
            negativeBtnAction: { [weak self] in
                self?.alertPrompt = nil
            }
        )
    }

    /// 반려 버튼 탭
    func rejectButtonTapped(member: OperatorPendingMember, sessionId: UUID) {
        alertPrompt = AlertPrompt(
            title: "출석 반려",
            message: "\(member.name)님의 출석을 반려하시겠습니까?",
            positiveBtnTitle: "반려",
            positiveBtnAction: { [weak self] in
                Task {
                    await self?.rejectAttendance(memberId: member.id, sessionId: sessionId)
                }
            },
            negativeBtnTitle: "취소",
            negativeBtnAction: { [weak self] in
                self?.alertPrompt = nil
            },
            isPositiveBtnDestructive: true
        )
    }

    /// 전체 승인 버튼 탭
    func approveAllButtonTapped(sessionId: UUID) {
        alertPrompt = AlertPrompt(
            title: "전체 승인",
            message: "모든 승인 대기 출석을 승인하시겠습니까?",
            positiveBtnTitle: "전체 승인",
            positiveBtnAction: { [weak self] in
                Task {
                    await self?.approveAllAttendances(sessionId: sessionId)
                }
            },
            negativeBtnTitle: "취소",
            negativeBtnAction: { [weak self] in
                self?.alertPrompt = nil
            }
        )
    }

    /// 전체 거절 버튼 탭
    func rejectAllButtonTapped(sessionId: UUID) {
        alertPrompt = AlertPrompt(
            title: "전체 거절",
            message: "모든 승인 대기 출석을 거절하시겠습니까?",
            positiveBtnTitle: "전체 거절",
            positiveBtnAction: { [weak self] in
                Task {
                    await self?.rejectAllAttendances(sessionId: sessionId)
                }
            },
            negativeBtnTitle: "취소",
            negativeBtnAction: { [weak self] in
                self?.alertPrompt = nil
            },
            isPositiveBtnDestructive: true
        )
    }

    /// 선택 승인 버튼 탭
    func approveSelectedButtonTapped(members: [OperatorPendingMember], sessionId: UUID) {
        guard !members.isEmpty else { return }

        alertPrompt = AlertPrompt(
            title: "선택 승인",
            message: "\(members.count)명의 출석을 승인하시겠습니까?",
            positiveBtnTitle: "승인",
            positiveBtnAction: { [weak self] in
                Task {
                    await self?.approveSelectedAttendances(members: members, sessionId: sessionId)
                }
            },
            negativeBtnTitle: "취소",
            negativeBtnAction: { [weak self] in
                self?.alertPrompt = nil
            }
        )
    }

    /// 선택 거절 버튼 탭
    func rejectSelectedButtonTapped(members: [OperatorPendingMember], sessionId: UUID) {
        guard !members.isEmpty else { return }

        alertPrompt = AlertPrompt(
            title: "선택 거절",
            message: "\(members.count)명의 출석을 거절하시겠습니까?",
            positiveBtnTitle: "거절",
            positiveBtnAction: { [weak self] in
                Task {
                    await self?.rejectSelectedAttendances(members: members, sessionId: sessionId)
                }
            },
            negativeBtnTitle: "취소",
            negativeBtnAction: { [weak self] in
                self?.alertPrompt = nil
            },
            isPositiveBtnDestructive: true
        )
    }

    /// 확인 없이 즉시 출석 승인 (사유 확인 AlertPrompt에서 호출)
    func approveDirectly(member: OperatorPendingMember, sessionId: UUID) {
        Task {
            await approveAttendance(memberId: member.id, sessionId: sessionId)
        }
    }

    /// 확인 없이 즉시 출석 반려 (사유 확인 AlertPrompt에서 호출)
    func rejectDirectly(member: OperatorPendingMember, sessionId: UUID) {
        Task {
            await rejectAttendance(memberId: member.id, sessionId: sessionId)
        }
    }

    // MARK: - Polling

    /// 세션 목록 배경 갱신 (로딩 상태 변경 없이)
    ///
    /// 폴링 시 UI 깜빡임을 방지하기 위해
    /// Loadable.loading 전환 없이 데이터를 갱신합니다.
    @MainActor
    func refreshSessions() async {
        guard !sessionsState.isLoading else { return }

        // 기존 pending members 보존용
        let existingMembers: [String: [OperatorPendingMember]]
        if case .loaded(let current) = sessionsState {
            existingMembers = Dictionary(
                uniqueKeysWithValues: current.compactMap {
                    guard let id = $0.serverID else { return nil }
                    return (id, $0.pendingMembers)
                }
            )
        } else {
            existingMembers = [:]
        }

        do {
            let statsList = try await useCase
                .fetchScheduleStats()
            var updated: [OperatorSessionAttendance] = []
            for stats in statsList {
                let session = Self.makeSession(from: stats)
                let key = String(stats.scheduleId)
                updated.append(OperatorSessionAttendance(
                    serverID: key,
                    session: session,
                    attendanceRate: stats.attendanceRate,
                    attendedCount: stats.presentCount,
                    totalCount: stats.totalCount,
                    pendingCount: stats.pendingCount,
                    pendingMembers: existingMembers[key] ?? []
                ))
            }
            sessionsState = .loaded(updated)
        } catch {
            // 백그라운드 갱신 실패는 무시 (기존 데이터 유지)
        }
    }

    /// 세션 진행 중일 때 주기적으로 데이터를 갱신합니다.
    ///
    /// `.task` 모디파이어에서 호출하면 뷰 사라질 때
    /// 자동 취소됩니다.
    /// 진행 중인 세션이 없으면 폴링을 중단합니다.
    @MainActor
    func startPollingIfNeeded() async {
        // isComplete는 .loaded 또는 .failed 모두 true.
        // .failed 시 hasActiveSession이 false이므로
        // 아래 guard에서 즉시 return 되어 폴링 미시작.
        guard sessionsState.isComplete else { return }

        while !Task.isCancelled {
            guard hasActiveSession else { return }
            try? await Task.sleep(for: .seconds(
                PollingConfig.intervalSeconds
            ))
            guard !Task.isCancelled else { break }
            await refreshSessions()
        }
    }

    // MARK: - Private Action

    @MainActor
    private func approveAttendance(
        memberId: UUID,
        sessionId: UUID
    ) async {
        alertPrompt = nil
        guard case .loaded(let sessions) = sessionsState,
              let session = sessions.first(where: {
                  $0.id == sessionId
              }),
              let member = session.pendingMembers.first(where: {
                  $0.id == memberId
              }),
              let recordId = Int(member.serverID ?? "")
        else { return }

        processingMemberIds.insert(memberId)
        defer { processingMemberIds.remove(memberId) }

        do {
            try await useCase.approveAttendance(
                recordId: recordId
            )
            updateSessionByRemovingMember(
                memberId: memberId,
                sessionId: sessionId,
                isApproval: true
            )
        } catch {
            errorHandler.handle(error, context: .init(
                feature: "Activity",
                action: "approveAttendance"
            ))
        }
    }

    @MainActor
    private func rejectAttendance(
        memberId: UUID,
        sessionId: UUID
    ) async {
        alertPrompt = nil
        guard case .loaded(let sessions) = sessionsState,
              let session = sessions.first(where: {
                  $0.id == sessionId
              }),
              let member = session.pendingMembers.first(where: {
                  $0.id == memberId
              }),
              let recordId = Int(member.serverID ?? "")
        else { return }

        processingMemberIds.insert(memberId)
        defer { processingMemberIds.remove(memberId) }

        do {
            try await useCase.rejectAttendance(
                recordId: recordId
            )
            updateSessionByRemovingMember(
                memberId: memberId,
                sessionId: sessionId,
                isApproval: false
            )
        } catch {
            errorHandler.handle(error, context: .init(
                feature: "Activity",
                action: "rejectAttendance"
            ))
        }
    }

    @MainActor
    private func approveAllAttendances(sessionId: UUID) async {
        alertPrompt = nil
        guard case .loaded(let sessions) = sessionsState,
              let session = sessions.first(where: {
                  $0.id == sessionId
              })
        else { return }

        for member in session.pendingMembers {
            guard let recordId = Int(member.serverID ?? "")
            else { continue }
            try? await useCase.approveAttendance(
                recordId: recordId
            )
        }
        updateSessionByRemovingAllMembers(
            sessionId: sessionId,
            isApproval: true
        )
    }

    @MainActor
    private func rejectAllAttendances(sessionId: UUID) async {
        alertPrompt = nil
        guard case .loaded(let sessions) = sessionsState,
              let session = sessions.first(where: {
                  $0.id == sessionId
              })
        else { return }

        for member in session.pendingMembers {
            guard let recordId = Int(member.serverID ?? "")
            else { continue }
            try? await useCase.rejectAttendance(
                recordId: recordId
            )
        }
        updateSessionByRemovingAllMembers(
            sessionId: sessionId,
            isApproval: false
        )
    }

    @MainActor
    private func approveSelectedAttendances(
        members: [OperatorPendingMember],
        sessionId: UUID
    ) async {
        alertPrompt = nil

        for member in members {
            guard let recordId = Int(member.serverID ?? "")
            else { continue }
            try? await useCase.approveAttendance(
                recordId: recordId
            )
        }
        updateSessionByRemovingSelectedMembers(
            memberIds: members.map(\.id),
            sessionId: sessionId,
            isApproval: true
        )
    }

    @MainActor
    private func rejectSelectedAttendances(
        members: [OperatorPendingMember],
        sessionId: UUID
    ) async {
        alertPrompt = nil

        for member in members {
            guard let recordId = Int(member.serverID ?? "")
            else { continue }
            try? await useCase.rejectAttendance(
                recordId: recordId
            )
        }
        updateSessionByRemovingSelectedMembers(
            memberIds: members.map(\.id),
            sessionId: sessionId,
            isApproval: false
        )
    }

    // MARK: - Helper

    private func updateSessionByRemovingMember(
        memberId: UUID,
        sessionId: UUID,
        isApproval: Bool
    ) {
        guard case .loaded(var sessions) = sessionsState else { return }

        if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
            let updatedMembers = sessions[index].pendingMembers.filter { $0.id != memberId }
            sessions[index] = sessions[index].copyWith(
                attendedCount: isApproval
                    ? sessions[index].attendedCount + 1
                    : sessions[index].attendedCount,
                pendingMembers: updatedMembers
            )
            sessionsState = .loaded(sessions)
            notifySharedSessionChange(
                session: sessions[index],
                isApproval: isApproval
            )
        }
    }

    private func updateSessionByRemovingAllMembers(sessionId: UUID, isApproval: Bool) {
        guard case .loaded(var sessions) = sessionsState else { return }

        if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
            let memberCount = sessions[index].pendingMembers.count
            sessions[index] = sessions[index].copyWith(
                attendedCount: isApproval
                    ? sessions[index].attendedCount + memberCount
                    : sessions[index].attendedCount,
                pendingMembers: []
            )
            sessionsState = .loaded(sessions)
            notifySharedSessionChange(
                session: sessions[index],
                isApproval: isApproval
            )
        }
    }

    private func updateSessionByRemovingSelectedMembers(
        memberIds: [UUID],
        sessionId: UUID,
        isApproval: Bool
    ) {
        guard case .loaded(var sessions) = sessionsState else { return }

        if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
            let memberIdSet = Set(memberIds)
            let updatedMembers = sessions[index].pendingMembers.filter {
                !memberIdSet.contains($0.id)
            }
            sessions[index] = sessions[index].copyWith(
                attendedCount: isApproval
                    ? sessions[index].attendedCount + memberIds.count
                    : sessions[index].attendedCount,
                pendingMembers: updatedMembers
            )
            sessionsState = .loaded(sessions)
            notifySharedSessionChange(
                session: sessions[index],
                isApproval: isApproval
            )
        }
    }

    /// 공유 Session 객체 출석 상태 업데이트 + Notification 발송
    ///
    /// 운영진 승인/반려 후 챌린저 뷰의 @Observable Session이
    /// 자동 갱신되도록 직접 업데이트합니다.
    private func notifySharedSessionChange(
        session: OperatorSessionAttendance,
        isApproval: Bool
    ) {
        let sharedSession = session.session
        let newStatus: AttendanceStatus = isApproval ? .present : .absent

        if sharedSession.hasSubmitted,
           let existing = sharedSession.attendance
        {
            sharedSession.updateState(.loaded(Attendance(
                sessionId: existing.sessionId,
                userId: existing.userId,
                type: existing.type,
                status: newStatus,
                locationVerification: existing.locationVerification,
                reason: existing.reason
            )))
        }

        NotificationCenter.default.post(
            name: .attendanceStatusChanged,
            object: nil
        )
    }

}
