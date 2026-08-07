//
//  ChallengerAttendanceReasonSheet.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 8/2/26.
//

import CoreDesignSystem
import CoreUIComponents
import SwiftUI

/// 출석 사유 작성 시트
///
/// GPS 출석이 어려운 경우 사유를 작성하여 출석을 요청할 수 있는 시트입니다.
struct ChallengerAttendanceReasonSheet: View {

    // MARK: - Property

    @Environment(\.dismiss) private var dismiss
    @State private var reason: String = ""

    let onSubmit: (String) async -> Void

    // MARK: - Constants

    fileprivate enum Constants {
        static let sheetHeight: CGFloat = 230
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    reasonTextField
                } header: {
                    SectionHeaderView(title: "지각 사유 입력")
                } footer: {
                    descriptionText
                }
            }
            .toolbar {
                ToolBarCollection.CancelBtn {
                    dismiss()
                }

                // 제출이 끝난 뒤에 닫아야 하므로 버튼의 자동 dismiss 는 끄고
                // await 완료 후 직접 닫는다. (기본값을 쓰면 제출 중에 시트가 사라진다)
                ToolBarCollection.ConfirmBtn(
                    action: {
                        Task {
                            await onSubmit(reason)
                            dismiss()
                        }
                    },
                    dismissOnTap: false
                )
            }
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .presentationDetents([.height(Constants.sheetHeight)])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - View Components

    private var reasonTextField: some View {
        TextField(
            "",
            text: $reason,
            prompt: Text("길이 막혀요..")
        )
        .submitLabel(.done)
    }

    private var descriptionText: some View {
        Text(
            "위치 인증이 어려운 경우 사유를 작성하여 출석을 요청할 수 있습니다. "
                + "(예: GPS 오류, 지각, 개인 사정 등)"
        )
        .appFont(.footnote, color: .grey500)
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
    }
}

#if DEBUG
// MARK: - Preview

#Preview {
    Text("Preview Trigger")
        .sheet(isPresented: .constant(true)) {
            ChallengerAttendanceReasonSheet { _ in }
        }
}
#endif
