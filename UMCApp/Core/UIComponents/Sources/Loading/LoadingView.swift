//
//  LoadingView.swift
//  CoreUIComponents
//
//  Created by euijjang97 on 1/21/26.
//

import SwiftUI
import CoreDesignSystem

// MARK: - LoadingView

/// 데이터 로딩 중 표시되는 공용 로딩 뷰입니다.
///
/// 각 Feature별로 컨텍스트에 맞는 로딩 메시지를 표시하며,
/// Liquid Glass 효과가 적용된 디자인 시스템을 따릅니다.
///
/// - Important: `Loadable<T>` 의 `.loading` 상태에서 사용합니다.
///
/// - Usage:
/// ```swift
/// switch viewModel.seasonState {
/// case .idle: Color.clear
/// case .loading: LoadingView(.home(.seasonLoading))
/// case .loaded(let data): ContentView(data)
/// case .failed(let error): ErrorView(error)
/// }
/// ```
public struct LoadingView: View {

    // MARK: - Constants

    fileprivate enum Constants {
        /// `DefaultSpacing` 에 16/24는 있으나 20에 정확히 대응하는 토큰이 없어 레거시 값을 유지합니다.
        static let contentPadding: CGFloat = 20
    }

    // MARK: - Property

    /// 로딩 타입 (Feature별 메시지 구분)
    private let type: LoadingType

    // MARK: - Nested Types

    /// Feature별 로딩 타입을 정의하는 열거형입니다.
    ///
    /// 새로운 Feature의 로딩 메시지를 추가할 때는 여기에 case를 추가합니다.
    public enum LoadingType {
        /// 홈 화면 로딩 타입
        ///
        /// - Parameter home: 홈 화면 내 세부 로딩 타입
        case home(Home)

        /// 홈 화면의 세부 로딩 타입을 정의합니다.
        public enum Home: String {
            /// 기수 정보 로딩 중
            case seasonLoading = "기수 정보를 가져오는 중입니다."

            /// 패널티 정보 로딩 중
            case penaltyLoading = "패널티 정보를 가져오는 중입니다."

            /// 최근 공지 로딩 중
            case recentNoticeLoading = "최근 공지를 가져오는 중입니다."
        }

        /// 로딩 메시지 텍스트를 반환합니다.
        ///
        /// - Returns: 로딩 타입에 맞는 사용자 친화적 메시지
        public var text: String {
            switch self {
            case .home(let homeType):
                return homeType.rawValue
            }
        }
    }

    // MARK: - Initializer

    /// LoadingView 초기화
    ///
    /// - Parameter type: 로딩 타입 (Feature별 메시지 구분)
    public init(_ type: LoadingType) {
        self.type = type
    }

    // MARK: - Body

    public var body: some View {
        ProgressView(label: {
            Text(type.text)
                .appFont(.footnote, color: .grey400)
                .frame(maxWidth: .infinity)
        })
        .padding(Constants.contentPadding)
        .glassEffect(
            .regular,
            in: .rect(
                corners: .concentric(minimum: DefaultConstant.concentricRadius),
                isUniform: true
            )
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VStack(spacing: DefaultSpacing.spacing24) {
        LoadingView(.home(.seasonLoading))
        LoadingView(.home(.penaltyLoading))
        LoadingView(.home(.recentNoticeLoading))
    }
    .padding()
}
#endif
