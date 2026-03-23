//
//  ChallengerPendingApprovalView.swift
//  AppProduct
//
//  Created by jaewon Lee on 1/23/26.
//

import SwiftUI

/// 승인 대기 상태를 표시하는 전용 뷰
///
/// Glass Morphing 애니메이션과 함께 출석 버튼에서 전환됩니다.
struct ChallengerPendingApprovalView: View {

    // MARK: - Constant

    private enum Constant {
        static let iconSize: CGFloat = 32
        static let horizontalPadding: CGFloat = 24
        static let verticalPadding: CGFloat = 28
        static let backgroundOpacity: CGFloat = 0.1
    }

    @State private var isRotating = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: DefaultSpacing.spacing12) {
            iconView
            titleText
            descriptionText
        }
        .padding(.horizontal, Constant.horizontalPadding)
        .padding(.vertical, Constant.verticalPadding)
        .frame(maxWidth: .infinity)
        .background(Color.yellow.opacity(Constant.backgroundOpacity), in: .rect(corners: .concentric(minimum: DefaultConstant.concentricRadius), isUniform: true))
    }

    // MARK: - View Components

    private var iconView: some View {
        Image(systemName: "arrow.trianglehead.2.counterclockwise")
            .font(.system(size: Constant.iconSize))
            .foregroundStyle(.yellow)
            .rotationEffect(.degrees(isRotating ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    isRotating = true
                }
            }
    }

    private var titleText: some View {
        Text("승인 대기 중")
            .appFont(.bodyEmphasis, color: .grey600)
    }

    private var descriptionText: some View {
        Text("스터디장님이 출석 정보를 확인하고 있습니다")
            .appFont(.footnote, color: .grey500)
    }
}

// MARK: - Preview

#Preview(traits: .sizeThatFitsLayout) {
    ZStack {
        Color.grey100.frame(height: 300)

        ChallengerPendingApprovalView()
            .padding()
    }
}
