//
//  StudyManagementLoadingView.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 8/10/26.
//

import CoreDesignSystem
import SwiftUI

// MARK: - StudyManagementLoadingView

/// 운영진 스터디 관리의 전체 영역 로딩 표시
///
/// 그룹 관리·제출 현황 두 섹션이 첫 로딩에서 같은 모양을 쓰기 때문에, 섹션 파일이 갈린 뒤에도
/// 각자 스피너를 다시 선언하지 않도록 공용 컴포넌트로 뺐습니다.
struct StudyManagementLoadingView: View {

    // MARK: - Property

    /// 로딩 중임을 설명하는 안내 문구
    let message: String

    // MARK: - Body

    var body: some View {
        VStack(spacing: DefaultSpacing.spacing12) {
            ProgressView()
                .controlSize(.large)
                .tint(Color.grey500)

            Text(message)
                .appFont(.subheadline, color: .grey500)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
    }
}

// MARK: - StudyManagementLoadMoreIndicator

/// 리스트 하단의 다음 페이지 로딩 표시
///
/// 그룹 관리·제출 현황 모두 무한 스크롤을 쓰고 하단 스피너 모양이 같아 함께 묶었습니다.
struct StudyManagementLoadMoreIndicator: View {

    // MARK: - Body

    var body: some View {
        ProgressView()
            .tint(Color.grey500)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DefaultSpacing.spacing8)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("스터디 관리 로딩") {
    VStack(spacing: DefaultSpacing.spacing24) {
        StudyManagementLoadingView(message: "스터디 그룹 관리 불러오는 중...")

        StudyManagementLoadMoreIndicator()
    }
}
#endif
