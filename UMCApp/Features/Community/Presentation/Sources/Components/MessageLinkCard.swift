//
//  MessageLinkCard.swift
//  CommunityPresentation
//

import SwiftUI
import CommunityDomain
import CoreDI
import CoreDesignSystem

// MARK: - Constants

fileprivate enum Constants {
    static let cornerRadius: CGFloat = 12
    static let titleLineLimit = 2
    static let summaryLineLimit = 2
    static let chevronSize: CGFloat = 12
    static let skeletonCornerRadius: CGFloat = 4
    static let skeletonTitleHeight: CGFloat = 14
    static let skeletonSummaryHeight: CGFloat = 10
    static let skeletonSummaryWidth: CGFloat = 140
    static let noticeLabel = "공지"
    static let threadLabel = "스레드"
}

/// 메시지 안의 내부 링크를 제목·요약 카드로 그린다.
///
/// 메타를 못 가져오면 **아무것도 그리지 않는다.** 본문에는 원문 링크가 텍스트 링크로 이미
/// 남아 있어서, 실패한 자리에 에러 카드를 세우면 같은 링크가 두 번 보이고 버블만 커진다.
///
/// 탭은 `openURL` 로 흘려보낸다 — 본문 텍스트 링크와 카드가 같은 경로를 타야 라우팅 규칙이
/// 한 곳(``CommunityFeatureView``)에만 있게 된다.
struct MessageLinkCard: View {

    // MARK: - Property

    let link: MessageLink

    @Environment(\.di) private var di
    @Environment(\.openURL) private var openURL

    @State private var preview: MessageLinkPreview?
    @State private var isLoading = true

    // MARK: - Body

    var body: some View {
        // `Group` 이 아니라 실제 컨테이너로 감싼다 — `Group` 은 modifier 를 분기마다 새로
        // 붙여서, 로딩 → 완료로 갈라지는 순간 `task` 가 한 번 더 뜬다.
        VStack(spacing: 0) {
            if let preview {
                Button {
                    guard let url = link.url else { return }
                    openURL(url)
                } label: {
                    cardBody(preview)
                }
                .buttonStyle(.plain)
            } else if isLoading {
                skeleton
            }
        }
        .task { await load() }
    }

    // MARK: - View Component

    private func cardBody(_ preview: MessageLinkPreview) -> some View {
        HStack(alignment: .top, spacing: DefaultSpacing.spacing8) {
            VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
                HStack(spacing: DefaultSpacing.spacing4) {
                    Image(systemName: iconName)
                    Text(kindLabel)
                }
                .appFont(.caption2, weight: .semibold, color: .indigo600)

                Text(preview.title)
                    .appFont(.subheadline, weight: .semibold, color: .grey900)
                    .multilineTextAlignment(.leading)
                    .lineLimit(Constants.titleLineLimit)

                if !preview.summary.isEmpty {
                    Text(preview.summary)
                        .appFont(.caption1, color: .grey600)
                        .multilineTextAlignment(.leading)
                        .lineLimit(Constants.summaryLineLimit)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: Constants.chevronSize))
                .foregroundStyle(Color.grey400)
        }
        .cardSurface()
        .accessibilityElement(children: .combine)
        .accessibilityHint("\(kindLabel) 열기")
    }

    /// 카드 자리를 미리 잡아 둔다. 도착한 뒤에 자리가 생기면 읽던 위치가 밀린다.
    private var skeleton: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
            RoundedRectangle(cornerRadius: Constants.skeletonCornerRadius)
                .fill(Color.grey200)
                .frame(height: Constants.skeletonTitleHeight)

            RoundedRectangle(cornerRadius: Constants.skeletonCornerRadius)
                .fill(Color.grey100)
                .frame(maxWidth: Constants.skeletonSummaryWidth)
                .frame(height: Constants.skeletonSummaryHeight)
        }
        .cardSurface()
        .accessibilityHidden(true)
    }

    // MARK: - Computed Property

    private var kindLabel: String {
        switch link {
        case .notice:
            return Constants.noticeLabel
        case .thread:
            return Constants.threadLabel
        }
    }

    private var iconName: String {
        switch link {
        case .notice:
            return "megaphone.fill"
        case .thread:
            return "bubble.left.and.bubble.right.fill"
        }
    }

    // MARK: - Function

    private func load() async {
        defer { isLoading = false }
        preview = try? await di
            .resolve(MessageLinkPreviewUseCaseProtocol.self)
            .preview(for: link)
    }
}

// MARK: - Card Surface

private extension View {
    /// 카드 판. 버블 폭을 꽉 채운다 — 제목 길이만큼만 줄면 말풍선이 메시지마다 들쭉날쭉해진다.
    func cardSurface() -> some View {
        padding(DefaultSpacing.spacing8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.grey000, in: .rect(cornerRadius: Constants.cornerRadius))
    }
}
