//
//  RemoteImage.swift
//  AppProduct
//
//  Created by euijjang97 on 1/24/26.
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
struct RemoteImage: View {
    typealias ContentMode = SwiftUI.ContentMode
    
    // MARK: - Properties

    @Environment(\.displayScale) private var displayScale
    
    /// 이미지 로드 실패 상태 (true일 경우 실패)
    @State private var isError: Bool = false
    /// 이미지 로드 진행 상태
    @State private var isLoading: Bool = false
    
    /// 로드할 이미지 URL 문자열
    let urlString: String
    
    /// 이미지 뷰의 목표 크기
    let size: CGSize
    
    /// 이미지의 모서리 둥글기 반경 (기본값: 15)
    let cornerRadius: CGFloat
    
    /// 이미지의 가로세로 비율 (옵셔널)
    let ratio: CGFloat?
    
    /// 이미지 콘텐츠 모드 (fill, fit 등)
    let contentMode: ContentMode
    
    /// 로드 실패 시 표시할 플레이스홀더 시스템 이미지 이름
    let placeholderImage: String
    
    // MARK: - Init
    
    /// RemoteImage 뷰를 초기화합니다.
    /// - Parameters:
    ///   - urlString: 이미지 URL 문자열
    ///   - size: 이미지 뷰의 크기 (width, height)
    ///   - cornerRadius: 모서리 둥글기 (기본값: 15)
    ///   - ratio: 이미지 비율 (옵셔널)
    ///   - contentMode: 콘텐츠 모드 (기본값: .fill)
    ///   - placeholderImage: 실패 시 보여줄 시스템 이미지 이름 (기본값: "person.circle.fill")
    init(
        urlString: String,
        size: CGSize,
        cornerRadius: CGFloat = 15,
        ratio: CGFloat? = nil,
        contentMode: ContentMode = .fill,
        placeholderImage: String = "person.circle.fill"
    ) {
        self.urlString = urlString
        self.size = size
        self.cornerRadius = cornerRadius
        self.ratio = ratio
        self.contentMode = contentMode
        self.placeholderImage = placeholderImage
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if let url = URL(string: urlString), !isError {
                KFImage(url)
                    .downsampling(size: CGSize(
                        width: size.width * displayScale,
                        height: size.height * displayScale
                    ))
                    .scaleFactor(displayScale)
                    .fade(duration: 0.25)
                    .onSuccess { _ in
                        isLoading = false
                    }
                    .onFailure { _ in
                        isLoading = false
                        isError = true // 실패 시 상태 변경
                    }
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .task {
                        isLoading = true
                    }
            } else {
                // 실패 시 SwiftUI가 직접 벡터 이미지를 그리도록 함
                Image(.defaultProfile)
                    .resizable()
                    .symbolRenderingMode(.multicolor) // 시스템 이미지 고화질 유지
                    .foregroundStyle(.black)
            }
        }
        .aspectRatio(ratio, contentMode: contentMode)
        .frame(width: size.width, height: size.height)
        .clipShape(.circle)
        .overlay {
            if isLoading {
                ProgressView()
                    .tint(.gray)
            }
        }
    }
}
