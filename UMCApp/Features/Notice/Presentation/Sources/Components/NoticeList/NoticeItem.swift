//
//  NoticeItem.swift
//  NoticeData
//
//  Created by 이예지 on 5/30/26.
//

import SwiftUI
import CoreDesignSystem
import NoticeDomain

// MARK: - Constant

private enum Constant {
    static let mainVSpacing: CGFloat = 12
    static let mainBoxHeight: CGFloat = 128
    static let mainPadding: EdgeInsets = .init(top: 12, leading: 24, bottom: 12, trailing: 24)
    static let mainBoxRadius: CGFloat = 24
    // top
    static let topHSpacing: CGFloat = 4
    static let tagPadding: EdgeInsets = .init(top: 4, leading: 8, bottom: 4, trailing: 8)
    // content
    static let contentSpacing: CGFloat = 4
    // bottom
    static let bottomIconSize: CGFloat = 12
    static let unreadDotSize: CGFloat = 8
}

// MARK: - NoticeItem

/// 공지 탭 - 리스트

public struct NoticeItem: View {
    // MARK: - Properties

    private let model: NoticeItemModel
    private let action: () -> Void

    // MARK: - Init

    public init(model: NoticeItemModel, action: @escaping () -> Void) {
        self.model = model
        self.action = action
    }

    // MARK: - Body

    public var body: some View {
        Button(action: action) {
            NoticeItemPresenter(model: model)
                .equatable()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Presenter

private struct NoticeItemPresenter: View, Equatable {
    let model: NoticeItemModel

    static func == (lhs: NoticeItemPresenter, rhs: NoticeItemPresenter) -> Bool {
        lhs.model == rhs.model
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Constant.mainVSpacing) {
            TopSection(model: model)
            ContentSection(model: model)
            BottomSection(model: model)
        }
        .frame(height: Constant.mainBoxHeight)
        .padding(Constant.mainPadding)
        .background {
            ConcentricRectangle(corners: .concentric(minimum: DefaultConstant.concentricRadius), isUniform: true)
                .fill(.white)
                .cardShadow()
        }
    }
}

/// 태그 + 알림 + 날짜
private struct TopSection: View, Equatable {
    let model: NoticeItemModel

    var body: some View {
        HStack(spacing: Constant.topHSpacing) {
            ForEach(Array(model.tags.enumerated()), id: \.offset) { _, tagItem in
                tag(tagItem.text, color: tagItem.backColor)
            }

            Spacer()
        }
    }
    
    private func tag(_ text: String, color: Color) -> some View {
        Text(text)
            .appFont(.caption1, weight: .semibold, color: .grey000)
            .padding(Constant.tagPadding)
            .background {
                RoundedRectangle(cornerRadius: DefaultConstant.defaultCornerRadius)
                    .fill(color)
            }
            .glassEffect(.clear, in: .rect(cornerRadius: DefaultConstant.defaultCornerRadius))
    }
}

/// 제목 + 내용
private struct ContentSection: View, Equatable {
    let model: NoticeItemModel

    var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
            Text(model.title)
                .appFont(.body, weight: .semibold, color: .grey900)
                .lineLimit(1)

            Text(MarkdownSerializer.plainText(from: model.content))
                .appFont(.subheadline, color: .grey600)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
    }
}

/// 작성자 + 링크/투표 여부 + 조회수
private struct BottomSection: View, Equatable {
    let model: NoticeItemModel

    var body: some View {
        HStack(spacing: 8) {
            Text(model.displayWriter)

            Spacer()

            if model.hasLink {
                Image(systemName: "link")
                    .font(.system(size: Constant.bottomIconSize))
            }

            if model.hasVote {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: Constant.bottomIconSize))
            }

            if model.isAlert {
                Image(systemName: "bell.fill")
                    .font(.system(size: Constant.bottomIconSize))
            }

            if !model.isRead {
                Circle()
                    .fill(.red)
                    .glassEffect(.clear.tint(.red), in: .circle)
                    .frame(width: Constant.unreadDotSize, height: Constant.unreadDotSize)
            }

            Text(model.date.toYearMonthDay())

            Text("조회 \(model.viewCount)")
        }
        .appFont(.footnote, color: .gray)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    VStack(spacing: 16) {
        NoticeItem(model: NoticeItemModel(
            generation: "9",
            scope: .central,
            category: .general,
            mustRead: true,
            isAlert: true,
            date: Date(),
            title: "[투표] 12기 중앙 해커톤 회식 메뉴 선정 안내",
            content: "이번 해커톤 종료 후 진행될 회식 메뉴를 결정하고자 합니다. 가장 많은 표를 받은 메뉴로 진행됩니다!",
            writer: "쳇쳇/전채운",
            links: [],
            images: [],
            vote: NoticeVote(
                id: "vote1",
                question: "회식 메뉴를 선택해주세요",
                options: [
                    VoteOption(id: "1", title: "삼겹살", voteCount: "45"),
                    VoteOption(id: "2", title: "치킨", voteCount: "23"),
                    VoteOption(id: "3", title: "피자", voteCount: "18"),
                    VoteOption(id: "4", title: "떡볶이", voteCount: "34")
                ],
                startDate: Date(timeIntervalSinceNow: -86400),
                endDate: Date(timeIntervalSinceNow: 86400 * 7),
                allowMultipleChoices: false,
                isAnonymous: true,
                userVotedOptionIds: []
            ),
            viewCount: "32"
        )) {
            print("oo")
        }
    }
}
