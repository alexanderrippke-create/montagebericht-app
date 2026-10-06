import EventKit
import Foundation
import Combine

struct CalendarEntry: Identifiable {
    var id: String
    var title: String
    var location: String
    var notes: String
    var start: Date
    var end: Date
    var allDay: Bool
    var calendar: String
}

@MainActor
final class CalendarService: ObservableObject {
    private let store = EKEventStore()
    @Published private(set) var entries: [CalendarEntry] = []
    @Published private(set) var calendars: [EKCalendar] = []
    @Published private(set) var loading = false
    func load(from: Date, until: Date, calendarID: String?) async throws {
        loading = true; defer { loading = false }
        guard until >= from else { throw ReportError.message("Das Enddatum muss nach dem Anfangsdatum liegen.") }
        guard until.timeIntervalSince(from) < 366 * 86400 else { throw ReportError.message("Bitte höchstens ein Jahr auswählen.") }
        let status = EKEventStore.authorizationStatus(for: .event)
        if status != .fullAccess {
            guard status == .notDetermined else { throw ReportError.message("Kalenderzugriff ist nicht erlaubt. Du kannst ihn in Einstellungen → Datenschutz & Sicherheit → Kalender aktivieren. Der Bericht bleibt manuell nutzbar.") }
            guard try await store.requestFullAccessToEvents() else { throw ReportError.message("Kalenderzugriff wurde nicht freigegeben. Du kannst alle Felder manuell ausfüllen.") }
        }
        calendars = store.calendars(for: .event)
        guard !calendars.isEmpty else { entries = []; return }
        let selected = calendarID.flatMap { id in calendars.first { $0.calendarIdentifier == id } }.map { [$0] }
        let end = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: until)) ?? until
        let predicate = store.predicateForEvents(withStart: Calendar.current.startOfDay(for: from), end: end, calendars: selected)
        entries = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }.map {
            CalendarEntry(id: ($0.eventIdentifier ?? UUID().uuidString) + String($0.startDate.timeIntervalSince1970), title: $0.title ?? "Ohne Titel", location: $0.location ?? "", notes: $0.notes ?? "", start: $0.startDate, end: $0.endDate, allDay: $0.isAllDay, calendar: $0.calendar.title)
        }
    }
}

enum CalendarImport {
    static func parse(title: String, notes: String, location: String) -> [String: String] {
        let aliases = ["kunde":"customer", "kundenname":"customer", "firma":"customer", "auftrag":"order", "auftragsnummer":"order", "auftrags-nr.":"order", "auftrags-nr":"order", "kunden-e-mail":"email", "kunden-email":"email", "e-mail":"email", "email":"email", "arbeiten":"task", "beschreibung":"task", "aufgabe":"task", "datum":"date", "straße":"street", "strasse":"street", "plz":"postcode", "postleitzahl":"postcode", "ort":"town", "plz / ort":"city", "plz/ort":"city", "telefon":"phone", "tel":"phone", "maschine":"machine", "anlage":"machine", "sachbearbeiter":"officeContact", "sachbearbeiterin":"officeContact", "büro-kontakt":"officeContact", "buero-kontakt":"officeContact", "büro-kontak":"officeContact", "buero-kontak":"officeContact", "büro kontakt":"officeContact", "buero kontakt":"officeContact", "bürokontakt":"officeContact", "buerokontakt":"officeContact", "büro":"officeContact", "buero":"officeContact"]
        var result: [String: String] = [:]; var remaining: [String] = []
        let clean = notes.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").replacingOccurrences(of: "&nbsp;", with: " ").replacingOccurrences(of: "&#160;", with: " ")
        for line in clean.components(separatedBy: "\n") {
            guard let separator = line.firstIndex(of: ":") else { remaining.append(line); continue }
            let label = String(line[..<separator]).trimmingCharacters(in: .whitespaces).lowercased().replacingOccurrences(of: "[‐‑–—]", with: "-", options: .regularExpression).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            guard let key = aliases[label] else { remaining.append(line); continue }
            let value = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
            if key == "task" { remaining.append(value) } else { result[key] = value }
        }
        let orderPattern = "(?:Auftrags?(?:nummer|[-\\s]?Nr\\.?)?|Auftrag)\\s*[:#]?\\s*([A-Za-z0-9][A-Za-z0-9/._-]*)"
        if result["order", default: ""].isEmpty { result["order"] = capture(orderPattern, in: title + "\n" + clean, group: 1) }
        if result["email", default: ""].isEmpty, let regex = try? NSRegularExpression(pattern: "[A-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Z0-9.-]+\\.[A-Z]{2,}", options: .caseInsensitive) {
            let emails = Set(regex.matches(in: clean, range: NSRange(clean.startIndex..., in: clean)).compactMap { Range($0.range, in: clean).map { String(clean[$0]) } })
            if emails.count == 1 { result["email"] = emails.first }
        }
        let parts = location.replacingOccurrences(of: "(", with: ",").replacingOccurrences(of: ")", with: "").components(separatedBy: CharacterSet(charactersIn: "\n;,"))
        var address: [String: String] = [:]
        for raw in parts {
            let part = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if part.isEmpty { continue }
            if let city = capture("\\b\\d{5}\\s+.+$", in: part) {
                address["city"] = city
                let street = part.replacingOccurrences(of: city, with: "").trimmingCharacters(in: .whitespaces)
                if !street.isEmpty { address["street"] = street }
            } else if part.range(of: "(?:stra(?:ß|ss)e|str\\.?|weg|platz|allee|gasse|ring|ufer|chaussee|damm)\\b.*\\d|\\d+\\s*[a-z]?$", options: [.regularExpression, .caseInsensitive]) != nil { address["street"] = part }
            else if address["customer"] == nil { address["customer"] = part }
        }
        for key in ["customer", "street", "city"] where result[key, default: ""].isEmpty { result[key] = address[key] }
        if result["customer", default: ""].isEmpty {
            result["customer"] = title.replacingOccurrences(of: orderPattern, with: "", options: [.regularExpression, .caseInsensitive]).trimmingCharacters(in: CharacterSet(charactersIn: " |;–-\n"))
        }
        if result["postcode"] != nil || result["town"] != nil { result["city"] = [result["postcode"], result["town"]].compactMap { $0 }.joined(separator: " ") }
        result["task"] = remaining.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return result
    }
    private static func capture(_ pattern: String, in text: String, group: Int = 0) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive), let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)), let range = Range(match.range(at: group), in: text) else { return nil }
        return String(text[range])
    }
    static func apply(_ fields: [String: String], to report: inout Report) {
        let keys: [String: WritableKeyPath<Report, String>] = ["customer": \.customer, "order": \.order, "email": \.email, "task": \.task, "street": \.street, "city": \.city, "phone": \.phone, "machine": \.machine, "officeContact": \.officeContact]
        for (key, path) in keys { if let value = fields[key], !value.isEmpty { report[keyPath: path] = value } }
        if let value = fields["date"], let date = date(value) { report.date = date; report.confirmedDate = date }
    }
    static func apply(_ entry: CalendarEntry, to report: inout Report, fields: [String: String]? = nil) {
        apply(fields ?? parse(title: entry.title, notes: entry.notes, location: entry.location), to: &report)
        report.date = entry.start; report.confirmedDate = entry.start
        // Ganztägige Termine sind keine 24-Stunden-Arbeitszeit.
        var time = WorkTime(); time.date = entry.start
        if !entry.allDay { time.from = entry.start; time.to = entry.end; time.calculate(department: report.department) }
        report.times = [time]
    }
    static func date(_ value: String) -> Date? {
        for pattern in ["yyyy-MM-dd", "dd.MM.yyyy"] {
            let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = pattern; formatter.isLenient = false
            if let date = formatter.date(from: value), formatter.string(from: date) == value { return date }
        }
        return nil
    }
}
