//
//  ServerConfig.swift
//  Syncy
//

import Foundation

/// 분리 서버 설정. 서버 실행 방법은 저장소의 `server/README.md`.
enum ServerConfig {
    /// 시뮬레이터에서는 Mac 자신. iPad에서는 같은 Wi-Fi의 Mac IP로 바꾼다.
    static let separationBaseURL = URL(string: "http://127.0.0.1:8756")!
    /// 분리가 끝났는지 다시 확인하는 간격
    static let statusPollInterval: Duration = .seconds(1.5)
}
