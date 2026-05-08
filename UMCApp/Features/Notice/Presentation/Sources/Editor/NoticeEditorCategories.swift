//
//  NoticeEditorCategories.swift
//  NoticePresentation
//
//  Created by 이예지 on 5/9/26.
//

import Foundation
import UMCFoundation
import NoticeDomain

// MARK: - EditorMainCategory
/// 공지 에디터 메인 카테고리
public enum EditorMainCategory: Identifiable, Equatable, Hashable {
    case all
    case central
    case branch
    case school
    case part(UMCPartType)

    /// 고유 식별자
    public var id: String {
        switch self {
        case .all: return "all"
        case .central: return "central"
        case .branch: return "branch"
        case .school: return "school"
        case .part(let part): return "part_\(part.apiValue)"
        }
    }

    /// 카테고리 표시 텍스트
    public var labelText: String {
        switch self {
        case .all: return "전체 기수"
        case .central: return "특정 기수"
        case .branch: return "지부"
        case .school: return "학교"
        case .part(let part): return NoticePart(umcPartType: part)?.displayName ?? part.name
        }
    }

    /// 카테고리 아이콘 SF Symbol 이름
    public var labelIcon: String {
        switch self {
        case .all: return "line.3.horizontal.decrease"
        case .central: return "number.square"
        case .branch: return "mappin.and.ellipse"
        case .school: return "graduationcap"
        case .part: return "person.3.fill"
        }
    }

    /// 서브카테고리 목록
    public var subCategories: [EditorSubCategory] {
        switch self {
        case .all:
            return [.school]
        case .central:
            return [.branch, .school, .part]
        case .branch:
            return [.all, .part]
        case .school:
            return [.school, .part]
        case .part:
            return []
        }
    }

    /// 서브카테고리가 있는지 여부
    public var hasSubCategories: Bool {
        !subCategories.isEmpty
    }
}

// MARK: - EditorSubCategory
/// 공지 에디터 서브 카테고리
public enum EditorSubCategory: Identifiable, Equatable, Hashable {
    case all
    //case staff
    case branch
    case school
    case part

    /// 고유 식별자
    public var id: String {
        switch self {
        case .all: return "all"
        //case .staff: return "staff"
        case .branch: return "branch"
        case .school: return "school"
        case .part: return "part"
        }
    }

    /// 서브카테고리 표시 텍스트
    public var labelText: String {
        switch self {
        case .all: return "전체"
        //case .staff: return "운영진 공지"
        case .branch: return "지부"
        case .school: return "학교"
        case .part: return "파트"
        }
    }

    /// 추가 필터가 필요한지 여부
    public var hasFilter: Bool {
        switch self {
        case .branch, .school, .part:
            return true
        case .all:
            return false
        }
    }
}

// MARK: - EditorSubCategorySelection
/// 서브카테고리 선택 상태
public struct EditorSubCategorySelection: Equatable {
    /// 선택된 서브카테고리 목록
    public var selectedSubCategories: Set<EditorSubCategory> = []
    /// 선택된 파트 목록
    public var selectedParts: Set<UMCPartType> = []
    /// 선택된 지부
    public var selectedBranch: NoticeTargetOption?
    /// 선택된 학교
    public var selectedSchool: NoticeTargetOption?

    /// 선택 요약 텍스트
    public var summaryText: String {
        var items: [String] = []

        if selectedSubCategories.isEmpty {
            return "선택 안 함"
        }

        for subCategory in selectedSubCategories.sorted(by: { $0.id < $1.id }) {
            switch subCategory {
            case .all:
                items.append("전체")
//            case .staff:
//                items.append("운영진")
            case .branch:
                if let selectedBranch {
                    items.append(selectedBranch.name)
                } else {
                    items.append("지부")
                }
            case .school:
                if let selectedSchool {
                    items.append(selectedSchool.name)
                } else {
                    items.append("학교")
                }
            case .part:
                if selectedParts.isEmpty {
                    items.append("파트")
                } else {
                    items.append(
                        contentsOf: selectedParts.map {
                            NoticePart(umcPartType: $0)?.displayName ?? $0.name
                        }
                    )
                }
            }
        }
        return items.isEmpty ? "선택" : items.joined(separator: ", ")
    }
    
    public init(
        selectedSubCategories: Set<EditorSubCategory>,
        selectedParts: Set<UMCPartType>,
        selectedBranch: NoticeTargetOption? = nil,
        selectedSchool: NoticeTargetOption? = nil
    ) {
        self.selectedSubCategories = selectedSubCategories
        self.selectedParts = selectedParts
        self.selectedBranch = selectedBranch
        self.selectedSchool = selectedSchool
    }
}

