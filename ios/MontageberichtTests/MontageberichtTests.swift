import XCTest
import PDFKit
import PencilKit
@testable import Montagebericht

@MainActor
final class MontageberichtTests: XCTestCase {
    func sample() -> Report {
        var report = Report(); report.customer = "Müller & Söhne"; report.order = "A-123"; report.technician = "Testmonteur"; report.work = "Kompressorwartung – Öl wechseln"; report.signer = "Kunde"; report.signatureAccepted = true; report.times[0].hours = "8,50"
        let point = PKStrokePoint(location: CGPoint(x: 12, y: 10), timeOffset: 0, size: CGSize(width: 3, height: 3), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        let end = PKStrokePoint(location: CGPoint(x: 160, y: 50), timeOffset: 1, size: CGSize(width: 3, height: 3), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        let stroke = PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: [point,end], creationDate: Date()))
        report.customerSignature = PKDrawing(strokes: [stroke]).dataRepresentation()
        return report
    }
    func root() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true) }
    func fixed(_ value: String) -> Date { CalendarImport.date(value)! }
    func clock(_ hour: Int, _ minute: Int = 0) -> Date { Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: fixed("2026-10-05"))! }
    func testJSONRoundTrip() throws {
        let report = sample(); let data = try JSONEncoder().encode(report)
        XCTAssertEqual(report, try JSONDecoder().decode(Report.self, from: data))
    }
    func testNightShift() {
        var time = WorkTime(); time.date = fixed("2026-10-05"); time.from = clock(22); time.to = clock(6); time.pause = "30"; time.calculate(department: .montage)
        XCTAssertEqual(time.hours,"7.50"); XCTAssertEqual(time.normal,"7.50")
    }
    func testWeekdaySurcharges() {
        var time = WorkTime(); time.date = fixed("2026-10-05"); time.hours = "12"; time.distribute(department: .montage)
        XCTAssertEqual(time.normal,"8.00"); XCTAssertEqual(time.p25,"2.00"); XCTAssertEqual(time.p50,"2.00"); XCTAssertEqual(time.p70,"")
    }
    func testSaturdayAndSunday() {
        var time = WorkTime(); time.date = fixed("2026-10-10"); time.hours = "8"; time.distribute(department: .montage)
        XCTAssertEqual(time.normal,""); XCTAssertEqual(time.p25,"2.00"); XCTAssertEqual(time.p50,"6.00")
        time.date = fixed("2026-10-11"); time.p70 = "8"; time.normal = "manual"; time.distribute(department: .montage)
        XCTAssertEqual(time.p70,"8"); XCTAssertEqual(time.normal,"manual")
    }
    func testInvalidPause() {
        var time = WorkTime(); time.from = clock(8); time.to = clock(9); time.pause = "61"; time.calculate(department: .montage)
        XCTAssertEqual(time.hours, "")
        var report = sample(); report.times = [time]
        XCTAssertTrue(report.validation().contains { $0.contains("Pause") })
    }
    func testValidationMissingFieldsAndNumbers() {
        XCTAssertFalse(Report().validation(finalizing: true).isEmpty)
        var report = sample(); XCTAssertTrue(report.validation(finalizing: true).isEmpty)
        report.times[0].hours = "-1"; XCTAssertFalse(report.validation().isEmpty)
        report.times[0].hours = "NaN"; XCTAssertFalse(report.validation().isEmpty)
        report.email = "bad@email"; XCTAssertFalse(report.validation().isEmpty)
    }
    func testKarcherRequiresTechnicianSignature() {
        var report = sample(); report.department = .karcher
        XCTAssertTrue(report.validation(finalizing: true).contains("Unterschrift Monteur fehlt."))
        report.technicianSignature = report.customerSignature
        XCTAssertTrue(report.validation(finalizing: true).isEmpty)
    }
    func testDuplicateClearsSignatureAndArchive() {
        var report = sample(); report.finalizedAt = Date(); report.archiveSHA256 = "abc"
        let copy = report.editableCopy()
        XCTAssertNotEqual(report.id,copy.id); XCTAssertNil(copy.customerSignature); XCTAssertNil(copy.technicianSignature); XCTAssertNil(copy.finalizedAt); XCTAssertNil(copy.archiveSHA256); XCTAssertFalse(copy.signatureAccepted); XCTAssertEqual(copy.customer,report.customer)
    }
    func testStoreSaveLoadDeleteAndSettings() throws {
        let url = root(); defer { try? FileManager.default.removeItem(at: url) }
        let store = ReportStore(root: url); let report = sample(); try store.save(report)
        let reloaded = ReportStore(root: url)
        XCTAssertEqual(reloaded.reports.count,1); XCTAssertEqual(reloaded.reports[0].customerSignature,report.customerSignature)
        var settings = OfficeSettings(); settings.contacts.append(OfficeContact(name: "Davina", email: "davina@example.com")); settings.defaultName = "Davina"
        try reloaded.saveSettings(settings); XCTAssertEqual(ReportStore(root: url).settings.defaultName,"Davina")
        try reloaded.delete(reloaded.reports[0]); XCTAssertTrue(ReportStore(root: url).reports.isEmpty)
    }
    func testCorruptReportIsRetained() throws {
        let url = root(); defer { try? FileManager.default.removeItem(at: url) }
        let store = ReportStore(root: url); let report = sample(); try store.save(report)
        let file = url.appendingPathComponent(report.id.uuidString).appendingPathComponent("report.json")
        try Data("broken".utf8).write(to: file)
        let loaded = ReportStore(root: url); XCTAssertNotNil(loaded.issue); XCTAssertTrue(loaded.reports.isEmpty); XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }
    func testCorruptSettingsDoNotHideReports() throws {
        let url = root(); defer { try? FileManager.default.removeItem(at: url) }
        let store = ReportStore(root: url); try store.save(sample())
        try Data("broken".utf8).write(to: url.appendingPathComponent("settings.json"))
        let reloaded = ReportStore(root: url)
        XCTAssertEqual(reloaded.reports.count,1); XCTAssertNotNil(reloaded.issue)
    }
    func testStorageFailure() throws {
        let url = root(); try Data("file".utf8).write(to: url); defer { try? FileManager.default.removeItem(at: url) }
        let store = ReportStore(root: url); XCTAssertNotNil(store.issue); XCTAssertThrowsError(try store.save(sample()))
    }
    func testFinalizationAndTamperDetection() throws {
        let url = root(); defer { try? FileManager.default.removeItem(at: url) }
        let store = ReportStore(root: url); let source = sample(); try store.save(source)
        let archived = try store.finalize(source, renderer: ReportPDF.render)
        XCTAssertTrue(archived.isFinalized); XCTAssertEqual(store.reports.count,1)
        XCTAssertEqual(ReportStore(root: url).reports.count,1)
        XCTAssertThrowsError(try store.save(source))
        let data = try store.archivedPDF(archived)
        XCTAssertTrue(PDFDocument(data: data)?.string?.contains(archived.id.uuidString) == true)
        XCTAssertThrowsError(try store.save(archived))
        let pdf = url.appendingPathComponent(archived.id.uuidString).appendingPathComponent("bericht.pdf")
        try Data("changed".utf8).write(to: pdf); XCTAssertThrowsError(try store.archivedPDF(archived))
    }
    func testFailedFinalizationPreservesDraft() throws {
        let url = root(); defer { try? FileManager.default.removeItem(at: url) }
        let store = ReportStore(root: url); let source = sample(); try store.save(source)
        XCTAssertThrowsError(try store.finalize(source) { _ in throw ReportError.message("PDF failed") })
        XCTAssertEqual(ReportStore(root: url).reports.count,1); XCTAssertFalse(store.reports[0].isFinalized)
    }
    func testBackupImportIsNewUnsignedDraft() throws {
        let url = root(); defer { try? FileManager.default.removeItem(at: url) }
        let store = ReportStore(root: url); let source = sample(); try store.save(source)
        let backup = try store.backupURL(source); defer { try? FileManager.default.removeItem(at: backup) }
        let imported = try store.importBackup(backup)
        XCTAssertNotEqual(source.id,imported.id); XCTAssertNil(imported.customerSignature); XCTAssertEqual(imported.customer,source.customer)
    }
    func testCalendarLabelParsingAndLocation() {
        let fields = CalendarImport.parse(title:"Auftrag 123 – Wartung",notes:"Kunde: Müller GmbH\nSachbearbeiter: Davina\nPLZ: 12345\nOrt: Berlin\nAufgabe: Öl wechseln\nTelefon: 0123",location:"Andere Firma, Teststraße 1, 11111 Ort")
        XCTAssertEqual(fields["customer"],"Müller GmbH"); XCTAssertEqual(fields["city"],"12345 Berlin"); XCTAssertEqual(fields["street"],"Teststraße 1"); XCTAssertEqual(fields["officeContact"],"Davina"); XCTAssertEqual(fields["order"],"123"); XCTAssertEqual(fields["task"],"Öl wechseln")
    }
    func testCalendarApplicationAndAllDay() {
        var report = Report()
        let entry = CalendarEntry(id:"1",title:"Kunde",location:"Straße 2, 12345 Ort",notes:"Auftrag: A1",start:clock(8),end:clock(10),allDay:false,calendar:"Test")
        CalendarImport.apply(entry,to:&report)
        XCTAssertEqual(report.customer,"Kunde"); XCTAssertEqual(report.times[0].hours,"2.00")
        var allDay = entry; allDay.allDay = true; CalendarImport.apply(allDay,to:&report)
        XCTAssertNil(report.times[0].from); XCTAssertEqual(report.times[0].hours,"")
    }
    func testICSParsing() throws {
        let events = try ICSImport.parse("BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nDTSTART;TZID=Europe/Berlin:20261005T080000\r\nDTEND;TZID=Europe/Berlin:20261005T100000\r\nSUMMARY:Müller\r\nDESCRIPTION:Kunde: Müller\\nAuftrag: 123\r\nEND:VEVENT\r\nEND:VCALENDAR")
        XCTAssertEqual(events.count,1); XCTAssertTrue(events[0].notes.contains("\n")); XCTAssertEqual(events[0].end.timeIntervalSince(events[0].start),7200)
        XCTAssertThrowsError(try ICSImport.parse("broken"))
    }
    func testDateRejectsImpossibleDay() { XCTAssertNil(CalendarImport.date("31.02.2026")); XCTAssertNotNil(CalendarImport.date("05.10.2026")) }
    func testOfficeContacts() {
        let settings = OfficeSettings(); XCTAssertNotNil(settings.resolve(" alexander ")); XCTAssertNotNil(settings.resolve("")); XCTAssertNil(settings.resolve("Unknown"))
        var invalid = settings; invalid.contacts.append(OfficeContact(name:"Alexander",email:"other@example.com")); XCTAssertNotNil(invalid.validation)
    }
    func testPDFUnicodeAndMissingSignatures() throws {
        var report = sample(); report.customerSignature = nil
        let data = try ReportPDF.render(report); let document = try XCTUnwrap(PDFDocument(data:data))
        XCTAssertTrue(document.string?.contains("Müller") == true); XCTAssertTrue(document.string?.contains("Entwurf") == true)
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "com.adobe.pdf"); attachment.name = "Montagebericht-Test"; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testMultiPagePDFContainsEndingAndLongTableCells() throws {
        var report = sample(); report.work = String(repeating:"Lange Tätigkeit mit Umlauten äöü und Sonderzeichen. ",count:1000) + "ARBEITSENDE"
        report.times[0].note = String(repeating:"Bemerkung ",count:400) + "TABELLENENDE"
        report.parts[0].description = String(repeating:"Ersatzteil ",count:400) + "MATERIALENDE"
        let data = try ReportPDF.render(report); let document = try XCTUnwrap(PDFDocument(data:data)); let text = document.string ?? ""
        XCTAssertGreaterThan(document.pageCount,2)
        // PDFKit inserts line breaks at visual wrapping positions, also inside long words.
        let compact = text.components(separatedBy: .whitespacesAndNewlines).joined()
        for end in ["ARBEITSENDE","TABELLENENDE","MATERIALENDE",report.id.uuidString] { XCTAssertTrue(compact.contains(end), "Missing \(end)") }
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "com.adobe.pdf"); attachment.name = "Montagebericht-Mehrseitig"; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testKarcherPDF() throws {
        var report = sample(); report.department = .karcher; report.serviceKinds = ["Wartung","UVV-/VDE-Prüfung"]; report.parts[0].articleNumber = "6.123-456"; report.technicianSignature = report.customerSignature
        let data = try ReportPDF.render(report)
        let text = PDFDocument(data:data)?.string ?? ""
        XCTAssertTrue(text.contains("SERVICEBERICHT")); XCTAssertTrue(text.contains("6.123-456")); XCTAssertTrue(text.contains("Unterschrift Monteur"))
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "com.adobe.pdf"); attachment.name = "Kaercher-Test"; attachment.lifetime = .keepAlways; add(attachment)
    }
}
