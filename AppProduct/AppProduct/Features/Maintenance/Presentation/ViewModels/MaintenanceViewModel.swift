//
//  MaintenanceViewModel.swift
//  AppProduct
//
//  원격 점검 상태를 보유하고, 앱 진입/포그라운드 시 갱신하는 ViewModel.
//

import Foundation

/// 원격 점검(킬스위치) 상태를 관리하는 ViewModel.
///
/// 앱 루트에서 소유하며, `maintenanceInfo` 가 채워지면 전체화면 점검 안내로
/// 진입을 차단합니다. 서버가 점검을 해제하면 재확인 시 자동으로 차단이 풀립니다.
@MainActor
@Observable
final class MaintenanceViewModel {

    // MARK: - Property

    /// 현재 점검 정보. `nil` 이면 정상(차단 안 함).
    private(set) var maintenanceInfo: MaintenanceInfo?

    /// 점검으로 진입을 차단해야 하는지 여부.
    var isUnderMaintenance: Bool {
        maintenanceInfo?.isActive == true
    }

    private let checkMaintenanceUseCase: CheckMaintenanceUseCaseProtocol

    /// 중복 호출 가드 (앱 시작 `.task` 와 포그라운드 복귀가 겹칠 때).
    private var isChecking = false

    // MARK: - Init

    init(checkMaintenanceUseCase: CheckMaintenanceUseCaseProtocol) {
        self.checkMaintenanceUseCase = checkMaintenanceUseCase
    }

    // MARK: - Function

    /// 원격 점검 상태를 확인하고 차단 여부를 갱신합니다.
    ///
    /// 점검 중이 아니거나 확인에 실패하면 `maintenanceInfo` 를 `nil` 로 두어
    /// 진입을 허용합니다(fail-open).
    func check() async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        maintenanceInfo = await checkMaintenanceUseCase.execute()
    }
}
