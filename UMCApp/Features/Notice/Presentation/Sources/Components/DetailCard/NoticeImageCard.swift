//
//  NoticeImageCard.swift
//  NoticeData
//
//  Created by 이예지 on 6/1/26.
//

import SwiftUI
import Kingfisher
import UMCFoundation
import CoreDesignSystem
import CoreUIComponents
import NoticeDomain

// MARK: - NoticeImageCard
/// 공지 상세에서 첨부 이미지 썸네일 목록과 전체화면 뷰어를 제공하는 카드 컴포넌트
public struct NoticeImageCard: View {
    
    // MARK: - Property
    public let imageURLs: [String]
    @State private var selectedImageIndex: Int?
    
    // MARK: - Constants
    fileprivate enum Constants {
        static let imageSize: CGFloat = 120
        static let bottomPadding: CGFloat = 20
        static let thumbnailSpacing: CGFloat = DefaultSpacing.spacing8
    }
    
    // MARK: - Body
    public var body: some View {
        thumbnailSection
            .fullScreenCover(item: imageViewerBinding) { (item: ImageViewerItem) in
            ImageViewerScreen(
                imageURLs: imageURLs,
                selectedIndex: Int(item.index) ?? 0,
                onDismiss: { selectedImageIndex = nil }
            )
        }
    }

    // MARK: - Thumbnail Section

    private var thumbnailSection: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Constants.thumbnailSpacing) {
                ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
                    thumbnailImage(url: url, index: index)
                }
            }
            .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
        }
        .scrollIndicators(.hidden)
    }

    private func thumbnailImage(url: String, index: Int) -> some View {
        KFImage(resolveNoticeImageURL(from: url))
            .placeholder {
                Progress(size: .regular)
                    .frame(width: Constants.imageSize, height: Constants.imageSize)
                    .background(Color(.systemGroupedBackground))
            }
            .noticeImageCommonStyle()
            .aspectRatio(contentMode: .fill)
            .frame(width: Constants.imageSize, height: Constants.imageSize)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: DefaultConstant.defaultCornerRadius))
            .onTapGesture {
                selectedImageIndex = index
            }
    }

    private var imageViewerBinding: Binding<ImageViewerItem?> {
        Binding(
            get: { selectedImageIndex.map { ImageViewerItem(index: String($0)) } },
            set: { selectedImageIndex = $0.flatMap { Int($0.index) } }
        )
    }
}

// MARK: - ImageViewerScreen
/// 전체화면 이미지 뷰어
public struct ImageViewerScreen: View {
    
    // MARK: - Property
    public let imageURLs: [String]
    @State var selectedIndex: Int
    @State private var prefetcher: ImagePrefetcher?
    @State private var verticalDragOffset: CGFloat = .zero
    public let onDismiss: () -> Void
    
    // MARK: - Constant
    fileprivate enum Constants {
        static let closeButtonPadding: CGFloat = DefaultSpacing.spacing8
        static let backgroundBlurRadius: CGFloat = 18
        static let backgroundDimOpacity: Double = 0.25
        static let foregroundHorizontalCount: Int = 10
        static let foregroundHorizontalSpan: Int = 9
        static let foregroundVerticalCount: Int = 10
        static let foregroundVerticalSpan: Int = 5
        static let viewerDownsampleSize: CGSize = .init(width: 1440, height: 1440)
        static let dismissDragThreshold: CGFloat = 120
        static let dragResetAnimation: Animation = .spring(response: 0.28, dampingFraction: 0.85)
    }
    
    // MARK: - Body
    public var body: some View {
        ZStack(alignment: .topTrailing) {
            TabView(selection: $selectedIndex) {
                ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
                    pageImage(url: url)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()

            closeButton
        }
        .offset(y: max(0, verticalDragOffset))
        .gesture(dismissDragGesture)
        .task {
            startPrefetching()
        }
        .onDisappear(perform: stopPrefetching)
    }

    private func pageImage(url: String) -> some View {
        ZStack {
            blurredBackgroundImage(url: url)
            foregroundImage(url: url)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func blurredBackgroundImage(url: String) -> some View {
        let image = KFImage(resolveNoticeImageURL(from: url))
            .placeholder {
                Color.black
            }
            .noticeImageViewerStyle()
            .aspectRatio(contentMode: .fill)
            .ignoresSafeArea()
            .blur(radius: Constants.backgroundBlurRadius)
            .overlay {
                Color.black.opacity(Constants.backgroundDimOpacity)
            }
            .clipped()
            .backgroundExtensionEffect()

        image
    }

    private func foregroundImage(url: String) -> some View {
        KFImage(resolveNoticeImageURL(from: url))
            .placeholder {
                Progress(
                    progressColor: .grey200,
                    message: "이미지 로딩중",
                    messageColor: .grey400,
                    size: .large
                )
            }
            .noticeImageViewerStyle()
            .aspectRatio(contentMode: .fit)
            .containerRelativeFrame(
                .horizontal,
                count: Constants.foregroundHorizontalCount,
                span: Constants.foregroundHorizontalSpan,
                spacing: 0
            )
            .containerRelativeFrame(
                .vertical,
                count: Constants.foregroundVerticalCount,
                span: Constants.foregroundVerticalSpan,
                spacing: 0
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var closeButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark.circle.fill")
                .font(.title)
                .foregroundStyle(.white)
                .padding(Constants.closeButtonPadding)
        }
    }

    private var dismissDragGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .onChanged { value in
                guard value.translation.height > 0 else { return }
                verticalDragOffset = value.translation.height
            }
            .onEnded { value in
                if value.translation.height > Constants.dismissDragThreshold {
                    onDismiss()
                } else {
                    withAnimation(Constants.dragResetAnimation) {
                        verticalDragOffset = .zero
                    }
                }
            }
    }

    // MARK: - Prefetch

    private func startPrefetching() {
        let urls = imageURLs
            .compactMap(resolveNoticeImageURL(from:))
        guard !urls.isEmpty else { return }

        let prefetcher = ImagePrefetcher(urls: urls)
        self.prefetcher = prefetcher
        prefetcher.start()
    }

    private func stopPrefetching() {
        prefetcher?.stop()
        prefetcher = nil
    }

}

// MARK: - Image URL Resolver

/// 공지 이미지 문자열을 URL로 변환합니다.
///
/// 절대 URL이면 그대로, 상대 식별값(업로드 파일 ID)이면 서버 파일 조회 API 경로로 합성합니다.
private func resolveNoticeImageURL(from rawURL: String) -> URL? {
    let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    if let absoluteURL = URL(string: trimmed), absoluteURL.scheme != nil {
        return absoluteURL
    }

    guard let baseURL = URL(string: Config.API.baseURLString) else { return nil }
    return baseURL.appendingPathComponent("api/v1/storage/\(trimmed)")
}

// MARK: - KFImage Styling
private extension KFImage {
    /// 공지 이미지 썸네일/뷰어에서 공통으로 사용하는 네트워크 이미지 로딩 스타일입니다.
    func noticeImageCommonStyle() -> some View {
        self
            .retry(maxCount: 3, interval: .seconds(3))
            .fade(duration: 0.3)
            .resizable()
    }

    /// 이미지 뷰어 전용 스타일 (스와이프 중 끊김 최소화를 위해 페이드 없이 캐시 우선)
    func noticeImageViewerStyle() -> some View {
        self
            .retry(maxCount: 2, interval: .seconds(1))
            .downsampling(size: .init(width: 1440, height: 1440))
            .cacheOriginalImage()
            .cancelOnDisappear(true)
            .resizable()
    }
}

// MARK: - Preview
#if DEBUG
#Preview(traits: .sizeThatFitsLayout) {
    NoticeImageCard(imageURLs: [
        "https://picsum.photos/200/200",
        "https://picsum.photos/200/201",
        "https://picsum.photos/200/202",
        "https://picsum.photos/200/203",
        "https://picsum.photos/200/204"
    ])
}

#Preview("로딩 중", traits: .sizeThatFitsLayout) {
    NoticeImageCard(imageURLs: [
        "https://httpbin.org/delay/10",
        "https://httpbin.org/delay/10",
        "https://httpbin.org/delay/10"
    ])
}
#endif
