//
//  OperatorAttendanceViewModel.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/14/26.
//

import ActivityDomain
import Foundation
import UMCFoundation

/// 운영진 출석 관리 화면(단일 통합, Direction A)의 상태·액션을 관리하는 ViewModel.
///
/// 레거시 `AttendanceListViewModel` + `AttendanceDetailViewModel` 을 단일 화면 기준으로
/// 통합 이식했습니다. 출석 현황 목록 조회·단일 일정 상세 조회·일괄 승인/반려·위치 변경을
/// 모두 `OperatorAttendanceUseCaseProtocol` 에만 의존해 처리합니다(Repository 직접 의존 금지).
///
/// - 모든 서버 식별자는 `String` 으로 통일됩니다.
/// - `.task` 라이프사이클 취소(`CancellationError`)는 실패가 아니므로 이전 상태로 롤백합니다
///   (형제 `MemberListViewModel`/`ChallengerStudyViewModel` house 패턴).
///
/// > Note: 레거시 위치 변경 시트(`OperatorLocationChangeSheetView`)와 `PlaceSearchInfo` 는
///   아직 이식 전이라, 위치 변경은 검증된 원시 좌표 파라미터를 받는
///   ``changeLocation(name:latitude:longitude:)`` 로 노출합니다.
@MainActor
@Observable
final class OperatorAttendanceViewModel {

    // MARK: - Polling Config

    private enum PollingConfig {
        static let intervalSeconds: Int = 15
    }

    // MARK: - Dependency

    private let errorHandler: ErrorHandler
    private let useCase: OperatorAttendanceUseCaseProtocol

    // MARK: - Request Tokens

    /// 목록·상세 요청 순번. 응답을 적용할 때 토큰이 최신인지 확인해 최신 요청만 상태에
    /// 반영한다(latest-wins).
    ///
    /// 병합 VM 은 가변 식별자(`selectedScheduleId`)·필터(`selectedListFilter`/기간)를 갖고
    /// 그 값이 요청 도중 바뀔 수 있다. 형제 `MemberListViewModel` 의 단순 재진입 가드
    /// (`if state.isLoading { return }`)는 이 가변 식별자를 몰라서 진행 중 스케줄 전환을
    /// 통째로 막거나(요청 유실) 오래된 응답이 새 식별자에 바인딩되는 문제가 생긴다. 토큰은
    /// 이 둘을 함께 풀고 롤백 기준을 비-`.loading` 으로 잡아 stuck-loading 까지 막는다.
    @ObservationIgnored private var listRequestID = 0
    @ObservationIgnored private var detailRequestID = 0

    // MARK: - List State

    /// 출석 현황 목록 로드 상태
    private(set) var listState: Loadable<[ScheduleAttendanceInfo]> = .idle

    /// 목록 상태 필터 (`nil` = 전체)
    private(set) var selectedListFilter: ParticipantAttendanceStatus?

    /// 필터 칩 후보 (`.unknown` 제외)
    let filterableStatuses: [ParticipantAttendanceStatus] =
        ParticipantAttendanceStatus.filterableCases

    /// 선택된 기간 프리셋 (기본값: 최근 1개월)
    private(set) var periodPreset: AttendancePeriodPreset = .oneMonth

    /// 조회 시작 일시 (기본값: 현재 -1개월)
    var fromDate: Date = {
        Calendar.kstGregorian.date(byAdding: .month, value: -1, to: Date())
            ?? Date().addingTimeInterval(-30 * 24 * 60 * 60)
    }()

    /// 조회 종료 일시 (기본값: 현재 +24시간, 진행 중 일정 포함)
    var toDate: Date = Date().addingTimeInterval(24 * 60 * 60)

    // MARK: - Detail State

    /// 현재 상세 조회 대상 일정 식별자 (서버 응답 `String`)
    private(set) var selectedScheduleId: String?

    /// 단일 일정 출석 현황 로드 상태
    private(set) var detailState: Loadable<ScheduleAttendanceInfo> = .idle

    /// 상세 화면 상태 필터 (`nil` = 전체, 클라이언트 측 필터링)
    private(set) var selectedDetailFilter: ParticipantAttendanceStatus?

    /// 상세 진입 후 일정이 삭제됐는지 여부 (SCHEDULE-0009 감지)
    private(set) var isScheduleDeleted: Bool = false

    /// 확인/에러 다이얼로그
    var alertPrompt: AlertPrompt?

    /// 승인/반려 처리 중인 멤버 ID Set (개별 행 ProgressView 표시용)
    private(set) var processingMemberIds: Set<String> = []

    // MARK: - Init

    init(
        errorHandler: ErrorHandler,
        useCase: OperatorAttendanceUseCaseProtocol
    ) {
        self.errorHandler = errorHandler
        self.useCase = useCase
    }

    // MARK: - List Derived State

    /// 전체 승인 대기 건수 (`.loaded` 상태에서만 집계)
    var totalPendingCount: Int {
        guard case .loaded(let infos) = listState else { return 0 }
        return infos.map(\.pendingCount).reduce(0, +)
    }

    /// 승인 대기가 1건 이상인 첫 번째 일정의 scheduleId
    var firstPendingScheduleId: String? {
        guard case .loaded(let infos) = listState else { return nil }
        return infos.first(where: { $0.pendingCount > 0 })?.scheduleId
    }

    /// 접근 권한 거부 상태 여부 (HTTP 403) — 권한 전용 UI 노출 분기용
    var isPermissionDenied: Bool {
        guard case .failed(let error) = listState else { return false }
        return Self.isPermissionDenied(error)
    }

    /// 진행 중인 세션이 하나라도 있는지 (KST 기준, 폴링 트리거용)
    private var hasActiveSession: Bool {
        guard case .loaded(let infos) = listState else { return false }
        let now = Date()
        return infos.contains { now >= $0.startsAt && now <= $0.endsAt }
    }

    // MARK: - List Fetch

    /// 출석 현황 목록 조회 (스피너 전환).
    func fetchList() async {
        await loadList(showLoading: true)
    }

    /// 배경 갱신 — `.loading` 전환 없이 성공 시에만 상태 교체(실패 시 기존 데이터 유지).
    func refreshList() async {
        guard listState.isComplete else { return }
        await loadList(showLoading: false)
    }

    /// 목록 조회 코어.
    ///
    /// 요청 토큰으로 최신 요청만 상태에 반영해 필터/기간이 요청 도중 바뀌어도 오래된 응답이
    /// 새 필터 상태를 덮어쓰지 못하게 한다. 취소는 실패가 아니므로 스피너 전환일 때만 롤백한다.
    /// - Parameter showLoading: `true` = 사용자 트리거(스피너·에러 노출), `false` = 배경 갱신
    ///   (에러를 삼켜 기존 데이터 유지 — 레거시 `refreshList` 동작).
    private func loadList(showLoading: Bool) async {
        listRequestID &+= 1
        let requestID = listRequestID
        // 롤백 기준: 진행 중(.loading) 상태는 복원 대상이 아니므로 .idle 로 대체(stuck-loading 방지).
        let restore: Loadable<[ScheduleAttendanceInfo]> = listState.isComplete ? listState : .idle
        // 요청 파라미터를 시작 시점에 고정 — 응답 적용은 토큰이 최신일 때만 이뤄진다.
        let from = fromDate
        let to = toDate
        let filter = selectedListFilter
        if showLoading { listState = .loading }
        do {
            let list = try await useCase.fetchAttendanceList(
                from: from,
                to: to,
                attendanceStatus: filter
            )
            guard requestID == listRequestID else { return }
            listState = .loaded(list)
        } catch is CancellationError {
            guard requestID == listRequestID, showLoading else { return }
            listState = restore
        } catch let error as NSError
            where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            guard requestID == listRequestID, showLoading else { return }
            listState = restore
        } catch let error as AppError {
            guard requestID == listRequestID, showLoading else { return }
            listState = .failed(error)
        } catch let error as DomainError {
            guard requestID == listRequestID, showLoading else { return }
            listState = .failed(.domain(error))
        } catch let error as NetworkError {
            guard requestID == listRequestID, showLoading else { return }
            listState = .failed(.network(error))
        } catch let error as RepositoryError {
            guard requestID == listRequestID, showLoading else { return }
            listState = .failed(.repository(error))
        } catch {
            guard requestID == listRequestID, showLoading else { return }
            listState = .failed(.unknown(message: error.localizedDescription))
        }
    }

    /// 진행 중인 세션이 있을 때 15초 주기로 배경 갱신.
    ///
    /// `.task` 에서 호출하면 뷰 소멸 시 자동 취소됩니다.
    func startListPollingIfNeeded() async {
        guard listState.isComplete else { return }
        while !Task.isCancelled {
            guard hasActiveSession else { return }
            try? await Task.sleep(for: .seconds(PollingConfig.intervalSeconds))
            guard !Task.isCancelled else { break }
            await refreshList()
        }
    }

    // MARK: - List Filter

    /// 상태 필터 칩 탭 — 같은 필터를 다시 누르면 해제. 변경 즉시 재조회.
    func listFilterButtonTapped(_ status: ParticipantAttendanceStatus) async {
        selectedListFilter = (selectedListFilter == status) ? nil : status
        await fetchList()
    }

    /// "전체" 선택 — 이미 전체면 재조회하지 않음.
    func clearListFilter() async {
        guard selectedListFilter != nil else { return }
        selectedListFilter = nil
        await fetchList()
    }

    /// 기간 프리셋 선택 — `.custom` 은 from/to 를 유지하고 사용자가 직접 조정.
    func presetSelected(_ preset: AttendancePeriodPreset) async {
        periodPreset = preset
        if let range = preset.dateRange {
            fromDate = range.fromDate
            toDate = range.toDate
        }
        await fetchList()
    }

    // MARK: - Detail Fetch

    /// 단일 일정 상세 조회 대상 선택 + 즉시 조회.
    func selectSchedule(_ scheduleId: String) async {
        selectedScheduleId = scheduleId
        selectedDetailFilter = nil
        await loadDetail(showLoading: true)
    }

    /// 선택된 일정의 출석 현황 상세 재조회 (스피너 전환).
    func fetchDetail() async {
        await loadDetail(showLoading: true)
    }

    /// 상세 배경 갱신 — 실패해도 기존 상태 유지.
    func refreshDetail() async {
        guard selectedScheduleId != nil, detailState.isComplete else { return }
        await loadDetail(showLoading: false)
    }

    /// 상세 조회 코어.
    ///
    /// 요청 토큰으로 최신 요청만 반영해, 스케줄 전환 중 오래된 응답이 새 `selectedScheduleId` 에
    /// 옛 데이터를 바인딩하지 않게 한다. 진입 후 일정이 삭제된 경우(SCHEDULE-0009)
    /// ``isScheduleDeleted`` 를 세운다.
    /// - Parameter showLoading: `true` = 사용자 트리거(스피너·에러 노출), `false` = 배경 갱신.
    private func loadDetail(showLoading: Bool) async {
        guard let scheduleId = selectedScheduleId else { return }
        detailRequestID &+= 1
        let requestID = detailRequestID
        let restore: Loadable<ScheduleAttendanceInfo> =
            detailState.isComplete ? detailState : .idle
        if showLoading {
            detailState = .loading
            isScheduleDeleted = false
        }
        do {
            let info = try await useCase.fetchAttendanceDetail(
                scheduleId: scheduleId,
                attendanceStatus: nil
            )
            guard requestID == detailRequestID else { return }
            detailState = .loaded(info)
        } catch is CancellationError {
            guard requestID == detailRequestID, showLoading else { return }
            detailState = restore
        } catch let error as NSError
            where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            guard requestID == detailRequestID, showLoading else { return }
            detailState = restore
        } catch let error as AppError {
            guard requestID == detailRequestID, showLoading else { return }
            detailState = .failed(error)
        } catch let error as DomainError {
            guard requestID == detailRequestID, showLoading else { return }
            detailState = .failed(.domain(error))
        } catch let error as NetworkError {
            guard requestID == detailRequestID, showLoading else { return }
            detailState = .failed(.network(error))
        } catch let error as RepositoryError {
            guard requestID == detailRequestID, showLoading else { return }
            if case .serverError(let code, _) = error, code == "SCHEDULE-0009" {
                isScheduleDeleted = true
            }
            detailState = .failed(.repository(error))
        } catch {
            guard requestID == detailRequestID, showLoading else { return }
            detailState = .failed(.unknown(message: error.localizedDescription))
        }
    }

    /// 진행 중인 일정일 때만 15초 폴링.
    func startDetailPollingIfNeeded() async {
        guard detailState.isComplete else { return }
        while !Task.isCancelled {
            guard isCurrentlyActive else { return }
            try? await Task.sleep(for: .seconds(PollingConfig.intervalSeconds))
            guard !Task.isCancelled else { break }
            await refreshDetail()
        }
    }

    // MARK: - Detail Filter

    /// 상세 필터 칩 탭 (클라이언트 측 필터링, 재조회 없음).
    func detailFilterButtonTapped(_ status: ParticipantAttendanceStatus) {
        selectedDetailFilter = (selectedDetailFilter == status) ? nil : status
    }

    /// 현재 필터를 적용한 참여자 목록.
    var filteredParticipants: [ParticipantAttendance] {
        guard case .loaded(let info) = detailState else { return [] }
        guard let filter = selectedDetailFilter else { return info.participants }
        return info.participants.filter { $0.attendanceStatus == filter }
    }

    // MARK: - Approval Button (AlertPrompt)

    /// 개별 승인 버튼 탭 (확인 AlertPrompt 표시).
    func approveButtonTapped(participant: ParticipantAttendance) {
        alertPrompt = AlertPrompt(
            title: "출석 승인",
            message: "\(participant.name)님의 출석을 승인하시겠습니까?",
            positiveBtnTitle: "승인",
            positiveBtnAction: { [weak self] in
                Task { await self?.decideAttendance(participant: participant, isApproved: true) }
            },
            negativeBtnTitle: "취소"
        )
    }

    /// 개별 반려 버튼 탭 (확인 AlertPrompt 표시).
    func rejectButtonTapped(participant: ParticipantAttendance) {
        alertPrompt = AlertPrompt(
            title: "출석 반려",
            message: "\(participant.name)님의 출석을 반려하시겠습니까?",
            positiveBtnTitle: "반려",
            positiveBtnAction: { [weak self] in
                Task { await self?.decideAttendance(participant: participant, isApproved: false) }
            },
            negativeBtnTitle: "취소",
            isPositiveBtnDestructive: true
        )
    }

    /// 전체 승인 버튼 탭.
    func approveAllButtonTapped() {
        alertPrompt = AlertPrompt(
            title: "전체 승인",
            message: "모든 승인 대기 출석을 승인하시겠습니까?",
            positiveBtnTitle: "전체 승인",
            positiveBtnAction: { [weak self] in
                Task { await self?.decideAllAttendances(isApproved: true) }
            },
            negativeBtnTitle: "취소"
        )
    }

    /// 전체 반려 버튼 탭.
    func rejectAllButtonTapped() {
        alertPrompt = AlertPrompt(
            title: "전체 거절",
            message: "모든 승인 대기 출석을 거절하시겠습니까?",
            positiveBtnTitle: "전체 거절",
            positiveBtnAction: { [weak self] in
                Task { await self?.decideAllAttendances(isApproved: false) }
            },
            negativeBtnTitle: "취소",
            isPositiveBtnDestructive: true
        )
    }

    /// 선택 승인 버튼 탭.
    func approveSelectedButtonTapped(participants: [ParticipantAttendance]) {
        guard !participants.isEmpty else { return }
        alertPrompt = AlertPrompt(
            title: "선택 승인",
            message: "\(participants.count)명의 출석을 승인하시겠습니까?",
            positiveBtnTitle: "승인",
            positiveBtnAction: { [weak self] in
                Task {
                    await self?.decideSelectedAttendances(
                        participants: participants,
                        isApproved: true
                    )
                }
            },
            negativeBtnTitle: "취소"
        )
    }

    /// 선택 반려 버튼 탭.
    func rejectSelectedButtonTapped(participants: [ParticipantAttendance]) {
        guard !participants.isEmpty else { return }
        alertPrompt = AlertPrompt(
            title: "선택 거절",
            message: "\(participants.count)명의 출석을 거절하시겠습니까?",
            positiveBtnTitle: "거절",
            positiveBtnAction: { [weak self] in
                Task {
                    await self?.decideSelectedAttendances(
                        participants: participants,
                        isApproved: false
                    )
                }
            },
            negativeBtnTitle: "취소",
            isPositiveBtnDestructive: true
        )
    }

    // MARK: - Decision (낙관적 갱신)

    /// 단건 승인/반려 — 성공 시 pending → present/absent 로 낙관적 갱신.
    func decideAttendance(
        participant: ParticipantAttendance,
        isApproved: Bool
    ) async {
        guard let scheduleId = selectedScheduleId else { return }
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
            updateParticipants(memberIds: [memberId], isApproved: isApproved)
        } catch {
            await handleDecisionError(
                error,
                action: isApproved ? "approveAttendance" : "rejectAttendance"
            )
        }
    }

    /// 전체 승인 대기 일괄 처리.
    func decideAllAttendances(isApproved: Bool) async {
        guard let scheduleId = selectedScheduleId else { return }
        alertPrompt = nil
        guard case .loaded(let info) = detailState else { return }

        let pending = info.participants.filter(\.attendanceStatus.isPending)
        guard !pending.isEmpty else { return }

        let decisions = pending.map {
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
            updateParticipants(
                memberIds: Set(pending.map(\.memberId)),
                isApproved: isApproved
            )
        } catch {
            await handleDecisionError(
                error,
                action: isApproved ? "approveAllAttendances" : "rejectAllAttendances"
            )
        }
    }

    /// 선택 참여자 일괄 처리.
    func decideSelectedAttendances(
        participants: [ParticipantAttendance],
        isApproved: Bool
    ) async {
        guard let scheduleId = selectedScheduleId else { return }
        alertPrompt = nil
        guard !participants.isEmpty else { return }

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
            updateParticipants(
                memberIds: Set(participants.map(\.memberId)),
                isApproved: isApproved
            )
        } catch {
            await handleDecisionError(
                error,
                action: isApproved ? "approveSelectedAttendances" : "rejectSelectedAttendances"
            )
        }
    }

    // MARK: - Location

    /// 세션 출석 위치 변경.
    ///
    /// 좌표 유효성(유한값·위경도 범위)을 검증한 뒤 UseCase 에 위임합니다. 성공하면 `true`.
    /// - Note: 레거시 `PlaceSearchInfo` 커플링을 제거하고 검증된 원시 좌표를 받습니다.
    func changeLocation(
        name: String,
        latitude: Double,
        longitude: Double
    ) async -> Bool {
        guard let scheduleId = selectedScheduleId else { return false }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            presentAlert(title: "위치 변경 실패", message: "변경할 위치를 선택해 주세요.")
            return false
        }

        guard latitude.isFinite, longitude.isFinite,
              (-90.0...90.0).contains(latitude),
              (-180.0...180.0).contains(longitude) else {
            presentAlert(title: "위치 변경 실패", message: "유효한 위치 좌표를 선택해 주세요.")
            return false
        }

        do {
            try await useCase.updateScheduleLocation(
                scheduleId: scheduleId,
                locationName: trimmedName,
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

    // MARK: - Private (Error)

    private func handleDecisionError(_ error: Error, action: String) async {
        if Self.isPermissionDenied(error) {
            presentAlert(
                title: "권한이 없어요",
                message: "출석을 처리할 권한이 없습니다. 운영진 권한을 확인해 주세요."
            )
            await refreshDetail()
            return
        }
        errorHandler.handle(error, context: ErrorContext(
            feature: "Activity",
            action: action
        ))
    }

    /// HTTP 403 여부 판별 — `AppError` 로 정규화됐거나 원본 `NetworkError` 둘 다 커버.
    private static func isPermissionDenied(_ error: Error) -> Bool {
        if let networkError = error as? NetworkError,
           case .requestFailed(let status, _) = networkError, status == 403 {
            return true
        }
        if let appError = error as? AppError,
           case .network(let networkError) = appError,
           case .requestFailed(let status, _) = networkError, status == 403 {
            return true
        }
        return false
    }

    // MARK: - Private (낙관적 갱신)

    /// 지정한 멤버들을 pending → present/absent 로 낙관적 갱신.
    ///
    /// 단건·전체·선택 결정이 동일 규칙을 공유하므로 대상 memberId 집합만 달리해 재사용합니다.
    private func updateParticipants(memberIds: Set<String>, isApproved: Bool) {
        guard case .loaded(let info) = detailState else { return }
        let newStatus: ParticipantAttendanceStatus = isApproved ? .present : .absent
        let updated = info.participants.map { participant -> ParticipantAttendance in
            guard memberIds.contains(participant.memberId),
                  participant.attendanceStatus.isPending else {
                return participant
            }
            return ParticipantAttendance(
                memberId: participant.memberId,
                name: participant.name,
                nickname: participant.nickname,
                profileImageURL: participant.profileImageURL,
                schoolId: participant.schoolId,
                schoolName: participant.schoolName,
                attendanceStatus: newStatus,
                isLocationVerified: participant.isLocationVerified,
                excuseReason: participant.excuseReason
            )
        }
        detailState = .loaded(rebuild(info, participants: updated))
        notifySharedSessionChange()
    }

    private func rebuild(
        _ info: ScheduleAttendanceInfo,
        participants: [ParticipantAttendance]
    ) -> ScheduleAttendanceInfo {
        ScheduleAttendanceInfo(
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
            participants: participants
        )
    }

    // MARK: - Private (Helper)

    /// 일정이 현재 진행 중인지 (KST 기준, 폴링용).
    private var isCurrentlyActive: Bool {
        guard case .loaded(let info) = detailState else { return false }
        let now = Date()
        return now >= info.startsAt && now <= info.endsAt
    }

    /// 챌린저 뷰를 실시간 갱신하도록 Notification 발송.
    private func notifySharedSessionChange() {
        NotificationCenter.default.post(name: .attendanceStatusChanged, object: nil)
    }

    private func presentAlert(title: String, message: String) {
        alertPrompt = AlertPrompt(
            title: title,
            message: message,
            positiveBtnTitle: "확인"
        )
    }
}
