//
//  MessageLink.swift
//  CommunityDomain
//

import Foundation

/// 앱 안의 화면을 가리키는 내부 링크.
///
/// 메시지 본문에서 뽑아 카드로 그리고(#1142), 공유 시트가 복사해 나가는 값(#1138)이 같은
/// 타입이어야 "공유한 링크를 붙여 넣으면 카드가 뜬다" 가 성립한다. 그래서 생성(``urlString``)과
/// 해석(``parse(_:)-4l5ny``)을 한 타입에 모아 두고 양쪽 피처가 함께 쓴다.
///
/// - Note: 외부 URL 은 여기 들어오지 않는다. 카드로 그리는 대상은 내부 링크뿐이고,
///   그 밖의 URL 은 일반 텍스트 링크로 남긴다 (명세 FLOW 04).
public enum MessageLink: Hashable, Sendable {

    // MARK: - Cases

    case notice(id: String)
    case thread(id: String)

    // MARK: - Constants

    /// 커스텀 스킴. `Info.plist` 의 `CFBundleURLTypes` 에 등록된 값과 같아야 한다.
    public static let scheme = "umc"
    /// 서버가 `CommunityThread.shareURL` 로 내려주는 웹 공유 링크 호스트.
    public static let shareHost = "umc.it.kr"
    /// 웹 공유 링크의 스레드 경로 접두사 (`https://umc.it.kr/t/12`).
    public static let shareThreadPath = "t"

    // MARK: - Computed Property

    public var id: String {
        switch self {
        case .notice(let id), .thread(let id):
            return id
        }
    }

    /// `umc://` 링크의 host 자리. 케이스 이름과 1:1이라 파싱과 생성이 같은 표를 본다.
    public var kind: String {
        switch self {
        case .notice:
            return "notice"
        case .thread:
            return "thread"
        }
    }

    /// 공유·복사용 정규 링크 문자열 (`umc://thread/12`).
    ///
    /// 서버가 `shareURL` 을 주는 스레드는 그 값을 우선 쓰고, 없을 때 이 값으로 대체한다.
    public var urlString: String {
        "\(Self.scheme)://\(kind)/\(id)"
    }

    /// ``urlString`` 을 URL 로 만든 값. `id` 가 URL 에 못 들어가는 문자를 담고 있으면 `nil`.
    public var url: URL? {
        URL(string: urlString)
    }

    // MARK: - Static Function

    /// 내부 링크 URL 을 해석한다. 내부 링크가 아니면 `nil`.
    ///
    /// 두 표기를 모두 받는다.
    /// - 커스텀 스킴 `umc://thread/12` · `umc://notice/34` — 앱 밖에서 들어오는 딥링크
    /// - 웹 공유 링크 `https://umc.it.kr/t/12` — 서버 `shareURL` 표기
    public static func parse(_ url: URL) -> MessageLink? {
        let segments = url.pathComponents.filter { $0 != "/" }

        if url.scheme?.lowercased() == scheme {
            guard let id = segments.first, isValidIdentifier(id) else { return nil }
            switch url.host?.lowercased() {
            case "thread":
                return .thread(id: id)
            case "notice":
                return .notice(id: id)
            default:
                return nil
            }
        }

        // 공지 웹 공유 링크는 서버 계약이 아직 없어 스레드 경로만 해석한다.
        guard url.host?.lowercased() == shareHost,
              segments.count == 2,
              segments[0] == shareThreadPath,
              isValidIdentifier(segments[1]) else {
            return nil
        }
        return .thread(id: segments[1])
    }

    public static func parse(_ string: String) -> MessageLink? {
        guard let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        return parse(url)
    }

    /// 본문을 텍스트 조각과 내부 링크로 쪼갠다.
    ///
    /// 내부 링크가 하나도 없으면 원본 한 조각만 돌려주므로, 호출부는 결과 개수로 "카드가 붙는
    /// 메시지인지" 를 따로 판단하지 않아도 된다.
    public static func segments(in content: String) -> [MessageContentSegment] {
        guard let detector, !content.isEmpty else {
            return content.isEmpty ? [] : [.text(content)]
        }

        let full = NSRange(content.startIndex..., in: content)
        var segments: [MessageContentSegment] = []
        var cursor = content.startIndex

        for match in detector.matches(in: content, range: full) {
            guard let range = Range(match.range, in: content) else { continue }
            let raw = String(content[range])
            // 정규식이 잡았어도 해석에 실패하면 내부 링크가 아니다 — 원문 그대로 텍스트에 남긴다.
            guard let link = parse(raw) else { continue }

            if cursor < range.lowerBound {
                segments.append(.text(String(content[cursor..<range.lowerBound])))
            }
            segments.append(.link(link, raw: raw))
            cursor = range.upperBound
        }

        if cursor < content.endIndex {
            segments.append(.text(String(content[cursor...])))
        }
        return segments
    }

    // MARK: - Private

    /// 서버 식별자는 정수를 String 으로 직렬화한 값이다(핵심 규칙 #2). 숫자로 좁혀 두면 문장
    /// 부호가 링크 뒤에 붙어 있어도 식별자에 딸려 들어가지 않는다.
    private static func isValidIdentifier(_ value: String) -> Bool {
        !value.isEmpty && value.allSatisfy(\.isNumber)
    }

    /// 본문 스캐너. 패턴이 상수라 실패할 수 없지만, 실패하면 링크 없는 본문으로 취급한다.
    private static let detector = try? NSRegularExpression(
        pattern: #"umc://(?:thread|notice)/[0-9]+|https://umc\.it\.kr/t/[0-9]+"#,
        options: [.caseInsensitive]
    )
}

/// ``MessageLink/segments(in:)`` 이 돌려주는 본문 조각.
public enum MessageContentSegment: Hashable, Sendable {

    // MARK: - Cases

    case text(String)
    /// - Parameter raw: 본문에 적혀 있던 원문. 메타 조회가 실패했을 때 그대로 보여 준다.
    case link(MessageLink, raw: String)
}
