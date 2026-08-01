//
//  Coordinate+MapKit.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/30/26.
//

import ActivityDomain
import CoreLocation

// MARK: - Coordinate + CoreLocation

extension Coordinate {

    /// 도메인 좌표를 지도 표시용 `CLLocationCoordinate2D` 로 변환합니다.
    ///
    /// 변환을 Presentation 에 두는 이유는 `ActivityDomain` 이 지도 프레임워크 타입을
    /// 노출하지 않도록 유지하기 위해서입니다. 지도 렌더링이 필요한 레이어에서만 변환합니다.
    var toCLLocationCoordinate2D: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
