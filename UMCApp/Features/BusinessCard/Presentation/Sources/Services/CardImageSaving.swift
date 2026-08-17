//
//  CardImageSaving.swift
//  BusinessCardPresentation
//
//  Created by One on 8/18/26.
//

import CoreGraphics
import Foundation
import Photos
import UIKit

/// 생성된 QR 이미지를 사진 앱에 넣는다 (MP-F04 「이미지 저장」).
///
/// ViewModel 이 사진 라이브러리를 직접 만지지 않게 가르는 이음매다 — 권한 대화상자는
/// 테스트에서 띄울 수 없다.
public protocol CardImageSaving: Sendable {

    /// - Throws: 권한이 없으면 ``CardImageSaveError/permissionDenied``.
    func save(_ image: CGImage) async throws
}

public enum CardImageSaveError: Error {
    case permissionDenied
    case encodingFailed
}

/// `PHPhotoLibrary` 구현.
///
/// 권한은 `.addOnly` 만 요청한다. 저장에 읽기는 필요 없고, 전체 접근을 물으면
/// 사용자가 거절할 이유만 늘어난다 (`NSPhotoLibraryAddUsageDescription` 하나로 끝난다).
public struct PhotoLibraryCardImageSaver: CardImageSaving {

    // MARK: - Init

    public init() {}

    // MARK: - Function

    public func save(_ image: CGImage) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        // `.limited` 는 읽기 범위를 좁힌 상태라 추가는 허용된다.
        guard status == .authorized || status == .limited else {
            throw CardImageSaveError.permissionDenied
        }

        guard let data = UIImage(cgImage: image).pngData() else {
            throw CardImageSaveError.encodingFailed
        }

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset()
                .addResource(with: .photo, data: data, options: nil)
        }
    }
}
