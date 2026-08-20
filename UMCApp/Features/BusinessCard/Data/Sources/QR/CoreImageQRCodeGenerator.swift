//
//  CoreImageQRCodeGenerator.swift
//  BusinessCardData
//
//  Created by One on 8/16/26.
//

import CoreImage.CIFilterBuiltins
import Foundation
import BusinessCardDomain

/// CIQRCodeGenerator 기반 QR 생성기 (MP-F02 뒷면·MP-F04 공용).
///
/// 스파이크(2026-08-15 실기기) 검증 파라미터: 보정 레벨 M, 정수 배율 12 업스케일.
/// "QR에 Glass/블러 금지"의 렌더링 처리(interpolation none 등)는 View 몫.
public struct CoreImageQRCodeGenerator: QRCodeGenerating {

    // MARK: - Constants

    private enum Constants {
        static let correctionLevel = "M"
        static let upscaleFactor: CGFloat = 12
    }

    // MARK: - Error

    public enum GenerationError: Error {
        case emptyPayload
        case renderingFailed
    }

    // MARK: - Init

    public init() {}

    // MARK: - Function

    public func generate(from payload: String) throws -> CGImage {
        guard !payload.isEmpty else { throw GenerationError.emptyPayload }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = Constants.correctionLevel

        guard let output = filter.outputImage else { throw GenerationError.renderingFailed }
        let scaled = output.transformed(
            by: CGAffineTransform(scaleX: Constants.upscaleFactor, y: Constants.upscaleFactor)
        )
        guard let image = CIContext().createCGImage(scaled, from: scaled.extent) else {
            throw GenerationError.renderingFailed
        }
        return image
    }
}
