//
//  GuestActionToast.swift
//  AppProduct
//

import SwiftUI

// MARK: - GuestActionToast

/// 게스트 모드 전용 플로팅 토스트
///
/// 쓰기 액션 직후 4초간 표시되며, 인증 세션에서는 절대 노출되지 않습니다.
/// View Modifier `.guestActionToast(isPresented:onLoginTapped:)` 를 통해 사용합니다.
struct GuestActionToast: View {

    // MARK: - Property

    let onLoginTapped: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: DefaultSpacing.spacing8) {
            Text("게스트 모드에서는 저장되지 않아요. 로그인하면 실제로 반영됩니다")
                .appFont(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)

            Button(action: onLoginTapped) {
                Text("지금 로그인하기")
                    .appFont(.footnoteEmphasis)
                    .foregroundStyle(.indigo500)
            }
        }
        .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
        .padding(.vertical, DefaultSpacing.spacing12)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular)
        .clipShape(
            ConcentricRectangle(
                corners: .concentric(minimum: DefaultConstant.concentricRadius),
                isUniform: true
            )
        )
        .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
    }
}

// MARK: - View+GuestActionToastModifier

private struct GuestActionToastModifier: ViewModifier {

    @Binding var isPresented: Bool
    let onLoginTapped: () -> Void

    @Environment(\.appSessionMode) private var sessionMode

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if isPresented && sessionMode == .guest {
                    GuestActionToast(onLoginTapped: {
                        isPresented = false
                        onLoginTapped()
                    })
                    .padding(.bottom, DefaultConstant.defaultSafeBottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(4))
                        withAnimation {
                            isPresented = false
                        }
                    }
                    .animation(.spring(duration: 0.35), value: isPresented)
                }
            }
            .onChange(of: sessionMode) { _, newMode in
                if newMode != .guest {
                    isPresented = false
                }
            }
    }
}

extension View {
    /// 게스트 모드 한정 토스트. 인증 세션에서는 절대 노출되지 않음.
    func guestActionToast(
        isPresented: Binding<Bool>,
        onLoginTapped: @escaping () -> Void
    ) -> some View {
        modifier(GuestActionToastModifier(
            isPresented: isPresented,
            onLoginTapped: onLoginTapped
        ))
    }
}

// MARK: - Preview

#Preview("GuestActionToast") {
    ZStack {
        Color.grey100.ignoresSafeArea()

        GuestActionToast(onLoginTapped: {})
            .padding()
    }
    .environment(\.appSessionMode, .guest)
}
