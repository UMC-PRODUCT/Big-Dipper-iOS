//
//  NoticeEditorModel.swift
//  AppProduct
//
//  Created by 이예지 on 1/24/26.
//

import Foundation

// MARK: - ManagementNoticeCategory

/// 운영진 공지 시나리오
enum ManagementNoticeCategory: Identifiable, Equatable, Hashable, CaseIterable {
    case centralAll
    case schoolCore
    case schoolPartLeader

    var id: String {
        switch self {
        case .centralAll: return "centralAll"
        case .schoolCore: return "schoolCore"
        case .schoolPartLeader: return "schoolPartLeader"
        }
    }

    var labelText: String {
        switch self {
        case .centralAll: return "중앙운영진"
        case .schoolCore: return "학교 회장단"
        case .schoolPartLeader: return "학교 파트장"
        }
    }

    var labelIcon: String {
        switch self {
        case .centralAll: return "person.3.sequence.fill"
        case .schoolCore: return "person.2.badge.gearshape"
        case .schoolPartLeader: return "person.crop.rectangle.stack"
        }
    }

    var serverNoticeTab: String {
        switch self {
        case .centralAll: return "CENTRAL_MEMBER"
        case .schoolCore: return "SCHOOL_CORE"
        case .schoolPartLeader: return "SCHOOL_PART_LEADER"
        }
    }
}

// MARK: - EditorMainCategory
/// 공지 에디터 메인 카테고리
enum EditorMainCategory: Identifiable, Equatable, Hashable {
    case all
    case central
    case branch
    case school
    case part(UMCPartType)
    case management(ManagementNoticeCategory)

    /// 고유 식별자
    var id: String {
        switch self {
        case .all: return "all"
        case .central: return "central"
        case .branch: return "branch"
        case .school: return "school"
        case .part(let part): return "part_\(part.apiValue)"
        case .management(let category): return "management_\(category.id)"
        }
    }

    /// 카테고리 표시 텍스트
    var labelText: String {
        switch self {
        case .all: return "전체 기수"
        case .central: return "특정 기수"
        case .branch: return "지부"
        case .school: return "학교"
        case .part(let part): return NoticePart(umcPartType: part)?.displayName ?? part.name
        case .management(let category): return category.labelText
        }
    }

    /// 카테고리 아이콘 SF Symbol 이름
    var labelIcon: String {
        switch self {
        case .all: return "line.3.horizontal.decrease"
        case .central: return "number.square"
        case .branch: return "mappin.and.ellipse"
        case .school: return "graduationcap"
        case .part: return "person.3.fill"
        case .management(let category): return category.labelIcon
        }
    }

    /// 서브카테고리 목록
    var subCategories: [EditorSubCategory] {
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
        case .management(let category):
            switch category {
            case .centralAll, .schoolCore: return []
            case .schoolPartLeader: return [.part]
            }
        }
    }

    /// 서브카테고리가 있는지 여부
    var hasSubCategories: Bool {
        !subCategories.isEmpty
    }
}

// MARK: - EditorSubCategory
/// 공지 에디터 서브 카테고리
enum EditorSubCategory: Identifiable, Equatable, Hashable {
    case all
    //case staff
    case branch
    case school
    case part

    /// 고유 식별자
    var id: String {
        switch self {
        case .all: return "all"
        //case .staff: return "staff"
        case .branch: return "branch"
        case .school: return "school"
        case .part: return "part"
        }
    }

    /// 서브카테고리 표시 텍스트
    var labelText: String {
        switch self {
        case .all: return "전체"
        //case .staff: return "운영진 공지"
        case .branch: return "지부"
        case .school: return "학교"
        case .part: return "파트"
        }
    }

    /// 추가 필터가 필요한지 여부
    var hasFilter: Bool {
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
struct EditorSubCategorySelection: Equatable {
    /// 선택된 서브카테고리 목록
    var selectedSubCategories: Set<EditorSubCategory> = []
    /// 선택된 파트 목록
    var selectedParts: Set<UMCPartType> = []
    /// 선택된 지부
    var selectedBranch: NoticeTargetOption?
    /// 선택된 학교
    var selectedSchool: NoticeTargetOption?

    /// 선택 요약 텍스트
    var summaryText: String {
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
}

// MARK: - NoticeTargetOption
/// 공지 타겟 선택(지부/학교)용 옵션 모델
struct NoticeTargetOption: Identifiable, Equatable, Hashable {
    let id: Int
    let name: String
}

// MARK: - TargetSheetType
/// 게시판 분류별 타겟 설정 sheet(지부, 학교, 파트)
enum TargetSheetType: Identifiable {
    case branch
    case school
    case part
    
    var id: String { String(describing: self) }
    
    /// Sheet 헤더 표시 텍스트
    var title: String {
        switch self {
        case .branch: return "지부 선택"
        case .school: return "학교 선택"
        case .part: return "파트 선택"
        }
    }
}

// MARK: - LinkItem
/// 링크 첨부 카드
struct NoticeLinkItem: Identifiable, Equatable {
      let id = UUID()
      var link: String = ""
  }

// MARK: - ImageItem
/// 이미지 첨부 카드
struct NoticeImageItem: Identifiable {
    let id = UUID()
    /// 로컬에서 선택한 이미지 바이너리
    var imageData: Data?
    /// 서버에 업로드된 이미지 URL (수정 모드에서 기존 이미지)
    var imageURL: String? = nil
    /// 업로드 시 사용할 원본 기반 파일명 (예: IMG_1234.jpg)
    var uploadFileName: String? = nil
    /// Presigned URL 업로드 진행 중 여부
    var isLoading: Bool = false
    /// 서버에 저장된 파일 ID (업로드 완료 후 할당)
    var fileId: String? = nil
    
    static func == (lhs: NoticeImageItem, rhs: NoticeImageItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.isLoading == rhs.isLoading
    }
}

// MARK: - VoteOptionItem
/// 투표 옵션 항목
struct VoteOptionItem: Identifiable, Equatable {
    let id = UUID()
    var text: String = ""
}

// MARK: - VoteFormData
/// 투표 폼 데이터
struct VoteFormData: Equatable {
    /// 투표 제목
    var title: String = ""
    /// 투표 선택지 (기본 2개)
    var options: [VoteOptionItem] = [
        VoteOptionItem(),
        VoteOptionItem()
    ]
    /// 익명 투표 여부
    var isAnonymous: Bool = false
    /// 복수 선택 허용 여부
    var allowMultipleSelection: Bool = false
    
    // 시작일: 00:00:00부터
    var startDate: Date = Calendar.current.startOfDay(for: Date())
    
    // 마감일: 23:59:59까지
    var endDate: Date = {
        let calendar = Calendar.current
        let sevenDaysLater = calendar.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        let startOfDay = calendar.startOfDay(for: sevenDaysLater)
        return calendar.date(bySettingHour: 23, minute: 59, second: 59, of: startOfDay) ?? sevenDaysLater
    }()
    
    static let minOptionCount = 2
    static let maxOptionCount = 5

    /// 옵션 추가 가능 여부
    var canAddOption: Bool {
        options.count < Self.maxOptionCount
    }
    
    /// 옵션 삭제 가능 여부
    var canRemoveOption: Bool {
        options.count > Self.minOptionCount
    }
    
    /// 투표 만들기 완료조건: 위에서부터 연속으로 채워진 항목 개수
    var validOptionsCount: Int {
        var count = 0
        for option in options {
            if option.text.trimmingCharacters(in: .whitespaces).isEmpty {
                break
            }
            count += 1
        }
        return count
    }
    
    /// 날짜 범위 유효성 검증
    var isDateRangeValid: Bool {
          let calendar = Calendar.current
          let startDay = calendar.startOfDay(for: startDate)
          let endDay = calendar.startOfDay(for: endDate)
          return endDay > startDay
      }
    
    /// 투표 확정 가능 여부 (제목 + 2개 이상 항목 + 날짜 유효성)
    var canConfirm: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        validOptionsCount >= 2 &&
        isDateRangeValid
    }
}


// MARK: - EditorMockData
/// 공지 에디터 프리뷰/디버그용 목 데이터
enum EditorMockData {
    static let branches: [NoticeTargetOption] = [
        .init(id: 1, name: "Nova"),
        .init(id: 2, name: "Leo"),
        .init(id: 3, name: "Cetus"),
        .init(id: 4, name: "Aquarius"),
        .init(id: 5, name: "Cassiopeia"),
        .init(id: 6, name: "Scorpio"),
        .init(id: 7, name: "Pegasus")
    ]
    static let chapterSchools: [Int: [NoticeTargetOption]] = [
        1: [
            .init(id: 101, name: "가천대"), .init(id: 102, name: "강릉원주대"), .init(id: 103, name: "건국대"),
            .init(id: 104, name: "경기대"), .init(id: 105, name: "경북대"), .init(id: 106, name: "경희대"),
            .init(id: 107, name: "고려대")
        ],
        2: [
            .init(id: 201, name: "광운대"), .init(id: 202, name: "국민대"), .init(id: 203, name: "단국대"),
            .init(id: 204, name: "동국대"), .init(id: 205, name: "명지대"), .init(id: 206, name: "부산대"),
            .init(id: 207, name: "서울과기대")
        ],
        3: [
            .init(id: 301, name: "서울대"), .init(id: 302, name: "서울시립대"), .init(id: 303, name: "서강대"),
            .init(id: 304, name: "성균관대"), .init(id: 305, name: "세종대"), .init(id: 306, name: "숙명여대")
        ],
        4: [
            .init(id: 401, name: "숭실대"), .init(id: 402, name: "아주대"), .init(id: 403, name: "연세대"),
            .init(id: 404, name: "이화여대"), .init(id: 405, name: "인하대"), .init(id: 406, name: "전남대"),
            .init(id: 407, name: "전북대")
        ],
        5: [
            .init(id: 501, name: "중앙대"), .init(id: 502, name: "충남대"), .init(id: 503, name: "한양대")
        ]
    ]
    static let schools: [NoticeTargetOption] = [
        .init(id: 101, name: "가천대"), .init(id: 102, name: "강릉원주대"), .init(id: 103, name: "건국대"),
        .init(id: 104, name: "경기대"), .init(id: 105, name: "경북대"), .init(id: 106, name: "경희대"),
        .init(id: 107, name: "고려대"), .init(id: 201, name: "광운대"), .init(id: 202, name: "국민대"),
        .init(id: 203, name: "단국대"), .init(id: 204, name: "동국대"), .init(id: 205, name: "명지대"),
        .init(id: 206, name: "부산대"), .init(id: 207, name: "서울과기대"), .init(id: 301, name: "서울대"),
        .init(id: 302, name: "서울시립대"), .init(id: 303, name: "서강대"), .init(id: 304, name: "성균관대"),
        .init(id: 305, name: "세종대"), .init(id: 306, name: "숙명여대"), .init(id: 401, name: "숭실대"),
        .init(id: 402, name: "아주대"), .init(id: 403, name: "연세대"), .init(id: 404, name: "이화여대"),
        .init(id: 405, name: "인하대"), .init(id: 406, name: "전남대"), .init(id: 407, name: "전북대"),
        .init(id: 501, name: "중앙대"), .init(id: 502, name: "충남대"), .init(id: 503, name: "한양대")
    ]
}

// MARK: - NoticeEditorMode

/// 공지 에디터 모드
enum NoticeEditorMode: Equatable, Hashable {
    /// 새 공지 작성
    case create
    /// 기존 공지 수정
    case edit(noticeId: Int, notice: NoticeDetail)
}
