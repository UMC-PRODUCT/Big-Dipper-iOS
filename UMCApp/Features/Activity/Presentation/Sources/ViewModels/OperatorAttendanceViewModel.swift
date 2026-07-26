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
/// > Note: 위치 변경은 특정 장소 검색 모델(`PlaceSearchInfo`)에 묶이지 않도록 검증된 원시
///   좌표 파라미터를 받는 ``changeLocation(name:latitude:longitude:)`` 로 노출합니다.
///   시트(``OperatorLocationChangeSheet``)가 장소 선택 결과를 이 좌표로 넘겨줍니다.
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
    ///
    /// mutation(결정·위치 변경) 경로는 토큰 대신 진입 시점에 캡처한 `scheduleId` 로 대상
    /// 일정을 고정하고, 성공 시 `detailRequestID` 를 올려 변경 이전 스냅샷을 실은
    /// in-flight 폴 응답이 결과를 되돌리지 못하게 한다.
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

    /// 진행 중인 세션이 하나라도 있는지 (폴링 트리거용)
    private var hasActiveSession: Bool {
        guard case .loaded(let infos) = listState else { return false }
        return infos.contains { $0.isOngoing() }
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
        // 프리셋 범위는 조회 시점 기준으로 재계산 — VM 이 오래 살아도 창이 init 시점에 고정되지
        // 않는다. `.custom` 은 dateRange 가 nil 이라 사용자가 지정한 from/to 를 그대로 쓴다.
        if let range = periodPreset.dateRange {
            fromDate = range.fromDate
            toDate = range.toDate
        }
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
        await PollingLoop.run(
            intervalSeconds: PollingConfig.intervalSeconds,
            while: { hasActiveSession },
            refresh: { await refreshList() }
        )
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

    /// 기간 프리셋 선택 — 변경 즉시 재조회 (범위는 조회 시점에 재계산).
    ///
    /// `.custom` 은 표시 중인 from/to 가 그대로라 즉시 재조회하면 동일 범위 중복 조회만
    /// 발생하므로, 사용자가 날짜를 조정한 뒤 조회한다.
    func presetSelected(_ preset: AttendancePeriodPreset) async {
        periodPreset = preset
        guard preset != .custom else { return }
        await fetchList()
    }

    // MARK: - Detail Fetch

    /// 단일 일정 상세 조회 대상 선택 + 즉시 조회.
    ///
    /// 이전 일정 기준으로 띄운 확인 다이얼로그가 새 일정 위에서 실행되지 않도록
    /// `alertPrompt` 를 함께 닫는다.
    func selectSchedule(_ scheduleId: String) async {
        selectedScheduleId = scheduleId
        selectedDetailFilter = nil
        alertPrompt = nil
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
        // 취소 롤백 시 상태와 페어로 복원해야 하므로 리셋 전에 함께 캡처한다.
        let restoreScheduleDeleted = isScheduleDeleted
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
            isScheduleDeleted = restoreScheduleDeleted
        } catch let error as NSError
            where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            guard requestID == detailRequestID, showLoading else { return }
            detailState = restore
            isScheduleDeleted = restoreScheduleDeleted
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
            guard requestID == detailRequestID else { return }
            // 일정 삭제는 배경 갱신에서도 감지해야 하는 터미널 상태 —
            // showLoading 가드보다 먼저 판정한다. 진입 후 삭제의 현실적 트리거가 폴링이다.
            if case .serverError(let code, _) = error, code == "SCHEDULE-0009" {
                isScheduleDeleted = true
                detailState = .failed(.repository(error))
                return
            }
            guard showLoading else { return }
            detailState = .failed(.repository(error))
        } catch {
            guard requestID == detailRequestID, showLoading else { return }
            detailState = .failed(.unknown(message: error.localizedDescription))
        }
    }

    /// 진행 중인 일정일 때만 15초 폴링.
    func startDetailPollingIfNeeded() async {
        guard detailState.isComplete else { return }
        await PollingLoop.run(
            intervalSeconds: PollingConfig.intervalSeconds,
            while: { isCurrentlyActive },
            refresh: { await refreshDetail() }
        )
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

    // 확인 Alert 액션은 실행 시점의 `selectedScheduleId` 를 재해석하지 않도록, 탭 시점에
    // 캡처한 scheduleId(전체 결정은 대상 목록까지)를 클로저에 고정해 결정 코어로 전달한다.
    // Alert 가 떠 있는 동안 선택 일정이 바뀌어도 결정은 탭한 화면의 일정으로만 전송된다.

    /// 개별 승인 버튼 탭 (확인 AlertPrompt 표시).
    func approveButtonTapped(participant: ParticipantAttendance) {
        guard let scheduleId = selectedScheduleId else { return }
        alertPrompt = AlertPrompt(
            title: "출석 승인",
            message: "\(participant.name)님의 출석을 승인하시겠습니까?",
            positiveBtnTitle: "승인",
            positiveBtnAction: { [weak self] in
                Task {
                    await self?.decide(
                        scheduleId: scheduleId,
                        participants: [participant],
                        isApproved: true,
                        action: "approveAttendance"
                    )
                }
            },
            negativeBtnTitle: "취소"
        )
    }

    /// 개별 반려 버튼 탭 (확인 AlertPrompt 표시).
    func rejectButtonTapped(participant: ParticipantAttendance) {
        guard let scheduleId = selectedScheduleId else { return }
        alertPrompt = AlertPrompt(
            title: "출석 반려",
            message: "\(participant.name)님의 출석을 반려하시겠습니까?",
            positiveBtnTitle: "반려",
            positiveBtnAction: { [weak self] in
                Task {
                    await self?.decide(
                        scheduleId: scheduleId,
                        participants: [participant],
                        isApproved: false,
                        action: "rejectAttendance"
                    )
                }
            },
            negativeBtnTitle: "취소",
            isPositiveBtnDestructive: true
        )
    }

    /// 사유 확인 버튼 탭 (사유 본문 + 승인/반려 선택 AlertPrompt 표시).
    ///
    /// 사유 결석 신청을 읽고 그 자리에서 결정하는 동선이라, 형제 확인 다이얼로그와 동일하게
    /// 탭 시점의 scheduleId 를 캡처해 결정 코어로 전달한다.
    func excuseReasonButtonTapped(participant: ParticipantAttendance) {
        guard let scheduleId = selectedScheduleId,
              let reason = participant.excuseReason,
              !reason.isEmpty else { return }
        alertPrompt = AlertPrompt(
            title: "출석 사유 확인",
            message: "\(participant.name)님이 작성한 사유입니다.\n\n\"\(reason)\"",
            positiveBtnTitle: "반려",
            positiveBtnAction: { [weak self] in
                Task {
                    await self?.decide(
                        scheduleId: scheduleId,
                        participants: [participant],
                        isApproved: false,
                        action: "rejectAttendance"
                    )
                }
            },
            secondaryBtnTitle: "승인",
            secondaryBtnAction: { [weak self] in
                Task {
                    await self?.decide(
                        scheduleId: scheduleId,
                        participants: [participant],
                        isApproved: true,
                        action: "approveAttendance"
                    )
                }
            },
            negativeBtnTitle: "닫기",
            isPositiveBtnDestructive: true
        )
    }

    /// 전체 승인 버튼 탭 — 승인 대기 대상도 탭 시점 기준으로 캡처한다.
    func approveAllButtonTapped() {
        guard let scheduleId = selectedScheduleId,
              case .loaded(let info) = detailState else { return }
        let pending = info.participants.filter(\.attendanceStatus.isPending)
        guard !pending.isEmpty else { return }
        alertPrompt = AlertPrompt(
            title: "전체 승인",
            message: "모든 승인 대기 출석을 승인하시겠습니까?",
            positiveBtnTitle: "전체 승인",
            positiveBtnAction: { [weak self] in
                Task {
                    await self?.decide(
                        scheduleId: scheduleId,
                        participants: pending,
                        isApproved: true,
                        action: "approveAllAttendances"
                    )
                }
            },
            negativeBtnTitle: "취소"
        )
    }

    /// 전체 반려 버튼 탭 — 승인 대기 대상도 탭 시점 기준으로 캡처한다.
    func rejectAllButtonTapped() {
        guard let scheduleId = selectedScheduleId,
              case .loaded(let info) = detailState else { return }
        let pending = info.participants.filter(\.attendanceStatus.isPending)
        guard !pending.isEmpty else { return }
        alertPrompt = AlertPrompt(
            title: "전체 거절",
            message: "모든 승인 대기 출석을 거절하시겠습니까?",
            positiveBtnTitle: "전체 거절",
            positiveBtnAction: { [weak self] in
                Task {
                    await self?.decide(
                        scheduleId: scheduleId,
                        participants: pending,
                        isApproved: false,
                        action: "rejectAllAttendances"
                    )
                }
            },
            negativeBtnTitle: "취소",
            isPositiveBtnDestructive: true
        )
    }

    // 선택 승인/반려의 확인 다이얼로그는 ViewModel 이 갖지 않는다. 선택 결정의 유일한 진입점인
    // 승인 대기 시트는 ViewModel 의 `alertPrompt`(시트 뒤 화면 바인딩)가 보이지 않아 확인을
    // 시트 내부에서 띄우고, 확정만 ``decideSelectedAttendances(participants:isApproved:)`` 로
    // 위임한다. 비-시트 선택 UI 가 생기면 형제 alert 빌더를 그때 추가한다.

    // MARK: - Decision (낙관적 갱신)

    /// 단건 승인/반려 — 호출 시점의 선택 일정 기준.
    func decideAttendance(
        participant: ParticipantAttendance,
        isApproved: Bool
    ) async {
        guard let scheduleId = selectedScheduleId else { return }
        await decide(
            scheduleId: scheduleId,
            participants: [participant],
            isApproved: isApproved,
            action: isApproved ? "approveAttendance" : "rejectAttendance"
        )
    }

    /// 전체 승인 대기 일괄 처리 — 호출 시점의 선택 일정·승인 대기 목록 기준.
    func decideAllAttendances(isApproved: Bool) async {
        guard let scheduleId = selectedScheduleId,
              case .loaded(let info) = detailState else { return }
        let pending = info.participants.filter(\.attendanceStatus.isPending)
        guard !pending.isEmpty else { return }
        await decide(
            scheduleId: scheduleId,
            participants: pending,
            isApproved: isApproved,
            action: isApproved ? "approveAllAttendances" : "rejectAllAttendances"
        )
    }

    /// 선택 참여자 일괄 처리 — 호출 시점의 선택 일정 기준.
    func decideSelectedAttendances(
        participants: [ParticipantAttendance],
        isApproved: Bool
    ) async {
        guard let scheduleId = selectedScheduleId, !participants.isEmpty else { return }
        await decide(
            scheduleId: scheduleId,
            participants: participants,
            isApproved: isApproved,
            action: isApproved ? "approveSelectedAttendances" : "rejectSelectedAttendances"
        )
    }

    /// 결정 공용 코어 — 단건/전체/선택 진입점과 확인 Alert 액션이 공유한다.
    ///
    /// - `scheduleId` 는 진입 시점 값으로 고정된다. 요청 진행 중 다른 일정으로 전환되면
    ///   낙관적 갱신이 전환된 화면으로 새지 않는다(일정-정체성 가드는 반영 단계에서 수행).
    /// - 성공 시 상세/목록 요청 토큰을 올려, 결정 이전 스냅샷을 실은 in-flight 배경 폴
    ///   응답이 낙관적 갱신을 되돌리지 못하게 한다. 스피너 로드(`.loading`)가 진행 중이면
    ///   bump 가 그 정당한 응답까지 폐기해 stuck-loading 이 되므로 건너뛴다
    ///   (배경 폴은 complete 상태에서만 돌아 그 창에는 존재하지 않는다).
    /// - 대상 전원을 `processingMemberIds` 에 등록해 배치 진행 중 행별 버튼의 중복 결정과
    ///   in-flight 대상 재결정을 막는다.
    private func decide(
        scheduleId: String,
        participants: [ParticipantAttendance],
        isApproved: Bool,
        action: String
    ) async {
        alertPrompt = nil
        let memberIds = Set(participants.map(\.memberId))
        // 같은 대상 결정이 in-flight 면 무시 — 중복 전송 + defer 조기 해제 방지.
        guard processingMemberIds.isDisjoint(with: memberIds) else { return }
        processingMemberIds.formUnion(memberIds)
        defer { processingMemberIds.subtract(memberIds) }

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
            if selectedScheduleId == scheduleId, !detailState.isLoading {
                detailRequestID &+= 1
            }
            if !listState.isLoading {
                listRequestID &+= 1
            }
            updateParticipants(
                scheduleId: scheduleId,
                memberIds: memberIds,
                isApproved: isApproved
            )
        } catch {
            await handleDecisionError(error, action: action, scheduleId: scheduleId)
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
            applyLocationChange(
                scheduleId: scheduleId,
                location: ScheduleLocation(
                    latitude: latitude,
                    longitude: longitude,
                    locationName: trimmedName
                )
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

    /// 위치 변경 성공을 화면 상태에 즉시 반영한다.
    ///
    /// 시작 전 일정은 폴링이 돌지 않아 재조회 없이는 옛 위치가 계속 남으므로 직접 교체한다.
    /// 변경 이전 위치를 실은 in-flight 폴 응답은 토큰으로 무효화한다(결정 경로와 동일 규칙).
    /// bump 는 해당 일정이 `.loaded` 일 때만 도달하므로 진행 중 스피너 로드를 폐기해
    /// stuck-loading 을 만들 위험이 없다.
    private func applyLocationChange(scheduleId: String, location: ScheduleLocation) {
        guard case .loaded(let info) = detailState, info.scheduleId == scheduleId else { return }
        if selectedScheduleId == scheduleId {
            detailRequestID &+= 1
        }
        detailState = .loaded(
            rebuild(info, participants: info.participants, location: location)
        )
    }

    // MARK: - Private (Error)

    private func handleDecisionError(
        _ error: Error,
        action: String,
        scheduleId: String
    ) async {
        if Self.isPermissionDenied(error) {
            presentAlert(
                title: "권한이 없어요",
                message: "출석을 처리할 권한이 없습니다. 운영진 권한을 확인해 주세요."
            )
            // 결정을 보낸 일정을 여전히 보고 있을 때만 재조회한다 (일정-정체성 가드).
            if selectedScheduleId == scheduleId {
                await refreshDetail()
            }
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

    /// 결정 성공 결과를 화면 상태에 반영한다.
    ///
    /// 상세는 결정을 보낸 일정이 그대로 로드돼 있을 때만 갱신하고(일정-정체성 가드),
    /// 목록은 같은 scheduleId 항목만 갱신해 per-card 승인 대기 배지(`pendingCount`)가
    /// 수동 재조회 없이 결정 결과를 즉시 반영하게 한다.
    private func updateParticipants(
        scheduleId: String,
        memberIds: Set<String>,
        isApproved: Bool
    ) {
        if case .loaded(let info) = detailState, info.scheduleId == scheduleId {
            detailState = .loaded(
                applyingDecision(to: info, memberIds: memberIds, isApproved: isApproved)
            )
        }
        if case .loaded(let infos) = listState {
            listState = .loaded(infos.map { info in
                guard info.scheduleId == scheduleId else { return info }
                return applyingDecision(to: info, memberIds: memberIds, isApproved: isApproved)
            })
        }
        notifySharedSessionChange()
    }

    /// 지정한 멤버들의 승인 대기 상태를 결정 확정 상태로 치환한 사본을 만든다.
    private func applyingDecision(
        to info: ScheduleAttendanceInfo,
        memberIds: Set<String>,
        isApproved: Bool
    ) -> ScheduleAttendanceInfo {
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
                attendanceStatus: decidedStatus(
                    from: participant.attendanceStatus,
                    isApproved: isApproved
                ),
                isLocationVerified: participant.isLocationVerified,
                excuseReason: participant.excuseReason
            )
        }
        return rebuild(info, participants: updated, location: info.location)
    }

    /// pending 종류별 확정 상태 매핑 — 서버 확정 규칙과 동일하게 승인은 대기 종류를 보존한다.
    ///
    /// 지각/사유 승인을 일괄 `.present` 로 뭉개면 배지·presentCount·상세 필터 소속이
    /// 서버 확정값과 어긋난다. 반려는 종류와 무관하게 일괄 `.absent`.
    private func decidedStatus(
        from pendingStatus: ParticipantAttendanceStatus,
        isApproved: Bool
    ) -> ParticipantAttendanceStatus {
        guard isApproved else { return .absent }
        switch pendingStatus {
        case .latePending: return .late
        case .excusedPending: return .excused
        default: return .present
        }
    }

    private func rebuild(
        _ info: ScheduleAttendanceInfo,
        participants: [ParticipantAttendance],
        location: ScheduleLocation?
    ) -> ScheduleAttendanceInfo {
        ScheduleAttendanceInfo(
            scheduleId: info.scheduleId,
            name: info.name,
            description: info.description,
            startsAt: info.startsAt,
            endsAt: info.endsAt,
            location: location,
            isOnline: info.isOnline,
            authorMemberId: info.authorMemberId,
            attendancePolicy: info.attendancePolicy,
            tags: info.tags,
            participants: participants
        )
    }

    // MARK: - Private (Helper)

    /// 일정이 현재 진행 중인지 (폴링용).
    private var isCurrentlyActive: Bool {
        guard case .loaded(let info) = detailState else { return false }
        return info.isOngoing()
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
