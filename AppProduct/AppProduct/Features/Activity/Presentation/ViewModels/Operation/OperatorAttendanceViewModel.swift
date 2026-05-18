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

    @MainActor
    func fetchSessions() async {
        sessionsState = .loading
        do {
            let infos = try await useCase.fetchAttendanceList(
                from: nil, to: nil, attendanceStatus: nil
            )
            sessionsState = .loaded(infos.map { $0.toOperatorSessionAttendance() })
        } catch let error as DomainError {
            sessionsState = .failed(.domain(error))
        } catch let error as NetworkError {
            sessionsState = .failed(.network(error))
        } catch {
            sessionsState = .failed(.unknown(message: error.localizedDescription))
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
                    await self?.decideAttendance(
                        memberId: member.id,
                        participantMemberId: member.participantMemberId,
                        sessionId: sessionId,
                        isApproved: true
                    )
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
                    await self?.decideAttendance(
                        memberId: member.id,
                        participantMemberId: member.participantMemberId,
                        sessionId: sessionId,
                        isApproved: false
                    )
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
                    await self?.decideAllAttendances(sessionId: sessionId, isApproved: true)
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
                    await self?.decideAllAttendances(sessionId: sessionId, isApproved: false)
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
                    await self?.decideSelectedAttendances(
                        members: members,
                        sessionId: sessionId,
                        isApproved: true
                    )
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
                    await self?.decideSelectedAttendances(
                        members: members,
                        sessionId: sessionId,
                        isApproved: false
                    )
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
            await decideAttendance(
                memberId: member.id,
                participantMemberId: member.participantMemberId,
                sessionId: sessionId,
                isApproved: true
            )
        }
    }

    /// 확인 없이 즉시 출석 반려 (사유 확인 AlertPrompt에서 호출)
    func rejectDirectly(member: OperatorPendingMember, sessionId: UUID) {
        Task {
            await decideAttendance(
                memberId: member.id,
                participantMemberId: member.participantMemberId,
                sessionId: sessionId,
                isApproved: false
            )
        }
    }

    // MARK: - Polling

    @MainActor
    func refreshSessions() async {
        guard sessionsState.isComplete else { return }
        do {
            let infos = try await useCase.fetchAttendanceList(
                from: nil, to: nil, attendanceStatus: nil
            )
            sessionsState = .loaded(infos.map { $0.toOperatorSessionAttendance() })
        } catch {
            // 배경 갱신 실패는 무시 — 기존 데이터 유지
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

    /// 단건 출석 승인/반려 (V2 일괄 API 단건 호출로 래핑)
    @MainActor
    private func decideAttendance(
        memberId: UUID,
        participantMemberId: Int,
        sessionId: UUID,
        isApproved: Bool
    ) async {
        alertPrompt = nil
        guard case .loaded(let sessions) = sessionsState,
              let session = sessions.first(where: { $0.id == sessionId }),
              let scheduleId = Int(session.serverID ?? "")
        else { return }

        processingMemberIds.insert(memberId)
        defer { processingMemberIds.remove(memberId) }

        let decision = AttendanceDecisionInput(
            isApproved: isApproved,
            participantMemberId: participantMemberId,
            reason: ""
        )

        do {
            _ = try await useCase.decideAttendances(
                scheduleId: scheduleId,
                decisions: [decision]
            )
            updateSessionByRemovingMember(
                memberId: memberId,
                sessionId: sessionId,
                isApproval: isApproved
            )
        } catch {
            await handleDecisionError(
                error,
                action: isApproved ? "approveAttendance" : "rejectAttendance"
            )
        }
    }

    /// 전체 출석 일괄 승인/반려 (V2 단일 호출)
    @MainActor
    private func decideAllAttendances(sessionId: UUID, isApproved: Bool) async {
        alertPrompt = nil
        guard case .loaded(let sessions) = sessionsState,
              let session = sessions.first(where: { $0.id == sessionId }),
              let scheduleId = Int(session.serverID ?? "")
        else { return }

        let decisions = session.pendingMembers.map {
            AttendanceDecisionInput(
                isApproved: isApproved,
                participantMemberId: $0.participantMemberId,
                reason: ""
            )
        }

        guard !decisions.isEmpty else { return }

        do {
            _ = try await useCase.decideAttendances(
                scheduleId: scheduleId,
                decisions: decisions
            )
            updateSessionByRemovingAllMembers(
                sessionId: sessionId,
                isApproval: isApproved
            )
        } catch {
            await handleDecisionError(
                error,
                action: isApproved ? "approveAllAttendances" : "rejectAllAttendances"
            )
        }
    }

    /// 선택 출석 일괄 승인/반려 (V2 단일 호출)
    @MainActor
    private func decideSelectedAttendances(
        members: [OperatorPendingMember],
        sessionId: UUID,
        isApproved: Bool
    ) async {
        alertPrompt = nil
        guard case .loaded(let sessions) = sessionsState,
              let session = sessions.first(where: { $0.id == sessionId }),
              let scheduleId = Int(session.serverID ?? "")
        else { return }

        let decisions = members.map {
            AttendanceDecisionInput(
                isApproved: isApproved,
                participantMemberId: $0.participantMemberId,
                reason: ""
            )
        }

        do {
            _ = try await useCase.decideAttendances(
                scheduleId: scheduleId,
                decisions: decisions
            )
            updateSessionByRemovingSelectedMembers(
                memberIds: members.map(\.id),
                sessionId: sessionId,
                isApproval: isApproved
            )
        } catch {
            await handleDecisionError(
                error,
                action: isApproved ? "approveSelectedAttendances" : "rejectSelectedAttendances"
            )
        }
    }

    /// 출석 승인/반려 실패 처리.
    ///
    /// HTTP 403 (권한 부족) 인 경우 명확한 안내 Alert 후 세션 목록을 갱신해
    /// 서버 측 권한/상태 변화를 즉시 반영합니다. 그 외 에러는 기존 ErrorHandler 로 위임합니다.
    @MainActor
    private func handleDecisionError(_ error: Error, action: String) async {
        if Self.isPermissionDenied(error) {
            alertPrompt = AlertPrompt(
                title: "권한이 없어요",
                message: "출석을 처리할 권한이 없습니다. 운영진 권한을 확인해 주세요.",
                positiveBtnTitle: "확인",
                positiveBtnAction: { [weak self] in
                    self?.alertPrompt = nil
                }
            )
            await refreshSessions()
            return
        }
        errorHandler.handle(error, context: .init(
            feature: "Activity",
            action: action
        ))
    }

    /// HTTP 403(권한 부족) 여부 감지.
    ///
    /// - `AppError.network(.requestFailed(403, _))`
    /// - `NetworkError.requestFailed(403, _)`
    /// 두 표현을 모두 처리합니다.
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
