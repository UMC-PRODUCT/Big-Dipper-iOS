//
//  MapCategoryTests.swift
//  CoreUIComponentsTests
//
//  Created by euijjang97 on 7/27/26.
//

import CoreDesignSystem
import MapKit
import SwiftUI
import Testing
@testable import CoreUIComponents

@Suite("MKPointOfInterestCategory+Icon/Color — POI 아이콘/배경색 매핑 분기")
struct MapCategoryTests {

    // MARK: - systemIconName

    @Test(
        "명시적으로 매핑된 카테고리는 지정된 SF Symbol을 반환한다",
        arguments: [
            (MKPointOfInterestCategory.airport, "airplane"),
            (.amusementPark, "flag.and.pennant.fill"),
            (.aquarium, "fish.fill"),
            (.atm, "banknote.fill"),
            (.bank, "banknote.fill"),
            (.bakery, "birthday.cake.fill"),
            (.cafe, "cup.and.saucer.fill"),
            (.campground, "tent.fill"),
            (.carRental, "car.fill"),
            (.evCharger, "car.fill"),
            (.gasStation, "car.fill"),
            (.parking, "car.fill"),
            (.hospital, "cross.case.fill"),
            (.pharmacy, "cross.case.fill"),
            (.hotel, "bed.double.fill"),
            (.laundry, "washer.fill"),
            (.library, "book.fill"),
            (.school, "book.fill"),
            (.university, "book.fill"),
            (.museum, "building.columns.fill"),
            (.park, "tree.fill"),
            (.police, "shield.fill"),
            (.postOffice, "envelope.fill"),
            (.publicTransport, "bus.fill"),
            (.restaurant, "fork.knife"),
            (.restroom, "figure.dress.line.vertical.figure"),
            (.store, "bag.fill"),
            (.theater, "popcorn.fill"),
            (.movieTheater, "popcorn.fill"),
        ]
    )
    func systemIconNameMapsKnownCategories(
        category: MKPointOfInterestCategory,
        expected: String
    ) {
        #expect(category.systemIconName == expected)
    }

    @Test("매핑되지 않은 카테고리는 기본 mappin 아이콘을 반환한다")
    func systemIconNameFallsBackForUnmappedCategory() {
        #expect(MKPointOfInterestCategory.stadium.systemIconName == "mappin.circle.fill")
    }

    // MARK: - backgroundColor

    @Test(
        "음식/음료 카테고리는 orange500 배경색을 반환한다",
        arguments: [
            MKPointOfInterestCategory.bakery,
            .cafe,
            .restaurant,
            .brewery,
            .distillery,
            .winery,
            .foodMarket,
        ]
    )
    func backgroundColorFoodCategoriesAreOrange(category: MKPointOfInterestCategory) {
        #expect(category.backgroundColor == Color.orange500)
    }

    @Test(
        "자연/휴식 카테고리는 green500 배경색을 반환한다",
        arguments: [
            MKPointOfInterestCategory.park,
            .campground,
            .beach,
            .nationalPark,
            .zoo,
            .aquarium,
        ]
    )
    func backgroundColorNatureCategoriesAreGreen(category: MKPointOfInterestCategory) {
        #expect(category.backgroundColor == Color.green500)
    }

    @Test(
        "교통/여행 카테고리는 시스템 blue 배경색을 반환한다",
        arguments: [
            MKPointOfInterestCategory.airport,
            .carRental,
            .evCharger,
            .gasStation,
            .parking,
            .publicTransport,
            .marina,
        ]
    )
    func backgroundColorTransportCategoriesAreBlue(category: MKPointOfInterestCategory) {
        #expect(category.backgroundColor == Color.blue)
    }

    @Test(
        "건강/긴급 카테고리는 red500 배경색을 반환한다",
        arguments: [
            MKPointOfInterestCategory.hospital,
            .pharmacy,
            .police,
            .fireStation,
        ]
    )
    func backgroundColorHealthCategoriesAreRed(category: MKPointOfInterestCategory) {
        #expect(category.backgroundColor == Color.red500)
    }

    @Test(
        "쇼핑/엔터테인먼트 카테고리는 시스템 purple 배경색을 반환한다",
        arguments: [
            MKPointOfInterestCategory.store,
            .movieTheater,
            .theater,
            .amusementPark,
            .nightlife,
        ]
    )
    func backgroundColorShoppingCategoriesArePurple(category: MKPointOfInterestCategory) {
        #expect(category.backgroundColor == Color.purple)
    }

    @Test(
        "교육/문화 카테고리는 시스템 brown 배경색을 반환한다",
        arguments: [
            MKPointOfInterestCategory.library,
            .museum,
            .school,
            .university,
        ]
    )
    func backgroundColorEducationCategoriesAreBrown(category: MKPointOfInterestCategory) {
        #expect(category.backgroundColor == Color.brown)
    }

    @Test(
        "금융/생활 편의 카테고리는 시스템 gray 배경색을 반환한다",
        arguments: [
            MKPointOfInterestCategory.atm,
            .bank,
            .postOffice,
            .laundry,
            .restroom,
            .fitnessCenter,
        ]
    )
    func backgroundColorConvenienceCategoriesAreGray(category: MKPointOfInterestCategory) {
        #expect(category.backgroundColor == Color.gray)
    }

    @Test("숙박 카테고리는 indigo500 배경색을 반환한다")
    func backgroundColorHotelIsIndigo() {
        #expect(MKPointOfInterestCategory.hotel.backgroundColor == Color.indigo500)
    }

    @Test("매핑되지 않은 카테고리는 secondary 배경색을 반환한다")
    func backgroundColorFallsBackToSecondaryForUnmappedCategory() {
        #expect(MKPointOfInterestCategory.stadium.backgroundColor == Color.secondary)
    }
}
