//
//  EditorMockData.swift
//  NoticePresentation
//
//  Created by 이예지 on 5/9/26.
//

import Foundation

#if DEBUG
// MARK: - EditorMockData
/// 공지 에디터 프리뷰/디버그용 목 데이터
public enum EditorMockData {
    public static let branches: [NoticeTargetOption] = [
        .init(id: "1", name: "Nova"),
        .init(id: "2", name: "Leo"),
        .init(id: "3", name: "Cetus"),
        .init(id: "4", name: "Aquarius"),
        .init(id: "5", name: "Cassiopeia"),
        .init(id: "6", name: "Scorpio"),
        .init(id: "7", name: "Pegasus")
    ]
    public static let chapterSchools: [Int: [NoticeTargetOption]] = [
        1: [
            .init(id: "101", name: "가천대"), .init(id: "102", name: "강릉원주대"), .init(id: "103", name: "건국대"),
            .init(id: "104", name: "경기대"), .init(id: "105", name: "경북대"), .init(id: "106", name: "경희대"),
            .init(id: "107", name: "고려대")
        ],
        2: [
            .init(id: "201", name: "광운대"), .init(id: "202", name: "국민대"), .init(id: "203", name: "단국대"),
            .init(id: "204", name: "동국대"), .init(id: "205", name: "명지대"), .init(id: "206", name: "부산대"),
            .init(id: "207", name: "서울과기대")
        ],
        3: [
            .init(id: "301", name: "서울대"), .init(id: "302", name: "서울시립대"), .init(id: "303", name: "서강대"),
            .init(id: "304", name: "성균관대"), .init(id: "305", name: "세종대"), .init(id: "306", name: "숙명여대")
        ],
        4: [
            .init(id: "401", name: "숭실대"), .init(id: "402", name: "아주대"), .init(id: "403", name: "연세대"),
            .init(id: "404", name: "이화여대"), .init(id: "405", name: "인하대"), .init(id: "406", name: "전남대"),
            .init(id: "407", name: "전북대")
        ],
        5: [
            .init(id: "501", name: "중앙대"), .init(id: "502", name: "충남대"), .init(id: "503", name: "한양대")
        ]
    ]
    public static let schools: [NoticeTargetOption] = [
        .init(id: "101", name: "가천대"), .init(id: "102", name: "강릉원주대"), .init(id: "103", name: "건국대"),
        .init(id: "104", name: "경기대"), .init(id: "105", name: "경북대"), .init(id: "106", name: "경희대"),
        .init(id: "107", name: "고려대"), .init(id: "201", name: "광운대"), .init(id: "202", name: "국민대"),
        .init(id: "203", name: "단국대"), .init(id: "204", name: "동국대"), .init(id: "205", name: "명지대"),
        .init(id: "206", name: "부산대"), .init(id: "207", name: "서울과기대"), .init(id: "301", name: "서울대"),
        .init(id: "302", name: "서울시립대"), .init(id: "303", name: "서강대"), .init(id: "304", name: "성균관대"),
        .init(id: "305", name: "세종대"), .init(id: "306", name: "숙명여대"), .init(id: "401", name: "숭실대"),
        .init(id: "402", name: "아주대"), .init(id: "403", name: "연세대"), .init(id: "404", name: "이화여대"),
        .init(id: "405", name: "인하대"), .init(id: "406", name: "전남대"), .init(id: "407", name: "전북대"),
        .init(id: "501", name: "중앙대"), .init(id: "502", name: "충남대"), .init(id: "503", name: "한양대")
    ]
}
#endif
