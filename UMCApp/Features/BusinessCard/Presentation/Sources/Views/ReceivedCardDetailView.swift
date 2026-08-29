//
//  ReceivedCardDetailView.swift
//  BusinessCardPresentation
//
//  Created by One on 8/28/26.
//

import SwiftUI
import BusinessCardDomain
import CoreDesignSystem
import CoreUIComponents
import UMCFoundation

// MARK: - Constants

private enum Constants {
    static let title = "받은 명함"

    static let contactSection = "연락처"
    static let exchangeSection = "교환 정보"

    static let emailLabel = "이메일"
    static let githubLabel = "GitHub"
    static let linkedInLabel = "LinkedIn"
    static let blogLabel = "블로그"

    static let methodLabel = "받은 경로"
    static let receivedAtLabel = "받은 시각"

    static let contextLabel = "교환 맥락"
    static let contextPlaceholder = "어디서 만났는지 적어 두세요 (예: OT에서 교환)"

    static let deleteTitle = "명함첩에서 삭제"
    static let deleteImage = "trash"

    static let emptyContact = "등록된 연락처가 없어요"
}

private enum Metrics {
    static let horizontalMargin: CGFloat = 16
    static let topMargin: CGFloat = 16
    static let sectionSpacing: CGFloat = 24
    static let rowSpacing: CGFloat = 12
    static let headerSpacing: CGFloat = 12
    static let cardRadius: CGFloat = 20
    static let cardPadding: CGFloat = 16
    static let methodIconSize: CGFloat = 15
    static let bottomMargin: CGFloat = 32
}

/// 받은 명함 상세 (#1227).
///
/// 명함첩 셀을 눌러 들어온다. 명함 앞/뒷면·연락처·교환 정보를 한 화면에 두고, 삭제
/// 동선도 여기로 옮겼다 — 그리드의 컨텍스트 메뉴는 「길게 눌러야 보이는」 임시 자리였다.
///
/// - Note: 이 화면의 시안은 아직 없다(#1227 「디자인 확인 필요」). 명함 카드는 기존
///   `명함_l` 컴포넌트를 그대로 쓰고, 나머지는 마이페이지 섹션 관용구(카드 배경 위
///   레이블/값 행)를 따랐다. 시안이 나오면 이 레이아웃부터 맞춘다.
/// - Note: 설계서 §5.3 의 3D 명함은 #1247·#1248 위에 올라간다. 지금은 2D 로 둔다.
/// - Important: 자체 `NavigationStack` 을 만들지 않는다. 탭별 스택은 상위 셸이 소유한다.
public struct ReceivedCardDetailView: View {

    // MARK: - Property

    @State private var viewModel: ReceivedCardDetailViewModel

    /// 옆 텍스트가 `.subheadline` 이라 아이콘만 고정 크기로 두면 AX 크기에서 홀로 작아진다.
    @ScaledMetric(relativeTo: .subheadline)
    private var methodIconSize: CGFloat = Metrics.methodIconSize

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    // MARK: - Init

    public init(viewModel: ReceivedCardDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    // MARK: - Body

    public var body: some View {
        ScrollView {
            VStack(spacing: Metrics.sectionSpacing) {
                BusinessCardFaceView(
                    card: viewModel.card.profile,
                    isFlipped: viewModel.isFlipped,
                    qrImage: viewModel.qrImage,
                    onFlip: { viewModel.isFlipped.toggle() }
                )

                contactSection
                exchangeSection
                deleteButton
            }
            .padding(.horizontal, Metrics.horizontalMargin)
            .padding(.top, Metrics.topMargin)
            .padding(.bottom, Metrics.bottomMargin)
        }
        .background(Color.grey000)
        .navigationTitle(Constants.title)
        .navigationBarTitleDisplayMode(.inline)
        .alertPrompt(item: $viewModel.alertPrompt)
        .onAppear { viewModel.prepare() }
        // 삭제된 명함을 계속 띄워 두면 「지웠는데 그대로 있다」로 읽힌다.
        .onChange(of: viewModel.isDeleted) { _, isDeleted in
            if isDeleted { dismiss() }
        }
    }

    // MARK: - View Component

    private var contactSection: some View {
        section(Constants.contactSection) {
            if contactRows.isEmpty {
                Text(Constants.emptyContact)
                    .appFont(.footnote, color: .grey500)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(contactRows, id: \.label) { row in
                    linkRow(label: row.label, value: row.value, url: row.url)
                }
            }
        }
    }

    private var exchangeSection: some View {
        section(Constants.exchangeSection) {
            HStack(spacing: Metrics.rowSpacing) {
                Text(Constants.methodLabel)
                    .appFont(.footnote, color: .grey500)

                Spacer(minLength: Metrics.rowSpacing)

                Label {
                    Text(viewModel.card.exchangeMethod.displayName)
                        .appFont(.subheadline, color: .grey900)
                } icon: {
                    Image(systemName: viewModel.card.exchangeMethod.iconName)
                        .font(.system(size: methodIconSize))
                        .foregroundStyle(Color.indigo500)
                }
            }
            // 「받은 경로」와 값이 따로 읽히면 무엇에 대한 값인지 조립해야 알 수 있다.
            .accessibilityElement(children: .combine)

            valueRow(
                label: Constants.receivedAtLabel,
                value: "\(viewModel.card.exchangedAt.toYearMonthDay())"
                    + " \(viewModel.card.exchangedAt.toHourMinutes())"
            )

            VStack(alignment: .leading, spacing: Metrics.rowSpacing) {
                Text(Constants.contextLabel)
                    .appFont(.footnote, color: .grey500)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 방식은 앱이 알지만 「어디서」는 알 수 없다 — 사용자가 직접 적는다.
                TextField(
                    Constants.contextPlaceholder,
                    text: $viewModel.contextDraft,
                    axis: .vertical
                )
                .appFont(.subheadline, color: .grey900)
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
                .onSubmit { Task { await viewModel.commitContext() } }
            }
        }
        // 화면을 뜨는 순간에도 적던 메모를 잃지 않게 저장한다.
        .onDisappear { Task { await viewModel.commitContext() } }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            viewModel.requestDelete()
        } label: {
            Label(Constants.deleteTitle, systemImage: Constants.deleteImage)
                .appFont(.subheadline, weight: .semibold, color: .red500)
                .frame(maxWidth: .infinity)
                .padding(Metrics.cardPadding)
                .background(
                    Color.grey100,
                    in: RoundedRectangle(cornerRadius: Metrics.cardRadius)
                )
        }
        .buttonStyle(.plain)
    }

    /// 레이블 + 카드 배경 한 덩어리. 두 섹션이 같은 틀을 쓴다.
    private func section(
        _ title: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: Metrics.headerSpacing) {
            Text(title)
                .appFont(.footnote, weight: .semibold, color: .grey600)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: Metrics.rowSpacing) {
                content()
            }
            .padding(Metrics.cardPadding)
            .frame(maxWidth: .infinity)
            .background(Color.grey100, in: RoundedRectangle(cornerRadius: Metrics.cardRadius))
        }
    }

    private func valueRow(label: String, value: String) -> some View {
        HStack(spacing: Metrics.rowSpacing) {
            Text(label)
                .appFont(.footnote, color: .grey500)

            Spacer(minLength: Metrics.rowSpacing)

            Text(value)
                .appFont(.subheadline, color: .grey900)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }

    /// 열 수 있는 값은 눌러서 열고, 아니면 텍스트로만 둔다 — 눌러도 아무 일 없는
    /// 링크처럼 보이는 줄을 만들지 않는다.
    @ViewBuilder
    private func linkRow(label: String, value: String, url: URL?) -> some View {
        if let url {
            Button {
                openURL(url)
            } label: {
                valueRow(label: label, value: value)
                    .foregroundStyle(Color.indigo500)
            }
            .buttonStyle(.plain)
        } else {
            valueRow(label: label, value: value)
        }
    }

    // MARK: - Computed Property

    private var contactRows: [ContactRow] {
        let profile = viewModel.card.profile
        return [
            ContactRow(label: Constants.emailLabel, value: profile.email, scheme: "mailto:"),
            ContactRow(label: Constants.githubLabel, value: profile.github),
            ContactRow(label: Constants.linkedInLabel, value: profile.linkedIn),
            ContactRow(label: Constants.blogLabel, value: profile.blog),
        ]
        .compactMap { $0 }
    }
}

// MARK: - ContactRow

/// 연락처 한 줄. 값이 없으면 만들어지지 않는다.
private struct ContactRow {

    let label: String
    let value: String
    let url: URL?

    /// - Parameter scheme: 값 앞에 붙일 스킴. 웹 링크는 `https://` 를 보충한다 —
    ///   서버·상대가 `github.com/…` 처럼 스킴 없이 보내면 `URL` 이 상대 경로로 읽혀
    ///   열리지 않는다.
    init?(label: String, value: String?, scheme: String = "https://") {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return nil }

        self.label = label
        self.value = trimmed
        self.url = trimmed.contains("://") || trimmed.hasPrefix("mailto:")
            ? URL(string: trimmed)
            : URL(string: scheme + trimmed)
    }
}
