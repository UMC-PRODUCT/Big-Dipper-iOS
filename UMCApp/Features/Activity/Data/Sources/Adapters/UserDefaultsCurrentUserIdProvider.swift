//
//  UserDefaultsCurrentUserIdProvider.swift
//  ActivityData
//
//  Created by jaewon Lee on 7/26/26.
//

import Foundation
import ActivityDomain
import UMCFoundation

/// 로컬 세션 저장소 기반 현재 사용자 식별자 제공자.
///
/// ``ActivityDomain/CurrentUserIdProviding`` 의 운영 구현체입니다. 로그인/승인 완료 시
/// `SyncProfileStorageUseCase` 가 기록하는 ``UMCFoundation/AppStorageKey/memberId`` 를
/// 식별자의 단일 진실원천으로 읽습니다.
///
/// 저장 형식 해석(신규 `String` 우선, 레거시 `Int` 폴백)은 canonical 헬퍼
/// ``UMCFoundation/AppStorageKey/memberIdString(in:)`` 에 위임하므로, 이 어댑터는 키
/// 문자열도 폴백 규칙도 재선언하지 않습니다.
///
/// - Note: 별도 세션 타입을 만들지 않습니다. `CoreDomain.UserSessionManager` 는 역할(role)
///   만 보유해 식별자의 진실원천이 아니므로 참조하지 않습니다.
public struct UserDefaultsCurrentUserIdProvider: CurrentUserIdProviding {

    // MARK: - Property

    private let defaults: UserDefaults

    // MARK: - Init

    /// - Parameter defaults: 식별자를 읽어올 저장소. 테스트는 격리된 suite 를 주입합니다.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - CurrentUserIdProviding

    /// 저장된 멤버 ID 를 ``ActivityDomain/UserID`` 로 반환합니다.
    ///
    /// 서버 식별자는 전 레이어 `String` 으로 통일되어 있어 값 변환 없이 그대로 감쌉니다.
    ///
    /// 저장값이 없으면 로그인 세션이 성립하지 않은 상태입니다. 화면 안에서 사용자가 스스로
    /// 복구할 수 없는 실패이므로, 인라인 표시용 도메인 에러가 아니라 전역 처리(재로그인 유도)로
    /// 이어지는 ``UMCFoundation/AuthError/notLoggedIn`` 을 던집니다.
    public func fetchCurrentUserId() async throws -> UserID {
        guard let memberId = AppStorageKey.memberIdString(in: defaults) else {
            throw AuthError.notLoggedIn
        }
        return UserID(value: memberId)
    }
}
