import AuthDomain
import CoreDesignSystem
import SwiftUI
import UMCFoundation

/// 회원가입 학교 선택 섹션.
///
/// `Loadable<[School]>` 상태에 따라 UI를 분기한다.
/// - `.idle`/`.loading`: 빈 옵션 목록 + 기본 placeholder (선택 불가, 레이아웃만 유지)
/// - `.loaded`: 실제 학교 목록 + 선택 가능한 Picker
/// - `.failed`: 오류 안내 placeholder (선택 불가)
struct SignUpSchoolSection: View {

    // MARK: - Property

    /// 학교 목록 로딩 상태 (ViewModel의 `schoolsState`)
    let schoolsState: Loadable<[School]>

    /// 사용자가 선택한 학교 (양방향 바인딩)
    @Binding var selectedSchool: School?

    // MARK: - Constant

    fileprivate enum Constants {
        static let title: String = "학교"
        static let defaultPlaceholder: String = "학교를 선택하세요"
        static let failedPlaceholder: String = "학교 목록을 불러올 수 없습니다"
    }

    // MARK: - Body

    @ViewBuilder
    var body: some View {
        switch schoolsState {
        case .idle, .loading:
            FormPickerField<School>(
                title: Constants.title,
                placeholder: Constants.defaultPlaceholder,
                selection: .constant(nil),
                options: [],
                displayText: { $0.name }
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
            FormPickerField<School>(
                title: Constants.title,
                placeholder: Constants.failedPlaceholder,
                selection: .constant(nil),
                options: [],
                displayText: { $0.name }
            )
        }
    }
}

// MARK: - Preview

#if DEBUG
private struct SignUpSchoolSectionPreviewWrapper: View {
    @State private var selectedSchool: School?

    var body: some View {
        VStack(spacing: DefaultSpacing.spacing16) {
            SignUpSchoolSection(
                schoolsState: .loaded([
                    School(id: "1", name: "서울대학교"),
                    School(id: "2", name: "연세대학교"),
                    School(id: "3", name: "고려대학교")
                ]),
                selectedSchool: $selectedSchool
            )
            SignUpSchoolSection(schoolsState: .loading, selectedSchool: .constant(nil))
            SignUpSchoolSection(
                schoolsState: .failed(.unknown(message: "네트워크 오류")),
                selectedSchool: .constant(nil)
            )
        }
        .padding()
    }
}

#Preview {
    SignUpSchoolSectionPreviewWrapper()
}
#endif
