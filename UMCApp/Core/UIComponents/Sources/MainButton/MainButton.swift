//
//  MainButton.swift
//  CoreUIComponents
//
//  Created by 이예지 on 7/3/26.
//

import SwiftUI
import CoreDesignSystem

// MARK: - MainButton

/// 앱 전체에서 사용하는 기본 버튼 컴포넌트 (Container-Presenter 패턴)
///
/// 필수 파라미터만 포함하고, 추가 기능은 ViewModifier로 확장
/// 스타일은 외부에서 `.buttonStyle()` 으로 적용
/// 내부적으로 `MainButtonContent`를 Equatable 처리하여 렌더링 최적화
///
/// - Important: `buttonSize()`, `loading()` 은 `buttonStyle()` 보다 먼저 호출
///
/// ```swift
/// // Legacy 스타일 (ButtonStyles.swift)
/// MainButton("로그인") { viewModel.login() }
///     .loading($isLoading)
///     .buttonStyle(.primary)
///
/// // Liquid Glass (Apple 공식)
/// MainButton("확인") { viewModel.confirm() }
///     .buttonSize(.large)
///     .buttonStyle(.glass)
/// ```
public struct MainButton: View {

    // MARK: - Properties

    private let title: String
    private let action: () -> Void

    @Environment(\.mainButtonSize) private var size
    @Environment(\.mainButtonIsLoading) private var isLoading

    // MARK: - Initializer

    /// MainButton 생성자
    /// - Parameters:
    ///   - title: 버튼 텍스트
    ///   - action: 버튼 탭 액션
    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    // MARK: - Body

    public var body: some View {
        Button(action: {
            if !isLoading {
                action()
            }
        }) {
            MainButtonContent(
                title: title, size: size, isLoading: isLoading)
            .equatable()
        }
        .tint(.indigo500)
        .disabled(isLoading)
    }
}

// MARK: - MainButtonContent (Presenter)

/// MainButton의 렌더링 담당 (Equatable로 최적화)
private struct MainButtonContent: View, Equatable {
    let title: String
    let size: MainButtonSize
    let isLoading: Bool
    
    static func == (lhs: MainButtonContent, rhs: MainButtonContent) -> Bool {
        lhs.isLoading == rhs.isLoading &&
        lhs.title == rhs.title &&
        lhs.size == rhs.size
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else {
                Text(title)
            }
        }
        .font(size.font)
        .frame(maxWidth: .infinity)
        .frame(height: size.height)
    }
}

// MARK: - MainButton + AnyMainButton

extension MainButton: AnyMainButton { }

// MARK: - Preview

#Preview("MainButton with Styles") {
    VStack(spacing: 16) {
        MainButton("Primary Button") { }
            .buttonStyle(.primary)

        MainButton("Secondary Button") { }
            .buttonStyle(.secondary)

        MainButton("Destructive Button") { }
            .buttonStyle(.destructive)

        GlassEffectContainer {
            MainButton("Glass Button") { }
                .buttonStyle(.glass)

            MainButton("Glass Prominent") { }
                .buttonStyle(.glassProminent)
        }

        MainButton("Text Button") { }
            .buttonStyle(.text)
    }
    .padding()
    .background(.gray.opacity(0.3))
}

#Preview("MainButton Sizes") {
    VStack(spacing: 16) {
        MainButton("Small") { }
            .buttonSize(.small)
            .buttonStyle(.primary)

        MainButton("Medium (Default)") { }
            .buttonSize(.medium)
            .buttonStyle(.primary)

        MainButton("Large") { }
            .buttonSize(.large)
            .buttonStyle(.primary)
    }
    .padding()
}

#Preview("MainButton Loading") {
    struct LoadingPreview: View {
        @State private var isLoading = true

        var body: some View {
            VStack(spacing: 16) {
                MainButton("Loading State") { }
                    .loading($isLoading)
                    .buttonStyle(.primary)

                Button("Toggle Loading") {
                    isLoading.toggle()
                }
            }
            .padding()
        }
    }

    return LoadingPreview()
}

#Preview("MainButton Disabled") {
    VStack(spacing: 16) {
        MainButton("Disabled Primary") { }
            .buttonStyle(.primary)
            .disabled(true)

        MainButton("Disabled Secondary") { }
            .buttonStyle(.secondary)
            .disabled(true)
    }
    .padding()
}
