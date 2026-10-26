import Foundation

nonisolated enum AudioServiceError: LocalizedError {
    case noTracks
    case invalidAudio
    case invalidRange
    case missingMicrophoneDescription
    case microphoneDenied
    case alreadyRecording
    case cannotRecord
    case notRecording

    var errorDescription: String? {
        switch self {
        case .noTracks: "먼저 곡을 불러와 주세요."
        case .invalidAudio: "오디오 파일의 길이나 형식을 확인할 수 없어요."
        case .invalidRange: "녹음 구간이 곡 범위를 벗어났어요."
        case .missingMicrophoneDescription: "앱에 마이크 사용 설명이 설정되지 않았어요."
        case .microphoneDenied: "설정에서 마이크 사용을 허용해 주세요."
        case .alreadyRecording: "이미 녹음을 준비하거나 진행하고 있어요."
        case .cannotRecord: "녹음을 시작하거나 파일을 만들 수 없어요."
        case .notRecording: "진행 중인 녹음이 없어요."
        }
    }
}
