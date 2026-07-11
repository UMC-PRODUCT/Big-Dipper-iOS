import CoreDesignSystem
import NoticeDomain
import SwiftUI
import UMCFoundation

/// 홈 화면 최근 공지 카드 — 공지 출처 아이콘, 제목, 상대 시간을 한 행에 표시한다.
struct RecentNoticeCard: View {

    // MARK: - Property

    let notice: NoticeItemModel

    // MARK: - Constants

    fileprivate enum Constants {
        static let iconSize: CGFloat = 36
        static let iconPadding: CGFloat = 8
        static let iconCornerRadius: CGFloat = 24
        static let rowPadding = EdgeInsets(top: 20, leading: 16, bottom: 20, trailing: 16)
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: DefaultSpacing.spacing12) {
            icon
            info
            Spacer(minLength: 0)
            relativeDate
        }
        .padding(Constants.rowPadding)
        .glassEffect(
            .regular,
            in: .rect(corners: .concentric(minimum: DefaultConstant.concentricRadius), isUniform: true)
        )
    }

    // MARK: - Component

    private var icon: some View {
        Image(systemName: scopeIcon)
            .font(.title2)
            .foregroundStyle(scopeColor)
            .frame(width: Constants.iconSize, height: Constants.iconSize)
            .padding(Constants.iconPadding)
            .background {
                RoundedRectangle(cornerRadius: Constants.iconCornerRadius)
                    .fill(scopeColor.opacity(0.4))
            }
            .glassEffect(.clear, in: .rect(cornerRadius: Constants.iconCornerRadius))
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
            Text(scopeLabel)
                .appFont(.caption1, weight: .semibold, color: .grey500)
            Text(notice.title)
                .appFont(.subheadline, weight: .semibold, color: .grey900)
                .lineLimit(1)
        }
    }

    private var relativeDate: some View {
        Text(notice.date.timeAgoText)
            .appFont(.caption1, color: .grey500)
    }

    // MARK: - Function

    /// 공지 출처(scope)별 아이콘. Notice 목록의 태그 색상 체계(`.orange500`/`.green500`)와 일관되게 맞춘다.
    private var scopeIcon: String {
        switch notice.scope {
        case .central: "megaphone.fill"
        case .branch: "network"
        case .campus: "graduationcap.fill"
        }
    }

    private var scopeColor: Color {
        switch notice.scope {
        case .central: .indigo500
        case .branch: .orange500
        case .campus: .green500
        }
    }

    private var scopeLabel: String {
        switch notice.scope {
        case .central:
            return "중앙운영사무국"
        case .branch:
            let displayName = notice.scopeDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return displayName.isEmpty ? "지부" : displayName
        case .campus:
            return "학교"
        }
    }
}

// MARK: - Preview

#Preview(traits: .sizeThatFitsLayout) {
    VStack(spacing: DefaultSpacing.spacing12) {
        RecentNoticeCard(notice: NoticeItemModel(
            generation: "12",
            scope: .central,
            category: .general,
            mustRead: true,
            isAlert: false,
            date: Date(timeIntervalSinceNow: -3600),
            title: "12기 중앙 해커톤 일정 안내",
            content: "",
            writer: "운영진",
            links: [],
            images: [],
            vote: nil,
            viewCount: "32"
        ))
        RecentNoticeCard(notice: NoticeItemModel(
            generation: "12",
            scope: .branch,
            category: .general,
            mustRead: false,
            isAlert: false,
            date: Date(timeIntervalSinceNow: -86400),
            title: "서울 지부 스터디 모집 공지",
            content: "",
            writer: "지부장",
            links: [],
            images: [],
            vote: nil,
            viewCount: "12",
            scopeDisplayName: "서울"
        ))
    }
    .padding()
}
