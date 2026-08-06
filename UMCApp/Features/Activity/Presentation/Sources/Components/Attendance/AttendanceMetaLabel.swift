//
//  AttendanceMetaLabel.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/25/26.
//

import CoreDesignSystem
import SwiftUI

/// 일정 부가 정보 한 줄 (아이콘 + 내용)
///
/// 일시·장소·비대면 같은 메타 정보를 목록 카드와 상세 헤더가 같은 아이콘 크기·색으로
/// 표시하도록 공유합니다.
struct AttendanceMetaLabel<Content: View>: View {

    // MARK: - Property

    private let systemImage: String
    private let content: () -> Content

    // MARK: - Init

    init(systemImage: String, @ViewBuilder content: @escaping () -> Content) {
        self.systemImage = systemImage
        self.content = content
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            Image(systemName: systemImage)
                .font(.app(.caption1))
                .foregroundStyle(Color.grey500)
            content()
        }
    }
}
