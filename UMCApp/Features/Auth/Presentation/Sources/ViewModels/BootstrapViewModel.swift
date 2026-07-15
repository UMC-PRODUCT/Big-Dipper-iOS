//
//  BootstrapViewModel.swift
//  AuthPresentation
//
//  Created by euijjang97 on 7/8/26.
//

import AuthDomain
import CoreDI
import Foundation

/// 부트스트랩 화면 ViewModel.
///
/// 절대규칙 #1에 따라 `@Observable`을 사용한다.
@Observable
final class BootstrapViewModel {

    // MARK: - Property

    private let checkAuthStatusUseCase: CheckAuthStatusUseCaseProtocol

    // MARK: - Init

    init(container: DIContainer) {
        self.checkAuthStatusUseCase = container.resolve(CheckAuthStatusUseCaseProtocol.self)
    }

    // MARK: - Function

    /// 토큰 존재 → 세션 강제 갱신 → 프로필 조회 → 승인 판정 순으로 부트스트랩 인증 상태를 확인한다.
    func resolveAuthStatus() async -> AuthBootstrapStatus {
        await checkAuthStatusUseCase.execute()
    }
}
