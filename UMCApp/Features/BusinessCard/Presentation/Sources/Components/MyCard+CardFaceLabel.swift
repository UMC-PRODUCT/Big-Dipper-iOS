//
//  MyCard+CardFaceLabel.swift
//  BusinessCardPresentation
//

import BusinessCardDomain
import Foundation

/// 명함 면(面) 표기의 단일 진실 원천.
///
/// `displayName` 은 그동안 `BusinessCardFaceView`·`BusinessCardSummaryView`·
/// `ReceivedCardCell` 에 글자 그대로 복제돼 있었다. 3D 카드가 네 번째 사본을 만드는 대신
/// 셋을 여기로 모았다 — 시안 규칙이 바뀌면 고칠 자리가 하나여야 한다.
///
/// 접근성 라벨은 `displayName` 과 달리 **면(面)이 있는 카드만** 여기 것을 쓴다.
/// 명함첩 셀·요약 카드는 뒤집히지 않아 「앞면.」 접두어가 붙으면 없는 뒷면을 암시한다.
extension MyCard {

    // MARK: - Display

    /// 시안 더미 `이름/닉네임` 규칙 — 닉네임이 비어 있으면 이름만 싣는다
    /// (`명함_l`·`명함_m`·`명함_s` 공통).
    ///
    /// - Note: 더미가 「이름 또는 닉네임」을 뜻하는 자리표시자일 수도 있다. 디자이너 확인 대기.
    var displayName: String {
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedNickname.isEmpty ? name : "\(name)/\(trimmedNickname)"
    }

    // MARK: - Accessibility

    /// 「앞면. 홍길동/길동, ○○대학교, iOS 파트, 12기」.
    ///
    /// 접두어가 **지금 보이는 면**을 전달한다. 3D 카드는 `RealityView` 라 VoiceOver 에
    /// 아무것도 주지 않아서, 면 정보가 라벨에 없으면 어느 쪽을 보고 있는지 알 방법이 없다.
    var frontFaceAccessibilityLabel: String {
        Constants.frontPrefix + [
            displayName,
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
