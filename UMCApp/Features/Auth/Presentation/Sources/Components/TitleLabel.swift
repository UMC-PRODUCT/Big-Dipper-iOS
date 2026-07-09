import CoreDesignSystem
import SwiftUI

/// 폼 입력 필드 상단에 제목과 필수 입력 표시(`*`)를 함께 보여주는 레이블.
///
/// `FormTextField`/`FormEmailField`/`FormPickerField`가 공통으로 사용한다.
struct TitleLabel: View {

    // MARK: - Property

    let title: String
    let isRequired: Bool

    // MARK: - Body

    var body: some View {
        HStack(spacing: DefaultSpacing.spacing4) {
            Text(title)
                .appFont(.body, weight: .semibold, color: .black)

            if isRequired {
                Text("*")
                    .appFont(.body, color: .red500)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
        TitleLabel(title: "이름", isRequired: true)
        TitleLabel(title: "닉네임", isRequired: false)
    }
    .padding()
}
#endif
