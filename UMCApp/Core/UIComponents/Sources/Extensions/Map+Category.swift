//
//  Map+Category.swift
//  CoreUIComponents
//
//  Created by euijjang97 on 7/27/26.
//

import CoreDesignSystem
import MapKit
import SwiftUI

// MARK: - MKPointOfInterestCategory + Icon

public extension MKPointOfInterestCategory {

    var systemIconName: String {
        switch self {
        case .airport: return "airplane"
        case .amusementPark: return "flag.and.pennant.fill"
        case .aquarium: return "fish.fill"
        case .atm, .bank: return "banknote.fill"
        case .bakery: return "birthday.cake.fill"
        case .cafe: return "cup.and.saucer.fill"
        case .campground: return "tent.fill"
        case .carRental, .evCharger, .gasStation, .parking: return "car.fill"
        case .hospital, .pharmacy: return "cross.case.fill"
        case .hotel: return "bed.double.fill"
        case .laundry: return "washer.fill"
        case .library, .school, .university: return "book.fill"
        case .museum: return "building.columns.fill"
        case .park: return "tree.fill"
        case .police: return "shield.fill"
        case .postOffice: return "envelope.fill"
        case .publicTransport: return "bus.fill"
        case .restaurant: return "fork.knife"
        case .restroom: return "figure.dress.line.vertical.figure"
        case .store: return "bag.fill"
        case .theater, .movieTheater: return "popcorn.fill"
        default: return "mappin.circle.fill"
        }
    }
}

// MARK: - MKPointOfInterestCategory + Background Color

public extension MKPointOfInterestCategory {

    var backgroundColor: Color {
        switch self {
        // 음식 및 음료
        case .bakery, .cafe, .restaurant, .brewery, .distillery, .winery, .foodMarket:
            return .orange500

        // 자연 및 휴식
        case .park, .campground, .beach, .nationalPark, .zoo, .aquarium:
            return .green500

        // 교통 및 여행
        // TODO: CoreDesignSystem에 blue 색상 패밀리 추가 시 토큰화
        case .airport, .carRental, .evCharger, .gasStation, .parking, .publicTransport, .marina:
            return .blue

        // 건강 및 긴급
        case .hospital, .pharmacy, .police, .fireStation:
            return .red500

        // 쇼핑 및 엔터테인먼트
        // TODO: CoreDesignSystem에 purple 색상 패밀리 추가 시 토큰화
        case .store, .movieTheater, .theater, .amusementPark, .nightlife:
            return .purple

        // 교육 및 문화
        // TODO: CoreDesignSystem에 brown 색상 패밀리 추가 시 토큰화
        case .library, .museum, .school, .university:
            return .brown

        // 금융 및 생활 편의
        // TODO: CoreDesignSystem에 gray 색상 패밀리 추가 시 토큰화
        case .atm, .bank, .postOffice, .laundry, .restroom, .fitnessCenter:
            return .gray

        // 숙박
        case .hotel:
            return .indigo500

        // 기타
        default:
            return .secondary
        }
    }
}
