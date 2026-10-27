//
//  AppRoute.swift
//  Syncy
//
//  Created by moo on 10/27/26.
//

import Foundation

/// AppFeature가 지금 어떤 화면을 보여줄지 정하는 값
enum AppRoute: Equatable {
    case launching
    case onboarding
    case main(MainScreen)
}

enum MainScreen: Equatable {
    case home
    case song(songID: String)
}
