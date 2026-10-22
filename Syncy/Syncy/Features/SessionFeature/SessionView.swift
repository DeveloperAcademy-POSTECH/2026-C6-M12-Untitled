//
//  SessionView.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//

import SwiftUI
import ComposableArchitecture

struct SessionView: View {
    let store: StoreOf<SessionFeature>
    
    @State private var bpmText = ""
    @State private var firstBeatText = ""

    
    var body: some View {
        Button("곡 선택하기") {
            store.send(.fileSelected(fileURL:URL(fileURLWithPath: "/martin/test.mp3")))
        }
        
        HStack(spacing: 18){
            Text("BPM = 180")
            Text("첫 박 위치 = 11초")
            Button("세션 분리하기") {
                store.send(.songInfoEntered(bpm: 185, firstBeat: 11))
                store.send(.startSeparationTapped)
            }
        }
        // Phase에 따라 다른 뷰 보여주기...
        
    }
}
