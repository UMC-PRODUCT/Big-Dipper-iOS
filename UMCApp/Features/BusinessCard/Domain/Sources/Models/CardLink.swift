//
//  CardLink.swift
//  BusinessCardDomain
//
//  Created by One on 8/16/26.
//

import Foundation

/// 명함 프로필 딥링크 — 생성과 파싱을 한 타입에 모은다.
///
/// 정본 형식은 **Universal Link** 다:
/// ```
/// https://api.university.neordinary.com/mypage/card?memberId={memberId}
/// ```
/// 서버·Android 와 **합의한** 크로스 플랫폼 계약이라 iOS 가 임의로 바꾸지 않는다. 다만
/// 합의일 뿐 아직 아무도 구현하지 않았다 (2026-08-19 확인) — Android 매니페스트에는 명함
/// intent-filter 자체가 없고(`autoVerify` 0건, Firebase·런처·카카오 OAuth 뿐), 서버에도
/// `assetlinks.json`·`apple-app-site-association` 이 없다. 「Android 는 이미 받는다」고
/// 적어 두었던 이전 주석은 계획을 현재형으로 쓴 것이었다.
///
/// QR 페이로드(MP-F02 뒷면·MP-F04)·공유 링크(MP-F03)·수신 딥링크 해석이 전부 이 타입을 본다.
/// Community 의 `MessageLink` 와 같은 이유(생성·해석 표 일치)로 한 몸이며, CommunityDomain
/// 역의존을 피하려고 BusinessCardDomain 이 별도로 소유한다.
///
/// - Note: **이 타입의 파싱 자체는 AASA 와 무관하다.** 앱이 이미 손에 쥔 문자열을 해석할
///   뿐이라, 인앱 스캐너가 카메라로 읽어 넘겨 주면 서버 없이도 동작한다. AASA 가 필요한 건
///   **밖에서 링크를 눌러 앱이 열리는 경로**다 — 카메라 앱 스캔·사파리·메신저. 시안에는
///   인앱 스캐너 화면이 없어(「스캔」 문구는 QR 화면 캡션 한 곳뿐) 시안대로라면 그 경로가
///   유일하고, 그래서 서버의 AASA 배포가 전제가 된다.
///   Android 도 12 부터는 검증되지 않은 https intent-filter 를 앱에 넘기지 않으므로
///   `assetlinks.json` 이 똑같이 필요하다 — iOS 만의 제약이 아니다.
public struct CardLink: Hashable, Sendable {

    // MARK: - Constants

    private enum Constants {
        static let scheme = "https"
        static let path = "/mypage/card"
        static let memberIdQueryName = "memberId"

        /// 백엔드가 2026-08-17 확정한 환경별 호스트. 한때 dev 를 `alpha.api…` 로 적어
        /// 두었는데 그런 DNS 는 존재한 적이 없다 — DEBUG 빌드가 굽는 QR 이 통째로
        /// 죽어 있었다.
        static let productionHost = "api.university.neordinary.com"
        static let devHost = "dev.api.university.neordinary.com"

        /// 커스텀 스킴 형식(`umc://card/{memberId}`). 굽지는 않고 **읽기만** 한다 —
        /// Android 가 이 형식으로 먼저 검증했고, 예전 QR 이 돌아다닐 수 있다.
        static let legacyScheme = "umc"
        static let legacyHost = "card"
    }

    // MARK: - Property

    public let memberId: String

    // MARK: - Static Property

    /// 링크를 **만들 때** 쓰는 호스트. 서버가 환경별로 호스트를 나눠 운영한다.
    ///
    /// 읽을 때는 ``parse(_:)`` 가 두 호스트를 모두 받는다 — dev 빌드로 만든 QR 을
    /// 운영 빌드로 스캔하는 상황이 검증 중에 흔하다.
    public static var host: String {
        #if DEBUG
        Constants.devHost
        #else
        Constants.productionHost
        #endif
    }

    // MARK: - Init

    public init(memberId: String) {
        self.memberId = memberId
    }

    // MARK: - Computed Property

    /// 공유·QR 용 정규 링크 문자열.
    public var urlString: String {
        "\(Constants.scheme)://\(Self.host)\(Constants.path)"
            + "?\(Constants.memberIdQueryName)=\(memberId)"
    }

    public var url: URL? {
        URL(string: urlString)
    }

    // MARK: - Static Function

    /// 명함 딥링크 URL 을 해석한다. 명함 링크가 아니면 `nil`.
    ///
    /// Universal Link 를 먼저 보고, 아니면 커스텀 스킴을 시도한다.
    public static func parse(_ url: URL) -> CardLink? {
        parseUniversalLink(url) ?? parseCustomScheme(url)
    }

    // MARK: - Private Static Function

    private static func parseUniversalLink(_ url: URL) -> CardLink? {
        guard url.scheme?.lowercased() == Constants.scheme,
              let host = url.host?.lowercased(),
              host == Constants.productionHost || host == Constants.devHost,
              url.path == Constants.path,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let identifier = components.queryItems?
                  .first(where: { $0.name == Constants.memberIdQueryName })?.value,
              isValidIdentifier(identifier)
        else { return nil }

        return CardLink(memberId: identifier)
    }

    private static func parseCustomScheme(_ url: URL) -> CardLink? {
        guard url.scheme?.lowercased() == Constants.legacyScheme,
              url.host?.lowercased() == Constants.legacyHost else { return nil }

        let segments = url.pathComponents.filter { $0 != "/" }
        guard let identifier = segments.first, segments.count == 1,
              isValidIdentifier(identifier) else { return nil }

        return CardLink(memberId: identifier)
    }

    /// 영숫자·하이픈·언더스코어만 허용 (서버 memberId 표현 범위).
    private static func isValidIdentifier(_ identifier: String) -> Bool {
        !identifier.isEmpty && identifier.allSatisfy {
            $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_"
        }
    }
}
