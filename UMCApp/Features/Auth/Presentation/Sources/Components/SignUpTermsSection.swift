import AuthDomain
import CoreDesignSystem
import SwiftUI
import UMCFoundation

/// 회원가입 약관 동의 섹션.
///
/// 전체 동의 버튼, 구분선, 약관 항목 목록(서비스·개인정보)을 `Loadable` 상태에 따라 표시한다.
/// 약관 원문 "보기"는 레거시와 달리 MyPage UseCase를 거치지 않고 `Terms.link`를
/// `openURL` 환경 값으로 직접 연다 (`NoticeLinkCard`와 동일한 패턴).
struct SignUpTermsSection: View {

    // MARK: - Property

    /// 약관 목록 로딩 상태 (ViewModel의 `termsState`)
    let termsState: Loadable<[Terms]>

    /// 약관 ID → 동의 여부 딕셔너리 (ViewModel의 `termsAgreements`)
    let termsAgreements: [String: Bool]

    /// 모든 약관에 동의했는지 여부 (ViewModel의 계산 프로퍼티)
    let isAllTermsAgreed: Bool

    /// 전체 동의 토글 콜백 — 인자로 새 동의 상태(`true`/`false`)를 전달한다.
    let onToggleAll: (Bool) -> Void

    /// 개별 약관 토글 콜백 — 인자로 약관 ID를 전달한다.
    let onToggleRow: (String) -> Void

    @Environment(\.openURL) private var openURL

    // MARK: - Constant

    fileprivate enum Constants {
        static let sectionTitle: String = "약관 동의"
        static let allAgreeTitle: String = "전체 동의"
        static let loadFailedMessage: String = "약관 정보를 불러오지 못했습니다."
    }

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
            .glassEffect(.regular, in: .rect(cornerRadius: DefaultConstant.cornerRadius))
        }
    }

    // MARK: - Subviews

    private var allAgreeButton: some View {
        Button {
            withAnimation(.easeInOut(duration: DefaultConstant.animationTime)) {
                onToggleAll(!isAllTermsAgreed)
            }
        } label: {
            HStack(spacing: DefaultSpacing.spacing8) {
                Image(systemName: isAllTermsAgreed ? "checkmark.circle.fill" : "circle")
                    .contentTransition(.symbolEffect(.replace))
                    .foregroundStyle(isAllTermsAgreed ? Color.indigo500 : Color.grey400)
                Text(Constants.allAgreeTitle)
                    .appFont(.callout, weight: .semibold)
            }
        }
        .buttonStyle(.plain)
    }

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

    private func termsRow(_ row: SignUpTermsRow) -> some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            Button {
                withAnimation(.easeInOut(duration: DefaultConstant.animationTime)) {
                    onToggleRow(row.id)
                }
            } label: {
                HStack(spacing: DefaultSpacing.spacing8) {
                    Image(systemName: row.isAgreed ? "checkmark.circle.fill" : "circle")
                        .contentTransition(.symbolEffect(.replace))
                        .foregroundStyle(row.isAgreed ? Color.indigo500 : Color.grey400)
                    Text(row.title)
                        .appFont(.subheadline)
                    Text(row.isMandatory ? "(필수)" : "(선택)")
                        .appFont(.footnote, color: row.isMandatory ? .red500 : .grey400)
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Button("보기") { openTerms(row.link) }
                .appFont(.footnote, color: .indigo500)
                .buttonStyle(.plain)
        }
    }

    // MARK: - Computed

    /// 표시할 약관 행 목록. 서비스·개인정보 약관만 필터링하고 정해진 순서로 정렬한다.
    private var termRows: [SignUpTermsRow] {
        guard case .loaded(let terms) = termsState else { return [] }
        return terms
            .filter { $0.type == .service || $0.type == .privacy }
            .sorted { $0.type.displayOrder < $1.type.displayOrder }
            .map {
                SignUpTermsRow(
                    id: $0.id,
                    title: $0.type.displayTitle,
                    isMandatory: $0.isMandatory,
                    isAgreed: termsAgreements[$0.id] == true,
                    link: $0.link
                )
            }
    }

    private func openTerms(_ link: String) {
        guard let url = URL(string: link) else { return }
        openURL(url)
    }
}

// MARK: - SignUpTermsRow

/// 약관 항목 하나를 화면에 표시하기 위한 View 전용 모델.
private struct SignUpTermsRow: Identifiable {
    let id: String
    let title: String
    let isMandatory: Bool
    let isAgreed: Bool
    let link: String
}

// MARK: - TermsType Display

/// 회원가입 화면에서 사용하는 `TermsType` 표시 전용 extension.
private extension TermsType {

    var displayTitle: String {
        switch self {
        case .service: return "서비스 이용 약관"
        case .privacy: return "개인정보처리 방침"
        case .marketing: return "마케팅 정보 수신 동의"
        }
    }

    var displayOrder: Int {
        switch self {
        case .service: return 0
        case .privacy: return 1
        case .marketing: return 2
        }
    }
}

// MARK: - Preview

#if DEBUG
private struct SignUpTermsSectionPreviewWrapper: View {
    @State private var termsAgreements: [String: Bool] = [:]

    private let mockTerms: [Terms] = [
        Terms(id: "1", type: .service, link: "https://umc.com/terms/service", isMandatory: true),
        Terms(id: "2", type: .privacy, link: "https://umc.com/terms/privacy", isMandatory: true)
    ]

    private var isAllAgreed: Bool {
        mockTerms.allSatisfy { termsAgreements[$0.id] == true }
    }

    var body: some View {
        SignUpTermsSection(
            termsState: .loaded(mockTerms),
            termsAgreements: termsAgreements,
            isAllTermsAgreed: isAllAgreed,
            onToggleAll: { newValue in
                mockTerms.forEach { termsAgreements[$0.id] = newValue }
            },
            onToggleRow: { id in
                termsAgreements[id] = !(termsAgreements[id] ?? false)
            }
        )
        .padding()
    }
}

#Preview {
    SignUpTermsSectionPreviewWrapper()
}
#endif
