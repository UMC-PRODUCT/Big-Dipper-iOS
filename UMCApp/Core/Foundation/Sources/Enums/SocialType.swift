//
//  SocialType.swift
//  UMCFoundation
//
//  Created by euijjang97 on 5/10/26.
//

import Foundation

/// 앱에서 지원하는 소셜 로그인 타입을 정의하는 열거형입니다.
///
/// UI 프로퍼티(image/color)는 사용처 Presentation 모듈의 extension으로 제공합니다.
public enum SocialType: String, CaseIterable, Hashable {
    /// 카카오 로그인
    case kakao = "Kakao"
    /// 애플 로그인
    case apple = "Apple"
    /// 구글 로그인
    case google = "Google"

    public static var allCases: [SocialType] {
        [.kakao, .apple, .google]
    }

    /// 앱에서 직접 로그인/연동 추가를 지원하는 소셜 목록입니다.
    public static var appConnectableCases: [SocialType] {
        [.kakao, .apple]
    }

    /// 서버 provider 문자열("KAKAO", "APPLE" 등)로 변환합니다.
    public init?(provider: String) {
        switch provider.uppercased() {
        case "KAKAO":
            self = .kakao
        case "APPLE":
            self = .apple
        case "GOOGLE":
            self = .google
        default:
            return nil
        }
    }
}

// MARK: - Connected Providers Persistence

public extension SocialType {
    /// UserDefaults에 저장된 연동 소셜 목록을 불러옵니다.
    static func loadConnected(from defaults: UserDefaults = .standard) -> [SocialType] {
        guard let rawValues = defaults.array(
            forKey: AppStorageKey.connectedSocialProviders
        ) as? [String] else {
            return []
        }

        let set = Set(rawValues.compactMap(SocialType.init(rawValue:)))
        return SocialType.allCases.filter { set.contains($0) }
    }

    /// UserDefaults에 연동 소셜 목록을 저장합니다.
    static func saveConnected(_ types: [SocialType], to defaults: UserDefaults = .standard) {
        let rawValues = Array(Set(types.map(\.rawValue))).sorted()
        defaults.set(rawValues, forKey: AppStorageKey.connectedSocialProviders)
    }

    /// 특정 소셜 연동 상태를 UserDefaults에 추가 저장합니다.
    static func addConnected(_ type: SocialType, to defaults: UserDefaults = .standard) {
        var current = Set(loadConnected(from: defaults))
        current.insert(type)
        saveConnected(Array(current), to: defaults)
    }
}
