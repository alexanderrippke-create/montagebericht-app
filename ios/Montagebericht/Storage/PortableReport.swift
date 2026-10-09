import Foundation
import UIKit
import PencilKit

// Shared offline envelope. Dates are calendar dates / wall times, images embedded PNG.
enum PortableReport {
    static func encoder() -> JSONEncoder { let value = JSONEncoder(); value.dateEncodingStrategy = .iso8601; return value }
    static func decoder() -> JSONDecoder { let value = JSONDecoder(); value.dateDecodingStrategy = .iso8601; return value }
    static func object<T: Encodable>(_ value: T) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: encoder().encode(value)) as? [String: Any] else { throw ReportError.message("Ungültiges Berichtsobjekt") }
        return object
    }
    static func formatter(_ pattern: String) -> DateFormatter {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.calendar = Calendar(identifier: .gregorian); f.dateFormat = pattern; f.isLenient = false; return f
    }
    static func image(_ data: Data?) -> UIImage? {
        guard let data else { return nil }
        if let image = UIImage(data: data) { return image }
        guard let drawing = try? PKDrawing(data: data), !drawing.strokes.isEmpty else { return nil }
        return drawing.image(from: drawing.bounds.insetBy(dx: -8, dy: -8), scale: 2)
    }
    static func imageURL(_ data: Data?) -> String? { image(data)?.pngData().map { "data:image/png;base64," + $0.base64EncodedString() } }
    static func imageData(_ value: Any?) throws -> Data? {
        guard let text = value as? String, !text.isEmpty else { return nil }
        guard text.hasPrefix("data:image/png;base64,"), let data = Data(base64Encoded: String(text.dropFirst(22))), UIImage(data: data) != nil else { throw ReportError.message("Unterschriftsbild ist ungültig.") }
        return data
    }
    static func export(_ report: Report, office: String, archive: Data?) throws -> Data {
        let native = try object(report)
        var fields = native
        for key in ["id", "schemaVersion", "department", "createdAt", "updatedAt", "times", "parts", "customerSignature", "technicianSignature", "finalizedAt", "archiveSHA256", "replacesDraftID"] { fields.removeValue(forKey: key) }
        let date = formatter("yyyy-MM-dd"), time = formatter("HH:mm")
        for (key, value) in [("date", Optional(report.date)), ("confirmedDate", Optional(report.confirmedDate)), ("purchaseDate", report.purchaseDate), ("compressorNextDate", report.compressorNextDate)] { fields[key] = value.map { date.string(from: $0) } ?? "" }
        fields["office"] = office
        fields["technicianSignatureData"] = imageURL(report.technicianSignature) ?? ""
        if let finalized = report.finalizedAt { fields["finalizedId"] = report.id.uuidString; fields["signedAt"] = ISO8601DateFormatter().string(from: finalized) }
        let times = try report.times.map { row -> [String: Any] in
            var value = try object(row); value.removeValue(forKey: "id")
            value["date"] = date.string(from: row.date); value["from"] = row.from.map { time.string(from: $0) } ?? ""; value["to"] = row.to.map { time.string(from: $0) } ?? ""; return value
        }
        var snapshot: [String: Any] = ["fields": fields, "times": times, "parts": try report.parts.map { try object($0) }, "signature": imageURL(report.customerSignature) as Any? ?? NSNull(), "iosReport": native]
        if let archive { snapshot["archive"] = ["pdf": archive.base64EncodedString(), "sha256": ReportStore.digest(archive)] }
        return try JSONSerialization.data(withJSONObject: ["format": "montagebericht", "schemaVersion": 1, "department": report.department.rawValue, "report": snapshot], options: [.prettyPrinted, .sortedKeys])
    }
    @MainActor static func decode(_ data: Data) throws -> (Report, Data?) {
        guard let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any], envelope["format"] as? String == "montagebericht", envelope["schemaVersion"] as? Int == 1,
              let department = envelope["department"] as? String, Department(rawValue: department) != nil,
              let snapshot = envelope["report"] as? [String: Any], let fields = snapshot["fields"] as? [String: Any],
              let times = snapshot["times"] as? [[String: Any]], let parts = snapshot["parts"] as? [[String: Any]] else { throw ReportError.message("Unbekanntes oder beschädigtes Berichtsformat.") }
        var native = try object(Report())
        if let original = snapshot["iosReport"] as? [String: Any] { native.merge(original) { _, new in new } }
        let defaults = try object(Report())
        let excluded: Set<String> = ["schemaVersion", "id", "department", "createdAt", "updatedAt", "times", "parts", "customerSignature", "technicianSignature", "date", "confirmedDate", "purchaseDate", "compressorNextDate", "finalizedAt", "archiveSHA256", "replacesDraftID"]
        for (key, value) in fields where !excluded.contains(key) && defaults[key] != nil { native[key] = value }
        native["department"] = department
        let date = formatter("yyyy-MM-dd"), clock = formatter("yyyy-MM-dd HH:mm"), iso = ISO8601DateFormatter()
        for key in ["date", "confirmedDate", "purchaseDate", "compressorNextDate"] {
            if let text = fields[key] as? String, !text.isEmpty {
                guard let value = date.date(from: text), date.string(from: value) == text else { throw ReportError.message("Ungültiges Datum: " + text) }
                native[key] = iso.string(from: value)
            } else if key == "purchaseDate" || key == "compressorNextDate" { native.removeValue(forKey: key) }
        }
        native["times"] = try times.map { source -> [String: Any] in
            var value = try object(WorkTime())
            for (key, item) in source where key != "id" && key != "date" && key != "from" && key != "to" { if value[key] != nil { value[key] = item } }
            let day = source["date"] as? String ?? ""
            guard let parsed = date.date(from: day), date.string(from: parsed) == day else { throw ReportError.message("Arbeitszeit enthält ein ungültiges Datum.") }
            value["date"] = iso.string(from: parsed)
            for key in ["from", "to"] {
                if let text = source[key] as? String, !text.isEmpty {
                    guard let parsed = clock.date(from: day + " " + text) else { throw ReportError.message("Ungültige Uhrzeit") }
                    value[key] = iso.string(from: parsed)
                }
            }
            return value
        }
        native["parts"] = try parts.map { source -> [String: Any] in var value = try object(Material()); for key in ["quantity", "articleNumber", "description"] { value[key] = source[key] as? String ?? "" }; return value }
        for (key, source) in [("customerSignature", snapshot["signature"]), ("technicianSignature", fields["technicianSignatureData"])] {
            let png = try imageData(source)
            // Retain editable PencilKit strokes if Windows has not changed the PNG.
            if let existing = native[key] as? String, let original = Data(base64Encoded: existing), imageURL(original) == source as? String {} else {
                if let png { native[key] = png.base64EncodedString() } else { native.removeValue(forKey: key) }
            }
        }
        var archive: Data?
        if let id = fields["finalizedId"] as? String, !id.isEmpty {
            guard UUID(uuidString: id) != nil, let signedAt = fields["signedAt"] as? String, iso.date(from: signedAt) != nil,
                  let record = snapshot["archive"] as? [String: String], let pdf = Data(base64Encoded: record["pdf"] ?? ""), ReportStore.digest(pdf) == record["sha256"], pdf.starts(with: Data("%PDF".utf8)) else { throw ReportError.message("Abgeschlossenem Bericht fehlt eine gültige Archiv-PDF.") }
            native["id"] = id; native["finalizedAt"] = signedAt; native["archiveSHA256"] = ReportStore.digest(pdf); archive = pdf
        } else { native.removeValue(forKey: "finalizedAt"); native.removeValue(forKey: "archiveSHA256"); native.removeValue(forKey: "replacesDraftID") }
        let report = try decoder().decode(Report.self, from: JSONSerialization.data(withJSONObject: native))
        return (report, archive)
    }
}
