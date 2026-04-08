//
//  NoticeEditorViewModel.swift
//  AppProduct
//
//  Created by 이예지 on 1/24/26.
//

import Foundation
import SwiftUI
import PhotosUI
import UIKit

/// 공지사항 에디터 ViewModel
///
/// 공지 생성/수정, 카테고리/타겟 선택, 이미지/링크/투표 첨부 상태를 관리합니다.
@Observable
final class NoticeEditorViewModel: MultiplePhotoPickerManageable {

    // MARK: - Dependency

    let container: DIContainer

    var noticeUseCase: NoticeUseCaseProtocol {
        container.resolve(NoticeUseCaseProtocol.self)
    }

    var targetUseCase: NoticeEditorTargetUseCaseProtocol {
        container.resolve(NoticeEditorTargetUseCaseProtocol.self)
    }

    var genRepository: ChallengerGenRepositoryProtocol {
        container.resolve(ChallengerGenRepositoryProtocol.self)
    }

    var errorHandler: ErrorHandler?

    // MARK: - Mode

    /// 편집 모드 (생성 or 수정)
    let mode: NoticeEditorMode

    // MARK: - User Context

    var gisuId: Int {
        UserDefaults.standard.integer(forKey: AppStorageKey.gisuId)
    }

    var organizationId: Int {
        UserDefaults.standard.integer(forKey: AppStorageKey.organizationId)
    }

    var schoolId: Int {
        UserDefaults.standard.integer(forKey: AppStorageKey.schoolId)
    }

    /// 사용자 조직 타입 (AppStorage 반영)
    var organizationType: OrganizationType?

    /// 사용자 권한/역할 (AppStorage 반영)
    var memberRole: ManagementTeam?

    /// 뷰에서 전달받는 사용자 컨텍스트(우선 적용)
    var userGisuId: Int?
    var userChapterId: Int?
    var selectedGenerationValue: Int?

    var resolvedGisuId: Int {
        userGisuId ?? gisuId
    }

    var resolvedChapterId: Int {
        userChapterId ?? organizationId
    }

    var selectedGenerationTitle: String? {
        guard let selectedGenerationValue else { return nil }
        return "\(selectedGenerationValue)기"
    }

    // MARK: - View State

    /// 공지 생성/수정 상태
    ///
    /// ViewModel 기능을 extension 파일로 분리해 관리하므로,
    /// 동일 타입 extension에서도 상태 전환이 가능하도록 setter를 내부 공개합니다.
    var createState: Loadable<NoticeDetail> = .idle

    /// 선택된 메인 카테고리
    var selectedCategory: EditorMainCategory {
        didSet {
            if oldValue != selectedCategory {
                subCategorySelection = EditorSubCategorySelection()
            }
        }
    }

    /// 서브카테고리 선택 상태
    var subCategorySelection = EditorSubCategorySelection()

    /// 공지 타겟(지부, 학교, 파트) 시트 표시 여부
    var activeSheetType: TargetSheetType?

    /// 사용자 조직 타입에 따라 노출 가능한 메인 카테고리 목록
    var availableCategories: [EditorMainCategory]

    /// 지부 선택 시트 목록 (중앙 선택 시)
    var branchOptions: [NoticeTargetOption] = []

    /// 학교 선택 시트 목록
    var schoolOptions: [NoticeTargetOption] = []

    /// 타겟(지부/학교/파트) 시트 데이터 로딩 상태
    var targetOptionsState: Loadable<Bool> = .idle

    /// 공지사항 제목
    var title: String = ""

    /// 공지사항 본문 (일반 텍스트 — 서버 전송용)
    var content: String = ""

    /// 리치 텍스트 에디터 툴바 ViewModel
    var editorToolbarViewModel: EditorToolbarViewModel = EditorToolbarViewModel()

    /// 리치 텍스트 에디터 본문 (NSAttributedString — 로컬 편집용)
    var richAttributedContent: NSAttributedString = NSAttributedString(string: "")

    /// 투표 폼 시트 표시 여부
    var showVoting: Bool = false

    /// 투표 폼 데이터
    var voteFormData: VoteFormData = VoteFormData()

    /// 투표 확정 여부
    var isVoteConfirmed: Bool = false

    /// 화면 AlertPrompt
    var alertPrompt: AlertPrompt?

    /// PhotosPicker 선택 아이템
    var selectedPhotoItems: [PhotosPickerItem] = []

    /// 로드된 UIImage 목록
    var selectedImages: [UIImage] = []

    /// 첨부 이미지 카드 목록
    var noticeImages: [NoticeImageItem] = []

    /// 첨부 링크 카드 목록
    var noticeLinks: [NoticeLinkItem] = []

    /// 알림 발송 여부
    var allowAlert: Bool = true

    // MARK: - Edit Snapshot

    /// 수정 화면 원본 제목
    var originalTitle: String = ""

    /// 수정 화면 원본 본문
    var originalContent: String = ""

    /// 수정 화면 원본 링크 목록
    var originalLinks: [String] = []

    /// 수정 화면 원본 이미지 ID 목록 (순서 유지)
    var originalImageIds: [String] = []
    /// 수정 화면 원본 이미지 URL 목록 (ID 미포함 응답 대비)
    var originalImageURLs: [String] = []

    /// 수정 화면 원본 투표 폼
    var originalVoteFormData: VoteFormData?

    /// 수정 진입 시점의 원본 투표 스냅샷
    var initialVoteSnapshot: VoteSnapshot?

    // MARK: - Derived State

    /// 수정 모드 여부
    var isEditMode: Bool {
        if case .edit = mode {
            return true
        }
        return false
    }

    /// 저장 가능 여부
    ///
    /// 생성: 제목/내용 필수
    /// 수정: 제목/내용 필수 + 실제 변경사항 존재
    var canSubmit: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasRequiredFields = !trimmedTitle.isEmpty && !trimmedContent.isEmpty

        switch mode {
        case .create:
            return hasRequiredFields
        case .edit:
            return hasRequiredFields && hasEditableChanges
        }
    }

    // MARK: - Initializer

    init(
        container: DIContainer,
        mode: NoticeEditorMode = .create,
        selectedGisuId: Int? = nil,
        initialCategory: EditorMainCategory? = nil
    ) {
        self.container = container
        self.mode = mode
        self.userGisuId = selectedGisuId

        let categories: [EditorMainCategory] = [.all, .central]
        availableCategories = categories
        selectedCategory = initialCategory.flatMap { categories.contains($0) ? $0 : nil } ?? categories.first ?? .all

        if case .edit(_, let notice) = mode {
            loadNoticeForEdit(notice)
        }

        refreshSelectedGenerationValue()
    }

    // MARK: - Helper

    /// 선택된 gisuId를 사용자 표시용 기수 값으로 역매핑합니다.
    func refreshSelectedGenerationValue() {
        let currentGisuId = resolvedGisuId
        guard currentGisuId > 0 else {
            selectedGenerationValue = nil
            return
        }

        do {
            let selectedGeneration = try genRepository
                .fetchGenGisuIdPairs()
                .first(where: { $0.gisuId == currentGisuId })?
                .gen
            selectedGenerationValue = selectedGeneration ?? currentGisuId
        } catch {
            selectedGenerationValue = currentGisuId
        }
    }
}
