//
//  ImageAttachmentCard.swift
//  NoticePresentation
//
//  Created by 이예지 on 7/3/26.
//

import SwiftUI
import PhotosUI
import Kingfisher
import CoreDesignSystem
import CoreUIComponents
import CoreNetwork
import NoticeDomain

/// 공지 첨부 이미지 카드 컴포넌트
///
/// 로딩 상태, 로컬 이미지(`imageData`), 원격 이미지(`imageURL`)를 지원하며,
/// `onDismiss` 클로저로 삭제 동작을 위임합니다.
struct ImageAttachmentCard: View, Equatable {

    // MARK: - Property
    let id: UUID
    let imageData: Data?
    let imageURL: String?
    let isLoading: Bool
    var onDismiss: () -> Void

    // MARK: - Constant
    fileprivate enum Constants {
        static let imageSize: CGSize = .init(width: 100, height: 100)
        static let xmarkPadding: CGFloat = 10
    }

    // MARK: - Equatable

    /// 클로저는 비교 대상에서 제외하고 id와 로딩 상태만 비교
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id &&
        lhs.isLoading == rhs.isLoading
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topTrailing) {
            imageCard
            if !isLoading {
                xButton
            }
        }
    }

    // MARK: - Private View

    /// 이미지 카드 본체 (로딩/로컬/원격 상태별 분기)
    private var imageCard: some View {
        imageContent
            .frame(width: Constants.imageSize.width, height: Constants.imageSize.height)
            .clipShape(RoundedRectangle(cornerRadius: DefaultConstant.defaultCornerRadius))
            .glassEffect(.clear, in: .rect(cornerRadius: DefaultConstant.defaultCornerRadius))
    }
    
    @ViewBuilder
    private var imageContent: some View {
        if isLoading {
            RoundedRectangle(cornerRadius: DefaultConstant.defaultCornerRadius)
                .fill(Color.grey200)
                .overlay {
                    Progress(size: .small)
                }
        } else if let imageData = imageData, let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else if let imageURL, let url = resolveImageURL(from: imageURL) {
            KFImage(url)
                .placeholder {
                    RoundedRectangle(cornerRadius: DefaultConstant.defaultCornerRadius)
                        .fill(Color.grey200)
                }
                .resizable()
                .scaledToFill()
        }
    }

    /// 이미지 카드 우상단 삭제 버튼
    private var xButton: some View {
        Button(action: {
            onDismiss()
        }) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(Color.grey700)
                .glassEffect()
                .padding(Constants.xmarkPadding)
        }
    }

    /// 이미지 문자열을 앱에서 사용할 수 있는 URL 문자열로 정규화합니다.
    /// 상대 식별값(예: 업로드 파일 ID)도 서버 파일 조회 API 경로로 변환합니다.
    private func resolveImageURL(from rawURL: String) -> URL? {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        if let absoluteURL = URL(string: trimmed), absoluteURL.scheme != nil {
            return absoluteURL
        }
        
        return NetworkConfig.baseURL.appendingPathComponent("api/v1/storage/\(trimmed)")
    }
}

// MARK: - Preview
#if DEBUG
#Preview("기본 이미지 카드") {
    @Previewable @State var noticeImageItems: [NoticeImageItem] = []
    @Previewable @State var selectedItems: [PhotosPickerItem] = []
    
    VStack {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(noticeImageItems) { item in
                    ImageAttachmentCard(
                        id: item.id,
                        imageData: item.imageData,
                        imageURL: item.imageURL,
                        isLoading: item.isLoading
                    ) {
                        noticeImageItems.removeAll { $0.id == item.id }
                    }
                }
            }
        }
        PhotosPicker("사진 추가", selection: $selectedItems, maxSelectionCount: 10, matching: .images)
    }
    .onChange(of: selectedItems) { _, newValues in
        Task {
            for item in newValues {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    noticeImageItems.append(NoticeImageItem(imageData: data, isLoading: false))
                }
            }
            selectedItems.removeAll()
        }
    }
}

#Preview("로딩 중인 카드") {
    HStack(spacing: 12) {
        // 로딩 중인 카드
        ImageAttachmentCard(
            id: UUID(),
            imageData: nil,
            imageURL: nil,
            isLoading: true,
            onDismiss: {}
        )
        
        // 로딩 중인 카드 2개
        ImageAttachmentCard(
            id: UUID(),
            imageData: nil,
            imageURL: nil,
            isLoading: true,
            onDismiss: {}
        )
        
        // 로드된 카드 (예시용 더미 데이터)
        ImageAttachmentCard(
            id: UUID(),
            imageData: UIImage(systemName: "photo")?.pngData(),
            imageURL: nil,
            isLoading: false,
            onDismiss: {}
        )
    }
    .padding()
}
#endif
