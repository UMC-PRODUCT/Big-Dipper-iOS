//
//  ThreadCardStyle.swift
//  CommunityPresentation
//

import SwiftUI
import CoreDesignSystem

// MARK: - Metrics

/// 스레드 카드 한 장의 치수. 실제 행(``ThreadListRow``)과 뼈대 행(``ThreadListSkeleton``)이
/// 같은 값을 써야 로드가 끝나는 순간 높이·모양이 튀지 않는다.
enum ThreadCardMetrics {
    static let iconSize: CGFloat = 44
    /// Dynamic Type 을 따라 커지되 여기서 멈춘다. 끝까지 따라가면 타일이 행 너비의 절반을
    /// 차지해 정작 제목이 밀린다.
    static let maxIconSize: CGFloat = 64
    /// 카드 사이 간격(위아래 4 씩 = 8)과 화면 좌우 여백. 기본 행 인셋으로는 카드가 화면
    /// 끝에 붙고 그림자가 잘린다.
    static let rowInsets = EdgeInsets(
        top: DefaultSpacing.spacing4,
        leading: DefaultConstant.defaultSafeHorizon,
        bottom: DefaultSpacing.spacing4,
        trailing: DefaultConstant.defaultSafeHorizon
    )
    /// 시안 그림자 `#0000001A · y 2 · blur 8`. Figma blur 는 SwiftUI radius 의 두 배라 4 로 옮긴다.
    static let shadowOpacity: Double = 0.1
    static let shadowRadius: CGFloat = 4
    static let shadowOffsetY: CGFloat = 2
}

// MARK: - Modifier

/// 흰 카드 한 장. 안쪽 여백과 배경 도형을 함께 건다.
private struct ThreadCardModifier: ViewModifier {

    func body(content: Content) -> some View {
        content
            .padding(.vertical, DefaultSpacing.spacing12)
            .padding(.horizontal, DefaultSpacing.spacing16)
            // 그림자를 배경 도형에만 건다. 카드 전체에 걸면 글자까지 그림자를 만들어 불필요한
            // 오프스크린 렌더링이 늘어난다.
            .background {
                RoundedRectangle(cornerRadius: DefaultConstant.cornerRadius)
                    .fill(Color.grey000)
                    .shadow(
                        color: .black.opacity(ThreadCardMetrics.shadowOpacity),
                        radius: ThreadCardMetrics.shadowRadius,
                        x: 0,
                        y: ThreadCardMetrics.shadowOffsetY
                    )
            }
    }
}

/// 카드를 담는 `List` 행. 기본 배경·구분선을 걷어 내야 카드 경계가 살아난다.
private struct ThreadCardRowModifier: ViewModifier {

    func body(content: Content) -> some View {
        content
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(ThreadCardMetrics.rowInsets)
    }
}

// MARK: - View Extension

extension View {

    func threadCard() -> some View {
        modifier(ThreadCardModifier())
    }

    func threadCardRow() -> some View {
        modifier(ThreadCardRowModifier())
    }
}
