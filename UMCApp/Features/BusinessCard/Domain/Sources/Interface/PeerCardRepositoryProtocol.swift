//
//  PeerCardRepositoryProtocol.swift
//  BusinessCardDomain
//
//  Created by One on 8/16/26.
//

import Foundation

/// 상대 명함 조회 경계 (QR 딥링크 스캔 전용).
///
/// QR 딥링크(`umc://card/{memberId}`)는 **memberId 하나만** 싣는다. 명함 내용은 QR 안에
/// 없으므로, 스캔한 쪽이 이 경계로 서버에 물어봐야 명함이 완성된다.
///
/// ``BusinessCardRepositoryProtocol``(내 명함)과 분리한 이유는 조회 대상이 다르기 때문이다 —
/// 내 명함은 정본 프로필 캐시를 위임받지만, 상대 명함은 캐시가 없는 단발 조회이고 서버가
/// 공개 응답(email·상벌점 마스킹)을 내려준다.
public protocol PeerCardRepositoryProtocol: Sendable {

    /// memberId로 상대 명함을 조회한다.
    ///
    /// - Parameter memberId: QR 딥링크에서 파싱한 식별자 (서버 응답 정수라 `String`)
    /// - Returns: 서버 공개 프로필로 복원한 명함. `email`은 서버가 마스킹하므로 항상 `nil`이다.
    func fetchCard(memberId: String) async throws -> MyCard
}
