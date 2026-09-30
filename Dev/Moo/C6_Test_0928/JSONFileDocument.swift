import SwiftUI
import UniformTypeIdentifiers

/// Minimal FileDocument wrapper so `.fileExporter` can hand out the JSON we
/// already encoded, without SwiftUI re-encoding anything itself.
struct JSONFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let fileData = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = fileData
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
