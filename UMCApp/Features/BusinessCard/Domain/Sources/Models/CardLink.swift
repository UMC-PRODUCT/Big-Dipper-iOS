//
//  CardLink.swift
//  BusinessCardDomain
//
//  Created by One on 8/16/26.
//

import Foundation

/// 명함 프로필 딥링크 — 생성과 파싱을 한 타입에 모은다.
///
/// 굽는 정본은 **Android 가 실제로 굽는 형식**에 맞춘다 (2026-08-20 팀 결정):
/// ```
/// umc://card?memberId={memberId}
/// ```
/// Android(`develop-compose`) QR 화면이 이 문자열을 굽고, 매니페스트의 `umc://card`
/// 필터와 NavHost 의 `umc://card?memberId={memberId}` 패턴이 이걸 받는다. 우리도 같은
/// 값을 구우면 **어느 쪽 폰의 카메라로 찍어도 서로의 앱이 열린다** — 커스텀 스킴은
/// AASA·assetlinks 검증이 없어서 서버 배포 없이 지금 동작한다는 것이 이 형식의 핵심이다.
/// (한때 정본이던 `https://…/mypage/card?memberId=` Universal Link 는 서버에 AASA 가
/// 없어 카메라 스캔이 사파리로 빠졌고, Android 는 그 경로를 등록조차 안 했다.)
///
/// QR 페이로드(MP-F02 뒷면·MP-F04)·수신 딥링크 해석이 전부 이 타입을 본다.
/// Community 의 `MessageLink` 와 같은 이유(생성·해석 표 일치)로 한 몸이며, CommunityDomain
/// 역의존을 피하려고 BusinessCardDomain 이 별도로 소유한다.
///
/// - Important: Android 는 memberId 를 무가드 `toLong()` 으로 받는다
///   (`MycardScreen` LaunchedEffect) — **숫자가 아닌 id 를 구우면 저쪽이 크래시한다.**
///   서버 memberId 는 숫자 문자열이라 실값으로는 안전하지만, 스텁·프리뷰 데이터도
///   숫자만 쓸 것.
/// - Note: 읽기는 굽기보다 넓다. 과거 정본이던 Universal Link 두 경로와 경로형 커스텀
///   스킴(`umc://card/{id}`)도 계속 해석한다 — 이미 구워진 QR 이미지는 회수할 수 없다.
public struct CardLink: Hashable, Sendable {

    // MARK: - Constants

    private enum Constants {
        /// 커스텀 스킴 — **굽는 정본.** Android QR 화면(`QrCodeViewModel`)이 굽는
        /// 형식과 문자 그대로 같다. 질의형(`?memberId=`)이 정본인 이유는 저쪽 NavHost
        /// 패턴이 질의형으로 등록돼 있어서다. 경로형(`umc://card/42`)은 읽기만 한다.
        static let cardScheme = "umc"
        static let cardHost = "card"
        static let memberIdQueryName = "memberId"

        /// 과거 정본이던 Universal Link 표기 — **읽기 전용.** 서버에 AASA 가 없어 굽기를
        /// 접었지만, 이 표기로 구워진 검증기 QR 이 남아 있을 수 있다.
        static let webScheme = "https"
        static let webPath = "/mypage/card"

        /// Android 가 등록한 https 경로 — **읽기 전용.** 저쪽은 스레드 딥링크 필터를
        /// 복제해 만들어 명함이 `/community/threads` 아래에 있다.
        static let androidWebPath = "/community/threads/card"

        /// 환경별 호스트. 한때 dev 를 `alpha.api…` 로 적어 두었는데 그런 DNS 는 존재한
        /// 적이 없다 — DEBUG 빌드가 굽는 QR 이 통째로 죽어 있었다.
        static let productionHost = "api.university.neordinary.com"
        static let devHost = "dev.api.university.neordinary.com"
    }

    // MARK: - Property

    public let memberId: String

    // MARK: - Init

    public init(memberId: String) {
        self.memberId = memberId
    }

    // MARK: - Computed Property

    /// QR 에 굽는 정규 문자열 — `umc://card?memberId={id}`. Android 와 같은 값이다.
    public var urlString: String {
        "\(Constants.cardScheme)://\(Constants.cardHost)"
            + "?\(Constants.memberIdQueryName)=\(memberId)"
    }

    public var url: URL? {
        URL(string: urlString)
    }

    // MARK: - Static Function

    /// 명함 딥링크 URL 을 해석한다. 명함 링크가 아니면 `nil`.
    ///
    /// 정본인 커스텀 스킴을 먼저 보고, 아니면 과거 표기(Universal Link)를 시도한다.
    public static func parse(_ url: URL) -> CardLink? {
        parseCustomScheme(url) ?? parseUniversalLink(url)
    }

    // MARK: - Private Static Function

    private static func parseUniversalLink(_ url: URL) -> CardLink? {
        guard url.scheme?.lowercased() == Constants.webScheme,
              let host = url.host?.lowercased(),
              host == Constants.productionHost || host == Constants.devHost,
              url.path == Constants.webPath || url.path == Constants.androidWebPath,
              let identifier = memberIdQuery(in: url),
              isValidIdentifier(identifier)
        else { return nil }

        return CardLink(memberId: identifier)
    }

    private static func parseCustomScheme(_ url: URL) -> CardLink? {
        guard url.scheme?.lowercased() == Constants.cardScheme,
              url.host?.lowercased() == Constants.cardHost else { return nil }

        // 경로형(`umc://card/42`)과 질의형(`umc://card?memberId=42`) 둘 다 받는다.
        let segments = url.pathComponents.filter { $0 != "/" }
        let identifier = segments.count == 1 ? segments[0] : memberIdQuery(in: url)

        guard let identifier, isValidIdentifier(identifier) else { return nil }

        return CardLink(memberId: identifier)
    }

    private static func memberIdQuery(in url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == Constants.memberIdQueryName })?
            .value
    }

    /// 영숫자·하이픈·언더스코어만 허용 (서버 memberId 표현 범위).
    private static func isValidIdentifier(_ identifier: String) -> Bool {
        !identifier.isEmpty && identifier.allSatisfy {
            $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_"
        }
    }
}
