//
//  ReadOnlyTextField.swift
//  MyPagePresentation
//
//  Created by euijjang97 on 8/10/26.
//

import CoreUIComponents
import SwiftUI

/// 수정 불가능한 사용자 정보(이름, 학교 등)를 한 섹션으로 보여주는 읽기 전용 필드.
struct ReadOnlyTextField: View, Equatable {

    // MARK: - Property

    private let placeholder: String
    private let header: String

    // MARK: - Init

    init(placeholder: String, header: String) {
        self.placeholder = placeholder
        self.header = header
    }

    // MARK: - Body

    var body: some View {
        Section(content: {
            // 값을 prompt로만 넘겨 편집 불가 상태에서도 회색 본문처럼 읽히게 한다.
            TextField("", text: .constant(""), prompt: Text(placeholder))
                .disabled(true)
        }, header: {
            SectionHeaderView(title: header, weight: .semibold)
        })
    }
}
