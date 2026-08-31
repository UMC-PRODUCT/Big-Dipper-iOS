//
//  PlaceSelection.swift
//  CoreUIComponents
//
//  Created by euijjang97 on 7/27/26.
//

import CoreLocation

// MARK: - PlaceSelection

/// 지도에서 선택한 장소 정보를 표현하는 Core-safe 모델
public struct PlaceSelection: Sendable {

    // MARK: - Property

    public var name: String
    public var address: String
    public var coordinate: CLLocationCoordinate2D

    // MARK: - Initializer

    public init(name: String, address: String, coordinate: CLLocationCoordinate2D) {
        self.name = name
        self.address = address
        self.coordinate = coordinate
    }
}

// MARK: - PlaceSelection + Equatable

extension PlaceSelection: Equatable {

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.name == rhs.name
            && lhs.address == rhs.address
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

// MARK: - PlaceSelection + Empty

extension PlaceSelection {

    public static let empty = PlaceSelection(
        name: "",
        address: "",
        coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0)
    )

    public var isEmpty: Bool {
        self == .empty
    }
}
