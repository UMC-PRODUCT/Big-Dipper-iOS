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

    // MARK: - Action

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
}
