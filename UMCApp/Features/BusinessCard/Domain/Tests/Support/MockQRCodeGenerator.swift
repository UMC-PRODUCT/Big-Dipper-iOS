//
//  MockQRCodeGenerator.swift
//  BusinessCardDomainTests
//
//  Created by One on 8/16/26.
//

import CoreGraphics
import Foundation
@testable import BusinessCardDomain

final class MockQRCodeGenerator: QRCodeGenerating, @unchecked Sendable {
    /// 마지막으로 전달받은 페이로드 (card.qrPayload 전달 검증용)
    private(set) var lastPayload: String?
    private(set) var generateCallCount = 0
    /// 세팅하면 generate가 이 에러를 던진다.
    var generateError: Error?

    func generate(from payload: String) throws -> CGImage {
        generateCallCount += 1
        lastPayload = payload
        if let generateError { throw generateError }
        return Self.makeStubImage()
    }

    /// 1×1 그레이스케일 스텁 이미지.
    private static func makeStubImage() -> CGImage {
        let context = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 1,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
        guard let image = context?.makeImage() else {
            preconditionFailure("스텁 CGImage 생성 실패")
        }
        return image
    }
}
