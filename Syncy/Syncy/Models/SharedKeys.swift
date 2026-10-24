//
//  SharedKeys.swift
//  Syncy
//
//  Created by martin on 10/22/26.
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
