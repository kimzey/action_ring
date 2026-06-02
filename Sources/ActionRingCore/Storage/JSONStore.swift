import Foundation

/// Tiny file-backed JSON store under `~/Library/Application Support/ActionRing`.
/// Used for both settings and the profile database. No network, ever.
public struct JSONStore: Sendable {

    public let directory: URL

    public init(appName: String = "ActionRing") {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.directory = base.appendingPathComponent(appName, isDirectory: true)
    }

    /// For tests / sandboxing: store in an explicit directory.
    public init(directory: URL) { self.directory = directory }

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func url(for name: String) -> URL {
        directory.appendingPathComponent(name)
    }

    public func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        let url = url(for: name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: data)
    }

    @discardableResult
    public func save<T: Encodable>(_ value: T, to name: String) -> Bool {
        do {
            try ensureDirectory()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(value)
            try data.write(to: url(for: name), options: .atomic)
            return true
        } catch {
            return false
        }
    }
}
