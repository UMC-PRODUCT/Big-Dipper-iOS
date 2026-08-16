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
/// 서버·Android 와 합의한 크로스 플랫폼 계약이라 iOS 가 임의로 바꾸지 않는다. Android 는
/// 같은 URL 을 `autoVerify` intent-filter 로 받고, 두 앱이 **같은 QR** 을 읽는다.
///
/// QR 페이로드(MP-F02 뒷면·MP-F04)·공유 링크(MP-F03)·수신 딥링크 해석이 전부 이 타입을 본다.
/// Community 의 `MessageLink` 와 같은 이유(생성·해석 표 일치)로 한 몸이며, CommunityDomain
/// 역의존을 피하려고 BusinessCardDomain 이 별도로 소유한다.
///
/// - Note: **QR 스캔은 Universal Link 등록(AASA)과 무관하게 동작한다.** 앱이 카메라로 읽은
///   문자열을 여기서 직접 파싱하기 때문이다. AASA 는 사파리·메신저에서 링크를 눌렀을 때
///   앱이 열리게 하는 용도라 「명함 공유하기」에만 필요하다.
public struct CardLink: Hashable, Sendable {

    // MARK: - Constants

    private enum Constants {
        static let scheme = "https"
        static let path = "/mypage/card"
        static let memberIdQueryName = "memberId"

        static let productionHost = "api.university.neordinary.com"
        static let alphaHost = "alpha.api.university.neordinary.com"

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
    /// 읽을 때는 ``parse(_:)`` 가 두 호스트를 모두 받는다 — alpha 빌드로 만든 QR 을
    /// 운영 빌드로 스캔하는 상황이 검증 중에 흔하다.
    public static var host: String {
        #if DEBUG
        Constants.alphaHost
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
              host == Constants.productionHost || host == Constants.alphaHost,
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
