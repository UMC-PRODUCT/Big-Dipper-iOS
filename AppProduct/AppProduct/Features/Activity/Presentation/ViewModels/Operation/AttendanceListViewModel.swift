//
//  AttendanceListViewModel.swift
//  AppProduct
//
//  Created by JEONG on 5/6/26.
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

    /// 기간 필터 펼침/접힘 상태
    var isFilterExpanded: Bool = false

    /// 선택된 기간 프리셋 (기본값: 최근 1개월)
    private(set) var periodPreset: AttendancePeriodPreset = .oneMonth

    /// 조회 시작 일시
    var fromDate: Date = {
        Calendar.kstGregorian.date(byAdding: .month, value: -1, to: Date())
            ?? Date().addingTimeInterval(-30 * 24 * 60 * 60)
    }()

    /// 조회 종료 일시 (기본값: 현재 +24시간, 진행 중 일정 포함)
    var toDate: Date = Date().addingTimeInterval(24 * 60 * 60)

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
