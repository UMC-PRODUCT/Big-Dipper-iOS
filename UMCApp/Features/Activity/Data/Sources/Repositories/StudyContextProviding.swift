//
//  StudyContextProviding.swift
//  ActivityData
//
//  Created by jaewon Lee on 6/24/26.
//

import Foundation
import UMCFoundation

/// 스터디 조회에 필요한 현재 사용자 컨텍스트(기수·담당 파트) 제공자.
///
/// ``StudyRepositoryProtocol`` 의 커리큘럼 조회와 챌린저 ID 해석은 파라미터로 기수·파트를
/// 받지 않으므로, Repository 가 이 추상화에서 값을 읽습니다. 운영 코드는
/// ``UserDefaultsStudyContextProvider`` 를, 테스트는 가짜 구현을 주입합니다.
///
/// - Note: ``NetworkRequesting`` 과 동일하게 비-`Sendable` 의존성으로 두고, Repository 가
///   `@unchecked Sendable` 로 감쌉니다.
protocol StudyContextProviding {

    /// 현재(우선) 기수 식별자 — 서버 응답이므로 `String`. 미설정 시 `nil`.
    var gisuId: String? { get }

    /// 현재 담당 파트의 서버 API 문자열 (예: `"IOS"`).
    var part: String { get }
}

// MARK: - UserDefaultsStudyContextProvider

/// `UserDefaults` 기반 기본 컨텍스트 제공자.
///
/// 키 상수와 식별자 해석은 ``UMCFoundation/AppStorageKey`` 의 canonical 헬퍼에 위임하고,
/// 이 타입은 스터디 조회에만 필요한 파트 정규화 정책을 얹습니다. `UserDefaults` 결합을 이
/// 작은 어댑터 한 곳에 격리해 Repository 본체는 추상화에만 의존합니다.
struct UserDefaultsStudyContextProvider: StudyContextProviding {

    // MARK: - Property

    private let defaults: UserDefaults

    /// 담당 파트 미설정/미지원 시 사용할 기본 파트.
    private static let fallbackPart: UMCPartType = .front(type: .ios)

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - StudyContextProviding

    var gisuId: String? {
        AppStorageKey.gisuIdString(in: defaults)
    }

    /// 저장된 담당 파트를 canonical ``UMCPartType`` 으로 해석하고, 스터디 조회 대상이 아닌
    /// 값이면 기본 파트로 대체합니다.
    ///
    /// - Note: 운영진(`ADMIN`)은 기술 파트가 아니라 역할이므로 스터디 파트 조회 대상에서
    ///   제외합니다. `SyncProfileStorageUseCase` 가 운영진 프로필의 `responsiblePart` 를
    ///   그대로 저장하므로 실제로 들어올 수 있는 값이며, 이때도 기본 파트로 대체합니다.
    var part: String {
        let stored = defaults.string(forKey: AppStorageKey.responsiblePart) ?? ""
        guard let part = UMCPartType(apiValue: stored.uppercased()), part != .admin else {
            return Self.fallbackPart.apiValue
        }
        return part.apiValue
    }
}
