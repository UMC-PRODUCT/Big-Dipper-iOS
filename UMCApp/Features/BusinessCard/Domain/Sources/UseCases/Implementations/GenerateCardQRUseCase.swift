//
//  GenerateCardQRUseCase.swift
//  BusinessCardDomain
//
//  Created by One on 8/16/26.
//

import CoreGraphics
import Foundation

public final class GenerateCardQRUseCase:
    GenerateCardQRUseCaseProtocol, @unchecked Sendable {

    // MARK: - Property

    private let generator: QRCodeGenerating

    // MARK: - Init

    public init(generator: QRCodeGenerating) {
        self.generator = generator
    }

    // MARK: - Function

    /// 명함 뒷면(MP-F02)과 QR 화면(MP-F04)이 같은 페이로드를 쓰도록 `qrPayload` 하나만 본다.
    public func execute(for card: MyCard) throws -> CGImage {
        try generator.generate(from: card.qrPayload)
    }
}
