//
//  ThreadClassificationPresenting.swift
//  CommunityPresentation
//

import Foundation
import CommunityDomain
import UMCFoundation

/// ``ThreadClassificationCard`` 가 읽는 분류 상태.
///
/// 생성 폼(#1132)과 편집 폼(#1134)이 같은 카드를 쓰는데 ViewModel 은 서로 다르다. 카드가 어느
/// 한쪽 타입을 직접 들면 다른 쪽은 250줄짜리 카드를 복제해야 해서, 카드가 실제로 읽는 값만
/// 이 프로토콜로 묶는다.
@MainActor
public protocol ThreadClassificationPresenting: AnyObject {

    var classification: Loadable<ThreadClassification> { get }

    /// 이 기기에서 자동 분류를 시도해 볼 수 있는지. `false` 면 카드가 수동 선택 안내로 바뀐다.
    var isClassificationAvailable: Bool { get }

    /// "분류하기" 를 누를 수 있는지.
    var canClassify: Bool { get }

    /// 카드 안에 인라인으로 띄울 실패 메시지.
    var classificationErrorMessage: String? { get }

    func classify() async
}

extension CommunityThreadCreateViewModel: ThreadClassificationPresenting {}
