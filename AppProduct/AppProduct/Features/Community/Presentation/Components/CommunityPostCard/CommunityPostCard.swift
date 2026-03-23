//
//  CommunityPostCard.swift
//  AppProduct
//
//  Created by 김미주 on 1/26/26.
//

import SwiftUI

/// 커뮤니티 게시글 카드 컴포넌트
///
/// 게시글의 카테고리, 제목, 프로필, 본문, 좋아요/스크랩 버튼을 표시합니다.
/// 번개 카테고리인 경우 오픈채팅 링크 버튼이 추가로 표시됩니다.
struct CommunityPostCard: View {
    // MARK: - Properties

    private let model: CommunityItemModel
    private let onLikeTapped: () async -> Void
    private let onScrapTapped: () async -> Void

    private enum Constant {
        static let mainPadding: EdgeInsets = .init(top: 16, leading: 16, bottom: 24, trailing: 16)
        static let profileSize: CGSize = .init(width: 40, height: 40)
        static let contentPadding: EdgeInsets = .init(top: 8, leading: 0, bottom: 12, trailing: 0)
        static let buttonPadding: EdgeInsets = .init(top: 8, leading: 12, bottom: 8, trailing: 12)
        static let tagPadding: EdgeInsets = .init(top: 8, leading: 12, bottom: 8, trailing: 12)
        static let kakaoSize: CGSize = .init(width: 40, height: 40)
        static let kakaoRadius: CGFloat = 12
        static let kakaoPadding: EdgeInsets = .init(top: 12, leading: 16, bottom: 12, trailing: 16)
    }

    // MARK: - Init

    init(
        model: CommunityItemModel,
        onLikeTapped: @escaping () async -> Void = {},
        onScrapTapped: @escaping () async -> Void = {}
    ) {
        self.model = model
        self.onLikeTapped = onLikeTapped
        self.onScrapTapped = onScrapTapped
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing24) {
            topSection

            Text(model.title)
                .appFont(.title2Emphasis, color: .black)

            profileSection

            Text(model.content)
                .appFont(.callout, color: .grey700)
                .padding(Constant.contentPadding)

            if model.category == .lighting {
                openChatSection
            }
            
            buttonSection
        }
        .padding(Constant.mainPadding)
        .background(
            RoundedRectangle(cornerRadius: DefaultConstant.defaultCornerRadius)
                .fill(.white)
        )
        .glass()
    }

    // MARK: - Section

    private var topSection: some View {
        HStack {
            Text(model.category.text)
                .appFont(.subheadline, color: .grey900)
                .padding(Constant.tagPadding)
                .glassEffect(.clear.tint(model.category.color))
            Spacer()
            Text(model.createdAt.timeAgoText)
                .appFont(.footnote, color: .grey500)
        }
    }

    private var profileSection: some View {
        HStack(spacing: DefaultSpacing.spacing12) {
            // 프로필 이미지
            RemoteImage(urlString: model.profileImage ?? "", size: Constant.profileSize)

            VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
                if model.part == .admin {
                    Text(model.displayUserName)
                        .appFont(.subheadlineEmphasis, color: .black)
                } else {
                    Text("\(model.displayUserName) • \(model.part.name)")
                        .appFont(.subheadlineEmphasis, color: .black)
                }
            }
        }
    }
    
    private var openChatSection: some View {
        Button(action: {
            openChatLink()
        }) {
            HStack(spacing: DefaultSpacing.spacing16) {
                Image(.kakaoInner)
                    .resizable()
                    .frame(width: Constant.kakaoSize.width, height: Constant.kakaoSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: Constant.kakaoRadius))
                VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
                    Text("오픈채팅방으로 이동")
                        .appFont(.subheadlineEmphasis, color: .black)
                    Text("참여 전 소통하기")
                        .appFont(.footnote, color: .black.opacity(0.72))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.grey500)
            }
            .padding(Constant.kakaoPadding)
        }
        .glassEffect(.clear.interactive().tint(.kakao))
    }

    private var buttonSection: some View {
        HStack(spacing: DefaultSpacing.spacing12) {
            makeButton(type: .like, isSelected: model.isLiked) {
                Task {
                    await onLikeTapped()
                }
            }
            makeButton(type: .scrap, isSelected: model.isScrapped) {
                Task {
                    await onScrapTapped()
                }
            }
        }
    }

    // MARK: - Function

    /// 오픈채팅 링크 열기
    private func openChatLink() {
        guard let urlString = model.lightningInfo?.openChatUrl,
              let url = URL(string: urlString) else { return }

        UIApplication.shared.open(url)
    }

    /// 좋아요/스크랩 액션 버튼을 생성합니다.
    ///
    /// - Parameters:
    ///   - type: 버튼 타입 (좋아요 또는 스크랩)
    ///   - isSelected: 현재 선택 상태
    ///   - action: 탭 시 실행할 클로저
    private func makeButton(type: CommunityButtonType, isSelected: Bool, action: @escaping () -> Void) -> some View {
        let count: Int = {
            switch type {
            case .like: return model.likeCount
            case .scrap: return model.scrapCount
            }
        }()

        return Button(action: action) {
            Image(systemName: isSelected ? type.filledIcon : type.icon)
            Text("\(count)")
        }
        .padding(Constant.buttonPadding)
        .appFont(.subheadline, color: type.foregroundColor)
        .glassEffect(.clear.tint(type.backgroundColor).interactive())
    }
}
