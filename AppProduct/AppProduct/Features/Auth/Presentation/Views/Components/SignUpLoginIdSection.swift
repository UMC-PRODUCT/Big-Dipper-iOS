//
//  SignUpLoginIdSection.swift
//  AppProduct
//
//  Created by euijjang97 on 4/29/26.
//

import SwiftUI

/// 회원가입 로그인 ID 입력 섹션
///
/// ID 입력 필드와 중복 확인 결과(아이콘 + 텍스트)를 함께 제공합니다.
/// - 외부에서 주입받는 상태: `loginId` 바인딩, `availability` (`Loadable<Bool>`)
/// - 중복 검사는 ViewModel이 `loginIdInput` `didSet` + 500ms debounce로 자동 수행하므로
///   이 섹션은 결과를 read-only로 표시하기만 합니다.
/// - 포커스는 부모의 `FocusState.Binding`을 직접 주입받아 관리합니다.
struct SignUpLoginIdSection: View {

    // MARK: - Property

    /// 사용자가 입력하는 로그인 ID (양방향 바인딩)
    @Binding var loginId: String

    /// ViewModel이 계산한 중복 확인 결과 — `.loading` 시 스피너, `.loaded(true)` 시 초록 체크 표시
    let availability: Loadable<Bool>

    /// 부모 View의 FocusState 바인딩 — 포커스 흐름을 부모가 일원 관리합니다.
    var focusBinding: FocusState<SignUpByIdPwField?>.Binding

    /// 제출(return) 시 포커스를 다음 필드로 이동시키는 콜백
    let onSubmit: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            TitleLabel(title: Constants.title, isRequired: true)
            HStack(spacing: DefaultSpacing.spacing8) {
                inputField
                statusIndicator
            }
            statusMessage
        }
    }

    // MARK: - Subviews

    private var inputField: some View {
        TextField(
            "",
            text: $loginId,
            prompt: Text(Constants.placeholder).font(.callout)
        )
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled(true)
        .foregroundStyle(.grey900)
        .padding(DefaultConstant.defaultTextFieldPadding)
        .glassEffect(.regular, in: .capsule)
        .submitLabel(.next)
        .focused(focusBinding, equals: .loginId)
        .onSubmit(onSubmit)
    }

    /// 중복 검사 상태를 아이콘으로 표시
    @ViewBuilder
    private var statusIndicator: some View {
        switch availability {
        case .loading:
            ProgressView()
                .frame(width: 24, height: 24)
        case .loaded(true):
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .loaded(false), .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red500)
        case .idle:
            EmptyView()
        }
    }

    /// 중복 검사 결과를 텍스트로 표시
    @ViewBuilder
    private var statusMessage: some View {
        switch availability {
        case .loaded(true):
            Text("사용 가능한 아이디입니다.")
                .appFont(.footnote, color: .green)
                .padding(.leading, DefaultSpacing.spacing8)
        case .loaded(false):
            Text("이미 사용 중인 아이디입니다.")
                .appFont(.footnote, color: .red500)
                .padding(.leading, DefaultSpacing.spacing8)
        case .failed(let error):
            Text(error.userMessage)
                .appFont(.footnote, color: .red500)
                .padding(.leading, DefaultSpacing.spacing8)
        case .idle, .loading:
            EmptyView()
        }
    }

    // MARK: - Constant

    private enum Constants {
        static let title: String = "로그인 ID"
        static let placeholder: String = "아이디 입력"
    }
}
