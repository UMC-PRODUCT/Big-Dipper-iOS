//
//  SignUpTermsSection.swift
//  AppProduct
//
//  Created by euijjang97 on 4/29/26.
//

import SwiftUI

// MARK: - SignUpByIdPwTermRow

/// 약관 항목 하나를 화면에 표시하기 위한 View 전용 모델
///
/// `Terms` 도메인 모델에서 화면 표시에 필요한 정보만 추출하여 보유합니다.
struct SignUpByIdPwTermRow: Identifiable {
    /// 약관 고유 ID (서버에서 부여)
    let id: String
    /// 화면에 표시할 약관 이름
    let title: String
    /// 필수 여부 — 필수면 "(필수)", 선택이면 "(선택)"으로 표시
    let isMandatory: Bool
    /// 현재 동의 상태
    let isAgreed: Bool
    /// 약관 원문 링크를 가져올 때 사용하는 타입
    let termsType: TermsType
}

// MARK: - TermsType Display

/// 회원가입(ID/PW) 화면에서 사용하는 TermsType 표시 전용 extension
extension TermsType {

    /// 약관 항목 이름 (화면 표시용)
    var signUpByIdPwTitle: String {
        switch self {
        case .service: return "서비스 이용 약관"
        case .privacy: return "개인정보처리 방침"
        case .marketing: return "마케팅 정보 수신 동의"
        }
    }

    /// 약관 항목 정렬 순서 — 서비스 → 개인정보 → 마케팅
    var signUpByIdPwOrder: Int {
        switch self {
        case .service: return 0
        case .privacy: return 1
        case .marketing: return 2
        }
    }

    /// 약관 원문 링크 조회 시 API에 전달하는 타입 문자열
    var signUpByIdPwApiType: String {
        switch self {
        case .service: return LawsType.terms.apiType
        case .privacy: return LawsType.policy.apiType
        case .marketing: return rawValue
        }
    }
}

// MARK: - SignUpTermsSection

/// 회원가입 약관 동의 섹션
///
/// 전체 동의 버튼, 구분선, 약관 항목 목록(서비스·개인정보)을 `Loadable` 상태에 따라 표시합니다.
/// - 외부에서 주입받는 상태: `termsState`, `termsAgreements`, `isAllTermsAgreed`
/// - 외부에서 주입받는 콜백: `onToggleAll`, `onToggleRow`, `onOpenTerms`
///
/// 약관 목록은 `TermsType.service`와 `TermsType.privacy`만 필터링하여
/// `signUpByIdPwOrder` 기준으로 오름차순 정렬합니다.
struct SignUpTermsSection: View {

    // MARK: - Property

    /// 약관 목록 로딩 상태 (ViewModel의 `termsState`)
    let termsState: Loadable<[Terms]>

    /// 약관 ID → 동의 여부 딕셔너리 (ViewModel의 `termsAgreements`)
    let termsAgreements: [String: Bool]

    /// 모든 약관에 동의했는지 여부 (ViewModel의 `isAllTermsAgreed`)
    let isAllTermsAgreed: Bool

    /// 전체 동의 토글 콜백 — 인자로 새 동의 상태(`true`/`false`)를 전달합니다.
    let onToggleAll: (Bool) -> Void

    /// 개별 약관 토글 콜백 — 인자로 약관 ID를 전달합니다.
    let onToggleRow: (String) -> Void

    /// "보기" 버튼 탭 콜백 — 인자로 약관 타입을 전달합니다.
    let onOpenTerms: (TermsType) -> Void

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
            TitleLabel(title: Constants.sectionTitle, isRequired: true)

            VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
                allAgreeButton
                Divider()
                termsContent
            }
            .padding()
            .glassEffect(
                .regular,
                in: .rect(cornerRadius: DefaultConstant.cornerRadius)
            )
        }
    }

    // MARK: - Subviews

    /// 전체 동의 버튼
    private var allAgreeButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                onToggleAll(!isAllTermsAgreed)
            }
        }) {
            HStack(spacing: DefaultSpacing.spacing8) {
                Image(
                    systemName: isAllTermsAgreed
                    ? "checkmark.circle.fill" : "circle"
                )
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(isAllTermsAgreed ? .indigo500 : .grey400)
                Text(Constants.allAgreeTitle)
                    .appFont(.calloutEmphasis)
            }
        }
        .buttonStyle(.plain)
    }

    /// 약관 목록 — Loadable 상태에 따라 로딩/오류/내용을 분기합니다.
    @ViewBuilder
    private var termsContent: some View {
        switch termsState {
        case .idle, .loading:
            ProgressView()
        case .failed:
            Text(Constants.loadFailedMessage)
                .appFont(.footnote, color: .grey500)
        case .loaded:
            VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
                ForEach(termRows) { row in
                    termsRow(row)
                }
            }
        }
    }

    /// 약관 항목 한 행 — 체크 버튼과 "보기" 버튼으로 구성
    private func termsRow(_ row: SignUpByIdPwTermRow) -> some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    onToggleRow(row.id)
                }
            }) {
                HStack(spacing: DefaultSpacing.spacing8) {
                    Image(
                        systemName: row.isAgreed
                        ? "checkmark.circle.fill" : "circle"
                    )
                    .contentTransition(.symbolEffect(.replace))
                    .foregroundStyle(row.isAgreed ? .indigo500 : .grey400)
                    Text(row.title)
                        .appFont(.subheadline)
                    Text(row.isMandatory ? "(필수)" : "(선택)")
                        .appFont(
                            .footnote,
                            color: row.isMandatory ? .red500 : .grey400
                        )
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Button("보기", action: { onOpenTerms(row.termsType) })
                .appFont(.footnote, color: .indigo500)
                .buttonStyle(.plain)
        }
    }

    // MARK: - Computed

    /// 표시할 약관 행 목록
    ///
    /// `termsState`가 `.loaded`인 경우에만 실제 값을 반환합니다.
    /// 서비스·개인정보 약관만 필터링하고 `signUpByIdPwOrder` 기준으로 정렬합니다.
    private var termRows: [SignUpByIdPwTermRow] {
        guard case .loaded(let terms) = termsState else { return [] }
        return terms
            .filter { $0.termsType == .service || $0.termsType == .privacy }
            .sorted { $0.termsType.signUpByIdPwOrder < $1.termsType.signUpByIdPwOrder }
            .map {
                SignUpByIdPwTermRow(
                    id: $0.id,
                    title: $0.termsType.signUpByIdPwTitle,
                    isMandatory: $0.isMandatory,
                    isAgreed: termsAgreements[$0.id] == true,
                    termsType: $0.termsType
                )
            }
    }

    // MARK: - Constant

    private enum Constants {
        static let sectionTitle: String = "약관 동의"
        static let allAgreeTitle: String = "전체 동의"
        static let loadFailedMessage: String = "약관 정보를 불러오지 못했습니다."
    }
}
