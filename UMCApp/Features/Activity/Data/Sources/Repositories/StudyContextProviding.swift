//
//  StudyContextProviding.swift
//  ActivityData
//
//  Created by jaewon Lee on 6/24/26.
//

import Foundation

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
/// 레거시 `AppStorageKey` 와 동일한 키(`gisuId`, `responsiblePart`)를 읽어, 향후 세션
/// 저장소가 도입되어도 같은 키를 공유하면 그대로 호환됩니다. `UserDefaults` 결합을 이
/// 작은 어댑터 한 곳에 격리해 Repository 본체는 추상화에만 의존합니다.
struct UserDefaultsStudyContextProvider: StudyContextProviding {

    // MARK: - Property

    private let defaults: UserDefaults

    /// 담당 파트 키에 매핑되는 알려진 서버 파트 문자열.
    private static let knownParts: Set<String> = [
        "PLAN", "DESIGN", "WEB", "ANDROID", "IOS", "NODEJS", "SPRINGBOOT"
    ]

    /// 담당 파트 미설정/미지원 시 사용할 기본 파트.
    private static let fallbackPart = "IOS"

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - StudyContextProviding

    /// `gisuId` 를 `String` 우선으로 읽고, 레거시 `Int` 저장값(>0)이면 문자열로 변환합니다.
    var gisuId: String? {
        if let value = defaults.string(forKey: Key.gisuId), !value.isEmpty {
            return value
        }
        let legacyInt = defaults.integer(forKey: Key.gisuId)
        return legacyInt > 0 ? String(legacyInt) : nil
    }

    /// 담당 파트를 대문자로 정규화하고, 알려지지 않은 값이면 기본 파트로 대체합니다.
    var part: String {
        let stored = defaults.string(forKey: Key.responsiblePart) ?? Self.fallbackPart
        let normalized = stored.uppercased()
        return Self.knownParts.contains(normalized) ? normalized : Self.fallbackPart
    }

    // MARK: - Storage Key

    private enum Key {
        static let gisuId = "gisuId"
        static let responsiblePart = "responsiblePart"
    }
}
