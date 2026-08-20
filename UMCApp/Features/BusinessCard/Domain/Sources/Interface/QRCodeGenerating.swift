//
//  QRCodeGenerating.swift
//  BusinessCardDomain
//
//  Created by One on 8/16/26.
//

import CoreGraphics
import Foundation

/// QR 생성 경계 (MP-F02 뒷면·MP-F04 공용).
///
/// CoreImage 의존은 Data 구현체에 격리한다 — Domain은 CGImage만 안다.
public protocol QRCodeGenerating: Sendable {
    func generate(from payload: String) throws -> CGImage
}
