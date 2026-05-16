//
//  NoticeEditorForm.swift
//  NoticePresentation
//
//  Created by 이예지 on 5/9/26.
//

import Foundation
import NoticeDomain

// MARK: - TargetSheetType
/// 게시판 분류별 타겟 설정 sheet(지부, 학교, 파트)
public enum TargetSheetType: Identifiable {
    case branch
    case school
    case part
    
    public var id: String { String(describing: self) }
    
    /// Sheet 헤더 표시 텍스트
    public var title: String {
        switch self {
        case .branch: return "지부 선택"
        case .school: return "학교 선택"
        case .part: return "파트 선택"
        }
    }
}

// MARK: - LinkItem
/// 링크 첨부 카드
public struct NoticeLinkItem: Identifiable, Equatable {
    public let id = UUID()
    public var link: String = ""
    
    public init(link: String) {
        self.link = link
    }
}

// MARK: - ImageItem
/// 이미지 첨부 카드
public struct NoticeImageItem: Identifiable, Equatable {
    public let id = UUID()
    /// 로컬에서 선택한 이미지 바이너리
    public var imageData: Data?
    /// 서버에 업로드된 이미지 URL (수정 모드에서 기존 이미지)
    public var imageURL: String? = nil
    /// 업로드 시 사용할 원본 기반 파일명 (예: IMG_1234.jpg)
    public var uploadFileName: String? = nil
    /// Presigned URL 업로드 진행 중 여부
    public var isLoading: Bool = false
    /// 서버에 저장된 파일 ID (업로드 완료 후 할당)
    public var fileId: String? = nil
    
    public static func == (lhs: NoticeImageItem, rhs: NoticeImageItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.isLoading == rhs.isLoading
    }
    
    public init(
        imageData: Data? = nil,
        imageURL: String? = nil,
        uploadFileName: String? = nil,
        isLoading: Bool,
        fileId: String? = nil
    ) {
        self.imageData = imageData
        self.imageURL = imageURL
        self.uploadFileName = uploadFileName
        self.isLoading = isLoading
        self.fileId = fileId
    }
}

// MARK: - VoteOptionItem
/// 투표 옵션 항목
public struct VoteOptionItem: Identifiable, Equatable {
    public let id = UUID()
    public var text: String = ""
    
    public init(text: String = "") {
        self.text = text
    }
}

// MARK: - VoteFormData
/// 투표 폼 데이터
public struct VoteFormData: Equatable {
    /// 투표 제목
    public var title: String = ""
    /// 투표 선택지 (기본 2개)
    public var options: [VoteOptionItem] = [
        VoteOptionItem(),
        VoteOptionItem()
    ]
    /// 익명 투표 여부
    public var isAnonymous: Bool = false
    /// 복수 선택 허용 여부
    public var allowMultipleSelection: Bool = false
    
    // 시작일: 00:00:00부터
    public var startDate: Date = Calendar.current.startOfDay(for: Date())
    
    // 마감일: 23:59:59까지
    public var endDate: Date = {
        let calendar = Calendar.current
        let sevenDaysLater = calendar.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        let startOfDay = calendar.startOfDay(for: sevenDaysLater)
        return calendar.date(bySettingHour: 23, minute: 59, second: 59, of: startOfDay) ?? sevenDaysLater
    }()
    
    public static let minOptionCount = 2
    public static let maxOptionCount = 5

    /// 옵션 추가 가능 여부
    public var canAddOption: Bool {
        options.count < Self.maxOptionCount
    }
    
    /// 옵션 삭제 가능 여부
    public var canRemoveOption: Bool {
        options.count > Self.minOptionCount
    }
    
    /// 투표 만들기 완료조건: 위에서부터 연속으로 채워진 항목 개수
    public var validOptionsCount: Int {
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
    public var isDateRangeValid: Bool {
          let calendar = Calendar.current
          let startDay = calendar.startOfDay(for: startDate)
          let endDay = calendar.startOfDay(for: endDate)
          return endDay > startDay
      }
    
    /// 투표 확정 가능 여부 (제목 + 2개 이상 항목 + 날짜 유효성)
    public var canConfirm: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        validOptionsCount >= 2 &&
        isDateRangeValid
    }
    
    public init(
        title: String,
        options: [VoteOptionItem],
        isAnonymous: Bool,
        allowMultipleSelection: Bool,
        startDate: Date,
        endDate: Date
    ) {
        self.title = title
        self.options = options
        self.isAnonymous = isAnonymous
        self.allowMultipleSelection = allowMultipleSelection
        self.startDate = startDate
        self.endDate = endDate
    }
}

// MARK: - NoticeEditorMode

/// 공지 에디터 모드
public enum NoticeEditorMode: Equatable, Hashable {
    /// 새 공지 작성
    case create
    /// 기존 공지 수정
    case edit(noticeId: String, notice: NoticeDetail)
}
