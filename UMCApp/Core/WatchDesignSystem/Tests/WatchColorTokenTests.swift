import Foundation
import Testing
@testable import CoreWatchDesignSystem

/// 시맨틱 상태색 3종(success/warning/error)은 iOS 와 값이 다르며 이는 의도된 결정이다 —
/// 워치는 항상 검정 배경이라 Apple 다크 시스템 팔레트를 쓴다. 그래서 이 테스트는 브랜드 4종 +
/// 중립 회색 1종만 잠근다.
@Suite("Watch 색 토큰 — iOS 브랜드 팔레트와의 정합")
struct WatchColorTokenTests {

    // MARK: - Test

    @Test("iOS colorset 의 universal 값과 워치 리터럴이 같다", arguments: BrandToken.all)
    func matchesIOSUniversalValue(_ token: BrandToken) {
        guard let assetHex = Self.universalHex(of: token) else { return }

        #expect(
            assetHex == token.watchHex,
            """
            브랜드 토큰 드리프트 — WatchColorHex.\(token.watchName) = \(Self.format(token.watchHex)), \
            \(token.colorsetPath).colorset universal = \(Self.format(assetHex)). \
            iOS 팔레트를 바꿨다면 워치 리터럴도 같이 갱신한다.
            """
        )
    }

    // MARK: - Function

    /// colorset 의 `appearances` 없는(universal) 엔트리 헥스를 읽는다.
    /// 파싱에 실패하면 조용히 통과하지 않도록 `Issue.record` 로 명시적 실패를 남긴다.
    private static func universalHex(of token: BrandToken) -> UInt32? {
        let url = colorsAssetRoot.appending(path: "\(token.colorsetPath).colorset/Contents.json")

        guard let data = try? Data(contentsOf: url) else {
            Issue.record("colorset 을 읽지 못했다: \(url.path)")
            return nil
        }
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let colors = root["colors"] as? [[String: Any]]
        else {
            Issue.record("colorset JSON 구조가 예상과 다르다: \(url.path)")
            return nil
        }
        guard
            let universal = colors.first(where: { $0["appearances"] == nil }),
            let color = universal["color"] as? [String: Any],
            let components = color["components"] as? [String: String]
        else {
            Issue.record("universal(appearances 없는) 엔트리를 찾지 못했다: \(url.path)")
            return nil
        }

        guard
            let red = channel(components["red"], key: "red", url: url),
            let green = channel(components["green"], key: "green", url: url),
            let blue = channel(components["blue"], key: "blue", url: url)
        else {
            return nil
        }
        return red << 16 | green << 8 | blue
    }

    /// `"0x48"` 형태의 채널 문자열을 파싱한다. 포맷이 바뀌면 명시적으로 실패시킨다.
    private static func channel(_ raw: String?, key: String, url: URL) -> UInt32? {
        guard let raw else {
            Issue.record("components.\(key) 가 없다: \(url.path)")
            return nil
        }
        guard raw.hasPrefix("0x"), let value = UInt32(raw.dropFirst(2), radix: 16) else {
            Issue.record("components.\(key) 가 0xRR 형식이 아니다(\"\(raw)\"): \(url.path)")
            return nil
        }
        return value
    }

    private static func format(_ hex: UInt32) -> String {
        String(format: "#%06X", hex)
    }

    /// `#filePath` 로 소스 트리를 역산한다 — 이 모듈은 asset 을 링크하지 않으므로
    /// 번들이 아니라 파일시스템에서 iOS 카탈로그를 직접 읽는다.
    /// `Tests/` → `WatchDesignSystem/` → `Core/`
    private static let colorsAssetRoot: URL = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "DesignSystem/Resources/Colors.xcassets")
}

// MARK: - BrandToken

/// iOS 와 값을 공유하는 토큰 한 쌍.
struct BrandToken: Sendable, CustomStringConvertible {

    let colorsetPath: String
    let watchName: String
    let watchHex: UInt32

    var description: String { watchName }

    static let all: [BrandToken] = [
        BrandToken(
            colorsetPath: "Primary/indigo500",
            watchName: "brandPrimary",
            watchHex: WatchColorHex.brandPrimary
        ),
        BrandToken(
            colorsetPath: "Primary/indigo400",
            watchName: "brandPrimaryHighlight",
            watchHex: WatchColorHex.brandPrimaryHighlight
        ),
        BrandToken(
            colorsetPath: "Primary/indigo300",
            watchName: "brandPrimarySoft",
            watchHex: WatchColorHex.brandPrimarySoft
        ),
        BrandToken(
            colorsetPath: "Accent/orange500",
            watchName: "brandAccent",
            watchHex: WatchColorHex.brandAccent
        ),
        BrandToken(
            colorsetPath: "Grey/grey400",
            watchName: "neutralGrey",
            watchHex: WatchColorHex.neutralGrey
        ),
    ]
}

// MARK: - WatchStatusSymbolTests

#if canImport(UIKit)
import UIKit

/// `WatchStatus.symbolName` 은 후속 화면들이 의존하는 public 계약이라 오타·SF Symbols 버전
/// 변경을 여기서 잡는다. watchOS 심볼 카탈로그는 iOS 와 공유되므로 iOS destination 으로 검증한다.
@Suite("Watch 상태 심볼 — SF Symbols 존재")
struct WatchStatusSymbolTests {

    @Test("상태 심볼이 전부 존재한다", arguments: WatchStatus.allCases)
    func symbolExists(_ status: WatchStatus) {
        #expect(UIImage(systemName: status.symbolName) != nil, "\(status.symbolName) 없음")
    }
}
#endif
