//
//  DebugReceivedCardsView.swift
//  UMCApp
//
//  Created by One on 8/16/26.
//

#if DEBUG
import BusinessCardDomain
import CoreUIComponents
import SwiftUI
import UMCFoundation

/// 「명함 관리 › 받은 명함」이 여는 명함첩. 시안 `12639:33678`(그리드) · `12640:35886`(검색).
///
/// **배치만 시안을 따른다** — 2열 고정 그리드, 카드 181×124, 간격 8. 색은 시안의 파트
/// 시드 7색(#6155F5 등)이 아니라 코드베이스에 이미 있는 `UMCPartType.color` 를 쓴다.
/// 임시뷰에 새 디자인 토큰을 들이지 않으려는 것이고, 실제 색 매핑은 진짜 뷰 작업에서 정한다.
///
/// 시안에 iOS 파트 변형이 없다는 점도 그때 정리해야 한다(Figma 7종 vs enum 8종).
///
/// 검증 도구(샘플 저장·upsert·영속 확인)는 이 화면에 두지 않는다 — 시안에 없는 것이
/// 배치 확인을 방해한다. 「검증 도구」 화면으로 옮겼다.
struct DebugReceivedCardsView: View {

    // MARK: - Property

    @Bindable var viewModel: BusinessCardDebugViewModel

    /// 시안 실측값 (`명함_s` 12657:35806).
    private enum Constants {
        static let horizontalMargin: CGFloat = 16
        static let gridSpacing: CGFloat = 8
        static let cardHeight: CGFloat = 124
        static let cardRadius: CGFloat = 34
        static let cardPadding: CGFloat = 16
        /// 상단 행(아바타·칩)과 텍스트 블록 사이.
        static let blockSpacing: CGFloat = 8
        static let avatarSize: CGFloat = 40
        static let chipSpacing: CGFloat = 4
        static let chipHeight: CGFloat = 21
        static let textSpacing: CGFloat = 4
    }

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: Constants.gridSpacing),
            GridItem(.flexible(), spacing: Constants.gridSpacing),
        ]
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Constants.gridSpacing) {
                content
            }
            .padding(.horizontal, Constants.horizontalMargin)
            .padding(.top, Constants.horizontalMargin)
        }
        .background(Color(.systemBackground))
        .navigationTitle("받은 명함")
        .navigationBarTitleDisplayMode(.inline)
        // 시안은 툴바 자리를 검색 필드가 통째로 대체하는 iOS 26 활성 상태다.
        // `.searchable` 이 그 동작을 그대로 준다 — 필드를 직접 그리지 않는다.
        .searchable(text: $viewModel.searchText, prompt: "이름, 파트 검색")
        .onSubmit(of: .search) { Task { await viewModel.reloadReceivedCards() } }
        .refreshable { await viewModel.reloadReceivedCards() }
    }

    // MARK: - View Component

    @ViewBuilder
    private var content: some View {
        switch viewModel.receivedCards {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .frame(height: Constants.cardHeight)

        case .loaded(let cards) where cards.isEmpty:
            // 시안에 빈 상태 프레임이 없다. 자리만 잡고 디자인은 뒤로 미룬다.
            Text("빈 명함첩")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: Constants.cardHeight)

        case .loaded(let cards):
            ForEach(cards) { card in
                cardCell(card)
                    .contextMenu {
                        Button("삭제", role: .destructive) {
                            Task { await viewModel.delete(id: card.id) }
                        }
                    }
            }

        case .failed(let error):
            Text("실패: \(error.localizedDescription)")
                .font(.footnote)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .frame(height: Constants.cardHeight)
        }
    }

    /// 시안 `명함_s` — 181×124, 내부 VStack gap 8 { 아바타+칩 행, 이름·학교 }.
    private func cardCell(_ card: ReceivedCard) -> some View {
        let tint = card.profile.part.color

        return VStack(alignment: .leading, spacing: Constants.blockSpacing) {
            HStack(alignment: .top, spacing: 0) {
                avatar(card)

                Spacer(minLength: Constants.chipSpacing)

                HStack(spacing: Constants.chipSpacing) {
                    chip(card.profile.part.name, tint: tint)
                    chip("\(card.profile.generation)기", tint: tint)
                }
            }

            VStack(alignment: .leading, spacing: Constants.textSpacing) {
                Text("\(card.profile.name)/\(card.profile.nickname)")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(card.profile.university)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(Constants.cardPadding)
        .frame(height: Constants.cardHeight, alignment: .top)
        .frame(maxWidth: .infinity)
        // 시안은 시드 컬러 2겹 그라데이션(alpha 0→0.1 + 0→0.05)이다.
        // 임시뷰라 단색 옅은 틴트로 대신한다 — 구분되는 것이 목적이다.
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: Constants.cardRadius))
    }

    private func avatar(_ card: ReceivedCard) -> some View {
        Group {
            if let avatarURL = card.profile.avatarURL, let url = URL(string: avatarURL) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image.umcDefaultProfile.resizable().scaledToFill()
                }
            } else {
                Image.umcDefaultProfile.resizable().scaledToFill()
            }
        }
        .frame(width: Constants.avatarSize, height: Constants.avatarSize)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }

    /// 시안: 높이 21 · 좌우 6 · radius 34(캡슐) · 파트 시드색 alpha 0.8 · 흰 글자.
    private func chip(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .frame(height: Constants.chipHeight)
            .background(tint.opacity(0.8), in: .capsule)
    }

}
#endif
