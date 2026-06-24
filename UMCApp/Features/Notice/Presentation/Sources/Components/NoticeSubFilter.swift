//
//  NoticeSubFilter.swift
//  NoticeData
//
//  Created by 이예지 on 5/30/26.
//

import SwiftUI
import CoreDesignSystem
import CoreUIComponents
import NoticeDomain

// MARK: - NoticeSubFilter
/// 서브필터 영역 (전체, 운영진 공지 칩 + 파트 메뉴)
public struct NoticeSubFilter: View, Equatable {

    @Bindable var viewModel: NoticeViewModel

    public static func == (lhs: NoticeSubFilter, rhs: NoticeSubFilter) -> Bool {
        lhs.viewModel.selectedSubFilter == rhs.viewModel.selectedSubFilter &&
        lhs.viewModel.selectedPart == rhs.viewModel.selectedPart &&
        lhs.viewModel.selectedMainFilter == rhs.viewModel.selectedMainFilter &&
        lhs.viewModel.subFilterChips == rhs.viewModel.subFilterChips
    }

    private enum Constants {
        static let hstackSpacing: CGFloat = 8
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Constants.hstackSpacing) {
                ForEach(viewModel.subFilterChips) { chip in
                    chipView(for: chip)
                }
            }
            .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
        }
    }

    /// 칩 타입에 따라 ChipButton 또는 PartFilterMenu를 반환합니다.
    @ViewBuilder
    private func chipView(for chip: NoticeListSubFilterChip) -> some View {
        switch chip {
        case .part:
            PartFilterMenu(viewModel: viewModel)
                .equatable()
        case .all, .branch, .school:
            ChipButton(chipDisplayTitle(chip), isSelected: isChipSelected(chip)) {
                handleChipTap(chip)
            }
            .buttonSize(.medium)
        }
    }

    /// 칩의 선택 상태를 판단합니다.
    ///
    /// - all: 파트가 미선택이면 선택 상태
    /// - branch: 현재 메인필터가 지부이면 선택 상태
    /// - school: 현재 메인필터가 학교이고 파트 미선택이면 선택 상태
    /// - part: 파트가 선택되었으면 선택 상태
    private func isChipSelected(_ chip: NoticeListSubFilterChip) -> Bool {
        switch chip {
        case .all:
            return viewModel.selectedPart == nil
        case .branch:
            if case .branch = viewModel.selectedMainFilter { return true }
            return false
        case .school:
            if case .school = viewModel.selectedMainFilter {
                return viewModel.selectedPart == nil
            }
            return false
        case .part:
            return viewModel.selectedPart != nil
        }
    }

    /// 칩 탭 시 메인필터 전환 또는 파트 초기화를 수행합니다.
    private func handleChipTap(_ chip: NoticeListSubFilterChip) {
        switch chip {
        case .all:
            viewModel.selectPart(nil)
        case .branch:
            let branchFilter = viewModel.mainFilterItems.first {
                if case .branch = $0 { return true }
                return false
            }
            if let branchFilter {
                viewModel.selectMainFilter(branchFilter)
            }
        case .school:
            // 학교 메인 탭에서는 "전체(학교 전체)" 칩으로 동작합니다.
            if case .school = viewModel.selectedMainFilter {
                viewModel.selectPart(nil)
                return
            }
            let schoolFilter = viewModel.mainFilterItems.first {
                if case .school = $0 { return true }
                return false
            }
            if let schoolFilter {
                viewModel.selectMainFilter(schoolFilter)
            }
        case .part:
            return
        }
    }

    /// 칩 라벨 텍스트를 반환합니다. 학교 메인탭에서는 "전체"로 표시합니다.
    private func chipDisplayTitle(_ chip: NoticeListSubFilterChip) -> String {
        switch chip {
        case .school:
            if case .school = viewModel.selectedMainFilter {
                return "전체"
            }
            return chip.labelText
        default:
            return chip.labelText
        }
    }
}

// MARK: - PartFilterMenu
/// 파트 선택 메뉴
private struct PartFilterMenu: View, Equatable {

    @Bindable var viewModel: NoticeViewModel

    static func == (lhs: PartFilterMenu, rhs: PartFilterMenu) -> Bool {
        lhs.viewModel.selectedPart == rhs.viewModel.selectedPart
    }

    private enum Constants {
        static let hstackSpacing: CGFloat = 4
        static let chevronSize: CGFloat = 10
        static let chipPadding: EdgeInsets = .init(top: 8, leading: 16, bottom: 8, trailing: 16)
    }

    private var partBinding: Binding<NoticePart?> {
        Binding(
            get: { viewModel.selectedPart },
            set: { viewModel.selectPart($0) }
        )
    }

    var body: some View {
        Menu {
            partPicker
        } label: {
            menuLabel
        }
    }

    private var partPicker: some View {
        Picker("파트 선택", selection: partBinding) {
            Label("파트", systemImage: "person.2.fill")
                .tag(nil as NoticePart?)
            ForEach(NoticePart.allCases) { part in
                Label(part.displayName, systemImage: part.iconName)
                    .tag(Optional(part))
            }
        }
        .pickerStyle(.inline)
    }

    private var isPartSelected: Bool {
        viewModel.selectedPart != nil
    }

    private var menuLabel: some View {
        HStack(spacing: Constants.hstackSpacing) {
            Image(systemName: viewModel.selectedPart?.iconName ?? "person.2.fill")
                .appFont(.subheadline)
            Text(viewModel.selectedPart?.displayName ?? "파트")
                .appFont(.subheadline, weight: .semibold)
            Image(systemName: "chevron.down")
                .font(.system(size: Constants.chevronSize))
        }
        .foregroundStyle(isPartSelected ? Color.grey000 : Color.grey600)
        .padding(Constants.chipPadding)
        .clipShape(Capsule())
        .background {
            Capsule()
                .fill(isPartSelected ? Color.indigo500 : Color.grey200)
        }
        .glassEffect(.clear.interactive(), in: Capsule())
    }
}
