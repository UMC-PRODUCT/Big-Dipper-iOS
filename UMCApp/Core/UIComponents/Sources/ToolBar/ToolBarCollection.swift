//
//  ToolBarCollection.swift
//  UMCFoundation
//
//  Created by 이예지 on 5/30/26.
//

import Foundation
import SwiftUI
import UMCFoundation
import CoreDesignSystem

/// 앱 전체에서 사용되는 재사용 가능한 Toolbar 컴포넌트 모음
///
/// 취소/확인/추가 등 공통 액션 버튼과 필터 메뉴를 제공합니다.
public struct ToolBarCollection {

    // MARK: - Primary Action Buttons
    
    /// 기본 시스템 뒤로 가기 동작과 추가 후처리를 함께 수행하는 툴바 버튼입니다.
    public struct BackBtn: ToolbarContent {
        @Environment(\.dismiss) var dismiss
        public var action: () -> Void
        
        public var body: some ToolbarContent {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .cancel, action: {
                    action()
                    dismiss()
                })
            }
        }
    }
    
    
    /// 시트나 편집 화면에서 취소 동작을 제공하는 툴바 버튼입니다.
    public struct CancelBtn: ToolbarContent {
        @Environment(\.dismiss) var dismiss
        public var action: () -> Void
        
        public init(action: @escaping () -> Void) {
            self.action = action
        }
        
        public var body: some ToolbarContent {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .cancel, action: {
                    action()
                    dismiss()
                })
            }
        }
    }
    
    /// 저장, 완료 같은 확인 액션에 사용하는 공용 툴바 버튼입니다.
    ///
    /// `isLoading`이 `true`이면 체크 아이콘 대신 `ProgressView`를 노출하고,
    /// 탭 입력도 함께 막아 중복 제출을 방지합니다.
    public struct ConfirmBtn: ToolbarContent {
        @Environment(\.dismiss) var dismiss
        public let action: () -> Void
        public let disable: Bool
        public let isLoading: Bool
        public let dismissOnTap: Bool
        public let tintColor: Color
        
        public init(
            action: @escaping () -> Void,
            disable: Bool = false,
            isLoading: Bool = false,
            dismissOnTap: Bool = true,
            tintColor: Color = .indigo500
        ) {
            self.action = action
            self.disable = disable
            self.isLoading = isLoading
            self.dismissOnTap = dismissOnTap
            self.tintColor = tintColor
        }
        
        public var body: some ToolbarContent {
            ToolbarItem(placement: .confirmationAction) {
                Button(role: .confirm, action: {
                    guard !isLoading, !disable else { return }
                    action()
                    if dismissOnTap {
                        dismiss()
                    }
                }, label: {
                    ZStack {
                        Image(systemName: "checkmark")
                            .opacity(isLoading ? 0 : 1)

                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.blue)
                        }
                    }
                })
                .tint((disable || isLoading) ? .grey300 : tintColor)
                .disabled(disable || isLoading)
            }
        }
    }
    
    /// 파괴적이거나 취소 성격이 강한 좌측 상단 액션에 사용하는 버튼입니다.
    public struct RejectBtn: ToolbarContent {
        @Environment(\.dismiss) var dismiss
        public let action: () -> Void
        public let disable: Bool
        
        public init(action: @escaping () -> Void, disable: Bool = false) {
            self.action = action
            self.disable = disable
        }
        
        public var body: some ToolbarContent {
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .destructive, action: {
                    action()
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                }
                .tint(.red)
                .disabled(disable)
            }
        }
    }
    
    /// 생성, 추가 같은 우측 상단 액션에 사용하는 공용 버튼입니다.
    ///
    /// 타이틀 없이 사용하면 시스템 아이콘 버튼으로, `title`을 전달하면 텍스트 버튼으로 동작합니다.
    public struct AddBtn: ToolbarContent {
        @Environment(\.dismiss) private var dismiss
        public let action: () -> Void
        public let disable: Bool
        public let isLoading: Bool
        public let dismissOnTap: Bool
        public let title: String?
        public let imageSystemName: String
        public let tintColor: Color
        
        public init(
            title: String? = nil,
            imageSystemName: String = "plus",
            action: @escaping () -> Void,
            disable: Bool = false,
            isLoading: Bool = false,
            dismissOnTap: Bool = false,
            tintColor: Color = .indigo500
        ) {
            self.title = title
            self.imageSystemName = imageSystemName
            self.action = action
            self.disable = disable
            self.isLoading = isLoading
            self.dismissOnTap = dismissOnTap
            self.tintColor = tintColor
        }
        
        public var body: some ToolbarContent {
            ToolbarItem(placement: .topBarTrailing) {
                baseButton
            }
        }

        private var baseButton: some View {
            Button(action: {
                guard !disable, !isLoading else { return }
                action()
                if dismissOnTap {
                    dismiss()
                }
            }, label: {
                ZStack {
                    if let title {
                        Text(title)
                            .opacity(isLoading ? 0 : 1)
                    } else {
                        Image(systemName: imageSystemName)
                            .opacity(isLoading ? 0 : 1)
                    }

                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.indigo500)
                    }
                }
            })
            .tint((disable || isLoading) ? .grey300 : tintColor)
            .disabled(disable || isLoading)
        }
    }

    // MARK: - Icon Buttons
    
    /// 좌측 상단에 임의의 SF Symbol 액션을 배치하는 버튼입니다.
    public struct LeadingButton: ToolbarContent {
        public let image: String
        public let action: () -> Void
        
        public var body: some ToolbarContent {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    action()
                }, label: {
                    Image(systemName: image)
                })
            }
        }
    }
    
    /// 알림함 진입 버튼입니다.
    ///
    /// `recentPush`가 `true`이면 배지 포함 심볼을 사용해 새 알림 존재를 표현합니다.
    public struct BellBtn: ToolbarContent {
        public let action: () -> Void
        public var tintColor: Color = .grey900
        public let recentPush: Bool

        public init(action: @escaping () -> Void, tintColor: Color = .grey900, recentPush: Bool = false) {
            self.action = action
            self.tintColor = tintColor
            self.recentPush = recentPush
        }

        public var body: some ToolbarContent {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { action() }, label: {
                    Image(systemName: recentPush ? "bell.badge" : "bell")
                })
                .tint(tintColor)
            }
        }
    }
    
    /// 앱 브랜딩용 로고를 상단 좌측에 배치하는 툴바입니다.
    public struct Logo: ToolbarContent {
        public let image: ImageResource
        @Namespace var namespace
        
        public var body: some ToolbarContent {
            ToolbarItem(placement: .topBarLeading) {
                Image(image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 40)
                    .padding(EdgeInsets(top: 8, leading: 6, bottom: 8, trailing: 6))
                    .disabled(true)
            }
            .sharedBackgroundVisibility(.hidden)
            .matchedTransitionSource(id: "logo", in: namespace)
        }
    }

    // MARK: - Filters
    
    /// 기수 선택 메뉴를 상단 좌측에 배치하는 필터 툴바입니다.
    public struct GenerationFilter: ToolbarContent {
        public let title: String
        public let generations: [Generation]
        @Binding public var selection: Generation
        
        public init(title: String, generations: [Generation], selection: Binding<Generation>) {
            self.title = title
            self.generations = generations
            self._selection = selection
        }
        
        public var body: some ToolbarContent {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    generationPicker
                } label: {
                    menuLabel
                }
            }
        }
        
        /// 등록된 기수 목록을 inline 스타일로 보여주는 Picker입니다.
        private var generationPicker: some View {
            Picker("기수 선택", selection: $selection) {
                ForEach(generations) { generation in
                    Text(generation.title).tag(generation)
                }
            }
            .pickerStyle(.inline)
        }
        
        /// 현재 필터 타이틀을 표시하는 메뉴 라벨입니다.
        private var menuLabel: some View {
            Text(title)
                .font(.callout)
                .fontWeight(.semibold)
        }
    }
    
    /// 커뮤니티 화면에서 주차를 선택하는 필터 툴바입니다.
    public struct CommunityWeekFilter: ToolbarContent {
        public let weeks: [Int]
        @Binding var selection: Int
        
        public var body: some ToolbarContent {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    weekPicker
                } label: {
                    Text("\(selection)주차")
                        .appFont(.subheadline, weight: .medium)
                }
            }
        }
        
        /// 주차 값을 선택하는 inline Picker입니다.
        private var weekPicker: some View {
            Picker("주차 선택", selection: $selection) {
                ForEach(weeks, id: \.self) { week in
                    Text("\(week)주차")
                        .tag(week)
                }
            }
            .pickerStyle(.inline)
        }
    }
    
    /// 커뮤니티 목록을 학교 기준으로 좁혀보는 필터 툴바입니다.
    public struct CommunityUnivFilter: ToolbarContent {
        @Binding var selectedUniversity: String
        public let universities: [String]

        public var body: some ToolbarContent {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    universityPicker
                } label: {
                    Image(systemName: "graduationcap.fill")
                        .appFont(.subheadline)
                }
            }
        }

        /// 학교 목록을 선택 가능한 메뉴 형태로 구성한 Picker입니다.
        private var universityPicker: some View {
            Picker("학교 선택", selection: $selectedUniversity) {
                Text("전체")
                    .tag("전체")

                ForEach(universities.filter { $0 != "전체" }, id: \.self) { university in
                    Text(university)
                        .tag(university)
                }
            }
            .pickerStyle(.inline)
        }
    }

    /// 커뮤니티 목록을 파트 기준으로 좁혀보는 필터 툴바입니다.
    public struct CommunityPartFilter: ToolbarContent {
        @Binding var selectedPart: UMCPartType?
        public let parts: [UMCPartType]

        public var body: some ToolbarContent {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    partPicker
                } label: {
                    Image(systemName: "building.columns.fill")
                        .appFont(.subheadline)
                }
            }
        }

        /// 파트 목록을 inline 메뉴로 렌더링하는 Picker입니다.
        private var partPicker: some View {
            Picker("파트 선택", selection: $selectedPart) {
                Label("전체", systemImage: "person.2.fill")
                    .tag(nil as UMCPartType?)

                ForEach(parts, id: \.self) { part in
                    Label(part.name, systemImage: part.icon)
                        .tag(part)
                }
            }
            .pickerStyle(.inline)
        }
    }

    /// 커뮤니티 명예의 전당에서 학교/파트 필터를 하나의 메뉴로 통합한 툴바입니다.
    public struct CommunityFameFilter: ToolbarContent {
        @Binding var selectedUniversity: String
        public let universities: [String]
        @Binding var selectedPart: UMCPartType?
        public let parts: [UMCPartType]

        public var body: some ToolbarContent {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Menu {
                        Picker("학교 선택", selection: $selectedUniversity) {
                            Text("전체")
                                .tag("전체")

                            ForEach(universities.filter { $0 != "전체" }, id: \.self) { university in
                                Text(university)
                                    .tag(university)
                            }
                        }
                        .pickerStyle(.inline)
                    } label: {
                        Label("\(selectedUniversity)", systemImage: "graduationcap.fill")
                    }

                    Menu {
                        Picker("파트 선택", selection: $selectedPart) {
                            Label("전체", systemImage: "person.2.fill")
                                .tag(nil as UMCPartType?)

                            ForEach(parts, id: \.self) { part in
                                Label(part.name, systemImage: part.icon)
                                    .tag(part)
                            }
                        }
                        .pickerStyle(.inline)
                    } label: {
                        Label("\(selectedPart?.name ?? "전체")", systemImage: "building.columns.fill")
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .appFont(.subheadline)
                }
            }
        }
    }

    // MARK: - Menus
    
    /// 상단 중앙 섹션 메뉴 툴바 (시스템 ToolbarTitleMenu 기반)
    ///
    /// - Note: 타이틀 텍스트는 각 화면에서 `.navigationTitle(...)`로 지정해야 합니다.
    public struct ToolBarCenterMenu<Item: Identifiable & Hashable>: ToolbarContent {

        // MARK: - Property
        public let items: [Item]
        @Binding var selection: Item
        public let itemLabel: (Item) -> String
        public let itemIcon: ((Item) -> String)?
        public let onSelect: ((Item) -> Void)?
        
        // MARK: - Initializer
        public init(
            items: [Item],
            selection: Binding<Item>,
            itemLabel: @escaping (Item) -> String,
            itemIcon: ((Item) -> String)? = nil,
            onSelect: ((Item) -> Void)? = nil
        ) {
            self.items = items
            self._selection = selection
            self.itemLabel = itemLabel
            self.itemIcon = itemIcon
            self.onSelect = onSelect
        }
        
        // MARK: - Body
        public var body: some ToolbarContent {
            ToolbarTitleMenu {
                ForEach(items) { item in
                    Button {
                        selection = item
                        onSelect?(item)
                    } label: {
                        if let itemIcon = itemIcon {
                            Label(itemLabel(item), systemImage: itemIcon(item))
                                .imageScale(.small)
                                .font(.subheadline)
                        } else {
                            Text(itemLabel(item))
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
    }
    
    /// 우측 상단의 `ellipsis` 메뉴를 공통 액션 목록으로 렌더링합니다.
    public struct ToolbarTrailingMenu: ToolbarContent {
        public let actions: [ActionItem]
        
        public init(actions: [ActionItem]) {
            self.actions = actions
        }
        
        /// `ToolbarTrailingMenu`가 노출할 단일 메뉴 액션 모델입니다.
        public struct ActionItem: Identifiable {
            public let id = UUID()
            public let title: String
            public let icon: String
            public let role: ButtonRole?
            public let action: () -> Void
            
            public init(title: String,
                 icon: String,
                 role: ButtonRole? = nil,
                 action: @escaping () -> Void
            ) {
                self.title = title
                self.icon = icon
                self.role = role
                self.action = action
            }
        }
        
        public var body: some ToolbarContent {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(actions) { item in
                        Button(role: item.role) {
                            item.action()
                        } label: {
                            Label(item.title, systemImage: item.icon)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
    }
    
    /// 운영진 출석 승인 메뉴 (선택 모드 토글 지원)
    ///
    /// - 일반 모드: "선택" 버튼 표시
    /// - 선택 모드: ellipsis 메뉴 + X 버튼 표시
    public struct OperationApprovalMenu: ToolbarContent {
        @Binding var isSelecting: Bool
        public let selectedCount: Int
        public var onApproveSelected: () -> Void
        public var onRejectSelected: () -> Void
        public var onApproveAll: () -> Void
        public var onRejectAll: () -> Void
        
        private var hasSelection: Bool {
            selectedCount > 0
        }
        
        public var body: some ToolbarContent {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if isSelecting {
                    approvalMenu
                    closeButton
                } else {
                    selectButton
                }
            }
        }
        
        // MARK: - View Components
        
        /// 선택 모드에서 승인/거절 관련 액션을 묶어 보여주는 메뉴입니다.
        private var approvalMenu: some View {
            Menu {
                Section {
                    Button(role: .destructive, action: onRejectSelected) {
                        Label("선택 거절 (\(selectedCount))", systemImage: "xmark.circle")
                    }
                    .disabled(!hasSelection)
                    
                    Button(action: onApproveSelected) {
                        Label("선택 승인 (\(selectedCount))", systemImage: "checkmark.circle")
                    }
                    .disabled(!hasSelection)
                }
                
                Section {
                    Button(role: .destructive, action: onRejectAll) {
                        Label("전체 거절", systemImage: "xmark.circle.fill")
                    }
                    Button(action: onApproveAll) {
                        Label("전체 승인", systemImage: "checkmark.circle.fill")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16))
                    .foregroundStyle(.black)
            }
        }
        
        /// 선택 모드를 종료하고 기본 표시 상태로 복귀시키는 버튼입니다.
        private var closeButton: some View {
            Button {
                withAnimation(.snappy(duration: DefaultConstant.animationTime)) {
                    isSelecting = false
                }
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 16))
                    .foregroundStyle(.black)
            }
        }
        
        /// 일반 모드에서 선택 모드로 진입시키는 버튼입니다.
        private var selectButton: some View {
            Button {
                withAnimation(.snappy(duration: DefaultConstant.animationTime)) {
                    isSelecting = true
                }
            } label: {
                Image(systemName: "checklist")
                    .font(.system(size: 16))
                    .foregroundStyle(.black)
            }
        }
    }
    
    // MARK: - Study Management Filters
    
    /// 스터디 관리 화면의 주차 선택 메뉴입니다.
    public struct StudyWeekFilter: ToolbarContent {
        public let weeks: [Int]
        @Binding var selection: Int
        public let onChange: (Int) -> Void
        
        public var body: some ToolbarContent {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    weekPicker
                } label: {
                    Text("\(selection)주차")
                        .appFont(.callout)
                }
            }
        }
        
        /// 주차 변경 시 외부 `onChange`까지 연결하는 Picker입니다.
        private var weekPicker: some View {
            Picker("주차", selection: $selection) {
                ForEach(weeks, id: \.self) { week in
                    Text("\(week)주차")
                        .tag(week)
                }
            }
            .onChange(of: selection) { _, newValue in
                onChange(newValue)
            }
        }
    }
    
//    /// 스터디 그룹별 세부 목록을 전환하는 우측 상단 필터입니다.
//    public struct StudyGroupFilter: ToolbarContent {
//        public let studyGroups: [StudyGroupItem]
//        @Binding var selection: StudyGroupItem
//        public let onChange: (StudyGroupItem) -> Void
//        
//        public var body: some ToolbarContent {
//            ToolbarItem(placement: .topBarTrailing) {
//                Menu {
//                    groupPicker
//                } label: {
//                    Image(
//                        systemName: selection == .all
//                        ? "line.3.horizontal.decrease"
//                        : selection.iconName
//                    )
//                }
//            }
//        }
//        
//        /// 스터디 그룹 선택과 변경 이벤트 전달을 담당하는 Picker입니다.
//        private var groupPicker: some View {
//            Picker("스터디 그룹", selection: $selection) {
//                ForEach(studyGroups, id: \.self) { group in
//                    Label(group.name, systemImage: group.iconName)
//                        .tag(group)
//                }
//            }
//            .onChange(of: selection) { _, newValue in
//                onChange(newValue)
//            }
//        }
//    }
    
    /// 공지 열람 현황 화면의 학교/지부 필터 메뉴입니다.
    public struct ReadStatusFilter<Item: Identifiable & Hashable>: ToolbarContent {
        public let items: [Item]
        @Binding var selection: Item
        public let itemLabel: (Item) -> String
        public let itemIcon: ((Item) -> String)?
        
        public init(
            items: [Item],
            selection: Binding<Item>,
            itemLabel: @escaping (Item) -> String,
            itemIcon: ((Item) -> String)? = nil
        ) {
            self.items = items
            self._selection = selection
            self.itemLabel = itemLabel
            self.itemIcon = itemIcon
        }
        
        public var body: some ToolbarContent {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("열람 현황 필터", selection: $selection) {
                        ForEach(items) { item in
                            if let itemIcon {
                                Label(itemLabel(item), systemImage: itemIcon(item))
                                    .tag(item)
                            } else {
                                Text(itemLabel(item))
                                    .tag(item)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                }
            }
        }
    }

    // MARK: - Specialized Bottom Toolbar

    /// 챌린저 인증 실패 화면 전용 하단 툴바입니다.
    ///
    /// 홈페이지 이동, 문의하기, 계정 관련 액션을 하단 바에 고정된 형태로 제공합니다.
    public struct FailedVerificationBottomToolbar: ToolbarContent {
        @State private var isAccountDialogPresented: Bool = false

        public let isSubmitting: Bool
        public let isDeletingAccount: Bool
        public let isLoggingOut: Bool
        public let onHome: () -> Void
        public let onInquiry: () -> Void
        public let onLogout: () -> Void
        public let onDeleteAccount: () -> Void

        private enum Constants {
            static let iconSize: CGFloat = 18
        }

        public init(
            isSubmitting: Bool,
            isDeletingAccount: Bool,
            isLoggingOut: Bool,
            onHome: @escaping () -> Void,
            onInquiry: @escaping () -> Void,
            onLogout: @escaping () -> Void,
            onDeleteAccount: @escaping () -> Void
        ) {
            self.isSubmitting = isSubmitting
            self.isDeletingAccount = isDeletingAccount
            self.isLoggingOut = isLoggingOut
            self.onHome = onHome
            self.onInquiry = onInquiry
            self.onLogout = onLogout
            self.onDeleteAccount = onDeleteAccount
        }

        public var body: some ToolbarContent {
            ToolbarItem(placement: .bottomBar) {
                actionButton(
                    icon: "house.fill",
                    title: "홈페이지",
                    color: .indigo,
                    disabled: isDeletingAccount,
                    action: onHome
                )
            }

            ToolbarItem(placement: .bottomBar) {
                actionButton(
                    icon: "message.fill",
                    title: "문의하기",
                    color: .yellow,
                    disabled: isDeletingAccount,
                    action: onInquiry
                )
            }

            ToolbarItem(placement: .bottomBar) {
                Button(action: onAccountAction) {
                    actionLabel(
                        icon: "person.crop.circle.badge.xmark",
                        title: "계정",
                        color: .red
                    )
                }
                .confirmationDialog(
                    "계정 관리",
                    isPresented: $isAccountDialogPresented,
                    titleVisibility: .hidden
                ) {
                    Button("로그아웃", action: onLogout)
                    Button("탈퇴하기", role: .destructive, action: onDeleteAccount)
                }
                .disabled(isSubmitting || isDeletingAccount || isLoggingOut)
            }
        }

        private func onAccountAction() {
            isAccountDialogPresented = true
        }

        /// 단일 하단 바 액션 버튼을 렌더링합니다.
        private func actionButton(
            icon: String,
            title: String,
            color: Color,
            disabled: Bool,
            action: @escaping () -> Void
        ) -> some View {
            Button(action: action) {
                VStack(spacing: DefaultSpacing.spacing4) {
                    Image(systemName: icon)
                        .font(.system(size: Constants.iconSize, weight: .semibold))
                        .foregroundStyle(color)

                    Text(title)
                        .appFont(.caption2, weight: .medium, color: .black)
                        .lineLimit(1)
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .disabled(disabled)
        }

        /// 계정 메뉴의 커스텀 라벨을 구성합니다.
        private func actionLabel(
            icon: String,
            title: String,
            color: Color
        ) -> some View {
            VStack(spacing: DefaultSpacing.spacing4) {
                Image(systemName: icon)
                    .font(.system(size: Constants.iconSize, weight: .semibold))
                    .foregroundStyle(color)

                Text(title)
                    .appFont(.caption2, weight: .medium, color: .black)
                    .lineLimit(1)
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
    }
}
