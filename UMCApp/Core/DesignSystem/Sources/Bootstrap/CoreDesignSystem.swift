//
//  CoreDesignSystem.swift
//  CoreDesignSystem
//
//  Created by euijjang97 on 4/27/26.
//

import CoreText
import Foundation
import os

private let logger = Logger(
    subsystem: "dev.umc.core.designsystem",
    category: "FontRegistration"
)

public enum CoreDesignSystem {

    /// 앱 시작 시 1회 호출 — Pretendard 폰트를 프로세스에 동적 등록합니다.
    ///
    /// `.staticFramework` 환경에서는 `Info.plist UIAppFonts` 가 동작하지 않으므로
    /// `Bundle.module` 을 통해 직접 등록합니다.
    public static func registerFonts() {
        let fontFiles = [
            "Pretendard-Regular",
            "Pretendard-Medium",
            "Pretendard-SemiBold",
        ]

        for name in fontFiles {
            guard let url = Bundle.module.url(forResource: name, withExtension: "otf") else {
                assertionFailure("폰트 파일 누락: \(name).otf")
                continue
            }

            var error: Unmanaged<CFError>?
            let success = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)

            if !success {
                let message = error?.takeRetainedValue().localizedDescription ?? "unknown"
                logger.error("폰트 등록 실패 [\(name, privacy: .public)]: \(message, privacy: .public)")
            }
        }
    }
}
