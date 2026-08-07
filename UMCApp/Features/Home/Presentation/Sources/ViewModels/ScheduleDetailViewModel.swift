//
//  ScheduleDetailViewModel.swift
//  HomePresentation
//
//  Created by euijjang97 on 8/6/26.
//

import CoreDI
import CoreDomain
import Foundation
import HomeDomain
import MapKit
import UMCFoundation

/// 일정 상세 화면 ViewModel
///
/// 조회는 읽기 전용이다. 수정/삭제는 대상 화면과 권한 판정이 아직 이식되지 않아 다루지 않는다.
@Observable
@MainActor
final class ScheduleDetailViewModel {

    // MARK: - Property

    private(set) var data: Loadable<ScheduleDetailData> = .idle

    private let scheduleId: String
    private let fetchScheduleDetailUseCase: FetchScheduleDetailUseCaseProtocol
    private let userSession: UserSessionManager

    // MARK: - Computed Property

    /// 출석 현황 화면으로 진입할 수 있는지 여부.
    ///
    /// 출석 현황은 운영진 화면이므로 Admin 모드일 때만, 그리고 출석 정책이 붙은 일정에만 연다.
    var canViewAttendanceStatus: Bool {
        guard let schedule = data.value else { return false }
        return userSession.currentActivityMode == .admin && schedule.requiresAttendanceApproval
    }

    /// 챌린저에게 보여줄 내 출석 상태 문구. 출석 비필수 일정이면 `nil`.
    ///
    /// ``ScheduleAttendanceStatus`` 의 표시 텍스트 매핑은 Presentation 책임이라 도메인이 아닌
    /// 여기에 둔다. 정책이 있는데 서버가 상태를 내려주지 않았다면 아직 출석 전으로 간주한다.
    var myAttendanceStatusText: String? {
        guard let schedule = data.value, schedule.requiresAttendanceApproval else { return nil }
        return displayText(for: schedule.attendanceStatus ?? .beforeAttendance)
    }

    // MARK: - Init

    init(container: DIContainer, scheduleId: String) {
        self.scheduleId = scheduleId
        fetchScheduleDetailUseCase = container.resolve(FetchScheduleDetailUseCaseProtocol.self)
        userSession = container.resolve(UserSessionManager.self)
    }

    // MARK: - Function

    /// 일정 상세를 조회한다. 실패는 화면 내 인라인 상태로만 표시하고 흐름을 끊지 않는다.
    func load() async {
        if data.isLoading { return }

        let previousData = data
        data = .loading

        do {
            data = .loaded(try await fetchScheduleDetailUseCase.execute(scheduleId: scheduleId))
        } catch is CancellationError {
            data = previousData
        } catch let error as RepositoryError {
            data = .failed(.repository(error))
        } catch let error as NetworkError {
            data = .failed(.network(error))
        } catch let error as AppError {
            data = .failed(error)
        } catch {
            data = .failed(.unknown(message: error.localizedDescription))
        }
    }

    /// 일정 장소를 Apple Maps 에서 연다. 비대면 일정은 아무 것도 하지 않는다.
    func openInMaps() {
        guard let location = data.value?.location else { return }

        let mapItem = MKMapItem(
            location: CLLocation(latitude: location.latitude, longitude: location.longitude),
            address: nil
        )
        mapItem.name = location.locationName
        mapItem.openInMaps()
    }

    // MARK: - Private Function

    private func displayText(for status: ScheduleAttendanceStatus) -> String {
        switch status {
        case .beforeAttendance: "출석 전"
        case .pendingApproval: "승인 대기"
        case .present: "출석"
        case .late: "지각"
        case .absent: "결석"
        }
    }
}
