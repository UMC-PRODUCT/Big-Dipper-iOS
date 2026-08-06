//
//  ChallengerPendingApprovalView.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/15/26.
//

import CoreDesignSystem
import SwiftUI

/// 승인 대기 상태를 표시하는 전용 뷰
///
/// Glass Morphing 애니메이션과 함께 출석 버튼에서 전환됩니다.
struct ChallengerPendingApprovalView: View {

    // MARK: - Constants

    fileprivate enum Constants {
        static let horizontalPadding: CGFloat = 24
        static let verticalPadding: CGFloat = 28
        static let backgroundOpacity: CGFloat = 0.1
        static let rotationDuration: TimeInterval = 1.5
    }

    // MARK: - Property

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isRotating = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: DefaultSpacing.spacing12) {
            iconView
            titleText
            descriptionText
        }
        .padding(.horizontal, Constants.horizontalPadding)
        .padding(.vertical, Constants.verticalPadding)
        .frame(maxWidth: .infinity)
        .background(
            Color.yellow500.opacity(Constants.backgroundOpacity),
            in: .rect(
                corners: .concentric(minimum: DefaultConstant.concentricRadius),
                isUniform: true
            )
        )
    }

    // MARK: - View Components

    private var iconView: some View {
        Image(systemName: "arrow.trianglehead.2.counterclockwise")
            .font(.app(.largeTitle))
            .foregroundStyle(Color.yellow500)
            .rotationEffect(.degrees(isRotating ? 360 : 0))
            .task(id: reduceMotion) { updateRotation() }
    }

    // MARK: - Function

    /// "동작 줄이기"가 켜져 있으면 무한 회전을 멈춘다(아이콘 자체는 정지 상태로 계속 표시).
    private func updateRotation() {
        guard !reduceMotion else {
            withAnimation(.linear(duration: .zero)) { isRotating = false }
            return
        }

        withAnimation(
            .linear(duration: Constants.rotationDuration)
                .repeatForever(autoreverses: false)
        ) {
            isRotating = true
        }
    }

    private var titleText: some View {
        Text("승인 대기 중")
            .appFont(.body, weight: .semibold, color: .grey600)
    }

    private var descriptionText: some View {
        Text("스터디장님이 출석 정보를 확인하고 있습니다")
            .appFont(.footnote, color: .grey500)
    }
}

#if DEBUG
// MARK: - Preview

#Preview(traits: .sizeThatFitsLayout) {
    ZStack {
        Color.grey100.frame(height: 300)

        ChallengerPendingApprovalView()
            .padding()
    }
}
#endif
