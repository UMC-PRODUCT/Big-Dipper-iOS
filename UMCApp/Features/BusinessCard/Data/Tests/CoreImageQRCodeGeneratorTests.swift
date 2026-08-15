//
//  CoreImageQRCodeGeneratorTests.swift
//  BusinessCardDataTests
//
//  Created by One on 8/16/26.
//

import CoreImage
import Testing
import BusinessCardDomain
@testable import BusinessCardData

@Suite("CoreImageQRCodeGenerator — 생성·역스캔 왕복")
struct CoreImageQRCodeGeneratorTests {

    @Test("생성한 QR을 역스캔하면 원본 페이로드가 나온다")
    func roundtripThroughDetector() throws {
        let payload = "umc://card/42"

        let image = try CoreImageQRCodeGenerator().generate(from: payload)

        let detector = CIDetector(
            ofType: CIDetectorTypeQRCode, context: nil,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        )
        let features = detector?.features(in: CIImage(cgImage: image)) ?? []
        let message = (features.first as? CIQRCodeFeature)?.messageString
        #expect(message == payload)
    }

    @Test("빈 페이로드는 에러를 던진다")
    func emptyPayloadThrows() {
        #expect(throws: (any Error).self) {
            _ = try CoreImageQRCodeGenerator().generate(from: "")
        }
    }
}
