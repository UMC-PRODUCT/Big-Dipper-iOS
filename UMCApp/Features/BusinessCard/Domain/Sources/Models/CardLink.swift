//
//  CardLink.swift
//  BusinessCardDomain
//
//  Created by One on 8/16/26.
//

import Foundation

/// 명함 프로필 딥링크 (`umc://card/{memberId}`) — 생성과 파싱을 한 타입에 모은다.
///
/// QR 페이로드(MP-F02 뒷면·MP-F04)·공유 링크 복사(MP-F03)·수신 딥링크 해석이 전부 이
/// 타입을 본다. Community의 `MessageLink`와 같은 이유(생성·해석 표 일치)로 한 몸이며,
/// CommunityDomain 역의존을 피하려고 BusinessCardDomain이 별도로 소유한다.
public struct CardLink: Hashable, Sendable {

    // MARK: - Constants

    /// 커스텀 스킴. `Info.plist` `CFBundleURLTypes`의 "umc"와 같아야 한다.
    public static let scheme = "umc"
    /// `umc://` 링크의 host 자리.
    public static let host = "card"

    // MARK: - Property

    public let memberId: String

    // MARK: - Init

    public init(memberId: String) {
        self.memberId = memberId
    }

    // MARK: - Computed Property

    /// 공유·QR용 정규 링크 문자열 (`umc://card/42`).
    public var urlString: String {
        "\(Self.scheme)://\(Self.host)/\(memberId)"
    }

    public var url: URL? {
        URL(string: urlString)
    }

    // MARK: - Static Function

    /// 명함 딥링크 URL을 해석한다. 명함 링크가 아니면 `nil`.
    public static func parse(_ url: URL) -> CardLink? {
        guard url.scheme?.lowercased() == scheme,
              url.host?.lowercased() == host else { return nil }
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
