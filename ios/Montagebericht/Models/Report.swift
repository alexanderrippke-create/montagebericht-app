import Foundation
import PencilKit

enum Department: String, Codable, CaseIterable, Identifiable {
    case montage, karcher
    var id: String { rawValue }
    var title: String { self == .montage ? "Montagebericht / Arbeitsnachweis" : "Kärcher-Servicebericht" }
}

struct WorkTime: Codable, Identifiable, Equatable {
    var id = UUID()
    var date = Date()
    var from: Date? = nil
    var to: Date? = nil
    var pause = ""
    var hours = ""
    var km = ""
    var normal = ""
    var p25 = ""
    var p50 = ""
    var p70 = ""
    var note = ""

    static func number(_ text: String) -> Double { Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    static func formatted(_ number: Double) -> String { String(format: "%.2f", number) }
    mutating func calculate(department: Department, calendar: Calendar = .current) {
        guard let from, let to else { hours = ""; return }
        let a = calendar.component(.hour, from: from) * 60 + calendar.component(.minute, from: from)
        let b = calendar.component(.hour, from: to) * 60 + calendar.component(.minute, from: to)
        let duration = b >= a ? b - a : b - a + 1440
        let rest = Self.number(pause)
        guard rest >= 0, rest <= Double(duration) else { hours = ""; return }
        hours = Self.formatted((Double(duration) - rest) / 60)
        distribute(department: department, calendar: calendar)
    }
    mutating func distribute(department: Department, calendar: Calendar = .current) {
        guard department == .montage else { return }
        let day = calendar.component(.weekday, from: date)
        guard day != 1 else { return } // Sonntag bleibt wie unter Windows manuell.
        let total = Self.number(hours)
        let n = day == 7 ? 0 : min(total, 8)
        let surcharge25 = min(max(total - n, 0), 2)
        normal = n > 0 ? Self.formatted(n) : ""
        p25 = surcharge25 > 0 ? Self.formatted(surcharge25) : ""
        let surcharge50 = max(total - n - surcharge25, 0)
        p50 = surcharge50 > 0 ? Self.formatted(surcharge50) : ""
        p70 = ""
    }
}

struct Material: Codable, Identifiable, Equatable {
    var id = UUID()
    var quantity = ""
    var articleNumber = ""
    var description = ""
}

struct Report: Codable, Identifiable, Equatable {
    var schemaVersion = 1
    var id = UUID()
    var department: Department = .montage
    var createdAt = Date()
    var updatedAt = Date()
    var customer = ""
    var order = ""
    var task = ""
    var email = ""
    var street = ""
    var city = ""
    var phone = ""
    var technician = ""
    var orderedBy = ""
    var purchase = ""
    var purchaseDate: Date? = nil
    var date = Date()
    var officeContact = ""
    var customerNumber = ""
    var machine = ""
    var machineId = ""
    var power = ""
    var year = ""
    var accessories = ""
    var defects = ""
    var kind = "Montage"
    var serviceKinds: [String] = ["Reparatur"]
    var work = ""
    var compressorHours = ""
    var compressorLoadHours = ""
    var compressorNextDate: Date? = nil
    var compressorNextHours = ""
    var times: [WorkTime] = [WorkTime()]
    var parts: [Material] = [Material()]
    var machineOk = false
    var workOk = false
    var paid = false
    var confirmedDate = Date()
    var signer = ""
    var signatureAccepted = false
    var customerSignature: Data? = nil // PKDrawing; keine Bildschirmaufnahme.
    var technicianSignature: Data? = nil
    var finalizedAt: Date? = nil
    var archiveSHA256: String? = nil
    var replacesDraftID: UUID? = nil
    var isFinalized: Bool { finalizedAt != nil }
    var totalHours: Double { times.reduce(0) { $0 + WorkTime.number($1.hours) } }
    var totalKM: Double { times.reduce(0) { $0 + WorkTime.number($1.km) } }
    var isCompressorMaintenance: Bool {
        department == .montage && (task + " " + work).range(of: "(?:kompressor[\\s-]*wartung|wartung[\\s-]*(?:am\\s+|des\\s+)?kompressor)", options: [.regularExpression, .caseInsensitive]) != nil
    }
    static let confirmation = "Mit meiner Unterschrift bestätige ich die im Bericht eingetragenen Arbeitszeiten, ausgeführten Arbeiten und Materialien sowie die von mir angekreuzten Angaben."
    func validation(finalizing: Bool = false) -> [String] {
        var errors: [String] = []
        if customer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errors.append("Firma / Kunde fehlt.") }
        if !email.isEmpty && !OfficeSettings.validEmail(email) { errors.append("Kunden-E-Mail ist ungültig.") }
        for (index, time) in times.enumerated() {
            for value in [time.pause, time.hours, time.km, time.normal, time.p25, time.p50, time.p70] where !value.isEmpty {
                if let number = Double(value.replacingOccurrences(of: ",", with: ".")), number.isFinite, number >= 0 {} else {
                    errors.append("Arbeitszeit \(index + 1): Zahlen müssen gültig und nicht negativ sein."); break
                }
            }
            if let from = time.from, let to = time.to {
                let calendar = Calendar.current
                let a = calendar.component(.hour, from: from) * 60 + calendar.component(.minute, from: from)
                let b = calendar.component(.hour, from: to) * 60 + calendar.component(.minute, from: to)
                let duration = b >= a ? b - a : b - a + 1440
                if WorkTime.number(time.pause) > Double(duration) { errors.append("Arbeitszeit \(index + 1): Pause ist länger als die Arbeitszeit.") }
            }
        }
        for (index, part) in parts.enumerated() where !part.quantity.isEmpty {
            if let number = Double(part.quantity.replacingOccurrences(of: ",", with: ".")), number.isFinite, number >= 0 {} else { errors.append("Material \(index + 1): Menge ist ungültig.") }
        }
        for value in [compressorHours, compressorLoadHours, compressorNextHours] where isCompressorMaintenance && !value.isEmpty {
            if let number = Double(value.replacingOccurrences(of: ",", with: ".")), number.isFinite, number >= 0 {} else { errors.append("Kompressorstunden sind ungültig."); break }
        }
        if finalizing {
            for (value, label) in [(order, "Auftragsnummer"), (technician, "Monteur"), (work, "Ausgeführte Arbeiten"), (signer, "Name des Kunden")] {
                if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errors.append(label + " fehlt.") }
            }
            if !times.contains(where: { WorkTime.number($0.hours) > 0 }) { errors.append("Arbeitsstunden fehlen.") }
            if !Self.hasSignature(customerSignature) { errors.append("Unterschrift Kunde fehlt.") }
            if department == .karcher && !Self.hasSignature(technicianSignature) { errors.append("Unterschrift Monteur fehlt.") }
            if !signatureAccepted { errors.append("Bitte die Kundenbestätigung akzeptieren.") }
        }
        return errors
    }
    static func hasSignature(_ data: Data?) -> Bool {
        guard let data else { return false }
        if PortableReport.image(data) != nil { return true }
        guard let drawing = try? PKDrawing(data: data) else { return false }
        return !drawing.strokes.isEmpty
    }
    func editableCopy() -> Report {
        var copy = self
        copy.id = UUID(); copy.createdAt = Date(); copy.updatedAt = Date()
        copy.finalizedAt = nil; copy.archiveSHA256 = nil; copy.replacesDraftID = nil
        copy.customerSignature = nil; copy.technicianSignature = nil; copy.signatureAccepted = false
        return copy
    }
}

struct OfficeContact: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var email: String
}

struct OfficeSettings: Codable, Equatable {
    var contacts = [OfficeContact(name: "Alexander", email: "alexander.rippke@gustav-schmidt.de")]
    var defaultName = "Alexander"
    static func validEmail(_ email: String) -> Bool {
        email.count <= 254 && email.range(of: "^[^\\s@;,]+@[^\\s@;,]+\\.[^\\s@;,]+$", options: .regularExpression) != nil
    }
    func resolve(_ name: String) -> OfficeContact? {
        let requested = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = (requested.isEmpty ? defaultName : requested).trimmingCharacters(in: .whitespacesAndNewlines)
        return contacts.first { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(resolved) == .orderedSame }
    }
    var validation: String? {
        guard !contacts.isEmpty, resolve(defaultName) != nil else { return "Bitte einen Standardempfänger auswählen." }
        var seen = Set<String>()
        for contact in contacts {
            let name = contact.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !name.isEmpty, Self.validEmail(contact.email), seen.insert(name).inserted else { return "Kontakte benötigen eindeutige Namen und gültige E-Mail-Adressen." }
        }
        return nil
    }
}
