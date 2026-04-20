//
//  StudyMemberPreviewData.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/8/26.
//

import Foundation

extension StudyMemberItem {
    /// 기본 멤버 정보 (주차 없이)
    private static let baseMembers: [(
        serverID: String, name: String, nickname: String,
        part: StudyPart, university: String,
        studyTopic: String, submissionURL: String?,
        challengerWorkbookId: Int,
        profileImageURL: String?
    )] = [
        (
            "member_001", "정의찬", "제옹",
            .ios, "중앙대학교",
            "SwiftUI 심화",
            "https://github.com/jeong-ios/swiftui-deep-dive",
            1001,
            "https://picsum.photos/seed/member_001/140"
        ),
        (
            "member_002", "이재원", "리버",
            .ios, "한성대학교",
            "UIKit to SwiftUI 마이그레이션",
            "https://velog.io/@river/uikit-migration",
            1002,
            "https://picsum.photos/seed/member_002/140"
        ),
        (
            "member_003", "김연진", "코튼",
            .web, "상명대학교",
            "Next.js App Router",
            "https://github.com/cotton-web/nextjs-app-router",
            1003,
            "https://picsum.photos/seed/member_003/140"
        ),
        (
            "member_004", "박경운", "하늘",
            .spring, "중앙대학교",
            "Spring Boot JPA",
            nil,
            1004,
            "https://picsum.photos/seed/member_004/140"
        ),
        (
            "member_005", "박유수", "어헛차",
            .android, "숭실대학교",
            "Jetpack Compose",
            "https://github.com/sky-android/compose-study",
            1005,
            "https://picsum.photos/seed/member_005/140"
        ),
        (
            "member_006", "이희원", "삼이",
            .design, "성신여자대학교",
            "디자인 시스템 구축",
            nil,
            1006,
            "https://picsum.photos/seed/member_006/140"
        ),
        (
            "member_007", "김미주", "마티",
            .ios, "덕성여자대학교",
            "Combine & 비동기 처리",
            "https://velog.io/@mati/combine-async",
            1007,
            "https://picsum.photos/seed/member_007/140"
        ),
        (
            "member_008", "이예지", "소피",
            .ios, "가천대학교",
            "iOS 클린 아키텍처",
            "https://github.com/sophie-ios/clean-architecture",
            1008,
            "https://picsum.photos/seed/member_008/140"
        ),
        (
            "member_009", "양지애", "나루",
            .android, "서울여자대학교",
            "Kotlin Coroutines",
            nil,
            1009,
            "https://picsum.photos/seed/member_009/140"
        ),
        (
            "member_010", "조경석", "조나단",
            .android, "명지대학교",
            "MVVM 아키텍처 패턴",
            "https://github.com/jonathan-android/mvvm-pattern",
            1010,
            "https://picsum.photos/seed/member_010/140"
        ),
        (
            "member_011", "김도연", "도리",
            .android, "서울여자대학교",
            "Hilt 의존성 주입",
            nil,
            1011,
            "https://picsum.photos/seed/member_011/140"
        ),
        (
            "member_012", "박지현", "박박지현",
            .nodejs, "동국대학교",
            "REST API 설계",
            "https://github.com/park-nodejs/rest-api",
            1012,
            "https://picsum.photos/seed/member_012/140"
        ),
        (
            "member_013", "강하나", "와나",
            .spring, "한양대학교 ERICA",
            "Spring Security",
            nil,
            1013,
            "https://picsum.photos/seed/member_013/140"
        ),
        (
            "member_014", "박세은", "세니",
            .nodejs, "동덕여자대학교",
            "Docker & CI/CD",
            "https://velog.io/@seni/docker-cicd",
            1014,
            "https://picsum.photos/seed/member_014/140"
        ),
        (
            "member_015", "이예은", "스읍",
            .spring, "중앙대학교",
            "MySQL 쿼리 최적화",
            nil,
            1015,
            "https://picsum.photos/seed/member_015/140"
        ),
        (
            "member_016", "김민서", "갈래",
            .nodejs, "동국대학교",
            "Node.js Express",
            "https://github.com/kim-nodejs/express-study",
            1016,
            "https://picsum.photos/seed/member_016/140"
        )
    ]

    /// 주차별 mock 데이터 (약 75% 출석률 시뮬레이션)
    static let preview: [StudyMemberItem] = {
        var items: [StudyMemberItem] = []
        for (index, base) in baseMembers.enumerated() {
            let memberNumber = index + 1
            for week in 1...10 {
                guard week == 1
                    || (memberNumber + week) % 4 != 0
                else {
                    continue
                }
                items.append(
                    StudyMemberItem(
                        serverID: base.serverID,
                        challengerWorkbookId: base.challengerWorkbookId,
                        name: base.name,
                        nickname: base.nickname,
                        part: base.part,
                        university: base.university,
                        studyTopic: base.studyTopic,
                        week: week,
                        profileImageURL: base.profileImageURL,
                        submissionURL: base.submissionURL
                    )
                )
            }
        }
        return items
    }()
}
