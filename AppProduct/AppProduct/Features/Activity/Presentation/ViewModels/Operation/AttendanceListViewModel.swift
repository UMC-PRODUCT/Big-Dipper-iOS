//
//  AttendanceListViewModel.swift
//  AppProduct
//
//  Created by euijjang97 on 5/6/26.
//

import Foundation

/// 운영진 출석 현황 목록 화면 ViewModel (Schedule V2)
///
/// `GET /api/v2/schedules/attendance` 호출 결과를 상태별로 필터링해 표시합니다.
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

    /// 현재 선택된 필터 (`nil` = 전체)
    private(set) var selectedFilter: AttendanceStatusV2?

    /// 필터 칩에 표시할 후보 (필터 가능 케이스 = `unknown` 제외)
    let filterableStatuses: [AttendanceStatusV2] = AttendanceStatusV2.filterableCases

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
    /// `from`/`to` 미지정 → 서버 기본값(요청 시점 -1개월 ~ +24시간) 적용.
    @MainActor
    func fetch() async {
        listState = .loading
        do {
            let list = try await useCase.fetchAttendanceList(
                from: nil,
                to: nil,
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

    /// 필터 칩 탭
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
}
