//
//  AppView.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//

import SwiftUI
import ComposableArchitecture

struct AppView: View {
    let store: StoreOf<AppFeature>
    
    var body: some View {
        SessionView(
            store: store.scope(state: \.session, action: \.session)
        )
    }
}
