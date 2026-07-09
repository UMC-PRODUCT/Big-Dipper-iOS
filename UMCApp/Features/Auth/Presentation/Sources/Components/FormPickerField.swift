import CoreDesignSystem
import SwiftUI

/// 옵션 목록을 드롭다운 메뉴로 선택하는 제네릭 폼 피커 필드.
///
/// `selection`에 대한 프로토콜 제약을 두지 않아(`Hashable` 불요) 도메인 모델을
/// 추가 컨포먼스 없이 그대로 사용할 수 있다. 옵션 식별은 배열 인덱스를 사용한다.
struct FormPickerField<T>: View {

    // MARK: - Property

    let title: String
    let placeholder: String
    @Binding var selection: T?
    let options: [T]
    let displayText: (T) -> String
    var isRequired: Bool = true

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            TitleLabel(title: title, isRequired: isRequired)
            pickerView
        }
    }

    // MARK: - Subviews

    private var pickerView: some View {
        Menu {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                Button(displayText(option)) {
                    selection = option
                }
            }
        } label: {
            menuLabel
        }
    }

    private var menuLabel: some View {
        HStack {
            Text(selection.map(displayText) ?? placeholder)
                .appFont(.callout, color: selection == nil ? .grey400 : .grey900)
            Spacer()
            Image(systemName: DefaultConstant.chevronDownImage)
                .foregroundStyle(Color.grey900)
        }
        .padding(DefaultConstant.defaultTextFieldPadding)
        .glassEffect(.regular.interactive())
    }
}

// MARK: - Preview

#if DEBUG
private struct FormPickerFieldPreviewWrapper: View {
    @State private var selection: String?
    private let options = ["서울대학교", "연세대학교", "고려대학교", "서강대학교"]

    var body: some View {
        VStack(spacing: DefaultSpacing.spacing16) {
            FormPickerField(
                title: "학교",
                placeholder: "학교를 선택하세요",
                selection: $selection,
                options: options,
                displayText: { $0 }
            )
            FormPickerField(
                title: "학교",
                placeholder: "학교를 선택하세요",
                selection: .constant(options.first),
                options: options,
                displayText: { $0 }
            )
        }
        .padding()
    }
}

#Preview {
    FormPickerFieldPreviewWrapper()
}
#endif
