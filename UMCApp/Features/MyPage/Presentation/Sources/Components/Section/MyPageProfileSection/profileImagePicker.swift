//
//  profileImagePicker.swift
//  MyPage
//
//  Created by 김동민 on 7/8/26.
//

import SwiftUI
import PhotosUI
import CoreDesignSystem
import CoreUIComponents

/// 프로필 이미지 선택 컴포넌트
///
/// PhotosPicker를 사용하여 사진 라이브러리에서 이미지를 선택할 수 있습니다.
/// 선택된 이미지가 있으면 해당 이미지를, 없으면 서버에서 받은 프로필 이미지를 표시합니다.
public struct profileImagePicker: View {
    
    // MARK: - Property
    
    /// 사용자가 선택한 사진 아이템 (PhotosPicker 바인딩)
    @Binding public var selectedPhotoItem: PhotosPickerItem?
    
    /// 선택된 사진이 UIImage로 변환된 결과
    private var selectedImage: UIImage?
    
    /// 기존 프로필 이미지 URL (서버에서 받은 값)
    private var profileImage: String?
    
    private enum Constants {
        /// 프로필 이미지 크기
        fileprivate static let imageSize:CGFloat = 112
        
        /// 버튼 텍스트
        fileprivate static let btnText: String = "사진 변경"
        
        /// 프로필 이미지 곡률
        fileprivate static let cornerRadius: CGFloat = 60
    }
    
    // MARK: - Function
    
    public var body: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            VStack(spacing: DefaultSpacing.spacing8, content: {
                // 새로 선택한 이미지가 있으면 우선 표시
                if let selectedImage = selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: Constants.imageSize, height: Constants.imageSize)
                        .clipShape(Circle())
                } else {
                    // 기존 프로필 이미지 표시 (URL에서 로드)
                    RemoteImage(
                        urlString: profileImage ?? "",
                        size: .init(width: Constants.imageSize, height: Constants.imageSize),
                        cornerRadius: Constants.cornerRadius
                    )
                }
                Text(Constants.btnText)
                    .appFont(.caption1, color: .blue)
            })
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets())
        .background(Color(.systemGroupedBackground))
    }
}
