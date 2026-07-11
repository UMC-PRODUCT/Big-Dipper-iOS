//
//  MemberContextProviding.swift
//  ActivityData
//
//  Created by jaewon Lee on 6/28/26.
//

import Foundation

/// 멤버 관리 조회에 필요한 현재 사용자 컨텍스트 제공자.
///
/// ``MemberRepositoryProtocol`` 의 멤버 목록 조회는 학교 단위 오프셋 검색을 사용하므로
/// `schoolId` 가 필요하고, 상벌점 히스토리 열람 권한 판별·기수 우선순위 해석을 위해
/// `currentMemberId`·`gisuId` 가 필요합니다. Repository 는 이 추상화에서 값을 읽습니다.
///
/// - Note: ``StudyContextProviding`` 과 같은 이유로 비-`Sendable` 의존성으로 두고,
///   Repository 가 `@unchecked Sendable` 로 감쌉니다. 운영 코드는
///   ``UserDefaultsMemberContextProvider`` 를, 테스트는 가짜 구현을 주입합니다.
protocol MemberContextProviding {

    /// 현재 학교 식별자 — 서버 응답이므로 `String`. 미설정 시 `nil`.
    var schoolId: String? { get }

    /// 현재 로그인 멤버 식별자 — 서버 응답이므로 `String`. 미설정 시 `nil`.
    var currentMemberId: String? { get }

    /// 현재(우선) 기수 식별자 — 서버 응답이므로 `String`. 미설정 시 `nil`.
    var gisuId: String? { get }
}

// MARK: - UserDefaultsMemberContextProvider

/// `UserDefaults` 기반 기본 컨텍스트 제공자.
///
/// 레거시 `AppStorageKey` 와 동일한 키(`schoolId`, `memberId`, `gisuId`)를 읽어, 향후
/// 세션 저장소가 도입되어도 같은 키를 공유하면 호환됩니다. 식별자는 `String` 우선으로 읽고,
/// 레거시 `Int` 저장값(>0)이면 문자열로 변환합니다.
struct UserDefaultsMemberContextProvider: MemberContextProviding {

    // MARK: - Property

    private let defaults: UserDefaults

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - MemberContextProviding

    var schoolId: String? {
        resolvedIdentifier(forKey: Key.schoolId)
    }

    var currentMemberId: String? {
        resolvedIdentifier(forKey: Key.memberId)
    }

    var gisuId: String? {
        resolvedIdentifier(forKey: Key.gisuId)
    }

    // MARK: - Function

    /// `String` 우선, 레거시 `Int` 저장값(>0) 폴백으로 식별자를 읽습니다.
    private func resolvedIdentifier(forKey key: String) -> String? {
        if let value = defaults.string(forKey: key), !value.isEmpty {
            return value
        }
        let legacyInt = defaults.integer(forKey: key)
        return legacyInt > 0 ? String(legacyInt) : nil
    }

    // MARK: - Storage Key

    private enum Key {
        static let schoolId = "schoolId"
        static let memberId = "memberId"
        static let gisuId = "gisuId"
    }
}
