//
//  MyActivePostRow.swift
//  MyPagePresentation
//
//  Created by euijjang97 on 8/10/26.
//

import CoreDesignSystem
import CoreDomain
import SwiftUI
import UMCFoundation

/// 내 활동(작성/댓글/스크랩) 목록의 게시글 한 줄.
///
/// 커뮤니티 상세 화면이 아직 이식되지 않아 탭 동작 없이 요약만 보여준다.
struct MyActivePostRow: View {

    // MARK: - Property

    private let item: CommunityItemModel

    private enum Constants {
        static let contentLineLimit: Int = 2
    }

    // MARK: - Init

    init(item: CommunityItemModel) {
        self.item = item
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            header
            Text(item.title)
                .appFont(.subheadline, weight: .semibold, color: .grey900)
            Text(item.content)
                .appFont(.footnote, color: .grey600)
                .lineLimit(Constants.contentLineLimit)
                .multilineTextAlignment(.leading)
            counts
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - View Component

    private var header: some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            Text(item.category.text)
                .appFont(.caption1, weight: .semibold, color: .indigo500)
            Text(item.displayUserName)
                .appFont(.caption1, color: .grey500)
            Spacer()
            Text(item.createdAt.timeAgoText)
                .appFont(.caption1, color: .grey500)
        }
    }

    private var counts: some View {
        HStack(spacing: DefaultSpacing.spacing12) {
            countLabel(systemImage: "heart", count: item.likeCount)
            countLabel(systemImage: "bubble.right", count: item.commentCount)
            countLabel(systemImage: "bookmark", count: item.scrapCount)
        }
    }

    private func countLabel(systemImage: String, count: Int) -> some View {
        Label("\(count)", systemImage: systemImage)
            .labelStyle(.titleAndIcon)
            .appFont(.caption2, color: .grey500)
    }
}
