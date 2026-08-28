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
/// 카드는 라이트·다크 어느 쪽에서도 인디고라 이 흰색은 모드와 무관하다.
struct PartChip: View {

    // MARK: - Size

    /// 시안이 카드마다 칩 치수를 따로 잡아 둬서 그대로 옮긴다. 이름은 Figma 컴포넌트
    /// (`명함_l` / `명함_m`)를 그대로 따라 추적이 끊기지 않게 한다.
    enum Size {
        case cardLarge
        case cardMedium

        /// 시안 실측 높이. **바닥값**이다 — 글자가 커지면 칩이 따라 커진다.
        var minHeight: CGFloat {
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

    /// 시안 폭. 라벨이 길면 늘어나되 「PM」처럼 짧을 때 이보다 좁아지면
    /// 칩 두 개의 리듬이 깨진다. 글자 크기를 따라 함께 넓어져야 라벨이 잘리지 않는다.
    @ScaledMetric(relativeTo: .caption) private var minWidth: CGFloat = Constants.baseMinWidth

    private enum Constants {
        static let baseMinWidth: CGFloat = 39
        static let horizontalPadding: CGFloat = 8
        /// 시안은 높이 고정이라 세로 여백이 없다. 높이를 최소값으로 풀면서
        /// 큰 글자에서 캡슐이 글리프에 달라붙지 않도록 여백을 준다.
        static let verticalPadding: CGFloat = 3
        static let minimumScaleFactor: CGFloat = 0.8
    }

    // MARK: - Body

    var body: some View {
        Text(text)
            .appFont(size.font, color: Color.white)
            .lineLimit(1)
            // AX 크기에서 「Android」 같은 긴 파트명이 「Andr...」로 잘리면 뜻이 사라진다.
            // 칩은 카드 폭에 갇혀 있으니 줄이는 대신 살짝 축소해 글자를 지킨다.
            .minimumScaleFactor(Constants.minimumScaleFactor)
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.vertical, Constants.verticalPadding)
            .frame(minWidth: minWidth, minHeight: size.minHeight)
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
