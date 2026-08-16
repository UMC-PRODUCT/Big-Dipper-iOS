//
//  MyCard+PeerPreview.swift
//  BusinessCardDomain
//
//  Created by One on 8/16/26.
//

import Foundation
import CoreNearbyExchange

public extension MyCard {

    /// 발견 목록 행에 그릴 최소 정보만 뽑는다.
    ///
    /// **이메일·외부 링크는 넣지 않는다.** 이 값은 상대가 명함을 받기 전에, 동의 없이
    /// 오간다. 명함 본체(``toExchangePayload(cardID:)``)와 담기는 것이 다른 이유다.
    func toPeerPreview() -> PeerPreview {
        PeerPreview(
            name: name,
            nickname: nickname,
            part: part.apiValue,
            generation: generation,
            avatarURL: avatarURL
        )
    }
}
