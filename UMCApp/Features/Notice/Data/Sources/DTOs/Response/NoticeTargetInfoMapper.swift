//
//  NoticeTargetInfoMapper.swift
//  NoticeData
//
//  Created by 이예지 on 5/17/26.
//

import Foundation
import NoticeDomain
import UMCFoundation

/// NoticeTargetInfoDTO → 도메인 모델 변환 유틸리티
extension NoticeTargetInfoDTO {

    // MARK: - Computed Property
    /// 기수 ID를 Int로 변환 (실패 시 0)
    var generationValue: Int {
        if let targetGisu, let generation = Int(targetGisu), generation > 0 {
            return generation
        }
        return 0
    }

    /// targetInfo 기반으로 공지 출처(scope)를 추론합니다.
    var resolvedScope: NoticeScope {
        if targetSchoolId != nil {
            return .campus
        }
        if targetChapterId != nil {
            return .branch
        }
        return .central
    }

    /// targetInfo 기반으로 공지 카테고리를 추론합니다.
    var resolvedCategory: NoticeCategory {
        if let part = targetParts?.first {
            return .part(part)
        }
        return .general
    }

    /// 일반 공지(scope=branch) 칩 표기용 이름을 제공합니다.
    var resolvedScopeDisplayName: String? {
        switch resolvedScope {
        case .branch:
            return resolvedChapterName
        case .central, .campus:
            return nil
        }
    }

    var resolvedParts: [UMCPartType] {
        targetParts ?? []
    }

    /// iOS-01 "UMC 공지" 필터에 포함되는지 여부를 반환합니다.
    ///
    /// 서버-01(전체 기수 전체 공지), 서버-03(특정 기수 전체 공지)만 허용합니다.
    var isUMCWideGeneralNotice: Bool {
        targetChapterId == nil && targetSchoolId == nil && resolvedParts.isEmpty
    }

    // MARK: - Function
    /// TargetAudience 도메인 모델로 변환합니다.
    func toTargetAudience(scope: NoticeScope? = nil) -> TargetAudience {
        let targetScope = scope ?? resolvedScope
        return TargetAudience(
            generation: String(generationValue),
            scope: targetScope,
            parts: resolvedParts,
            chapterId: targetChapterId,
            schoolId: targetSchoolId,
            branches: targetScope == .branch ? [resolvedChapterName].compactMap { $0 } : [],
            schools: targetScope == .campus ? [resolvedSchoolName].compactMap { $0 } : []
        )
    }
}
