//
//  CommunityThreadCreateRuleTests.swift
//  CommunityDomainTests
//

import Foundation
import Testing
@testable import CommunityDomain

// MARK: - Tests

/// 아이콘 칸은 순정 이모지 키보드에 맡기므로(#1132) 무엇이 들어오는지는 OS 판이 바뀌면
/// 같이 바뀐다. 키보드가 어떻게 변하든 서버로 나가는 값은 이 규칙이 고정한다.
@Suite("스레드 아이콘 정규화")
struct CommunityThreadCreateRuleTests {

    // MARK: - 거르는 입력

    @Test("빈 문자열은 그대로 빈 값이다")
    func rejectsEmpty() {
        #expect(CommunityThreadCreateRule.normalizedIcon("") == "")
    }

    /// Genmoji·Memoji 같은 adaptive image glyph 는 `String` 필드로 떨어질 때
    /// U+FFFC(OBJECT REPLACEMENT CHARACTER)로 남는다. 이모지가 아니므로 버린다.
    @Test("OBJECT REPLACEMENT CHARACTER 는 버린다")
    func rejectsObjectReplacementCharacter() {
        #expect(CommunityThreadCreateRule.normalizedIcon("\u{FFFC}") == "")
    }

    @Test("일반 텍스트는 버린다")
    func rejectsPlainText() {
        #expect(CommunityThreadCreateRule.normalizedIcon("abc") == "")
    }

    /// 숫자·`#`·`*` 는 키캡 base 라 `isEmoji` 가 `true` 다. 변이 선택자 없이 단독으로
    /// 오면 이모지가 아니라 문자이므로 걸러야 한다.
    @Test("키캡 base 문자는 단독으로 오면 버린다", arguments: ["1", "#", "*"])
    func rejectsKeycapBase(_ icon: String) {
        #expect(CommunityThreadCreateRule.normalizedIcon(icon) == "")
    }

    // MARK: - 통과하는 입력

    @Test("기본 이모지 표현은 통과한다")
    func acceptsEmojiPresentation() {
        #expect(CommunityThreadCreateRule.normalizedIcon("🔥") == "🔥")
    }

    /// ZWJ 로 이어진 가족 이모지는 `Character` 하나라 잘리지 않는다.
    @Test("ZWJ 조합 이모지는 통째로 통과한다")
    func acceptsZWJSequence() {
        #expect(CommunityThreadCreateRule.normalizedIcon("👨‍👩‍👧") == "👨‍👩‍👧")
    }

    /// ❤ 는 기본이 텍스트 표현이라 U+FE0F 가 붙어야 이모지로 인정된다.
    @Test("변이 선택자로 이모지 표현을 명시하면 통과한다")
    func acceptsVariationSelector() {
        #expect(CommunityThreadCreateRule.normalizedIcon("❤️") == "❤️")
    }

    // MARK: - 마지막 글자 교체

    @Test("여러 글자가 들어오면 마지막 글자만 남는다")
    func keepsLastCharacter() {
        #expect(CommunityThreadCreateRule.normalizedIcon("ab🔥") == "🔥")
    }

    @Test("마지막 글자가 이모지가 아니면 앞에 이모지가 있어도 버린다")
    func dropsWhenLastCharacterIsNotEmoji() {
        #expect(CommunityThreadCreateRule.normalizedIcon("🔥a") == "")
    }
}
