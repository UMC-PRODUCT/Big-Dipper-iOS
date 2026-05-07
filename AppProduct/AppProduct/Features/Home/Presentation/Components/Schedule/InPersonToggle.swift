//
//  InPersonToggle.swift
//  AppProduct
//
//  Created by jaewon Lee on 5/7/26.
//

import SwiftUI

/// 대면/비대면 전환 토글 컴포넌트
///
/// `isInPerson == true` 이면 "대면 일정" 레이블과 함께 토글이 ON 상태입니다.
struct InPersonToggle: View {

    @Binding var isInPerson: Bool

    var body: some View {
        Toggle(isOn: $isInPerson) {
            Text("대면 일정")
                .appFont(.body, color: .black)
        }
        .tint(.indigo500)
    }
}
