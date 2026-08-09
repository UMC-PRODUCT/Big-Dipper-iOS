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
/// 조회 실패는 화면 내 `Loadable` 로, 삭제·강제 삭제 실패는 흐름을 끊는 `ErrorHandler` 로 나눠 처리한다.
/// 수정·삭제 진입점 노출 여부는 리소스 권한으로 각각 판단한다.
@Observable
@MainActor
final class ScheduleDetailViewModel {

    // MARK: - Property

    private(set) var data: Loadable<ScheduleDetailData> = .idle

    var alertPrompt: AlertPrompt?

    private(set) var canEditSchedule: Bool = false

    private(set) var canDeleteSchedule: Bool = false
    private(set) var canForceDeleteSchedule: Bool = false
    private(set) var isDeleting: Bool = false
    private(set) var isDeleted: Bool = false

    private let scheduleId: String
    private let fetchScheduleDetailUseCase: FetchScheduleDetailUseCaseProtocol
    private let deleteScheduleUseCase: DeleteScheduleUseCaseProtocol
    private let forceDeleteScheduleUseCase: ForceDeleteScheduleUseCaseProtocol
    private let authorizationUseCase: AuthorizationUseCaseProtocol
    private let userSession: UserSessionManager
    private let errorHandler: ErrorHandler

    // MARK: - Computed Property

    /// 이미 시작된 일정인지 여부. 시작된 일정은 서버가 수정을 거부한다.
    var isScheduleStarted: Bool {
        guard let schedule = data.value else { return false }
        return Date() >= schedule.startsAt
    }

    /// 수정 진입을 열어도 되는지 여부.
    ///
    /// 권한이 있어도 이미 시작된 일정은 서버가 `SCHEDULE-0028` 로 거부하므로, 편집 화면을 다 채운
    /// 뒤 저장 단계에서 튕기지 않도록 진입 자체를 막는다.
    var isEditActionEnabled: Bool {
        canEditSchedule && !isScheduleStarted
    }

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

    init(container: DIContainer, scheduleId: String, errorHandler: ErrorHandler) {
        self.scheduleId = scheduleId
        self.errorHandler = errorHandler
        fetchScheduleDetailUseCase = container.resolve(FetchScheduleDetailUseCaseProtocol.self)
        deleteScheduleUseCase = container.resolve(DeleteScheduleUseCaseProtocol.self)
        forceDeleteScheduleUseCase = container.resolve(ForceDeleteScheduleUseCaseProtocol.self)
        authorizationUseCase = container.resolve(AuthorizationUseCaseProtocol.self)
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

    /// 일정 리소스 권한을 조회한다.
    ///
    /// 조회에 실패하면 권한을 전부 닫는다. 상세 응답에는 권한 필드가 없어 대체할 근거가 없고,
    /// 열어 두면 서버가 거부할 액션을 노출하게 된다.
    func fetchSchedulePermission() async {
        do {
            let permission = try await authorizationUseCase.getResourcePermission(
                resourceType: .schedule,
                resourceId: scheduleId
            )
            canEditSchedule = permission.hasAny([.edit, .write, .manage])
            canDeleteSchedule = permission.hasAny([.delete, .manage])
            canForceDeleteSchedule = permission.hasAny([.forceDelete, .manage])
        } catch {
            canEditSchedule = false
            canDeleteSchedule = false
            canForceDeleteSchedule = false
        }
    }

    /// 삭제 확인 다이얼로그를 띄운다.
    func showDeleteConfirmation() {
        alertPrompt = AlertPrompt(
            title: "일정 삭제",
            message: "일정을 삭제하겠습니까?",
            positiveBtnTitle: "삭제",
            positiveBtnAction: { [weak self] in
                Task { @MainActor in await self?.deleteSchedule() }
            },
            negativeBtnTitle: "취소",
            negativeBtnAction: {},
            isPositiveBtnDestructive: true
        )
    }

    /// 일정을 삭제한다.
    ///
    /// 서버가 출석 기록을 이유로 거부했고 강제 삭제 권한까지 있을 때만 2차 확인으로 넘긴다.
    /// 권한이 없으면 강제 삭제를 제안해 봐야 서버가 다시 거부하므로 일반 에러 경로를 탄다.
    func deleteSchedule() async {
        guard !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }

        do {
            try await deleteScheduleUseCase.execute(scheduleId: scheduleId)
            isDeleted = true
        } catch DomainError.scheduleHasAttendanceRecords where canForceDeleteSchedule {
            showForceDeleteConfirmation()
        } catch {
            errorHandler.handle(
                error,
                context: ErrorContext(
                    feature: "Home",
                    action: "deleteSchedule",
                    retryAction: { [weak self] in await self?.deleteSchedule() }
                )
            )
        }
    }

    // MARK: - Private Function

    private func showForceDeleteConfirmation() {
        alertPrompt = AlertPrompt(
            title: "출석 기록 포함 일정 강제 삭제",
            message:
                "이 일정에는 이미 출석 기록이 있습니다.\n강제 삭제하면 출석 데이터까지 함께 삭제되며, 되돌릴 수 없습니다.",
            positiveBtnTitle: "강제 삭제",
            positiveBtnAction: { [weak self] in
                Task { @MainActor in await self?.forceDeleteSchedule() }
            },
            negativeBtnTitle: "취소",
            negativeBtnAction: {},
            isPositiveBtnDestructive: true
        )
    }

    private func forceDeleteSchedule() async {
        guard !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }

        do {
            try await forceDeleteScheduleUseCase.execute(scheduleId: scheduleId)
            isDeleted = true
        } catch {
            errorHandler.handle(
                error,
                context: ErrorContext(
                    feature: "Home",
                    action: "forceDeleteSchedule",
                    retryAction: { [weak self] in await self?.forceDeleteSchedule() }
                )
            )
        }
    }

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
