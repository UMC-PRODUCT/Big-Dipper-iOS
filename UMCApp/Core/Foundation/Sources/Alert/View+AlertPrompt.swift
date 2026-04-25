//
//  View+AlertPrompt.swift
//  UMCFoundation
//
//  Created by JEONG on 4/25/26.
//

import SwiftUI

public extension View {
    /// 커스텀 알림 프롬프트를 표시하는 View Modifier
    ///
    /// `AlertPrompt` 상태를 바인딩하여 시스템 알림창을 표시합니다.
    /// 긍정/보조/부정 버튼(최대 3개)의 제목과 액션을 설정할 수 있으며,
    /// 긍정 버튼은 파괴적(destructive) 스타일을 지원합니다.
    ///
    /// - Parameter item: 알림창을 제어할 `AlertPrompt` 데이터 바인딩
    /// - Returns: 알림이 적용된 View
    ///
    /// - Usage:
    /// ```swift
    /// // ViewModel
    /// @Observable
    /// final class ViewModel {
    ///     var alertPrompt: AlertPrompt?
    ///
    ///     func deleteButtonTapped() {
    ///         alertPrompt = AlertPrompt(
    ///             title: "삭제 확인",
    ///             message: "정말 삭제하시겠습니까?",
    ///             positiveBtnTitle: "삭제",
    ///             positiveBtnAction: { [weak self] in
    ///                 self?.delete()
    ///             },
    ///             negativeBtnTitle: "취소",
    ///             isPositiveBtnDestructive: true
    ///         )
    ///     }
    /// }
    ///
    /// // View
    /// struct ContentView: View {
    ///     @State private var viewModel = ViewModel()
    ///
    ///     var body: some View {
    ///         Button("Delete") {
    ///             viewModel.deleteButtonTapped()
    ///         }
    ///         .alertPrompt(item: $viewModel.alertPrompt)
    ///     }
    /// }
    /// ```
    func alertPrompt(item: Binding<AlertPrompt?>) -> some View {
        self.alert(
            item.wrappedValue?.title ?? "",
            isPresented: Binding(
                get: { item.wrappedValue != nil },
                set: { if !$0 { item.wrappedValue = nil } }
            ),
            presenting: item.wrappedValue
        ) { alert in
            if let positiveBtnTitle = alert.positiveBtnTitle {
                Button(
                    positiveBtnTitle,
                    role: alert.isPositiveBtnDestructive ? .destructive : .confirm
                ) {
                    alert.positiveBtnAction?()
                }
            }

            // 보조 버튼 (3번째 선택지, 선택 사항)
            if let secondaryBtnTitle = alert.secondaryBtnTitle {
                Button(secondaryBtnTitle) {
                    alert.secondaryBtnAction?()
                }
            }

            if let negativeBtnTitle = alert.negativeBtnTitle {
                Button(negativeBtnTitle, role: .cancel) {
                    alert.negativeBtnAction?()
                }
            }
        } message: { alert in
            Text(alert.message)
        }
    }
}
