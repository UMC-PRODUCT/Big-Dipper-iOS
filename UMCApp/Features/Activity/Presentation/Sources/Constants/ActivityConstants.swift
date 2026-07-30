//
//  ActivityConstants.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/15/26.
//

import SwiftUI

/// Activity Presentation 전역에서 공유하는 레이아웃 상수 모음.
enum ActivityConstants {

    /// 미션 제출 결과 상태 카드 내부 패딩
    static let statusCardPadding: EdgeInsets = .init(
        top: 16, leading: 12, bottom: 16, trailing: 12)

    /// 상태 아이콘 크기
    static let statusIconSize: CGSize = .init(width: 24, height: 24)
}
