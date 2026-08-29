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

    /// 명함 뒷면(MP-F02)과 QR 화면(MP-F04)이 같은 페이로드를 쓰도록 memberId 하나만 본다.
    ///
    /// 만료(#1226)는 **여기서만** 굽는다. QR 은 이미지로 저장·공유되어 손을 떠나는 유일한
    /// 경로라 수명을 묶을 값어치가 있는 반면, `MyCard/cardLink` 는 근거리 교환 페이로드와
    /// 명함첩 저장값에도 쓰여서 만료를 넣으면 저장된 명함이 시간이 지나 스스로 상한다.
    public func execute(for card: MyCard) throws -> CGImage {
        try generator.generate(from: CardLink.issued(memberId: card.memberId).urlString)
    }
}
