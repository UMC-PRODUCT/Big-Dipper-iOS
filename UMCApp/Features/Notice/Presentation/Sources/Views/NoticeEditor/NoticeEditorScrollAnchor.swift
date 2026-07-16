//
//  NoticeEditorScrollAnchor.swift
//  NoticePresentation
//
//  Created by 이예지 on 7/16/26.
//

import Foundation

// MARK: - NoticeEditorScrollAnchor

/// 공지 에디터 화면의 스크롤 앵커 ID 단일 소스입니다.
///
/// 앵커를 부착하는 `NoticeEditorView`와 스크롤을 요청하는 `NoticeEditorBindings`가
/// 같은 값을 참조해야 하므로 한 곳에서만 정의합니다.
enum NoticeEditorScrollAnchor {
    static let imageSection: String = "notice_editor_image_section"
    static let voteSection: String = "notice_editor_vote_section"
}
