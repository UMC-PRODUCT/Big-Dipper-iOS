//
//  MyPageListRow.swift
//  MyPagePresentation
//
//  Created by One on 8/18/26.
//

import CoreDesignSystem
import SwiftUI

/// 마이페이지 v3 리스트 카드가 공유하는 행 아이콘 타일 색.
///
/// 시안 4색(`#34C759`/`#0088FF`/`#FF8D28`/`#00C3D0`)이 디자인 시스템 accent 토큰(orange500 등)과
/// 값이 달라 실측 hex를 그대로 쓴다(`BusinessCardPalette`와 같은 이유).
enum MyPageListIconColor {
    static let green = Color(red: 0x34 / 255, green: 0xC7 / 255, blue: 0x59 / 255)
    static let blue = Color(red: 0x00 / 255, green: 0x88 / 255, blue: 0xFF / 255)
    static let orange = Color(red: 0xFF / 255, green: 0x8D / 255, blue: 0x28 / 255)
    static let teal = Color(red: 0x00 / 255, green: 0xC3 / 255, blue: 0xD0 / 255)
}

/// ``MyPageListCard``의 치수. 제네릭 타입 안에 중첩된 타입은 `static` 저장 프로퍼티를
/// 가질 수 없어(Swift 제약) 카드 밖으로 뺀다.
private enum MyPageListCardMetrics {
    static let cornerRadius: CGFloat = 27
    static let horizontalPadding: CGFloat = 16
    static let verticalPadding: CGFloat = 4
}

/// 흰 배경 radius 27 카드. 「명함 관리」·「나의 활동」 섹션이 이 안에 ``MyPageListRow``를 담는다.
struct MyPageListCard<Content: View>: View {

    @ViewBuilder private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0, content: { content })
            .padding(.horizontal, MyPageListCardMetrics.horizontalPadding)
            .padding(.vertical, MyPageListCardMetrics.verticalPadding)
            .background(
                Color.white,
                in: RoundedRectangle(cornerRadius: MyPageListCardMetrics.cornerRadius)
            )
    }
}

/// ``MyPageListCard`` 안의 두 행 사이 구분선. 아이콘 타일 우측부터 시작한다.
struct MyPageListDivider: View {

    /// 아이콘 타일 폭(32) + 아이콘-텍스트 간격(16).
    private static let leadingInset: CGFloat = 48

    var body: some View {
        Divider()
            .padding(.leading, Self.leadingInset)
    }
}

/// 시안 `item/MypageList` — 32x32 컬러 아이콘 타일 + 레이블 + (옵션)우측 값 + chevron.
///
/// `action`이 `nil`이면 탭 제스처도, chevron도 달지 않는다 — chevron만 남기면 목적지가
/// 없는 행이 활성 외관인 채 눌러도 무반응인, 바로 그 죽은 탭이 된다.
///
/// `isPending`이 `true`면 `action`이 있어도 탭을 막고 chevron 대신 진행 표시를 보여준다 —
/// 목적지는 있는데 아직 필요한 데이터가 도착하지 않은 경우다(예: 명함 편집이 프로필 스냅샷을
/// 기다리는 동안). 목적지가 아예 없는 행과 달리 "곧 활성화될 것"이라는 피드백을 준다.
struct MyPageListRow: View {

    private enum Constants {
        /// 시안 실측 높이. **바닥값**이다 — 글자가 커지면 줄이 따라 늘어난다.
        static let minRowHeight: CGFloat = 54
        static let verticalPadding = DefaultSpacing.spacing8
        static let contentSpacing: CGFloat = 16
        static let iconTileSize: CGFloat = 32
        static let iconTileRadius: CGFloat = 8
        static let iconGlyphSize: CGFloat = 17
        static let titleLineLimit = 2
        static let trailingSpacing: CGFloat = 8
        static let chevronSize: CGFloat = 17
        static let pendingOpacity: CGFloat = 0.6
        static let pendingHint = "필요한 정보를 불러오는 중입니다"
    }

    let systemIcon: String
    let iconColor: Color
    let title: String
    var value: String? = nil
    var action: (() -> Void)? = nil
    var isPending: Bool = false

    var body: some View {
        Group {
            if let action, !isPending {
                Button(action: action) { rowContent }
                    .buttonStyle(.plain)
            } else {
                rowContent
                    .opacity(isPending ? Constants.pendingOpacity : 1)
            }
        }
    }

    /// 「나의 활동 ・프로젝트, 3건」. 아이콘 타일과 chevron은 옆 글자를 그림으로 옮긴
    /// 장식이라 따로 읽히면 줄 하나를 네 번 스와이프하게 된다.
    private var accessibilityLabel: String {
        [title, value].compactMap { $0 }.joined(separator: ", ")
    }

    private var rowContent: some View {
        HStack(spacing: Constants.contentSpacing) {
            iconTile

            Text(title)
                .appFont(.callout, color: .black)
                .lineLimit(Constants.titleLineLimit)

            Spacer(minLength: Constants.contentSpacing)

            HStack(spacing: Constants.trailingSpacing) {
                if let value {
                    Text(value)
                        .appFont(.callout, color: .grey500)
                }

                if isPending {
                    ProgressView()
                        .controlSize(.mini)
                } else if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: Constants.chevronSize))
                        .foregroundStyle(Color.grey500)
                }
            }
        }
        .padding(.vertical, Constants.verticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: Constants.minRowHeight)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isPending ? Constants.pendingHint : "")
    }

    private var iconTile: some View {
        Image(systemName: systemIcon)
            .font(.system(size: Constants.iconGlyphSize))
            .foregroundStyle(Color.white)
            .frame(width: Constants.iconTileSize, height: Constants.iconTileSize)
            .background(iconColor, in: RoundedRectangle(cornerRadius: Constants.iconTileRadius))
    }
}
