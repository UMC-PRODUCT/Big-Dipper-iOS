//
//  PartChip.swift
//  BusinessCardPresentation
//
//  Created by One on 8/17/26.
//

import CoreDesignSystem
import SwiftUI

/// 명함 카드 위의 파트·기수 칩.
///
/// radius 24 · Liquid Glass Clear/Light · 흰 라벨. 명함_l 과 명함_m 이 같은 칩을
/// 높이 1pt·글자 1pt 차이로 쓴다 (`Figma I12639:33234;12639:33210` / `12639:33288`).
///
/// 라벨이 흰색 고정인 이유는 카드가 인디고 그라디언트라서다. `UMCPartType.color` 는
/// 시스템 컬러를 돌려주는데 이 톤 위에서는 읽히지 않아 쓰지 않는다.
struct PartChip: View {

    // MARK: - Size

    /// 시안이 카드마다 칩 치수를 따로 잡아 둬서 그대로 옮긴다. 이름은 Figma 컴포넌트
    /// (`명함_l` / `명함_m`)를 그대로 따라 추적이 끊기지 않게 한다.
    enum Size {
        case cardLarge
        case cardMedium

        var height: CGFloat {
            switch self {
            case .cardLarge:  return 23
            case .cardMedium: return 24
            }
        }

        var font: AppFont {
            switch self {
            case .cardLarge:  return .caption1
            case .cardMedium: return .footnote
            }
        }
    }

    // MARK: - Property

    let text: String
    var size: Size = .cardLarge

    private enum Constants {
        /// 시안 폭. 라벨이 길면 늘어나되 「PM」처럼 짧을 때 이보다 좁아지면
        /// 칩 두 개의 리듬이 깨진다.
        static let minWidth: CGFloat = 39
        static let horizontalPadding: CGFloat = 8
    }

    // MARK: - Body

    var body: some View {
        Text(text)
            .appFont(size.font, color: Color.white)
            .lineLimit(1)
            .padding(.horizontal, Constants.horizontalPadding)
            .frame(minWidth: Constants.minWidth)
            .frame(height: size.height)
            .glassEffect(.clear, in: Capsule())
    }
}

#if DEBUG
#Preview {
    HStack(spacing: 5) {
        PartChip(text: "iOS")
        PartChip(text: "12기")
        PartChip(text: "PM")
    }
    .padding()
    .background(Color.indigo500)
}
#endif
