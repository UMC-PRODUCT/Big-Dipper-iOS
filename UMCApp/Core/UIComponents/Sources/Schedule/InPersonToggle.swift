//
//  InPersonToggle.swift
//  CoreUIComponents
//
//  Created by jaewon Lee on 8/3/26.
//

import CoreDesignSystem
import SwiftUI

/// 대면/비대면 전환 토글.
///
/// `isInPerson == true` 이면 대면 일정이며, 호출부는 이때만 장소 입력을 노출한다.
public struct InPersonToggle: View {

    // MARK: - Property

    @Binding private var isInPerson: Bool

    // MARK: - Initializer

    /// - Parameter isInPerson: 대면 일정 여부 바인딩
    public init(isInPerson: Binding<Bool>) {
        self._isInPerson = isInPerson
    }

    // MARK: - Body

    public var body: some View {
        Toggle(isOn: $isInPerson) {
            Text("대면 일정")
                .appFont(.body, color: Color.grey900)
        }
        .tint(.indigo500)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("InPersonToggle") {
    Form {
        InPersonToggle(isInPerson: .constant(true))
    }
}
#endif
