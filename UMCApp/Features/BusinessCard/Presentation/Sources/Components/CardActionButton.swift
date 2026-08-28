//
//  CardActionButton.swift
//  BusinessCardPresentation
//
//  Created by One on 8/18/26.
//

import SwiftUI
import CoreDesignSystem

/// 명함 화면 하단의 전폭 캡슐 버튼 (시안 `12639:33671` / `12639:33672`).
///
/// 코어 `MainButton` 을 쓰지 않는다. 시안은 Apple iOS 26 `Buttons` 컴포넌트라
/// 높이 48 · radius 100 캡슐인데, `MainButtonSize` 는 36/44/52 뿐이고 `.primary`
/// 스타일은 radius 8 이다. 어느 조합으로도 맞출 수 없다.
///
/// - Note: **명함 전용으로 유지한다** (#1237 결정). 공용 `MainButton` 으로 수렴하려면
///   `MainButtonSize` 에 48 케이스를, `ButtonStyle` 에 캡슐 변형을 새로 넣어야 하는데
///   그건 앱 전역 버튼 어휘를 바꾸는 일이라 명함 브랜치가 결정할 범위가 아니다.
///   코어 버튼 규격이 시안에서 밀린 상태라는 사실만 남겨 둔다.
struct CardActionButton: View {

    // MARK: - Role

    enum Role {
        case primary
        case secondary
        /// 시안 Apple `Buttons` Destructive 변형 (교환 중지).
        case destructive

        var background: Color {
            switch self {
            case .primary:
                // 시안 실측은 #5468FC 였지만 코어 토큰으로 수렴했다(#1237).
                // 토큰은 Asset Catalog 라 다크 모드 값을 스스로 들고 있다.
                return .indigo500
            case .secondary:
                // iOS Fills/Secondary = rgba(120,120,128,0.16).
                return Color(uiColor: .secondarySystemFill)
            case .destructive:
                // 시안은 Apple 스톡 컴포넌트라 hex 가 없다. 시맨틱 토큰이 그 톤에 맞는다.
                return .red100
            }
        }

        var foreground: Color {
            switch self {
            case .primary:     return .white
            case .secondary:   return .grey900
            case .destructive: return .red500
            }
        }
    }

    // MARK: - Property

    let title: String
    let role: Role
    let action: () -> Void

    /// 시안 높이 48 (Apple iOS 26 `Buttons`). **바닥값**이다 — 글자가 커지면
    /// 버튼이 따라 커진다(고정하면 AX 크기에서 라벨이 캡슐 밖으로 넘친다).
    static let labelMinHeight: CGFloat = 48

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            Text(title).cardActionLabel(role: role)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Label Style

extension View {

    /// 버튼 껍데기와 무관하게 시안 라벨 모양만 입힌다.
    ///
    /// `ShareLink` 는 `Button` 이 아니라서 ``CardActionButton`` 을 그대로 못 쓴다.
    /// 두 곳이 같은 모양이어야 하므로 스타일만 따로 뺐다.
    func cardActionLabel(role: CardActionButton.Role) -> some View {
        // 시안은 SF Pro Medium 17 이지만 앱 전체가 Pretendard 다. 스톡 Apple
        // 컴포넌트를 쓴 흔적으로 보여 서체는 앱을 따른다.
        appFont(.body, weight: .medium, color: role.foreground)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .frame(minHeight: CardActionButton.labelMinHeight)
            .background(role.background, in: Capsule())
    }
}

// MARK: - Preview

#if DEBUG
#Preview("명함 하단 버튼") {
    VStack(spacing: 10) {
        CardActionButton(title: "공유하기", role: .primary) {}
        CardActionButton(title: "이미지 저장", role: .secondary) {}
    }
    .padding(16)
}
#endif
