//
//  MultiplePhotoPickerManageable.swift
//  CorePhoto
//
//  Created by 김동민 on 7/5/26.
//

import SwiftUI
import UIKit
import PhotosUI
import os

private let logger = Logger(
    subsystem: "dev.umc.core.photo",
    category: "MultiplePhotoPickerManageable"
)

// MARK: - MultiplePhotoPickerManageable

/// PhotosPicker로 다중 이미지를 선택하고 로드하는 기능을 제공하는 프로토콜입니다.
///
/// ViewModel에서 이 프로토콜을 채택하면 PhotosPicker와 연동하여 여러 이미지를 한번에 로드할 수 있습니다.
///
/// - Important: `PhotosPicker(selection:maxSelectionCount:)`를 사용하여 다중 선택 모드로 설정합니다.
///
/// - Usage:
/// ```swift
/// @Observable
/// final class MyViewModel: MultiplePhotoPickerManageable {
///     var selectedPhotoItems: [PhotosPickerItem] = []
///     var selectedImages: [UIImage] = []
///
///     // 선택적: 이미지 로드 후 추가 작업이 필요한 경우
///     func didLoadImages(images: [UIImage]) async {
///         // 예: 서버 일괄 업로드, 압축 등
///     }
/// }
///
/// // View
/// PhotosPicker(selection: $viewModel.selectedPhotoItems, maxSelectionCount: 5) {
///     Label("사진 선택 (최대 5장)", systemImage: "photo.on.rectangle.angled")
/// }
/// .onChange(of: viewModel.selectedPhotoItems) { _, _ in
///     Task { await viewModel.loadSelectedImages() }
/// }
/// ```
public protocol MultiplePhotoPickerManageable: AnyObject {
    /// PhotosPicker에서 선택된 여러 PhotosPickerItem (SwiftUI View 바인딩 용)
    var selectedPhotoItems: [PhotosPickerItem] { get set }
    
    /// 로드된 여러 이미지 데이터 (UIImage 배열)
    var selectedImages: [UIImage] { get set }
    
    /// 선택한 `selectedPhotoItems`로부터 모든 이미지를 로드하는 메서드
    ///
    /// 일부 이미지 로드에 실패하더라도 성공한 이미지는 `selectedImages`에 저장됩니다.
    ///
    /// - Note: 로드 완료 후 내부에서 `didLoadImages(images:)`를 호출합니다.
    @MainActor
    func loadSelectedImages() async
    
    /// 이미지들이 성공적으로 로드된 후 호출되는 후크 메서드
    ///
    /// 기본 구현은 비어있으며, 필요 시 오버라이드하여 추가 로직을 구현할 수 있습니다.
    ///
    /// - Parameter images: 로드된 모든 이미지 배열 (실패한 항목은 제외)
    ///
    /// - Example:
    /// ```swift
    /// func didLoadImages(images: [UIImage]) async {
    ///     // 이미지 검증
    ///     let validImages = images.filter { $0.size.width >= 100 }
    ///     // 서버로 일괄 업로드
    ///     await uploadImages(validImages)
    /// }
    /// ```
    @MainActor
    func didLoadImages(images: [UIImage]) async
}

// MARK: - MultiplePhotoPickerManageable Default Implementation

public extension MultiplePhotoPickerManageable {
    /// 선택된 다중 이미지를 비동기로 로드하는 기본 구현
    ///
    /// - Note:
    ///   - 일부 이미지 로드 실패 시에도 성공한 이미지는 `selectedImages`에 포함됩니다.
    ///   - 로드 실패한 항목은 건너뛰며, 통합 로그에 에러가 기록됩니다.
    @MainActor
    func loadSelectedImages() async {
        guard !selectedPhotoItems.isEmpty else {
            selectedImages = []
            return
        }
        
        var loadedImages: [UIImage] = []
        
        for item in selectedPhotoItems {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    loadedImages.append(uiImage)
                } else {
                    logger.error("이미지 데이터 변환 실패 (항목 건너뜀)")
                }
            } catch {
                logger.error(
                    "이미지 로드 실패 (항목 건너뜀): \(error.localizedDescription, privacy: .public)"
                )
            }
        }
        
        selectedImages = loadedImages
        await didLoadImages(images: loadedImages)
    }
    
    /// 이미지 로드 후 호출되는 후크 메서드의 기본 구현(빈 구현)
    @MainActor
    func didLoadImages(images: [UIImage]) async {
        // 기본 구현은 비어있음 (필요 시 채택하는 쪽에서 오버라이드)
    }
}
