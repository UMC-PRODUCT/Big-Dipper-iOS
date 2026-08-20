//
//  DebugMyPageRow.swift
//  UMCApp
//
//  Created by One on 8/16/26.
//

#if DEBUG
import SwiftUI

/// 시안 실측값 — 마이페이지 v3 루트(12630:33563) · 행(12640:36707).
///
/// 세 타입(행 · 섹션 카드 · 구분선)이 같이 쓰므로 파일 수준에 둔다. 구분선 들여쓰기가
/// 아이콘 타일 크기에서 파생되는 것처럼, 값 하나가 어긋나면 나머지가 따라 어긋난다.
fileprivate enum Metrics {
    // 행
    static let rowHeight: CGFloat = 54
    static let rowSpacing: CGFloat = 16
    static let valueSpacing: CGFloat = 8
    static let iconTileSize: CGFloat = 32
    static let iconTileRadius: CGFloat = 8
    /// 구분선은 아이콘 타일 오른쪽부터 시작한다 (타일 32 + gap 16 = 48, 실측 폭 290).
    static let dividerInset: CGFloat = iconTileSize + rowSpacing

    // 섹션
    static let sectionHeaderSpacing: CGFloat = 16
    static let cardRadius: CGFloat = 27
    static let cardHorizontalPadding: CGFloat = 16
    static let cardVerticalPadding: CGFloat = 4
}

/// 시안 `item/MypageList`(340×54)에 대응하는 행. 아이콘 · 제목 · 우측 값 · chevron.
///
/// 검증 화면용이라 색·타이포는 시안 토큰이 아니라 시스템 값을 쓴다 — 맞추는 것은 **배치**다.
struct DebugMyPageRow<Destination: View>: View {

    // MARK: - Property

    let icon: String
    let iconTint: Color
    let title: String
    /// 우측 회색 값 (예: "12장", "3건"). 없으면 chevron만 보인다.
    var trailingValue: String?

    @ViewBuilder let destination: () -> Destination

    // MARK: - Body

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            // 시안 실측: HStack gap 16, 행 높이 54. 좌우 여백은 카드가 갖는다
            // (`DebugSectionCard` padding 16) — 행이 또 가지면 340이 아니라 308이 된다.
            HStack(spacing: Metrics.rowSpacing) {
                RoundedRectangle(cornerRadius: Metrics.iconTileRadius)
                    .fill(iconTint)
                    .frame(width: Metrics.iconTileSize, height: Metrics.iconTileSize)
                    .overlay {
                        Image(systemName: icon)
                            .foregroundStyle(.white)
                            .font(.system(size: 17))
                    }

                Text(title)
                    .foregroundStyle(.primary)

                Spacer(minLength: Metrics.valueSpacing)

                // 값과 chevron 사이 gap 8 — 시안에서 둘은 한 묶음이다.
                HStack(spacing: Metrics.valueSpacing) {
                    if let trailingValue {
                        Text(trailingValue)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 17))
                }
                .foregroundStyle(.secondary)
            }
            .frame(height: Metrics.rowHeight)
        }
        .buttonStyle(.plain)
    }
}

/// 시안의 「명함 관리」·「나의 활동」 묶음 — 제목 + 흰 카드 안에 행들.
struct DebugSectionCard<Content: View>: View {

    // MARK: - Property

    let title: String
    @ViewBuilder let content: () -> Content

    // MARK: - Body

    var body: some View {
        // 시안: 헤더와 카드 사이 16. 헤더는 카드와 같은 폭을 쓴다(들여쓰지 않는다).
        VStack(alignment: .leading, spacing: Metrics.sectionHeaderSpacing) {
            Text(title)
                .font(.headline)

            VStack(spacing: 0) {
                content()
            }
            // 좌우 16 / 상하 4 — 행 높이 54 두 개 + 상하 4 = 카드 116.
            .padding(.horizontal, Metrics.cardHorizontalPadding)
            .padding(.vertical, Metrics.cardVerticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius))
        }
    }
}

/// 행 사이 구분선. 시안은 **첫 행 아래에만** 있고 아이콘 타일 오른쪽부터 시작한다.
struct DebugRowDivider: View {
    var body: some View {
        Divider().padding(.leading, Metrics.dividerInset)
    }
}
#endif
