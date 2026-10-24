//
//  SeparationService.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//

import Foundation

/// 분리 서버(`server/`)와 HTTP로 통신하는 실제 일꾼. SeparationClient의 liveValue가 이걸 부른다.
struct SeparationService: Sendable {

    /// 서버가 살아 있는지. 실패해도 에러를 던지지 않고 false.
    func health(baseURL: URL) async -> Bool {
        do {
            let (_, response) = try await URLSession.shared.data(from: baseURL.appendingPathComponent("health"))
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    /// 곡 파일을 올리고 작업 번호(jobID)를 받는다.
    func upload(file: URL, baseURL: URL) async throws -> String {
        // 파일 선택기로 고른 파일은 읽기 권한을 열어야 한다. 앱 안의 파일이면 false가 와도 그냥 읽는다.
        let isScoped = file.startAccessingSecurityScopedResource()
        defer { if isScoped { file.stopAccessingSecurityScopedResource() } }

        let fileData: Data
        do {
            fileData = try Data(contentsOf: file)
        } catch {
            throw SeparationServiceError.cannotReadFile
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(file.lastPathComponent)\"\r\n")
        body.append("Content-Type: application/octet-stream\r\n\r\n")
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n")

        var request = URLRequest(url: baseURL.appendingPathComponent("jobs"))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.upload(for: request, from: body)
        try check(response)

        struct Created: Decodable { let job_id: String }
        do {
            return try JSONDecoder().decode(Created.self, from: data).job_id
        } catch {
            throw SeparationServiceError.badResponse
        }
    }

    /// 분리가 어디까지 됐는지 한 번 확인한다.
    func status(jobID: String, baseURL: URL) async throws -> JobStatus {
        let (data, response) = try await URLSession.shared.data(from: baseURL.appendingPathComponent("jobs/\(jobID)"))
        try check(response)

        // 서버가 보내는 모양 → 앱의 JobStatus
        struct Raw: Decodable {
            let status: String
            let stems: [String]
            let error: String?
        }
        guard let raw = try? JSONDecoder().decode(Raw.self, from: data),
              let state = JobStatusState(rawValue: raw.status) else {
            throw SeparationServiceError.badResponse
        }
        return JobStatus(
            state: state,
            stems: raw.stems.compactMap(SessionID.init(rawValue:)),
            error: raw.error
        )
    }

    /// 나뉜 파트 mp3 하나를 받아서, 받은 파일의 임시 위치를 돌려준다.
    func downloadStem(jobID: String, stem: SessionID, baseURL: URL) async throws -> URL {
        let url = baseURL.appendingPathComponent("jobs/\(jobID)/stems/\(stem.rawValue).mp3")
        let (downloaded, response) = try await URLSession.shared.download(from: url)
        try check(response)

        // 시스템이 받은 임시 파일은 곧 지워질 수 있어서, 바로 우리 임시 위치로 옮긴다.
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(jobID)_\(stem.rawValue).mp3")
        try? FileManager.default.removeItem(at: tempURL)
        try FileManager.default.moveItem(at: downloaded, to: tempURL)
        return tempURL
    }

    private func check(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw SeparationServiceError.badResponse
        }
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
