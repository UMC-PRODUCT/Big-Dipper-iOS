import Foundation

/// 회원가입 화면(`SignUpView`/`SignUpByIdPwView`)의 키보드 포커스 대상 필드.
///
/// 두 화면이 `SignUpPasswordSection`/`SignUpNameNicknameSection`을 공유하므로
/// `FocusState.Binding`도 동일한 타입을 사용해야 한다. 이메일 필드는 `FormEmailField`가
/// 자체 관리하므로 이 목록에 포함하지 않는다.
enum SignUpFocusField: Hashable, CaseIterable {
    case password
    case passwordConfirm
    case name
    case nickname
}
