//
//  AuthConfig.swift
//  UMCFoundation
//
//  Created by euijjang97 on 3/6/26.
//

import Foundation

public extension Config {
    /// 인증 공급자 연동에 필요한 설정 모음입니다.
    ///
    /// 서드파티 인증 설정을 feature 코드에서 분리하고,
    /// 빌드 설정을 통해 주입된 값을 한 곳에서 일관되게 참조할 수 있도록 합니다.
    enum Auth {
        // MARK: - Property

        /// Kakao SDK 연동에 사용하는 네이티브 앱 키입니다.
        ///
        /// - Important: 값은 일반적으로 `Secrets.xcconfig`를 통해 주입되며,
        ///   `Info.plist`의 `KAKAO_KEY` 항목에서 읽을 수 있어야 합니다.
        public static var kakaoKey: String {
            Config.stringValue(for: "KAKAO_KEY")
        }

        /// Kakao 앱 간 인증에 사용하는 URL Scheme입니다.
        ///
        /// `CFBundleURLSchemes`에 등록되는 형식과 동일한 규칙으로 조합해,
        /// 인증 흐름이 같은 값을 한 소스에서 재사용할 수 있게 합니다.
        public static var kakaoURLScheme: String {
            "kakao\(kakaoKey)"
        }

        /// GoogleSignIn 연동에 사용하는 OAuth 클라이언트 ID입니다.
        ///
        /// - Important: 값은 일반적으로 `Secrets.xcconfig`를 통해 주입되며,
        ///   `Info.plist`의 `GOOGLE_CLIENT_ID` 항목에서 읽을 수 있어야 합니다.
        public static var googleClientId: String {
            Config.stringValue(for: "GOOGLE_CLIENT_ID")
        }

        /// GoogleSignIn 리다이렉트 URL Scheme(reversed client ID)입니다.
        ///
        /// `CFBundleURLSchemes`에 등록되는 값과 동일한 규칙으로 조합해,
        /// 인증 흐름이 같은 값을 한 소스에서 재사용할 수 있게 합니다.
        public static var googleReversedClientId: String {
            Config.stringValue(for: "GOOGLE_REVERSED_CLIENT_ID")
        }
    }
}
