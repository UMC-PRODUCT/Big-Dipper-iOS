//
//  AISummaryDraftOverlay.swift
//  AppProduct
//
//  Created by euijjang97 on 5/31/26.
//

import SwiftUI

/// AI 요약 완료 후 생성된 제목·본문 초안을 검토하고 수락 또는 기각하는 오버레이입니다.
///
/// 수락 시 에디터의 title/content/richAttributedContent에 반영됩니다.
/// 카테고리·대상·알림 발송 여부는 절대 자동 변경되지 않습니다.
struct AISummaryDraftOverlay: View {

    // MARK: - Property

    let draft: NoticeEditorViewModel.AISummaryDraft
    let onAccept: () -> Void
    let onReject: () -> Void

    // MARK: - Constants

    private enum Constants {
        static let cardPadding: EdgeInsets = .init(top: 24, leading: 28, bottom: 24, trailing: 28)
        static let cardMaxWidth: CGFloat = 360
        static let bodyLineLimit: Int = 6
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()

            VStack(spacing: DefaultSpacing.spacing16) {
                headerSection
                draftSection
                draftNoticeLabel
                actionSection
            }
            .padding(Constants.cardPadding)
            .frame(maxWidth: Constants.cardMaxWidth)
            .glassEffect(.regular, in: .rect(corners: .concentric(minimum: DefaultConstant.concentricRadius)))
        }
    }

    // MARK: - View Builders

    private var headerSection: some View {
        VStack(spacing: DefaultSpacing.spacing8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: DefaultConstant.iconSize, weight: .medium))
                .foregroundStyle(.indigo500)

            Text("초안이 완성됐어요")
                .appFont(.calloutEmphasis)
                .multilineTextAlignment(.center)
        }
    }

    private var draftSection: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
            if !draft.title.isEmpty {
                VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
                    Text("제목")
                        .appFont(.caption1)
                        .foregroundStyle(.grey500)
                    Text(draft.title)
                        .appFont(.calloutEmphasis)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
            }

            if !draft.body.isEmpty {
                VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
                    Text("본문")
                        .appFont(.caption1)
                        .foregroundStyle(.grey500)
                    Text(draft.body)
                        .font(.app(.footnote))
                        .foregroundStyle(.grey600)
                        .multilineTextAlignment(.leading)
                        .lineLimit(Constants.bodyLineLimit)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DefaultSpacing.spacing12)
        .glassEffect(.regular, in: .rect(cornerRadius: DefaultConstant.defaultCornerRadius))
    }

    private var draftNoticeLabel: some View {
        Text("초안입니다. 수락 후 직접 검토·수정해주세요.")
            .font(.app(.caption1))
            .foregroundStyle(.grey500)
            .multilineTextAlignment(.center)
    }

    private var actionSection: some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            MainButton("기각") { onReject() }
                .buttonStyle(.glass)
            MainButton("에디터에 적용") { onAccept() }
                .buttonStyle(.glassProminent)
        }
    }
}
