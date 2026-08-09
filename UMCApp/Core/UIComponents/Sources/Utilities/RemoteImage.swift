//
//  RemoteImage.swift
//  CoreDesignSystem
//
//  Created by 이예지 on 6/1/26.
//

import SwiftUI
import Kingfisher

/// Kingfisher를 사용하여 원격 이미지를 로드하고 표시하는 커스텀 뷰입니다.
///
/// 로딩 실패 시 기본 이미지(플레이스홀더)를 표시하거나, 커스텀 에러 처리를 수행합니다.
///
/// - Usage:
/// ```swift
/// RemoteImage(
///     urlString: "https://example.com/image.jpg",
///     size: CGSize(width: 100, height: 100),
///     cornerRadius: 10,
///     contentMode: .fill
/// )
/// ```
public struct RemoteImage: View {
    public typealias ContentMode = SwiftUI.ContentMode
    
    // MARK: - Properties

    @Environment(\.displayScale) private var displayScale
    
    /// 이미지 로드 실패 상태 (true일 경우 실패)
    @State private var isError: Bool = false
    /// 이미지 로드 진행 상태
    @State private var isLoading: Bool = false
    
    /// 로드할 이미지 URL 문자열
    public let urlString: String
    
    /// 이미지 뷰의 목표 크기
    public let size: CGSize
    
    /// 이미지의 모서리 둥글기 반경 (기본값: 15)
    public let cornerRadius: CGFloat
    
    /// 이미지의 가로세로 비율 (옵셔널)
    public let ratio: CGFloat?
    
    /// 이미지 콘텐츠 모드 (fill, fit 등)
    let contentMode: ContentMode

    // MARK: - Init
    
    /// RemoteImage 뷰를 초기화합니다.
    /// - Parameters:
    ///   - urlString: 이미지 URL 문자열
    ///   - size: 이미지 뷰의 크기 (width, height)
    ///   - cornerRadius: 모서리 둥글기 (기본값: 15)
    ///   - ratio: 이미지 비율 (옵셔널)
    ///   - contentMode: 콘텐츠 모드 (기본값: .fill)
    public init(
        urlString: String,
        size: CGSize,
        cornerRadius: CGFloat = 15,
        ratio: CGFloat? = nil,
        contentMode: ContentMode = .fill
    ) {
        self.urlString = urlString
        self.size = size
        self.cornerRadius = cornerRadius
        self.ratio = ratio
        self.contentMode = contentMode
    }
    
    // MARK: - Body
    
    public var body: some View {
        imageContent
            .aspectRatio(ratio, contentMode: contentMode)
            .frame(width: size.width, height: size.height)
            .clipShape(.circle)
    }
    
    @ViewBuilder
    private var imageContent: some View {
        if let url = URL(string: urlString), !isError {
            KFImage.url(url)
                .placeholder { ProgressView().tint(.gray) }
                .setProcessor(DownsamplingImageProcessor(
                    size: CGSize(
                        width: size.width * displayScale,
                        height: size.height * displayScale
                    )
                ))
                .fade(duration: 0.25)
                .onSuccess { _ in }
                .onFailure { _ in isError = true }
                .resizable()
        } else {
            Image.umcDefaultProfile
                .resizable()
        }
    }
}
