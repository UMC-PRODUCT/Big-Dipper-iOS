//
//  SignUpSchoolSection.swift
//  AppProduct
//
//  Created by euijjang97 on 4/29/26.
//

import SwiftUI

/// 회원가입 학교 선택 섹션
///
/// `Loadable<[School]>` 상태에 따라 세 가지 UI를 분기합니다.
/// - `.idle` / `.loading`: 빈 옵션 목록 + 기본 placeholder (선택 불가)
/// - `.loaded`: 실제 학교 목록 + 선택 가능한 Picker
/// - `.failed`: 오류 안내 placeholder (선택 불가)
///
/// 외부에서 주입받는 상태: `schoolsState`, `selectedSchool` 바인딩
struct SignUpSchoolSection: View {

    // MARK: - Property

    /// 학교 목록 로딩 상태 (ViewModel의 `schoolsState`)
    let schoolsState: Loadable<[School]>

    /// 사용자가 선택한 학교 (양방향 바인딩)
    @Binding var selectedSchool: School?

    // MARK: - Body

    @ViewBuilder
    var body: some View {
        switch schoolsState {
        case .idle, .loading:
            // 로딩 중에는 빈 Picker로 레이아웃을 유지하여 화면 흔들림 방지
            FormPickerField(
                title: Constants.title,
                placeholder: Constants.defaultPlaceholder,
                selection: .constant(nil as String?),
                options: [String](),
                displayText: { $0 }
            )
        case .loaded(let schools):
            FormPickerField(
                title: Constants.title,
                placeholder: Constants.defaultPlaceholder,
                selection: $selectedSchool,
                options: schools,
                displayText: { $0.name }
            )
        case .failed:
            FormPickerField(
                title: Constants.title,
                placeholder: Constants.failedPlaceholder,
                selection: .constant(nil as String?),
                options: [String](),
                displayText: { $0 }
            )
        }
    }

    // MARK: - Constant

    private enum Constants {
        static let title: String = "학교"
        static let defaultPlaceholder: String = "학교를 선택하세요"
        static let failedPlaceholder: String = "학교 목록을 불러올 수 없습니다"
    }
}
