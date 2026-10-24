//
//  SeparationServiceError.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//

import Foundation

enum SeparationServiceError: LocalizedError {
    case cannotReadFile
    case badResponse

    var errorDescription: String? {
        switch self {
        case .cannotReadFile: return "선택한 파일을 읽을 수 없습니다."
        case .badResponse: return "서버 응답을 해석할 수 없습니다."
        }
    }
}
