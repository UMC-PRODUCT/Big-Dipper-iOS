//
//  AttendanceListViewModel.swift
//  AppProduct
//
//  Created by euijjang97 on 5/6/26.
//

import Foundation

/// 운영진 출석 현황 목록 화면 ViewModel (Schedule V2)
///
/// `GET /api/v2/schedules/attendance` 호출 결과를 상태별/기간별로 필터링해 표시합니다.
/// 직책별 조회 범위는 서버에서 자동 분기되므로 클라이언트는 권한 분기 없이 호출만 합니다.
///
/// ## 권한 분기 (AC-E1)
/// `canCreateAttendanceRequiredSchedule = false` 인 사용자가 진입한 경우
/// 빈 폴백 화면을 표시하고, 호출 측 (ActivityView root) 에서 카드 자체를 숨깁니다.
///
/// - SeeAlso: ``AttendanceListView``, ``OperatorAttendanceUseCaseProtocol/fetchAttendanceList(from:to:attendanceStatus:)``
@Observable
final class AttendanceListViewModel {

    // MARK: - Property

    private enum PollingConfig {
        static let intervalSeconds: Int = 15
    }

    private var container: DIContainer
    private var errorHandler: ErrorHandler
    private var useCase: OperatorAttendanceUseCaseProtocol

    /// 출석 현황 로드 상태
    private(set) var listState: Loadable<[ScheduleAttendanceInfo]> = .idle

    /// 현재 선택된 상태 필터 (`nil` = 전체)
    private(set) var selectedFilter: AttendanceStatusV2?

    /// 필터 칩에 표시할 후보 (`.unknown` 제외 — AC#7)
    let filterableStatuses: [AttendanceStatusV2] = AttendanceStatusV2.filterableCases

    // MARK: - Period Filter (AC#7)

    /// 선택된 기간 프리셋 (기본값: 최근 1개월)
    private(set) var periodPreset: AttendancePeriodPreset = .oneMonth

    /// 조회 시작 일시
    var fromDate: Date = {
        Calendar.kstGregorian.date(byAdding: .month, value: -1, to: Date())
            ?? Date().addingTimeInterval(-30 * 24 * 60 * 60)
    }()

    /// 조회 종료 일시 (기본값: 현재 +24시간, 진행 중 일정 포함)
    var toDate: Date = Date().addingTimeInterval(24 * 60 * 60)

    // MARK: - Derived State

    /// 전체 승인 대기 건수 (`.loaded` 상태에서만 집계)
    var totalPendingCount: Int {
        guard case .loaded(let infos) = listState else { return 0 }
        return infos.map(\.pendingCount).reduce(0, +)
    }

    /// 승인 대기가 1건 이상인 첫 번째 일정의 scheduleId
    var firstPendingScheduleId: Int? {
        guard case .loaded(let infos) = listState else { return nil }
        return infos.first(where: { $0.pendingCount > 0 })?.scheduleId
    }

    /// 현재 진행 중인 세션이 하나라도 있는지 여부 (KST 기준)
    private var hasActiveSession: Bool {
        guard case .loaded(let infos) = listState else { return false }
        let now = Date()
        return infos.contains { now >= $0.startsAt && now <= $0.endsAt }
    }

    /// 접근 권한 거부 상태 여부 (HTTP 403)
    ///
    /// 필터 칩·기간 필터·승인 대기 배너 등 **권한 보유자 전용 UI** 노출 분기에 사용합니다.
    /// 권한이 없는 사용자에게는 ``AttendanceListView`` 가 폴백 안내만 표시합니다.
    var isPermissionDenied: Bool {
        guard case .failed(let error) = listState else { return false }
        return error.isPermissionDenied
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

    /// 출석 현황 목록 조회
    ///
    /// `fromDate`/`toDate` 를 파라미터로 전달합니다.
    @MainActor
    func fetch() async {
        listState = .loading
        do {
            let list = try await useCase.fetchAttendanceList(
                from: fromDate,
                to: toDate,
                attendanceStatus: selectedFilter
            )
            listState = .loaded(list)
        } catch let error as DomainError {
            listState = .failed(.domain(error))
        } catch let error as NetworkError {
            listState = .failed(.network(error))
        } catch {
            errorHandler.handle(error, context: ErrorContext(
                feature: "Activity",
                action: "fetchAttendanceList",
                retryAction: { [weak self] in
                    await self?.fetch()
                }
            ))
            listState = .failed(.unknown(message: error.localizedDescription))
        }
    }

    /// 배경 갱신 — `.loading` 전환 없이 fetch 후 상태 교체
    ///
    /// 실패 시 기존 데이터를 유지합니다.
    @MainActor
    func refreshList() async {
        guard listState.isComplete else { return }
        do {
            let list = try await useCase.fetchAttendanceList(
                from: fromDate,
                to: toDate,
                attendanceStatus: selectedFilter
            )
            listState = .loaded(list)
        } catch {
            // 배경 갱신 실패는 무시 — 기존 데이터 유지
        }
    }

    /// 진행 중인 세션이 있을 때 15초 주기로 배경 갱신
    ///
    /// `.task` 모디파이어에서 호출하면 View 소멸 시 자동 취소됩니다.
    @MainActor
    func startPollingIfNeeded() async {
        guard listState.isComplete else { return }

        while !Task.isCancelled {
            guard hasActiveSession else { return }
            try? await Task.sleep(for: .seconds(PollingConfig.intervalSeconds))
            guard !Task.isCancelled else { break }
            await refreshList()
        }
    }

    /// 상태 필터 칩 탭
    ///
    /// 같은 필터를 다시 누르면 해제 (전체 보기). 변경 즉시 재조회.
    @MainActor
    func filterButtonTapped(_ status: AttendanceStatusV2) async {
        if selectedFilter == status {
            selectedFilter = nil
        } else {
            selectedFilter = status
        }
        await fetch()
    }

    /// "전체" 칩 선택 — 상태 필터를 해제하고 전체 목록을 다시 불러온다.
    /// 이미 전체(필터 없음)면 불필요한 재조회를 막기 위해 아무 것도 하지 않는다.
    @MainActor
    func clearFilter() async {
        guard selectedFilter != nil else { return }
        selectedFilter = nil
        await fetch()
    }

    /// 기간 프리셋 선택
    ///
    /// `.custom` 선택 시에는 `fromDate`/`toDate` 를 현재 값으로 유지하며
    /// 사용자가 DatePicker 로 직접 조정합니다.
    @MainActor
    func presetSelected(_ preset: AttendancePeriodPreset) async {
        periodPreset = preset
        if let range = preset.dateRange {
            fromDate = range.fromDate
            toDate = range.toDate
        }
        await fetch()
    }
}

// MARK: - Preview Support

#if DEBUG

/// 프리뷰 전용 운영진 출석 UseCase 스텁
///
/// 네트워크 호출 없이 ``AttendanceListViewModel/previewInfos`` 더미 데이터를 반환합니다.
/// `#if DEBUG` 가드로 릴리스 빌드에는 포함되지 않습니다.
private final class PreviewOperatorAttendanceUseCase: OperatorAttendanceUseCaseProtocol {

    func decideAttendances(
        scheduleId: Int,
        decisions: [AttendanceDecisionInput]
    ) async throws -> [AttendanceDecisionResult] { [] }

    func updateScheduleLocation(
        scheduleId: Int,
        locationName: String,
        latitude: Double,
        longitude: Double
    ) async throws {}

    func fetchAttendanceList(
        from: Date?,
        to: Date?,
        attendanceStatus: AttendanceStatusV2?
    ) async throws -> [ScheduleAttendanceInfo] {
        AttendanceListViewModel.previewInfos
    }

    func fetchAttendanceDetail(
        scheduleId: Int,
        attendanceStatus: AttendanceStatusV2?
    ) async throws -> ScheduleAttendanceInfo {
        AttendanceListViewModel.previewInfos.first { $0.scheduleId == scheduleId }
            ?? AttendanceListViewModel.previewInfos[0]
    }
}

extension AttendanceListViewModel {

    /// 더미 출석 현황이 이미 로드된 상태의 프리뷰용 ViewModel
    ///
    /// 네트워크 fetch 없이 `.loaded` 상태로 시작하므로 `View` 의 `.task` 가
    /// 재조회하지 않고 곧바로 카드 리스트를 표시합니다.
    static func preview(
        container: DIContainer,
        selected: AttendanceStatusV2? = nil
    ) -> AttendanceListViewModel {
        let viewModel = AttendanceListViewModel(
            container: container,
            errorHandler: ErrorHandler(),
            useCase: PreviewOperatorAttendanceUseCase()
        )
        viewModel.selectedFilter = selected
        viewModel.listState = .loaded(previewInfos)
        return viewModel
    }

    // MARK: - Dummy Data

    /// 운영진 출석 현황 더미 목록 (상태·장소·비대면 조합)
    ///
    /// - 정시 출석/지각/결석/사유결석/승인 대기 상태를 골고루 포함
    /// - 대면(좌표 보유) · 비대면(`isOnline`) 행을 모두 노출
    /// - 진행 중(현재 시각이 `startsAt...endsAt` 에 걸친) 일정은 없어 배경 폴링이 돌지 않음
    static let previewInfos: [ScheduleAttendanceInfo] = {
        let now = Date()

        func participant(
            _ id: Int,
            _ name: String,
            _ nickname: String,
            _ school: String,
            _ status: AttendanceStatusV2,
            verified: Bool = true,
            reason: String? = nil
        ) -> ParticipantAttendance {
            ParticipantAttendance(
                memberId: id,
                name: name,
                nickname: nickname,
                profileImageUrl: "",
                schoolId: 1,
                schoolName: school,
                attendanceStatus: status,
                isLocationVerified: verified,
                excuseReason: reason
            )
        }

        return [
            ScheduleAttendanceInfo(
                scheduleId: 101,
                name: "iOS 8주차 정기 세션",
                description: "좋은 컴포넌트 설계란 무엇일까",
                startsAt: now.addingTimeInterval(-3 * 24 * 3600),
                endsAt: now.addingTimeInterval(-3 * 24 * 3600 + 2 * 3600),
                location: ScheduleLocation(
                    latitude: 37.582967,
                    longitude: 127.010527,
                    locationName: "한성대학교 상상관 502호"
                ),
                isOnline: false,
                authorMemberId: 1,
                attendancePolicy: nil,
                tags: ["STUDY"],
                participants: [
                    participant(1, "김미주", "마티", "덕성여자대학교", .present),
                    participant(2, "이재원", "리버", "한성대학교", .present),
                    participant(3, "정의장", "제이", "가천대학교", .present),
                    participant(4, "이예지", "예지", "한성대학교", .late),
                    participant(5, "박찬호", "찬", "국민대학교", .absent, verified: false)
                ]
            ),
            ScheduleAttendanceInfo(
                scheduleId: 102,
                name: "PM DAY 통합 세션",
                description: "기획 파트 합동 발표",
                startsAt: now.addingTimeInterval(-1 * 24 * 3600),
                endsAt: now.addingTimeInterval(-1 * 24 * 3600 + 2 * 3600),
                location: ScheduleLocation(
                    latitude: 37.5445,
                    longitude: 126.9519,
                    locationName: "공덕 프론트원 11층"
                ),
                isOnline: false,
                authorMemberId: 1,
                attendancePolicy: nil,
                tags: ["LEADERSHIP"],
                participants: [
                    participant(6, "한지원", "지원", "숙명여자대학교", .present),
                    participant(7, "오세윤", "세윤", "한성대학교", .present),
                    participant(8, "유관식", "관식", "가천대학교", .presentPending),
                    participant(9, "최민호", "민호", "국민대학교", .presentPending),
                    participant(10, "강다은", "다은", "덕성여자대학교", .latePending),
                    participant(11, "임도현", "도현", "한성대학교", .absent, verified: false)
                ]
            ),
            ScheduleAttendanceInfo(
                scheduleId: 103,
                name: "디자인 시스템 워크숍",
                description: "Liquid Glass 컴포넌트 정리",
                startsAt: now.addingTimeInterval(2 * 24 * 3600),
                endsAt: now.addingTimeInterval(2 * 24 * 3600 + 2 * 3600),
                location: nil,
                isOnline: true,
                authorMemberId: 1,
                attendancePolicy: nil,
                tags: ["DESIGN"],
                participants: [
                    participant(12, "서연우", "연우", "이화여자대학교", .present),
                    participant(13, "노준영", "준영", "한성대학교", .present),
                    participant(14, "백서윤", "서윤", "가천대학교", .excused, reason: "병원 진료"),
                    participant(15, "고은채", "은채", "국민대학교", .present)
                ]
            ),
            ScheduleAttendanceInfo(
                scheduleId: 104,
                name: "연합 네트워킹 데이",
                description: "전 파트 합동 네트워킹",
                startsAt: now.addingTimeInterval(-7 * 24 * 3600),
                endsAt: now.addingTimeInterval(-7 * 24 * 3600 + 2 * 3600),
                location: ScheduleLocation(
                    latitude: 37.5445,
                    longitude: 126.9519,
                    locationName: "공덕 창업허브 대강당"
                ),
                isOnline: false,
                authorMemberId: 1,
                attendancePolicy: nil,
                tags: ["NETWORKING"],
                participants: [
                    participant(16, "윤하늘", "하늘", "한성대학교", .present),
                    participant(17, "조시우", "시우", "가천대학교", .present),
                    participant(18, "남기훈", "기훈", "국민대학교", .present),
                    participant(19, "허지안", "지안", "덕성여자대학교", .present),
                    participant(20, "문채원", "채원", "숙명여자대학교", .present),
                    participant(21, "배준서", "준서", "한성대학교", .late),
                    participant(22, "신유나", "유나", "이화여자대학교", .excusedPending, reason: "가족 행사"),
                    participant(23, "권태양", "태양", "가천대학교", .absent, verified: false)
                ]
            )
        ]
    }()
}

#endif
