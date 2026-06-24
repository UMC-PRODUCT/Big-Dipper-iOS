//
//  NoticeLinkCard.swift
//  NoticeData
//
//  Created by 이예지 on 6/1/26.
//

import LinkPresentation
import SwiftUI
import CoreDesignSystem

// MARK: - LinkMetadata
/// OG 메타데이터 로컬 모델
private struct LinkMetadata {
    let title: String
    let description: String?
    let image: UIImage?
}

// MARK: - NoticeLinkCard
/// 공지 상세에서 첨부 링크를 표시하는 카드 컴포넌트
public struct NoticeLinkCard: View {

    // MARK: - Property
    public let url: String
    @Environment(\.openURL) var openURL
    @State private var metadata: LinkMetadata?
    @State private var isLoading: Bool = true

    // MARK: - Constants
    fileprivate enum Constants {
        static let innerPadding: CGFloat = 8
        static let imageSize: CGFloat = 56
        static let imageCornerRadius: CGFloat = 10
        static let contentSpacing: CGFloat = 12
        static let textSpacing: CGFloat = 4
        static let chevronSize: CGFloat = 12
        static let skeletonCornerRadius: CGFloat = 4
        static let skeletonTitleHeight: CGFloat = 16
        static let skeletonTitleMaxWidth: CGFloat = 180
        static let skeletonDescHeight: CGFloat = 12
        static let skeletonDescMaxWidth: CGFloat = 140
        static let richLeadingPadding: CGFloat = 10
        static let richTrailingPadding: CGFloat = 4
        static let richVerticalPadding: CGFloat = 6
        static let titleLineLimit: Int = 2
        static let descLineLimit: Int = 2
        static let animationDuration: Double = 0.25
    }

    // MARK: - Body
    public var body: some View {
        Button(action: {
            let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
            guard
                let linkURL = URL(string: trimmed),
                linkURL.scheme != nil
            else {
                return
            }
            openURL(linkURL)
        }) {
            Group {
                if isLoading {
                    loadingContent
                } else if let metadata {
                    richPreviewContent(metadata)
                } else {
                    fallbackContent
                }
            }
            .padding(Constants.innerPadding)
            .glassEffect(
                .clear.interactive().tint(Color(.systemGroupedBackground)),
                in: .rect(
                    corners: .concentric(minimum: DefaultConstant.concentricRadius),
                    isUniform: true
                )
            )
        }
       
        .task {
            await fetchMetadata()
        }
    }

    // MARK: - Function

    private var loadingContent: some View {
        HStack(spacing: Constants.contentSpacing) {
            VStack(alignment: .leading, spacing: Constants.textSpacing) {
                RoundedRectangle(cornerRadius: Constants.skeletonCornerRadius)
                    .fill(Color.grey200)
                    .frame(height: Constants.skeletonTitleHeight)
                    .frame(maxWidth: Constants.skeletonTitleMaxWidth)

                RoundedRectangle(cornerRadius: Constants.skeletonCornerRadius)
                    .fill(Color.grey100)
                    .frame(height: Constants.skeletonDescHeight)
                    .frame(maxWidth: Constants.skeletonDescMaxWidth)
            }

            Spacer()

            RoundedRectangle(cornerRadius: Constants.imageCornerRadius)
                .fill(Color.grey100)
                .frame(
                    width: Constants.imageSize,
                    height: Constants.imageSize
                )

            chevronIcon
        }
        .redacted(reason: .placeholder)
    }

    private func richPreviewContent(_ metadata: LinkMetadata) -> some View {
        HStack(spacing: Constants.contentSpacing) {
            VStack(alignment: .leading, spacing: Constants.textSpacing) {
                Text(metadata.title)
                    .appFont(.subheadline, weight: .semibold, color: .black)
                    .multilineTextAlignment(.leading)
                    .lineLimit(Constants.titleLineLimit)

                if let description = metadata.description,
                   !description.isEmpty {
                    Text(description)
                        .appFont(.footnote, color: .grey600)
                        .multilineTextAlignment(.leading)
                        .lineLimit(Constants.descLineLimit)
                }

                Text(displayHost)
                    .appFont(.caption2, color: .grey500)
                    .lineLimit(1)
            }

            Spacer()

            if let image = metadata.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width: Constants.imageSize,
                        height: Constants.imageSize
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: Constants.imageCornerRadius)
                    )
            }

            chevronIcon
        }
        .padding(.leading, Constants.richLeadingPadding)
        .padding(.trailing, Constants.richTrailingPadding)
        .padding(.vertical, Constants.richVerticalPadding)
    }

    private var fallbackContent: some View {
        HStack {
            LinkIconPresenter()

            LinkTextPresenter(url: url)

            Spacer()

            chevronIcon
        }
    }

    private var chevronIcon: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: Constants.chevronSize))
            .foregroundStyle(Color.grey400)
    }

    private var displayHost: String {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = URL(string: trimmed),
              let host = parsed.host else {
            return trimmed
        }
        return host
    }

    private func fetchMetadata() async {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let linkURL = URL(string: trimmed),
              linkURL.scheme != nil else {
            isLoading = false
            return
        }

        let provider = LPMetadataProvider()
        do {
            let lpMetadata = try await provider.startFetchingMetadata(
                for: linkURL
            )

            let title = lpMetadata.title ?? trimmed
            let description = lpMetadata.value(forKey: "_summary") as? String

            var image: UIImage?
            if let imageProvider = lpMetadata.imageProvider {
                image = await loadImage(from: imageProvider)
            }

            withAnimation(.easeInOut(duration: Constants.animationDuration)) {
                metadata = LinkMetadata(
                    title: title,
                    description: description,
                    image: image
                )
                isLoading = false
            }
        } catch {
            withAnimation(.easeInOut(duration: Constants.animationDuration)) {
                isLoading = false
            }
        }
    }

    private func loadImage(from provider: NSItemProvider) async -> UIImage? {
        await withCheckedContinuation { continuation in
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                continuation.resume(returning: object as? UIImage)
            }
        }
    }
}


// MARK: - LinkIconPresenter
/// 링크 아이콘
public struct LinkIconPresenter: View {

    // MARK: - Constants
    fileprivate enum Constants {
        static let linkIconSize: CGSize = .init(width: 20, height: 20)
        static let iconPadding: CGFloat = 10
        static let iconTintColor: Color = .indigo500
        static let iconBackgroundColor: Color = .indigo100
    }

    // MARK: - Body
    public var body: some View {
        Image(systemName: "link")
            .resizable()
            .frame(
                width: Constants.linkIconSize.width,
                height: Constants.linkIconSize.height
            )
            .foregroundStyle(Constants.iconTintColor)
            .padding(Constants.iconPadding)
            .background {
                RoundedRectangle(cornerRadius: DefaultConstant.defaultCornerRadius)
                    .foregroundStyle(Constants.iconBackgroundColor)
            }
    }
}


// MARK: - LinkTextPresenter
/// 링크 텍스트
public struct LinkTextPresenter: View {

    // MARK: - Property
    public let url: String

    // MARK: Constants
    fileprivate enum Constants {
        static let vstackSpacing: CGFloat = 3
    }

    // MARK: - Body
    public var body: some View {
        VStack(alignment: .leading, spacing: Constants.vstackSpacing) {
            Text("관련 링크 바로가기")
                .font(.app(.callout, weight: .semibold))
                .foregroundStyle(Color.black)

            Text(url)
                .font(.app(.footnote, weight: .regular))
                .foregroundStyle(Color.grey700)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
        }
    }
}


// MARK: - Preview
// url을 https:// 까지 입력해야 정상작동!
#Preview(traits: .sizeThatFitsLayout) {
    NoticeLinkCard(url: "https://www.naver.com")
}
