//
//  ScheduleDetailViewModel.swift
//  AppProduct
//
//  Created by euijjang97 on 2/13/26.
//

import CoreLocation
import Foundation
import MapKit

/// 일정 상세 화면의 상태 관리 및 비즈니스 로직을 담당하는 ViewModel
///
/// 일정 상세 데이터 표시, 역지오코딩을 통한 주소 조회,
/// Apple Maps 연동, 삭제 확인 Alert 등을 처리합니다.
///
/// - SeeAlso: ``ScheduleDetailView``, ``ScheduleDetailData``
@Observable
class ScheduleDetailViewModel {
    // MARK: - Property

    /// 조회 대상 일정 ID
    var scheduleId: Int
    private(set) var data: Loadable<ScheduleDetailData> = .idle

    /// 역지오코딩으로 가져온 도로명 주소
    private(set) var roadAddress: String?
    /// 삭제 확인 Alert 데이터
    var alertPromprt: AlertPrompt?
    /// 수정 화면 표시 여부
    var isShowModify: Bool = false
    /// 일정 수정 가능 여부 (WRITE/MANAGE)
    var canEditSchedule: Bool = false
    /// 일정 삭제 가능 여부 (DELETE/MANAGE)
    var canDeleteSchedule: Bool = false
    /// 일정 삭제 진행 중 여부
    var isDeleting: Bool = false

    /// 일정이 이미 시작되었는지 여부 (상세 화면 수정 버튼 사전 차단용)
    var isScheduleStarted: Bool {
        guard case .loaded(let data) = self.data else { return false }
        return Date() >= data.startsAt
    }

    // MARK: - Init
    init(scheduleId: Int) {
        self.scheduleId = scheduleId
    }

    // MARK: - Function

    /// 위도/경도로 도로명 주소 조회
    @MainActor
    func fetchRoadAddress(latitude: Double, longitude: Double) async {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else {
            roadAddress = nil
            return
        }

        do {
            let mapItems = try await request.mapItems
            guard let first = mapItems.first else {
                roadAddress = nil
                return
            }

            roadAddress =
                first.address?.shortAddress
                ?? first.address?.fullAddress
                ?? first.addressRepresentations?.fullAddress(
                    includingRegion: false,
                    singleLine: true
                )
                ?? first.name
        } catch {
            roadAddress = nil
        }
    }

    /// Apple Maps 앱에서 해당 좌표 열기
    func mapLinkTapped(latitude: Double, longitude: Double, locationName: String?) {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let mapItem = MKMapItem(location: location, address: nil)
        mapItem.name = locationName ?? roadAddress
        mapItem.openInMaps()
    }

    /// 일정 삭제 확인 Alert을 표시합니다.
    /// - Parameter onConfirm: 삭제 확인 버튼 탭 시 실행할 액션
    func deleteAlertAction(onConfirm: @escaping () -> Void) {
        alertPromprt = .init(
            title: "일정 삭제",
            message: "일정을 삭제하겠습니까?",
            positiveBtnTitle: "삭제",
            positiveBtnAction: onConfirm,
            negativeBtnTitle: "취소",
            negativeBtnAction: {},
            isPositiveBtnDestructive: true
        )
    }

    /// 일정 리소스 권한을 조회합니다.
    @MainActor
    func fetchSchedulePermission(
        authorizationUseCase: AuthorizationUseCaseProtocol
    ) async {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--schedule-force-permission") {
            canEditSchedule = true
            canDeleteSchedule = true
            return
        }
        #endif

        do {
            let permission = try await authorizationUseCase.getResourcePermission(
                resourceType: .schedule,
                resourceId: scheduleId
            )
            canEditSchedule = permission.hasAny([.write, .manage])
            canDeleteSchedule = permission.hasAny([.delete, .manage])
        } catch {
            canEditSchedule = false
            canDeleteSchedule = false
        }
    }

    /// 일정 상세 정보를 조회합니다.
    @MainActor
    func fetchScheduleDetail(
        fetchScheduleDetailUseCase: FetchScheduleDetailUseCaseProtocol
    ) async {
        if data.isIdle {
            data = .loading
        }

        do {
            let detail = try await fetchScheduleDetailUseCase.execute(
                scheduleId: scheduleId
            )
            data = .loaded(detail)
        } catch let error as AppError {
            data = .failed(error)
        } catch {
            data = .failed(.unknown(message: error.localizedDescription))
        }
    }
}
