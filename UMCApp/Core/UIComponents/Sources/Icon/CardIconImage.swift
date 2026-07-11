//
//  CardIconImage.swift
//  UMCApp
//
//  Created by JEONG on 7/11/26.
//

import CoreDesignSystem
import SwiftUI

/// 카드 좌측에 배치하는 원형 아이콘 이미지.
///
/// 홈 일정/공지 카드, 출석/커리큘럼 카드 등 여러 Feature가 공유하는 아이콘 래퍼입니다.
/// `isLoading`이 `true`인 동안에는 아이콘 대신 진행 인디케이터를 표시합니다.
public struct CardIconImage: View {

    // MARK: - Property

    private let image: String
    private let color: Color
    @Binding private var isLoading: Bool

    // MARK: - Initializer

    public init(image: String, color: Color, isLoading: Binding<Bool>) {
        self.image = image
        self.color = color
        self._isLoading = isLoading
    }

    // MARK: - Body

    public var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .tint(.black)
            } else {
                Image(systemName: image)
                    .font(.title2)
                    .foregroundStyle(color)
            }
        }
        .frame(width: DefaultConstant.iconSize, height: DefaultConstant.iconSize)
        .padding(DefaultConstant.iconPadding)
        .background {
            RoundedRectangle(cornerRadius: DefaultConstant.cornerRadius)
                .fill(color.opacity(0.4))
        }
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: DefaultConstant.cornerRadius))
    }
}

// MARK: - Preview

#Preview(traits: .sizeThatFitsLayout) {
    HStack {
        CardIconImage(image: "calendar.badge", color: .indigo500, isLoading: .constant(false))
        CardIconImage(image: "calendar.badge", color: .indigo500, isLoading: .constant(true))
    }
    .padding()
}
