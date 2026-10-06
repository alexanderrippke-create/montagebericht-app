import Foundation

enum ICSImport {
    static func parse(_ source: String) throws -> [CalendarEntry] {
        guard source.utf8.count <= 2_000_000 else { throw ReportError.message("Termindatei ist zu groß (maximal 2 MB).") }
        let lines = source.replacingOccurrences(of: "\u{FEFF}", with: "").replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").replacingOccurrences(of: "\n[ \\t]", with: "", options: .regularExpression).components(separatedBy: "\n")
        guard lines.contains(where: { $0.uppercased() == "BEGIN:VCALENDAR" }) else { throw ReportError.message("Keine gültige .ics-Kalenderdatei.") }
        var fields: [String: String]?; var nested = 0; var events: [CalendarEntry] = []
        for line in lines {
            let upper = line.uppercased()
            if upper == "BEGIN:VEVENT" { fields = [:]; nested = 0; continue }
            guard fields != nil else { continue }
            if upper == "END:VEVENT" {
                if let fields, let startString = fields["DTSTART"], let start = date(startString, property: fields["STARTPARAM", default: ""]) {
                    let end = fields["DTEND"].flatMap { date($0, property: fields["ENDPARAM", default: ""]) } ?? start
                    events.append(CalendarEntry(id: UUID().uuidString, title: unescape(fields["SUMMARY", default: "Ohne Titel"]), location: unescape(fields["LOCATION", default: ""]), notes: unescape(fields["DESCRIPTION", default: ""]), start: start, end: end, allDay: startString.count == 8 || fields["DTEND"] == nil, calendar: "Kalenderdatei"))
                }
                fields = nil; continue
            }
            if upper.hasPrefix("BEGIN:") { nested += 1; continue }
            if upper.hasPrefix("END:") { nested -= 1; continue }
            guard nested == 0, let colon = line.firstIndex(of: ":") else { continue }
            let property = String(line[..<colon]); let name = property.components(separatedBy: ";")[0].uppercased()
            fields?[name] = String(line[line.index(after: colon)...])
            if name == "DTSTART" { fields?["STARTPARAM"] = property }
            if name == "DTEND" { fields?["ENDPARAM"] = property }
        }
        guard !events.isEmpty else { throw ReportError.message("Kein vollständiger Termin mit gültigem Startdatum gefunden.") }
        guard events.count <= 500 else { throw ReportError.message("Bitte höchstens 500 Termine auf einmal importieren.") }
        return events
    }
    private static func unescape(_ text: String) -> String {
        var result = ""; var escaped = false
        for character in text {
            if escaped { result.append(character == "n" || character == "N" ? "\n" : character); escaped = false }
            else if character == "\\" { escaped = true } else { result.append(character) }
        }
        if escaped { result.append("\\") }; return result
    }
    private static func date(_ value: String, property: String) -> Date? {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.isLenient = false
        if value.count == 8 { f.dateFormat = "yyyyMMdd" }
        else if value.hasSuffix("Z") { f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"; f.timeZone = TimeZone(secondsFromGMT: 0) }
        else { f.dateFormat = "yyyyMMdd'T'HHmmss" }
        if let range = property.range(of: "TZID=") { let id = property[range.upperBound...].components(separatedBy: ";")[0]; guard let zone = TimeZone(identifier: id) else { return nil }; f.timeZone = zone }
        guard let date = f.date(from: value), f.string(from: date) == value else { return nil }
        return date
    }
}
