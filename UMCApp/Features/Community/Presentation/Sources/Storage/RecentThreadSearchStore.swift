//
//  RecentThreadSearchStore.swift
//  CommunityPresentation
//

import Foundation
import CommunityDomain
import UMCFoundation

/// 스레드 최근 검색어 로컬 저장소.
///
/// 기기 단위 정보라 `AppStorageKey.sessionScopedKeys` 에 넣지 않는다 — 로그아웃해도 남는다.
/// 변경 함수는 저장 후의 목록을 돌려주므로 호출부는 반환값을 그대로 화면 상태에 대입하면 된다.
public struct RecentThreadSearchStore {

    // MARK: - Property

    /// 보관 상한. 넘으면 오래된 것부터 버린다.
    public static let maxCount = 10

    private let defaults: UserDefaults

    // MARK: - Init

    /// - Parameter defaults: 테스트에서 격리 suite 를 주입한다.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Function

    public func load() -> [String] {
        defaults.stringArray(forKey: AppStorageKey.recentThreadSearches) ?? []
    }

    /// 맨 앞에 넣는다. 대소문자만 다른 기존 항목은 새 표기로 대체한다 — 서버 검색이 대소문자를
    /// 가리지 않아 `UMC`/`umc` 가 나란히 남으면 같은 검색이 두 줄로 보인다.
    ///
    /// 저장 전에 검색어 상한(80 code point)으로 자르는 이유는 실제로 조회된 값과 목록을
    /// 일치시키기 위해서다 — `CommunityThreadListUseCase` 가 전송 직전 같은 길이로 자른다.
    public func add(_ term: String) -> [String] {
        let normalized = CommunityThreadCreateRule.clamped(
            term.trimmingCharacters(in: .whitespacesAndNewlines),
            max: CommunityThreadListUseCase.queryMaxLength
        )
        guard !normalized.isEmpty else { return load() }

        var terms = load().filter { $0.caseInsensitiveCompare(normalized) != .orderedSame }
        terms.insert(normalized, at: 0)
        return save(Array(terms.prefix(Self.maxCount)))
    }

    public func remove(_ term: String) -> [String] {
        save(load().filter { $0 != term })
    }

    public func clear() -> [String] {
        save([])
    }

    // MARK: - Private Function

    private func save(_ terms: [String]) -> [String] {
        defaults.set(terms, forKey: AppStorageKey.recentThreadSearches)
        return terms
    }
}
