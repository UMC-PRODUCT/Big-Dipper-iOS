//
//  DebugMyPageRow.swift
//  UMCApp
//
//  Created by One on 8/16/26.
//

#if DEBUG
import SwiftUI

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
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconTint)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: icon)
                            .foregroundStyle(.white)
                            .font(.system(size: 16, weight: .semibold))
                    }

                Text(title)
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                if let trailingValue {
                    Text(trailingValue)
                        .foregroundStyle(.secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
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
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

/// 행 사이 구분선 (시안은 아이콘 왼쪽 여백만큼 들여쓴 선).
struct DebugRowDivider: View {
    var body: some View {
        Divider().padding(.leading, 60)
    }
}
#endif
