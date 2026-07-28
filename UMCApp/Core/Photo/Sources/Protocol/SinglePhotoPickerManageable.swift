//
//  SinglePhotoPickerManageable.swift
//  CorePhoto
//
//  Created by 김동민 on 7/5/26.
//

import UIKit
import SwiftUI
import PhotosUI
import os

private let logger = Logger(
    subsystem: "dev.umc.core.photo",
    category: "SinglePhotoPickerManageable"
)

// MARK: - SinglePhotoPickerManageable

/// PhotosPicker로 단일 이미지를 선택하고 로드하는 기능을 제공하는 프로토콜입니다.
///
/// ViewModel에서 이 프로토콜을 채택하면 PhotosPicker와 연동하여 단일 이미지를 간편하게 로드할 수 있습니다.
///
/// - Important: `PhotosPicker(selection:)`를 사용하여 단일 선택 모드로 설정합니다.
///
/// - Usage:
/// ```swift
/// @Observable
/// final class MyViewModel: SinglePhotoPickerManageable {
///     var selectedPhotoItem: PhotosPickerItem?
///     var selectedImage: UIImage?
///
///     // 선택적: 이미지 로드 후 추가 작업이 필요한 경우
///     func didLoadImage(image: UIImage) async {
///         // 예: 서버 업로드, 리사이징 등
///     }
/// }
///
/// // View
/// PhotosPicker(selection: $viewModel.selectedPhotoItem) {
///     Label("사진 선택", systemImage: "photo")
/// }
/// .onChange(of: viewModel.selectedPhotoItem) { _, _ in
///     Task { await viewModel.loadSelectedImage() }
/// }
/// ```
public protocol SinglePhotoPickerManageable: AnyObject {
    /// PhotoPicker에서 선택된 단일 PhotoPickerItem (SwiftUI View 바인딩 전용)
    var selectedPhotoItem: PhotosPickerItem? { get set }
    
    /// 로드된 이미지 데이터(UIImage)
    var selectedImage: UIImage? { get set }
    
    /// 선택한 `selectedPhotoItem`으로부터 실제 이미지를 로드하는 메서드
    ///
    /// - Note: 로드 성공 시 내부에서 `didLoadImage(image:)`를 호출합니다.
    @MainActor
    func loadSelectedImage() async
    
    /// 이미지가 성공적으로 로드된 후 호출되는 후크 메서드
    ///
    /// 기본 구현은 비어있으며, 필요 시 오버라이드하여 추가 로직을 구현할 수 있습니다.
    ///
    /// - Parameter image: 로드된 이미지
    ///
    /// - Example:
    /// ```swift
    /// func didLoadImage(image: UIImage) async {
    ///     // 서버로 이미지 업로드
    ///     await uploadImage(image)
    /// }
    /// ```
    @MainActor
    func didLoadImage(image: UIImage) async
}

// MARK: - SinglePhotoPickerManageable Default Implementation

public extension SinglePhotoPickerManageable {
    /// 선택된 단일 이미지를 비동기로 로드하는 기본 구현
    ///
    /// - Note: 로드 실패 시 `selectedImage`는 nil로 설정되며, 통합 로그에 에러가 기록됩니다.
    @MainActor
    func loadSelectedImage() async {
        guard let item = selectedPhotoItem else {
            selectedImage = nil
            return
        }
        
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                selectedImage = uiImage
                await didLoadImage(image: uiImage)
            } else {
                selectedImage = nil
                logger.error("이미지 데이터 변환 실패")
            }
        } catch {
            selectedImage = nil
            logger.error("이미지 로드 실패: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    /// 이미지 로드 후 호출되는 후크 메서드의 기본 구현(빈 구현)
    @MainActor
    func didLoadImage(image: UIImage) async {
        //기본 구현은 비어있음 (필요 시 채택하는 쪽에서 오버라이드)
    }
}

