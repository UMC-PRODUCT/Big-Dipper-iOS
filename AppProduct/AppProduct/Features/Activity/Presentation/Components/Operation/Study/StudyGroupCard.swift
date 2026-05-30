//
//  StudyGroupCard.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/9/26.
//

import SwiftUI

// MARK: - StudyGroupDetailCard

/// 스터디 그룹 상세 카드
///
/// 그룹명, 파트, 멘토(담당 파트장) 목록, 멤버 목록과 관리 액션을 표시합니다.
struct StudyGroupCard: View, Equatable {

    // MARK: - Property

    @State private var deleteAlertPrompt: AlertPrompt?
    /// 멘토/스터디원 섹션 펼침 상태
    ///
    /// 멘토가 N명 가능 + 멤버 많을수록 카드 길이가 빠르게 늘어남.
    /// 기본 collapsed → 헤더만으로 빠른 스캔, 관심 카드만 펼침.
    @State private var isExpanded: Bool = false

    /// 펼침 콘텐츠(멘토+멤버 섹션)의 자연 높이.
    ///
    /// `fixedSize`로 클램프와 무관하게 측정한 natural height를 보관한다. `frame(height:)`를
    /// 이 값↔0 으로 애니메이션해 콘텐츠를 카드 안에 가둔 채(clip) 펼침/접힘을 표현한다.
    /// `if + .transition` 방식은 제거되는 뷰가 축소된 부모 밖으로 잔류 렌더되며 clip을 벗어나
    /// 잔상이 생기는데(이번 이슈 영상 검증), 이 방식은 콘텐츠가 항상 클램프 프레임 안에 있어
    /// 헤더 아래로 넘치지 않는다.
    @State private var expandedSectionsHeight: CGFloat = 0

    private let detail: StudyGroupInfo
    private var onEdit: (() -> Void)?
    private var onDelete: (() -> Void)?
    private var onAddMember: (() -> Void)?
    private var onAddMentor: (() -> Void)?
    private var onSchedule: (() -> Void)?
    private var onRemoveMember: ((StudyGroupMember) -> Void)?
    private var onRemoveMentor: ((StudyGroupMember) -> Void)?

    // MARK: - Initializer

    /// - Parameters:
    ///   - detail: 그룹 상세 정보
    ///   - onEdit: 편집 버튼 탭 콜백
    ///   - onDelete: 삭제 버튼 탭 콜백
    ///   - onAddMember: 멤버 추가 버튼 탭 콜백
    ///   - onAddMentor: 멘토 추가 버튼 탭 콜백
    ///   - onSchedule: 일정 등록 버튼 탭 콜백
    ///   - onRemoveMember: 멤버 칩 삭제 콜백
    ///   - onRemoveMentor: 멘토 칩 삭제 콜백
    init(
        detail: StudyGroupInfo,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onAddMember: (() -> Void)? = nil,
        onAddMentor: (() -> Void)? = nil,
        onSchedule: (() -> Void)? = nil,
        onRemoveMember: ((StudyGroupMember) -> Void)? = nil,
        onRemoveMentor: ((StudyGroupMember) -> Void)? = nil
    ) {
        self.detail = detail
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onAddMember = onAddMember
        self.onAddMentor = onAddMentor
        self.onSchedule = onSchedule
        self.onRemoveMember = onRemoveMember
        self.onRemoveMentor = onRemoveMentor
    }

    // MARK: - Equatable

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.detail == rhs.detail
    }

    // MARK: - Constants

    fileprivate enum Constants {
        /// 카드 외곽 라운드 — Apple 가이드 권장 `.glassEffect(_:in:)` 패턴에서 사용
        ///
        /// `ConcentricRectangle`은 superview corner 상속에 의존하는데,
        /// `GlassEffectContainer` 내부에서는 그 상속이 끊겨 의도와 다른 거대 round로
        /// morphing되는 문제가 있어 명시 corner radius로 고정한다.
        static let cardCornerRadius: CGFloat = 24
        /// 좌측 파트 컬러 strip 너비
        static let accentStripWidth: CGFloat = 4
        /// strip 모서리 둥글기
        static let accentStripCornerRadius: CGFloat = 2
        /// sub-section(멘토/멤버) 내부 패딩
        static let subSectionPadding: CGFloat = 12
        /// sub-section Material 배경 라운드
        static let subSectionCornerRadius: CGFloat = 14
        /// HIG 권장 최소 터치 타겟
        static let minTouchTarget: CGFloat = 44
        /// metadataRow 배경 라운드
        static let metadataRowCornerRadius: CGFloat = 10
    }

    // MARK: - Body

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            accentStrip

            VStack(alignment: .leading, spacing: 0) {
                headerSection

                // 펼침 콘텐츠는 항상 트리에 존재하고 `fixedSize`로 자연 높이를 측정한다.
                // 표시 높이는 `frame(height:)`로 0↔측정값을 애니메이션하고 `clipped()`로 잘라,
                // 콘텐츠가 헤더 아래로 빠져나오는 잔상 없이 카드 안에서만 열리고 닫힌다.
                expandableSections
                    .fixedSize(horizontal: false, vertical: true)
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { newHeight in
                        expandedSectionsHeight = newHeight
                    }
                    .frame(
                        height: isExpanded ? expandedSectionsHeight : 0,
                        alignment: .top
                    )
                    .opacity(isExpanded ? 1 : 0)
                    .clipped()
            }
            .padding(DefaultConstant.defaultCardPadding)
        }
        // Apple 가이드 권장 패턴: View 자체에 `.glassEffect(_:in:)` 적용
        // → GlassEffectContainer 내부 morphing/blending이 정상 동작
        .glassEffect(
            .regular,
            in: .rect(cornerRadius: Constants.cardCornerRadius)
        )
        // 카드 외곽 라운드로 콘텐츠를 한 번 더 clip — 내부 섹션 clip과 더불어 어떤 자식도
        // 카드 모서리를 넘지 않도록 보장한다.
        .clipShape(.rect(cornerRadius: Constants.cardCornerRadius))
        // 카드 전체를 펼침/접힘 탭 영역으로 만든다. 내부 Button/Menu(일정 등록·설정·추가)는
        // 자체적으로 탭을 소비하므로 토글되지 않고, 빈 영역·타이틀·메타·파트장/멤버 행을
        // 탭하면 펼침/접힘이 토글된다.
        .contentShape(.rect(cornerRadius: Constants.cardCornerRadius))
        .onTapGesture { toggleExpansion() }
        .alertPrompt(item: $deleteAlertPrompt)
    }

    /// 펼침/접힘 토글 — `metadataRow`의 chevron과 카드 전체 탭이 공유하는 단일 진입점.
    private func toggleExpansion() {
        withAnimation(.smooth(duration: 0.3)) {
            isExpanded.toggle()
        }
    }

    /// 펼침 시 노출되는 멘토/멤버 섹션 묶음.
    ///
    /// 헤더와의 간격(spacing16)을 이 블록 상단 패딩으로 흡수해, 접힘 시 `frame(height: 0)`로
    /// 갭까지 함께 사라지게 한다(외곽 VStack spacing은 0).
    private var expandableSections: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing16) {
            mentorSection
            membersSection
        }
        .padding(.top, DefaultSpacing.spacing16)
    }

    // MARK: - View Components

    /// 카드 좌측 파트 컬러 accent strip
    ///
    /// `maxHeight: .infinity`로 카드 content 영역 전체 높이를 채워 파트 정체성을 강한 시각 단서로
    /// 표현한다. 좌측만 leading 패딩을 두고, 카드 패딩과의 어색한 갭이 생기지 않도록 한다.
    private var accentStrip: some View {
        RoundedRectangle(cornerRadius: Constants.accentStripCornerRadius)
            .fill(detail.part.color)
            .frame(width: Constants.accentStripWidth)
            .frame(maxHeight: .infinity)
            .padding(.vertical, DefaultConstant.defaultCardPadding.top)
            .padding(.leading, DefaultSpacing.spacing8)
            .accessibilityHidden(true)
    }

    /// 헤더 — 2-row 구조로 식별/액션을 분리한다.
    ///
    /// Row 1 (Identity): 그룹명·파트 뱃지·오늘 미팅 — primary attention.
    /// Row 2 (Meta + Actions): 멤버 수·생성일·펼침 토글 + 일정 등록·설정 — secondary.
    ///
    /// 그룹명에 `lineLimit(2) + fixedSize(vertical)`를 부여해 긴 이름이 truncate 되는 대신 줄바꿈된다.
    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            // Row 1: 식별 정보 (primary)
            HStack(alignment: .firstTextBaseline, spacing: DefaultSpacing.spacing8) {
                Text(detail.name)
                    .appFont(.calloutEmphasis)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                InfoBadge(
                    detail.part.name,
                    textColor: detail.part.color,
                    tintColor: detail.part.color
                )

                // "오늘 미팅" active 상태 뱃지 — UI hook만 준비, 산정 로직은 별도 이슈
                // .tint(part.color)는 prominence 신호 보존을 위해 이 active 뱃지에만 한정한다.
                if isMeetingToday {
                    todayMeetingBadge
                }

                Spacer(minLength: 0)
            }

            // Row 2: 메타/펼침 토글 + 액션 버튼
            HStack(spacing: DefaultSpacing.spacing8) {
                metadataRow

                Spacer(minLength: DefaultSpacing.spacing8)

                scheduleActionButton
                settingsMenu
            }
        }
    }

    /// 그룹 편집·삭제 메뉴 — HIG 44×44 터치 타겟 보장.
    ///
    /// 인접한 expand 토글(`metadataRow`) 영역과 오탭을 피하기 위해 명시 frame을 사용한다.
    private var settingsMenu: some View {
        Menu {
            Button("그룹 편집", systemImage: "pencil") {
                onEdit?()
            }

            Divider()

            Button("그룹 삭제", systemImage: "trash", role: .destructive) {
                deleteAlertPrompt = AlertPrompt(
                    title: "그룹 삭제",
                    message: "'\(detail.name)' 그룹을 삭제하시겠습니까?",
                    positiveBtnTitle: "삭제",
                    positiveBtnAction: {
                        onDelete?()
                    },
                    negativeBtnTitle: "취소",
                    isPositiveBtnDestructive: true
                )
            }
        } label: {
            Image(systemName: "gearshape")
                .font(.app(.title3))
                .frame(
                    width: Constants.minTouchTarget,
                    height: Constants.minTouchTarget
                )
                .contentShape(Rectangle())
                .glassEffect(.regular.interactive())
        }
        .accessibilityLabel("그룹 설정")
    }

    /// 일정 등록 — collapsed에서는 quiet 아이콘 chip, expanded에서 tinted prominent capsule.
    ///
    /// soyeon-ui-review CRITICAL: 카드 N개에 prominent CTA가 반복 배치되면 화면 전체에서
    /// "primary CTA가 N개" 패턴이 되어 그룹명의 primary attention을 침범한다. collapsed는
    /// 정보 스캔 우선 → 액션 강조 약화, expanded는 운영 작업 우선 → 강조 회복.
    ///
    /// **잔상 방지를 위한 단일 persistent view 패턴**: 이전엔 collapsed(원형)와 expanded(캡슐)를
    /// 서로 다른 뷰로 두고 `glassEffectID`로 morphing했는데, 전환 중 두 상태가 cross-fade되며
    /// 캘린더 아이콘이 두 개로 겹쳐 보이는 잔상이 생겼다(영상 검증). 아이콘 하나가 항상 존재하는
    /// 단일 HStack으로 만들고, 배경은 항상 `.capsule`(44×44면 원으로 보임)로 두어 **너비·틴트·
    /// 글자만 연속 변화**시킨다. 뷰 identity가 유지되므로 아이콘이 중복 렌더되지 않는다.
    ///
    /// 높이는 인접한 `settingsMenu`(고정 44×44)와 baseline 정렬을 위해 `minHeight: 44`.
    private var scheduleActionButton: some View {
        Button {
            onSchedule?()
        } label: {
            HStack(spacing: isExpanded ? DefaultSpacing.spacing4 : 0) {
                Image(systemName: "calendar.badge.plus")
                    .font(.app(.title3))
                    .foregroundStyle(isExpanded ? Color.white : Color.indigo600)

                if isExpanded {
                    Text("일정 등록")
                        .appFont(.footnoteEmphasis, color: .white)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .padding(.horizontal, isExpanded ? DefaultSpacing.spacing12 : 0)
            .frame(
                minWidth: Constants.minTouchTarget,
                minHeight: Constants.minTouchTarget
            )
            .contentShape(.capsule)
            // 배경을 항상 `.capsule`로 두면 collapsed(44×44)는 원, expanded는 알약으로 같은
            // shape 프리미티브 안에서 너비만 변해 shape swap 잔상이 없다. tint opacity는
            // collapsed에서 0(plain glass) → expanded에서 1(indigo)로 연속 전환된다.
            .glassEffect(
                .regular
                    .tint(.indigo600.opacity(isExpanded ? 1 : 0))
                    .interactive(),
                in: .capsule
            )
        }
        .accessibilityLabel("일정 등록")
    }

    /// "오늘 미팅" active 상태 뱃지 (UI hook)
    /// 산정 로직은 별도 이슈에서 추가하고, 여기서는 `isMeetingToday` false 고정으로 hidden 상태.
    private var todayMeetingBadge: some View {
        InfoBadge(
            "오늘 미팅",
            textColor: detail.part.color,
            tintColor: detail.part.color,
            glassVariant: .regular
        )
        .tint(detail.part.color)
    }

    /// 오늘 미팅 여부 — 산정 로직은 후속 이슈에서 도입. 현 시점에서는 hidden.
    private var isMeetingToday: Bool { false }

    /// 메타 + 펼침 토글 — collapsed 시각 단서를 강화한 secondary 액션.
    ///
    /// 멘토/멤버 수만 표시해 좁은 디바이스에서도 절대 잘리지 않도록 한다.
    /// 생성일은 부가정보로 prominence가 낮아 collapsed에서는 생략, 필요 시 expanded 내부
    /// 메타 카드에서 노출 가능하다(향후 도입). 배경에 thinMaterial을 깔아 탭 가능 영역을
    /// 시각화하고, 우측 chevron 회전으로 상태를 표현한다. `minHeight: 44`로 HIG 터치 타겟 보장.
    private var metadataRow: some View {
        Button {
            toggleExpansion()
        } label: {
            HStack(spacing: DefaultSpacing.spacing4) {
                Text("멘토 \(detail.mentors.count)명 · 멤버 \(detail.members.count)명")
                    .appFont(.caption1Emphasis, color: .grey600)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.app(.caption1))
                    .foregroundStyle(.grey500)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(.horizontal, DefaultSpacing.spacing8)
            .frame(minHeight: Constants.minTouchTarget)
            .background(
                .thinMaterial,
                in: .rect(cornerRadius: Constants.metadataRowCornerRadius)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isExpanded ? "스터디 그룹 상세 접기" : "스터디 그룹 상세 펼치기")
        .accessibilityHint("멘토와 스터디원 목록 보기")
    }

    @ViewBuilder
    private var mentorSection: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            HStack {
                SectionHeaderView(title: "담당 파트장")
                Spacer()
                addMentorButton
            }

            ForEach(detail.mentors) { mentor in
                StudyGroupLeaderRow(
                    leader: mentor,
                    partTintColor: detail.part.color
                )
                .equatable()
                .contextMenu {
                    Button(role: .destructive) {
                        onRemoveMentor?(mentor)
                    } label: {
                        Label("멘토 삭제", systemImage: "trash")
                    }
                }
            }
        }
        .padding(Constants.subSectionPadding)
        .background(
            .regularMaterial,
            in: .rect(cornerRadius: Constants.subSectionCornerRadius)
        )
    }

    @ViewBuilder
    private var membersSection: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            HStack {
                SectionHeaderView(title: "스터디원")
                Spacer()
                addMemberButton
            }

            FlowLayout(spacing: DefaultSpacing.spacing8) {
                ForEach(detail.members) { member in
                    StudyGroupMemberChip(
                        member: member,
                        showsBestWorkbookBadge: topBestWorkbookMemberServerIDs.contains(member.serverID)
                    )
                    .equatable()
                    .contextMenu {
                        Button(role: .destructive) {
                            onRemoveMember?(member)
                        } label: {
                            Label("멤버 삭제", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .padding(Constants.subSectionPadding)
        .background(
            .regularMaterial,
            in: .rect(cornerRadius: Constants.subSectionCornerRadius)
        )
    }

    private var topBestWorkbookMemberServerIDs: Set<String> {
        guard let topScore = detail.members
            .map(\.bestWorkbookPoint)
            .max(),
              topScore > 0 else {
            return []
        }

        return Set(
            detail.members
                .filter { $0.bestWorkbookPoint == topScore }
                .map(\.serverID)
        )
    }

    private var addMemberButton: some View {
        Button {
            onAddMember?()
        } label: {
            Image(systemName: "plus")
                .padding(DefaultConstant.defaultBtnPadding)
        }
        .glassEffect(.regular.interactive())
        .accessibilityLabel("스터디원 추가")
    }

    private var addMentorButton: some View {
        Button {
            onAddMentor?()
        } label: {
            Image(systemName: "plus")
                .padding(DefaultConstant.defaultBtnPadding)
        }
        .glassEffect(.regular.interactive())
        .accessibilityLabel("멘토 추가")
    }

}

// MARK: - Preview

#if DEBUG
#Preview(traits: .sizeThatFitsLayout) {
    StudyGroupCard(
        detail: .preview,
        onEdit: { print("Edit") },
        onDelete: { print("Delete") },
        onAddMember: { print("Add Member") },
        onAddMentor: { print("Add Mentor") },
        onSchedule: { print("Schedule") },
        onRemoveMember: { _ in print("Remove Member") },
        onRemoveMentor: { _ in print("Remove Mentor") }
    )
    .padding(DefaultConstant.defaultSafeHorizon)
}
#endif
