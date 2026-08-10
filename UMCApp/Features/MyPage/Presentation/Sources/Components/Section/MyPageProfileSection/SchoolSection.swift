//
//  SchoolSection.swift
//  MyPagePresentation
//
//  Created by euijjang97 on 8/10/26.
//

import SwiftUI

/// 소속 대학교를 읽기 전용 섹션으로 보여준다.
struct SchoolSection: View, Equatable {

    // MARK: - Property

    private let univ: String
    private let header: String

    // MARK: - Init

    init(univ: String, header: String) {
        self.univ = univ
        self.header = header
    }

    // MARK: - Body

    var body: some View {
        ReadOnlyTextField(placeholder: univ, header: header)
    }
}
