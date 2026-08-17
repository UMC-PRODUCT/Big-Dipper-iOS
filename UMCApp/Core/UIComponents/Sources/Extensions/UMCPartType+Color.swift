//
//  UMCPartType+Color.swift
//  CoreUIComponents
//
//  Created by 이예지 on 5/8/26.
//

import SwiftUI
import UMCFoundation

extension UMCPartType {

    /// 명함 시드 컬러 — 시안이 raw hex 로 지정한 파트 브랜드 색.
    ///
    /// ``color`` 와 **일부러 분리해 둔다.** ``color`` 는 SwiftUI 시스템 컬러라
    /// Activity·Notice 가 이미 그 값으로 화면을 그리고 있고, 시안 hex 와는 4종이
    /// 어긋난다(Admin·PM·Web·Android). 여기서 ``color`` 를 시안 값으로 갈아끼우면
    /// 명함과 무관한 남의 화면 색이 같이 바뀐다.
    ///
    /// 명함첩 카드는 배경 그라데이션 2겹과 칩 2개가 전부 이 한 값에서 파생된다.
    ///
    /// - Note: iOS 파트만 시안에 변형이 없어(7종) `systemOrange` 로 채웠다.
    ///   나머지 7종이 iOS 시스템 팔레트 계열이고 주황이 비어 있어 충돌하지 않는다.
    ///   디자이너 확인이 오면 이 값만 교체하면 된다.
    public var seedColor: Color {
        switch self {
        case .admin:
            return Color(red: 97 / 255, green: 85 / 255, blue: 245 / 255)
        case .pm:
            return Color(red: 203 / 255, green: 48 / 255, blue: 224 / 255)
        case .design:
            return Color(red: 255 / 255, green: 45 / 255, blue: 85 / 255)
        case .server(let type):
            switch type {
            case .spring:
                return Color(red: 52 / 255, green: 199 / 255, blue: 89 / 255)
            case .node:
                return Color(red: 255 / 255, green: 204 / 255, blue: 0 / 255)
            }
        case .front(let type):
            switch type {
            case .web:
                return Color(red: 172 / 255, green: 127 / 255, blue: 94 / 255)
            case .android:
                return Color(red: 0 / 255, green: 192 / 255, blue: 232 / 255)
            case .ios:
                return Color(red: 255 / 255, green: 149 / 255, blue: 0 / 255)
            }
        }
    }

    /// 파트별 고유 색상
    public var color: Color {
        switch self {
        case .admin:
            return .indigo
        case .pm:
            return .purple
        case .design:
            return .pink
        case .server(let type):
            switch type {
            case .spring: return .green
            case .node:   return .yellow
            }
        case .front(let type):
            switch type {
            case .web:     return .brown
            case .android: return .teal
            case .ios:     return .orange
            }
        }
    }
}
