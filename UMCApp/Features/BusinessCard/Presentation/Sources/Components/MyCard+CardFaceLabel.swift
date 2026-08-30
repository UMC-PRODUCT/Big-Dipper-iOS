//
//  MyCard+CardFaceLabel.swift
//  BusinessCardPresentation
//

import BusinessCardDomain
import Foundation

/// 명함 면(面) 표기의 단일 진실 원천.
///
/// 표기 이름은 ``MyCard/nameWithNickname``(#1236) 한 곳에 있고 여기서는 그것을 읽기만 한다.
///
/// 접근성 라벨은 표기 이름과 달리 **면(面)이 있는 카드만** 여기 것을 쓴다.
/// 명함첩 셀·요약 카드는 뒤집히지 않아 「앞면.」 접두어가 붙으면 없는 뒷면을 암시한다.
extension MyCard {


    // MARK: - Accessibility

    /// 「앞면. 홍길동/길동, ○○대학교, iOS 파트, 12기」.
    ///
    /// 접두어가 **지금 보이는 면**을 전달한다. 3D 카드는 `RealityView` 라 VoiceOver 에
    /// 아무것도 주지 않아서, 면 정보가 라벨에 없으면 어느 쪽을 보고 있는지 알 방법이 없다.
    var frontFaceAccessibilityLabel: String {
        Constants.frontPrefix + [
            nameWithNickname,
            university,
            "\(partDisplayName)\(Constants.partSuffix)",
            "\(generation)\(Constants.generationSuffix)"
        ].joined(separator: Constants.separator)
    }

    /// 「뒷면. QR 코드, github.com/umc, …」.
    ///
    /// 값 없는 링크는 빼고 읽는다 — `BusinessCardFaceView.linkRow` 가 「값 없으면 줄 자체를
    /// 안 그린다」는 규칙과 같다. 빈 줄을 읽으면 서버 미입력이 링크가 있는 것처럼 들린다.
    var backFaceAccessibilityLabel: String {
        let links = [github, linkedIn, blog].compactMap { link -> String? in
            guard let link, !link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return link
        }
        return Constants.backPrefix
            + ([Constants.qrLabel] + links).joined(separator: Constants.separator)
    }
}

// MARK: - Constants

private enum Constants {
    static let frontPrefix = "앞면. "
    static let backPrefix = "뒷면. "
    static let separator = ", "
    static let partSuffix = " 파트"
    static let generationSuffix = "기"
    static let qrLabel = "QR 코드"
}
