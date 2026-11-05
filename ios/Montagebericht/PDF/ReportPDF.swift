import UIKit
import CoreText
import PencilKit
import PDFKit

@MainActor
enum ReportPDF {
    static func render(_ report: Report) throws -> Data {
        guard report.validation().isEmpty else { throw ReportError.message(report.validation().joined(separator: "\n")) }
        let engine = PDFLayout(report: report)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [kCGPDFContextTitle as String: report.department.title, kCGPDFContextAuthor as String: "Gustav Schmidt GmbH & Co. KG"]
        let data = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595.28, height: 841.89), format: format).pdfData { context in
            engine.context = context
            engine.page()
            engine.content()
        }
        guard let document = PDFDocument(data: data), document.pageCount > 0 else { throw ReportError.message("PDF konnte nicht erstellt werden.") }
        return data
    }
    static func export(_ report: Report, store: ReportStore) throws -> URL {
        let data = report.isFinalized ? try store.archivedPDF(report) : try render(report)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(report.department == .montage ? "Montagebericht" : "Kaercher-Service")-\(report.id.uuidString).pdf")
        try data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
        return url
    }
}

@MainActor
private final class PDFLayout {
    let report: Report
    var context: UIGraphicsPDFRendererContext!
    var y: CGFloat = 0
    var pageNumber = 0
    let left: CGFloat = 28.35
    let width: CGFloat = 538.58
    let bottom: CGFloat = 784
    init(report: Report) { self.report = report }
    func text(_ value: String, size: CGFloat = 9, bold: Bool = false) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle(); paragraph.lineBreakMode = .byCharWrapping; paragraph.lineSpacing = 2
        return NSAttributedString(string: value.isEmpty ? " " : value, attributes: [.font: bold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size), .foregroundColor: UIColor.black, .paragraphStyle: paragraph])
    }
    func date(_ value: Date?) -> String { guard let value else { return "" }; let f = DateFormatter(); f.locale = Locale(identifier: "de_DE"); f.dateFormat = "dd.MM.yyyy"; return f.string(from: value) }
    func time(_ value: Date?) -> String { guard let value else { return "" }; let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: value) }
    func page() {
        context.beginPage(); pageNumber += 1
        let cg = context.cgContext
        cg.setFillColor(UIColor.white.cgColor); cg.fill(context.pdfContextBounds)
        text(report.department == .montage ? "Montagebericht / Arbeitsnachweis" : "SERVICEBERICHT", size: 12, bold: true).draw(in: CGRect(x: left, y: 30, width: 340, height: 36))
        if report.department == .montage, let logo = UIImage(named: "company-logo") {
            let ratio = min(150 / logo.size.width, 38 / logo.size.height)
            logo.draw(in: CGRect(x: left + width - logo.size.width * ratio, y: 25, width: logo.size.width * ratio, height: logo.size.height * ratio))
        } else {
            text("KÄRCHER\nCENTER GUSTAV SCHMIDT", size: 12, bold: true).draw(in: CGRect(x: left + width - 180, y: 25, width: 180, height: 40))
        }
        cg.setStrokeColor(UIColor.darkGray.cgColor); cg.setLineWidth(1)
        cg.move(to: CGPoint(x: left, y: 69)); cg.addLine(to: CGPoint(x: left + width, y: 69)); cg.strokePath()
        let footer = report.department == .montage ? "Gustav Schmidt · www.gustav-schmidt.de" : "Gustav Schmidt GmbH & Co. KG · info@gustav-schmidt.de · kaercher.gustav-schmidt.de/service"
        text(footer, size: 7).draw(in: CGRect(x: left, y: 803, width: width - 60, height: 24))
        text("Seite \(pageNumber)", size: 7).draw(in: CGRect(x: left + width - 50, y: 803, width: 50, height: 15))
        y = 80
    }
    func heading(_ title: String) {
        if bottom - y < 48 { page() }
        text(title, size: 10, bold: true).draw(in: CGRect(x: left, y: y, width: width, height: 15)); y += 17
    }
    // CoreText liefert die tatsächlich gezeichnete Zeichenanzahl. Auch ein einzelnes
    // mehrseitiges Feld wird vollständig fortgesetzt, einschließlich langer Wörter.
    func drawSegment(_ value: NSAttributedString, offset: Int, rect: CGRect) -> Int {
        guard offset < value.length else { return 0 }
        let remaining = value.attributedSubstring(from: NSRange(location: offset, length: value.length - offset))
        let setter = CTFramesetterCreateWithAttributedString(remaining)
        let frame = CTFramesetterCreateFrame(setter, CFRange(location: 0, length: 0), CGPath(rect: CGRect(origin: .zero, size: rect.size), transform: nil), nil)
        let visible = CTFrameGetVisibleStringRange(frame).length
        let cg = context.cgContext
        cg.saveGState(); cg.translateBy(x: rect.minX, y: rect.maxY); cg.scaleBy(x: 1, y: -1); cg.textMatrix = .identity
        CTFrameDraw(frame, cg); cg.restoreGState()
        return visible
    }
    func height(_ value: NSAttributedString, width: CGFloat) -> CGFloat {
        ceil(CTFramesetterSuggestFrameSizeWithConstraints(CTFramesetterCreateWithAttributedString(value), CFRange(location: 0, length: 0), nil, CGSize(width: width, height: .greatestFiniteMagnitude), nil).height) + 4
    }
    func paragraph(_ value: String, size: CGFloat = 9, bold: Bool = false) {
        let content = text(value, size: size, bold: bold)
        var offset = 0
        while offset < content.length {
            if bottom - y < 24 { page() }
            let rest = content.attributedSubstring(from: NSRange(location: offset, length: content.length - offset))
            let h = min(height(rest, width: width), bottom - y)
            let count = drawSegment(content, offset: offset, rect: CGRect(x: left, y: y, width: width, height: h))
            if count == 0 { page(); continue }
            offset += count; y += h + 5
            if offset < content.length { page() }
        }
    }
    func block(_ title: String, _ value: String) {
        heading(title)
        let content = text(value)
        var offset = 0
        while offset < content.length {
            if bottom - y < 35 { page(); heading(title + " (Fortsetzung)") }
            let remaining = content.attributedSubstring(from: NSRange(location: offset, length: content.length - offset))
            let h = min(height(remaining, width: width - 8) + 8, bottom - y)
            context.cgContext.setStrokeColor(UIColor.gray.cgColor)
            context.cgContext.stroke(CGRect(x: left, y: y, width: width, height: h))
            let count = drawSegment(content, offset: offset, rect: CGRect(x: left + 4, y: y + 4, width: width - 8, height: h - 6))
            if count == 0 { page(); continue }
            offset += count; y += h + 8
            if offset < content.length { page(); heading(title + " (Fortsetzung)") }
        }
    }
    func grid(_ fields: [(String, String)], columns: Int) {
        for start in stride(from: 0, to: fields.count, by: columns) {
            let cells = fields[start..<min(start + columns, fields.count)].map { "\($0.0)\n\($0.1.isEmpty ? "–" : $0.1)" }
            row(cells, fractions: Array(repeating: 1 / CGFloat(columns), count: cells.count), font: 9)
        }
        y += 8
    }
    func row(_ cells: [String], fractions: [CGFloat], font: CGFloat, bold: Bool = false, repeatHeader: (() -> Void)? = nil) {
        let attributed = cells.map { text($0, size: font, bold: bold) }
        var offsets = Array(repeating: 0, count: cells.count)
        repeat {
            if bottom - y < 28 { page(); repeatHeader?() }
            var desired: CGFloat = 18
            for i in cells.indices where offsets[i] < attributed[i].length {
                let remaining = attributed[i].attributedSubstring(from: NSRange(location: offsets[i], length: attributed[i].length - offsets[i]))
                desired = max(desired, height(remaining, width: width * fractions[i] - 6) + 6)
            }
            let h = min(desired, bottom - y)
            var x = left; var consumed = 0
            for i in cells.indices {
                let w = width * fractions[i]
                let rect = CGRect(x: x, y: y, width: w, height: h)
                if bold { context.cgContext.setFillColor(UIColor(white: 0.93, alpha: 1).cgColor); context.cgContext.fill(rect) }
                context.cgContext.setStrokeColor(UIColor.gray.cgColor); context.cgContext.setLineWidth(0.5); context.cgContext.stroke(rect)
                let count = drawSegment(attributed[i], offset: offsets[i], rect: rect.insetBy(dx: 3, dy: 3))
                offsets[i] += count; consumed += count; x += w
            }
            y += h
            if consumed == 0 { page(); repeatHeader?() }
        } while cells.indices.contains(where: { offsets[$0] < attributed[$0].length })
    }
    func table(_ title: String, headings: [String], rows: [[String]], fractions: [CGFloat]) {
        heading(title)
        let header = { self.row(headings, fractions: fractions, font: 7, bold: true) }
        header()
        for values in rows.isEmpty ? [Array(repeating: "", count: headings.count)] : rows { row(values, fractions: fractions, font: 7, repeatHeader: header) }
        y += 8
    }
    func signature(_ data: Data?, title: String, x: CGFloat, name: String) {
        text(name, size: 9).draw(in: CGRect(x: x, y: y, width: width / 2 - 12, height: 20))
        if let image = PortableReport.image(data) {
            let area = CGRect(x: x, y: y + 18, width: width / 2 - 14, height: 44)
            let scale = min(area.width / image.size.width, area.height / image.size.height)
            image.draw(in: CGRect(x: x, y: area.maxY - image.size.height * scale, width: image.size.width * scale, height: image.size.height * scale))
        }
        text(title, size: 8).draw(in: CGRect(x: x, y: y + 66, width: width / 2 - 14, height: 18))
    }
    func content() {
        let r = report
        if r.department == .montage {
            grid([("Firma / Kunde",r.customer),("Monteur",r.technician),("Straße",r.street),("Auftragsnummer",r.order),("PLZ / Ort",r.city),("Bestellung durch",r.orderedBy),("Telefon",r.phone),("Bestellnummer",r.purchase),("Kunden-E-Mail",r.email),("Bestelldatum",date(r.purchaseDate)),("Einsatzdatum",date(r.date))], columns: 3)
            grid([("Anlage / Maschine / Antrieb",r.machine),("Leistung",r.power),("Typ / Teile-Nr. / Fabr.-Nr. / Inv.-Nr.",r.machineId),("Baujahr",r.year)], columns: 2)
            paragraph("Art des Einsatzes: " + r.kind)
        } else {
            paragraph("Serviceart: " + r.serviceKinds.joined(separator: " · "))
            grid([("Firma / Name",r.customer),("Gerätetyp",r.machine),("Straße",r.street),("Baujahr",r.year),("PLZ / Ort",r.city),("Geräte- / Seriennummer",r.machineId),("Telefon",r.phone),("Zubehör",r.accessories),("E-Mail",r.email),("Voraussichtliche Mängel",r.defects),("Kunden-Nr.",r.customerNumber),("Auftragsnummer",r.order),("Monteur",r.technician),("Einsatzdatum",date(r.date))], columns: 2)
        }
        if !r.task.isEmpty { block("Aufgabe aus dem Termin", r.task) }
        if r.isCompressorMaintenance { block("Kompressorwartung", "Betriebsstunden: \(r.compressorHours)\nLaststunden: \(r.compressorLoadHours)\nNächste Wartung voraussichtlich am: \(date(r.compressorNextDate))\nNächste Wartung bei Betriebsstunden: \(r.compressorNextHours)") }
        if r.department == .montage {
            table("Arbeitszeiten", headings: ["Datum","Von","Bis","Pause Min.","Std. inkl. Anfahrt","km","N","25 %","50 %","70 %","Bemerkungen"], rows: r.times.map { [date($0.date),time($0.from),time($0.to),$0.pause,$0.hours,$0.km,$0.normal,$0.p25,$0.p50,$0.p70,$0.note] }, fractions: [0.115,0.075,0.075,0.065,0.085,0.055,0.055,0.055,0.055,0.055,0.31])
        } else {
            table("ARBEITSZEIT", headings: ["Datum","Von","Bis","Pause Min.","Stunden"], rows: r.times.map { [date($0.date),time($0.from),time($0.to),$0.pause,$0.hours] }, fractions: [0.24,0.19,0.19,0.19,0.19])
        }
        paragraph("Gesamtstunden: \(WorkTime.formatted(r.totalHours))" + (r.department == .montage ? "     Kilometer: \(WorkTime.formatted(r.totalKM))" : ""), bold: true)
        block(r.department == .montage ? "Ausgeführte Arbeiten" : "ARBEITSBERICHT", r.work)
        let materials = r.parts.filter { !$0.quantity.isEmpty || !$0.description.isEmpty || (r.department == .karcher && !$0.articleNumber.isEmpty) }
        if r.department == .karcher {
            table("ERSATZTEILE", headings: ["Menge","Artikelnummer","Bezeichnung der zu berechnenden Ersatzteile"], rows: materials.map { [$0.quantity,$0.articleNumber,$0.description] }, fractions: [0.12,0.25,0.63])
        } else {
            let half = (materials.count + 1) / 2
            var rows: [[String]] = []
            for i in 0..<half { rows.append([materials[i].quantity,materials[i].description,i+half < materials.count ? materials[i+half].quantity : "",i+half < materials.count ? materials[i+half].description : ""]) }
            table("Material / zu berechnende Ersatzteile", headings: ["Menge","Bezeichnung","Menge","Bezeichnung"], rows: rows, fractions: [0.08,0.42,0.08,0.42])
        }
        // Sehr lange Namen vollständig umbrechen statt sie in der Signaturhöhe abzuschneiden.
        let customerNameIsLong = height(text(r.signer), width: width / 2 - 12) > 22
        let technicianNameIsLong = height(text(r.technician), width: width / 2 - 12) > 22
        if customerNameIsLong { block("Name des Kunden", r.signer) }
        if r.department == .karcher && technicianNameIsLong { block("Name des Monteurs", r.technician) }
        let checkText = [(r.machineOk,"Maschinen / Anlagen in Ordnung"),(r.workOk,"Arbeiten ordnungsgemäß ausgeführt"),(r.paid,"Gegen Bezahlung")].map { ($0.0 ? "[X] " : "[ ] ") + $0.1 }.joined(separator: "    ")
        let notice = "Dieser Arbeitsnachweis dient als Grundlage für die Abrechnung der eingetragenen Tätigkeit."
        let status: String
        if let finalizedAt = r.finalizedAt { let f = DateFormatter(); f.locale = Locale(identifier: "de_DE"); f.dateStyle = .medium; f.timeStyle = .medium; status = "Abgeschlossen am \(f.string(from: finalizedAt)) (Gerätezeit)\nBericht-ID: \(r.id.uuidString)" }
        else { status = "Entwurf – noch nicht abgeschlossen\nBericht-ID: \(r.id.uuidString)" }
        var confirmationHeight: CGFloat = 17 + 88 + height(text(status, size: 7), width: width) + 5 + 24
        if r.signatureAccepted { confirmationHeight += height(text(Report.confirmation, size: 7), width: width) + 5 }
        if r.department == .montage { confirmationHeight += 17 + height(text(checkText, size: 8), width: width) + 5 + height(text(notice, size: 7), width: width) + 5 }
        if bottom - y < confirmationHeight { page() }
        if r.department == .montage { heading("Kundenbestätigung"); paragraph(checkText, size: 8) }
        heading("Bestätigung · " + date(r.confirmedDate))
        if r.department == .karcher { signature(r.technicianSignature, title: "Unterschrift Monteur", x: left, name: technicianNameIsLong ? "Siehe Name des Monteurs" : r.technician) }
        else { text("Datum: " + date(r.confirmedDate), size: 9).draw(in: CGRect(x: left, y: y, width: width / 2, height: 24)) }
        signature(r.customerSignature, title: "Unterschrift Kunde", x: left + width / 2, name: customerNameIsLong ? "Siehe Name des Kunden" : r.signer)
        y += 88
        if r.signatureAccepted { paragraph(Report.confirmation, size: 7) }
        if r.department == .montage { paragraph(notice, size: 7) }
        paragraph(status, size: 7)
    }
}
