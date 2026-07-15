//
//  TermsAgreementFlow.swift
//  AuthPresentation
//
//  Created by euijjang97 on 7/11/26.
//

import AuthDomain
import Foundation
import UMCFoundation

/// 약관 조회·동의 토글 흐름을 캡슐화한 컴포지션 객체.
///
/// `SignUpViewModel`(소셜)과 `SignUpByIdPwViewModel`(이메일)이 동일한 약관 조회/토글/필수
/// 동의 판정 로직을 복사-붙여넣기로 중복 보유하던 것을 `EmailVerificationFlow`와 동일한
/// 패턴으로 추출했다. 두 ViewModel은 이 객체를 프로퍼티로 보유하고 위임한다.
///
/// - Important: 부모 `@Observable` ViewModel에서 `var termsAgreementFlow: TermsAgreementFlow`로
///   선언해야 한다(`let` 금지). `EmailVerificationFlow`와 동일한 이유(`Binding`의
///   `subscript(dynamicMember:)`가 `WritableKeyPath` 체인을 요구)로, `let`이면 중첩 바인딩이 깨진다.
@Observable
final class TermsAgreementFlow {

    // MARK: - Property

    private let fetchSignUpDataUseCase: FetchSignUpDataUseCaseProtocol

    /// 약관 동의 상태 (termsId → 동의 여부)
    var termsAgreements: [String: Bool] = [:]

    /// 약관 목록 로딩 상태 (서비스·개인정보 2종, marketing 미노출)
    private(set) var termsState: Loadable<[Terms]> = .idle

    // MARK: - Init

    init(fetchSignUpDataUseCase: FetchSignUpDataUseCaseProtocol) {
        self.fetchSignUpDataUseCase = fetchSignUpDataUseCase
    }

    // MARK: - Computed Property

    /// 전체 약관 동의 여부
    var isAllTermsAgreed: Bool {
        !termsAgreements.isEmpty && termsAgreements.values.allSatisfy { $0 }
    }

    /// 필수 약관 모두 동의 여부.
    ///
    /// 약관이 아직 로딩되지 않았다면(`termsState != .loaded`) 항상 `false`이므로, 이 값을
    /// 참조하는 폼 유효성 검증(`isFormValid`/`canSubmit`)은 자동으로 제출을 차단한다.
    /// 하드코딩된 termsId fallback은 두지 않는다.
    var mandatoryTermsAgreed: Bool {
        guard case .loaded(let terms) = termsState else { return false }
        return terms
            .filter(\.isMandatory)
            .allSatisfy { termsAgreements[$0.id] == true }
    }

    // MARK: - Function

    /// 약관 목록 조회 (SERVICE, PRIVACY — marketing은 미노출)
    @MainActor
    func fetchTerms() async {
        termsState = .loading
        do {
            var terms: [Terms] = []
            for type in [TermsType.service, TermsType.privacy] {
                let term = try await fetchSignUpDataUseCase.fetchTerms(type: type)
                terms.append(term)
                termsAgreements[term.id] = false
            }
            termsState = .loaded(terms)
        } catch {
            termsState = .failed(AppError.from(error))
        }
    }

    /// 전체 약관 동의/해제 토글
    func toggleAllTerms(_ agreed: Bool) {
        termsAgreements = termsAgreements.mapValues { _ in agreed }
    }

    /// 개별 약관 동의 토글
    func toggleTerm(_ termsId: String) {
        termsAgreements[termsId, default: false].toggle()
    }
}
