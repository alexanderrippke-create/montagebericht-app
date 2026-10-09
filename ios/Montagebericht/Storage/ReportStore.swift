import Foundation
import CryptoKit
import Combine

enum ReportError: LocalizedError {
    case message(String)
    var errorDescription: String? { switch self { case .message(let text): return text } }
}

@MainActor
final class ReportStore: ObservableObject {
    @Published private(set) var reports: [Report] = []
    @Published var pendingReports: [UUID: Report] = [:]
    @Published var settings = OfficeSettings()
    @Published var issue: String?
    let root: URL
    private let manager: FileManager
    private var documentBookmarks: [String: Data] = [:]
    init(root: URL? = nil, manager: FileManager = .default) {
        self.manager = manager
        self.root = root ?? manager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Montagebericht", isDirectory: true)
        reload()
    }
    private func folder(_ id: UUID) -> URL { root.appendingPathComponent(id.uuidString, isDirectory: true) }
    private func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(value)
    }
    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }
    func reload() {
        do {
            try manager.createDirectory(at: root, withIntermediateDirectories: true)
            if let data = try? Data(contentsOf: root.appendingPathComponent("document-paths.json")), let bookmarks = try? decode([String: Data].self, from: data) { documentBookmarks = bookmarks }
            let settingsURL = root.appendingPathComponent("settings.json")
            if manager.fileExists(atPath: settingsURL.path) {
                do {
                    let loadedSettings = try decode(OfficeSettings.self, from: Data(contentsOf: settingsURL))
                    if let validation = loadedSettings.validation { throw ReportError.message(validation) }
                    settings = loadedSettings
                } catch { issue = "Sachbearbeiter-Einstellungen konnten nicht geladen werden. Berichte bleiben verfügbar; bitte Einstellungen prüfen. Originaldatei bleibt erhalten." }
            }
            var loaded: [Report] = []; var failed = 0
            for url in try manager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) where UUID(uuidString: url.lastPathComponent) != nil {
                do {
                    let report = try decode(Report.self, from: Data(contentsOf: url.appendingPathComponent("report.json")))
                    guard report.schemaVersion == 1, report.id.uuidString == url.lastPathComponent else { throw ReportError.message("Unbekanntes Datenformat") }
                    loaded.append(report)
                } catch { failed += 1 }
            }
            let replaced = Set(loaded.filter(\.isFinalized).compactMap(\.replacesDraftID))
            reports = loaded.filter { !replaced.contains($0.id) }.sorted { $0.updatedAt > $1.updatedAt }
            if failed > 0 { issue = "\(failed) Bericht(e) konnten nicht geladen werden. Die Originaldateien bleiben erhalten. Bitte Datensicherung prüfen." }
        } catch { issue = "Lokale Daten konnten nicht geladen werden: \(error.localizedDescription)" }
    }
    func save(_ source: Report) throws {
        if reports.contains(where: { $0.isFinalized && $0.replacesDraftID == source.id }) { throw ReportError.message("Dieser Entwurf wurde bereits abgeschlossen. Bitte eine neue Bearbeitung erstellen.") }
        if let existing = reports.first(where: { $0.id == source.id }), existing.isFinalized { throw ReportError.message("Abgeschlossene Berichte sind gesperrt. Bitte eine neue Bearbeitung erstellen.") }
        var report = source; report.updatedAt = Date()
        let target = folder(report.id)
        try manager.createDirectory(at: target, withIntermediateDirectories: true)
        try encode(report).write(to: target.appendingPathComponent("report.json"), options: [.atomic, .completeFileProtectionUnlessOpen])
        reports.removeAll { $0.id == report.id }; reports.insert(report, at: 0)
        try saveDocument(report)
    }
    func finalize(_ source: Report, renderer: (Report) throws -> Data) throws -> Report {
        guard !source.isFinalized else { throw ReportError.message("Bericht ist bereits abgeschlossen.") }
        let problems = source.validation(finalizing: true)
        guard problems.isEmpty else { throw ReportError.message(problems.joined(separator: "\n")) }
        var completed = source
        completed.finalizedAt = Date(); completed.updatedAt = Date()
        // Eine komplette neue Fassung wird atomar als eigener Ordner veröffentlicht.
        // Der ursprüngliche Entwurf bleibt bei jedem Fehler erhalten.
        completed.id = UUID()
        completed.replacesDraftID = source.id
        // PDF muss dieselbe endgültige ID tragen.
        let finalPDF = try renderer(completed)
        completed.archiveSHA256 = Self.digest(finalPDF)
        let staging = root.appendingPathComponent("pending-" + UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: staging) }
        try finalPDF.write(to: staging.appendingPathComponent("bericht.pdf"), options: .completeFileProtectionUnlessOpen)
        try encode(completed).write(to: staging.appendingPathComponent("report.json"), options: .completeFileProtectionUnlessOpen)
        try manager.moveItem(at: staging, to: folder(completed.id))
        reports.removeAll { $0.id == source.id }
        reports.insert(completed, at: 0)
        // Erst nach Veröffentlichung des vollständigen Archivs den Entwurf entfernen.
        // Bei Abbruch/Dateifehler verhindert replacesDraftID seine Wiederverwendung.
        if manager.fileExists(atPath: folder(source.id).path) { try? manager.removeItem(at: folder(source.id)) }
        return completed
    }
    nonisolated static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    func archivedPDF(_ report: Report) throws -> Data {
        let data = try Data(contentsOf: folder(report.id).appendingPathComponent("bericht.pdf"))
        guard report.isFinalized, report.archiveSHA256 == Self.digest(data) else { throw ReportError.message("Die archivierte PDF stimmt nicht mit dem gespeicherten Nachweis überein.") }
        return data
    }
    func delete(_ report: Report) throws {
        if let original = report.replacesDraftID, manager.fileExists(atPath: folder(original).path) { try manager.removeItem(at: folder(original)) }
        try manager.removeItem(at: folder(report.id)); reports.removeAll { $0.id == report.id }
    }
    func saveSettings(_ value: OfficeSettings) throws {
        var cleaned = value
        cleaned.defaultName = cleaned.defaultName.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned.contacts = cleaned.contacts.map { contact in
            var contact = contact
            contact.name = contact.name.trimmingCharacters(in: .whitespacesAndNewlines)
            contact.email = contact.email.trimmingCharacters(in: .whitespacesAndNewlines)
            if let previous = settings.contacts.first(where: { $0.id == contact.id }), previous.name != contact.name {
                contact.aliases = Array(Set((contact.aliases ?? []) + (previous.aliases ?? []) + [previous.name]))
            }
            return contact
        }
        if cleaned.resolve(cleaned.defaultName) == nil {
            if let previous = settings.resolve(settings.defaultName), let renamed = cleaned.contacts.first(where: { $0.id == previous.id }) { cleaned.defaultName = renamed.name }
            else if let first = cleaned.contacts.first { cleaned.defaultName = first.name }
        }
        if let selected = cleaned.resolve(cleaned.defaultName) { cleaned.defaultName = selected.name }
        if let error = cleaned.validation { throw ReportError.message(error) }
        try encode(cleaned).write(to: root.appendingPathComponent("settings.json"), options: [.atomic, .completeFileProtectionUnlessOpen])
        settings = cleaned
    }
    func backupURL(_ report: Report) throws -> URL {
        let url = manager.temporaryDirectory.appendingPathComponent("Montagebericht-\(report.id).json")
        try encode(report).write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
        return url
    }
    func associateDocument(_ url: URL, report: Report) throws {
        let bookmark = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        var next = documentBookmarks; next[report.id.uuidString] = bookmark
        try encode(next).write(to: root.appendingPathComponent("document-paths.json"), options: [.atomic, .completeFileProtectionUnlessOpen])
        documentBookmarks = next
    }
    private func saveDocument(_ report: Report) throws {
        guard let bookmark = documentBookmarks[report.id.uuidString] else { return }
        var stale = false
        let url = try URL(resolvingBookmarkData: bookmark, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &stale)
        let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
        try PortableReport.export(report, office: settings.resolve(report.officeContact)?.email ?? "", archive: nil).write(to: url, options: [.atomic])
        if stale { try associateDocument(url, report: report) }
    }
    func portableURL(_ report: Report) throws -> URL {
        let url = manager.temporaryDirectory.appendingPathComponent("Bericht-\(report.id).montagebericht")
        try PortableReport.export(report, office: settings.resolve(report.officeContact)?.email ?? "", archive: report.isFinalized ? archivedPDF(report) : nil).write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
        return url
    }
    func importBackup(_ url: URL) throws -> Report {
        let data = try Data(contentsOf: url)
        guard data.count <= 20_000_000 else { throw ReportError.message("Die Sicherung ist zu groß (maximal 20 MB).") }
        if let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any], envelope["format"] as? String == "montagebericht" {
            for (id, bookmark) in documentBookmarks {
                var stale = false
                if let existingURL = try? URL(resolvingBookmarkData: bookmark, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &stale), existingURL.standardizedFileURL == url.standardizedFileURL,
                   let report = reports.first(where: { $0.id.uuidString == id }) { return pendingReports[report.id] ?? report }
            }
            let (source, archive) = try PortableReport.decode(data)
            var report = source
            if reports.contains(where: { $0.id == report.id }) {
                if report.isFinalized { throw ReportError.message("Dieser abgeschlossene Bericht ist bereits vorhanden.") }
                report.id = UUID()
            }
            if let archive {
                let target = folder(report.id)
                let staging = root.appendingPathComponent("pending-" + UUID().uuidString, isDirectory: true)
                try manager.createDirectory(at: staging, withIntermediateDirectories: true)
                defer { try? manager.removeItem(at: staging) }
                try archive.write(to: staging.appendingPathComponent("bericht.pdf"), options: .completeFileProtectionUnlessOpen)
                try encode(report).write(to: staging.appendingPathComponent("report.json"), options: .completeFileProtectionUnlessOpen)
                try manager.moveItem(at: staging, to: target)
                reports.insert(report, at: 0)
            } else { try save(report) }
            try associateDocument(url, report: report)
            return report
        }
        var report = try decode(Report.self, from: data)
        guard report.schemaVersion == 1 else { throw ReportError.message("Dieses Sicherungsformat wird nicht unterstützt.") }
        // JSON allein enthält keinen PDF-Archivnachweis. Import ist eine neue Bearbeitung.
        report = report.editableCopy()
        try save(report); return report
    }
}
