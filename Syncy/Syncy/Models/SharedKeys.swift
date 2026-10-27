//
//  SharedKeys.swift
//  Syncy
//
//  Created by anna on 10/22/26.
//

import ComposableArchitecture

extension SharedReaderKey where Self == InMemoryKey<PinDraft?>.Default {
    static var pinDraft: Self {
        Self[.inMemory("pinDraft"), default: nil]
    }
}

extension SharedReaderKey where Self == InMemoryKey<ActivePin?>.Default {
    static var activePin: Self {
        Self[.inMemory("activePin"), default: nil]
    }
}

extension SharedReaderKey where Self == InMemoryKey<IdentifiedArrayOf<Patch>>.Default {
    static var patches: Self {
        Self[.inMemory("patches"), default: []]
    }
}

// 쓰기: AppFeature · Settings, 읽기: Home · Feedback · Player
extension SharedReaderKey where Self == InMemoryKey<Band?>.Default {
    static var currentBand: Self {
        Self[.inMemory("currentBand"), default: nil]
    }
}

// 쓰기: Settings, 읽기: Player · Practice
extension SharedReaderKey where Self == AppStorageKey<PracticeSettings>.Default {
    static var practiceSettings: Self {
        Self[.appStorage("practiceSettings"), default: PracticeSettings()]
    }
}

// 쓰기: Tutorial, 읽기: AppFeature
extension SharedReaderKey where Self == AppStorageKey<Bool>.Default {
    static var tutorialDone: Self {
        Self[.appStorage("tutorialDone"), default: false]
    }
}
