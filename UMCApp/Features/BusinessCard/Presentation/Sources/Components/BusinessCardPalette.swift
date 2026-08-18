//
//  BusinessCardPalette.swift
//  BusinessCardPresentation
//
//  Created by One on 8/18/26.
//

import SwiftUI

/// 명함 화면들이 공유하는 색.
///
/// 여기 있는 값은 **디자인 시스템 토큰으로 대체할 수 없어서** 남는 것들이다.
/// 토큰으로 해결되는 색(회색 스케일 등)은 여기 두지 말고 `Color.greyXXX` 를 쓴다.
enum BusinessCardPalette {

    /// 시안 `Main Color/Indigo500` = #5468FC.
    ///
    /// 코어 토큰 `Color.indigo500` 은 **#4869F0 으로 다르다.** 명함 카드 그라디언트 끝값이
    /// 이 색이라, 같은 화면의 버튼·강조 텍스트가 토큰을 쓰면 나란히 놓인 요소가 서로 다른
    /// 파랑이 된다. 토큰 쪽을 정정하는 게 맞지만 그건 디자인 시스템 소유자 결정이라
    /// 명함 안에서만 이 값을 쓴다.
    static let indigo = Color(red: 84 / 255, green: 104 / 255, blue: 252 / 255)

    /// 명함 카드 그라디언트 시작색 rgb(114,142,253). 알파는 카드마다 달라 호출부가 얹는다
    /// (명함_l 0.8 / 명함_m 0.9).
    static let cardGradientStart = Color(red: 114 / 255, green: 142 / 255, blue: 253 / 255)

    /// 시안 QR 박스 테두리 #E5E8ED.
    static let hairline = Color(red: 229 / 255, green: 232 / 255, blue: 237 / 255)
}
