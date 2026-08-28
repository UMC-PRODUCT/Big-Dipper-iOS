//
//  AppDeepLink.swift
//  UMCApp
//

import Foundation

import BusinessCardDomain
import CommunityDomain

/// 앱이 밖에서 받아 여는 링크 한 종류.
///
/// 표기 규칙은 각 Feature 의 Domain 이 소유한다(``MessageLink``·``CardLink``) — App 은
/// 어느 파서에게 먼저 물어볼지만 정하고 링크 문법은 모른다.
enum AppDeepLink: Hashable {

    /// 커뮤니티 스레드·공지 링크.
    case message(MessageLink)

    /// 명함 QR·공유 링크. 그 사람의 명함을 명함첩에 저장한다.
    ///
    /// `memberId` 만 뽑지 않고 링크를 통째로 나른다 — 만료·서명(#1226)이 수신 측에
    /// 닿아야 검증할 수 있다.
    case card(CardLink)

    /// 내부 링크면 해석해 돌려준다. 아니면 `nil` — 소셜 로그인 콜백이 그 경로다.
    ///
    /// 두 파서가 무는 표기는 겹치지 않는다 (`umc://thread|notice`·`https://umc.it.kr/t/…`
    /// 대 `umc://card/…`·`https://{api host}/mypage/card?memberId=…`). 그래도 순서를
    /// 고정해 두는 편이 안전해 기존 동작인 메시지 링크를 먼저 본다.
    static func parse(_ url: URL) -> AppDeepLink? {
        if let message = MessageLink.parse(url) {
            return .message(message)
        }
        if let card = CardLink.parse(url) {
            return .card(card)
        }
        return nil
    }
}
