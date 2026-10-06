import SwiftUI
import UniformTypeIdentifiers

struct CalendarPicker: View {
    @Binding var report: Report
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = CalendarService()
    @State private var from = Date()
    @State private var until = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    @State private var calendarID: String? = nil
    @State private var selected: CalendarEntry?
    @State private var fields: [String: String] = [:]
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Apple-Kalender") {
                    Text("Nur Termine aus auf diesem Gerät verfügbaren Kalendern. Übernommene Daten bleiben editierbar. Bestehende Arbeitszeitzeilen werden nach Bestätigung durch die Terminzeit ersetzt.").font(.caption)
                    DatePicker("Von", selection: $from, displayedComponents: .date)
                    DatePicker("Bis", selection: $until, displayedComponents: .date)
                    if !service.calendars.isEmpty {
                        Picker("Kalender", selection: $calendarID) {
                            Text("Alle Kalender").tag(nil as String?)
                            ForEach(service.calendars, id: \.calendarIdentifier) { Text($0.title).tag($0.calendarIdentifier as String?) }
                        }
                    }
                    Button("Termine laden") { Task { do { try await service.load(from: from, until: until, calendarID: calendarID) } catch { self.error = error.localizedDescription } } }.disabled(service.loading)
                    if service.loading { ProgressView() }
                }
                Section("Termine (\(service.entries.count))") {
                    ForEach(service.entries) { entry in
                        Button { selected = entry; fields = CalendarImport.parse(title: entry.title, notes: entry.notes, location: entry.location) } label: {
                            VStack(alignment: .leading) { Text(entry.title).font(.headline); Text(entry.start, style: .date); Text(entry.calendar + " · " + entry.location).font(.caption) }.padding(.vertical, 8)
                        }
                    }
                    if service.entries.isEmpty { Text("Keine Termine geladen. Du kannst den Bericht jederzeit manuell erstellen.").foregroundStyle(.secondary) }
                }
                if let selected {
                    Section("Übernahme prüfen") {
                        Text(selected.title).font(.headline)
                        ImportFields(fields: $fields)
                        Text(selected.allDay ? "Ganztägiger Termin: keine Arbeitsstunden werden angenommen." : "Beginn und Ende werden in eine neue Arbeitszeitzeile übernommen.").font(.caption)
                        Button("Daten und Terminzeit übernehmen") { CalendarImport.apply(selected, to: &report, fields: fields); dismiss() }
                    }
                }
            }
            .navigationTitle("Termin übernehmen")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } } }
            .alert("Kalender", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
        }
    }
}

struct ImportFields: View {
    @Binding var fields: [String: String]
    let names = [("customer","Firma / Kunde"),("order","Auftragsnummer"),("email","Kunden-E-Mail"),("street","Straße"),("city","PLZ / Ort"),("phone","Telefon"),("machine","Maschine / Gerät"),("officeContact","Sachbearbeiter"),("task","Aufgabe")]
    var body: some View {
        ForEach(names, id: \.0) { key, title in
            TextField(title, text: Binding(get: { fields[key, default: ""] }, set: { fields[key] = $0 }), axis: .vertical)
        }
    }
}

struct TextImportView: View {
    @Binding var report: Report
    @Environment(\.dismiss) private var dismiss
    @State private var source = ""
    @State private var fields: [String: String] = [:]
    @State private var parsed = false
    @State private var importer = false
    @State private var events: [CalendarEntry] = []
    @State private var selected: CalendarEntry?
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Termindaten als Text") {
                    Text("Zum Beispiel: Kunde: Muster GmbH, Auftragsnummer: 123, Sachbearbeiter: Alexander. Pro Angabe eine Zeile.").font(.caption)
                    TextEditor(text: $source).frame(minHeight: 180)
                    Button("Text auswerten") { selected = nil; fields = CalendarImport.parse(title: "", notes: source, location: ""); parsed = true }
                    Button(".ics-Datei öffnen") { importer = true }
                }
                if !events.isEmpty {
                    Section("Termine aus Datei") {
                        ForEach(events) { event in Button(event.title + " · " + event.start.formatted(date: .numeric, time: .shortened)) { selected = event; fields = CalendarImport.parse(title: event.title, notes: event.notes, location: event.location); parsed = true } }
                    }
                }
                if parsed {
                    Section("Übernahme prüfen") {
                        ImportFields(fields: $fields)
                        TextField("Datum (JJJJ-MM-TT oder TT.MM.JJJJ)", text: Binding(get: { fields["date", default: ""] }, set: { fields["date"] = $0 }))
                        Button("Übernehmen") {
                            if let selected { CalendarImport.apply(selected, to: &report, fields: fields) } else { CalendarImport.apply(fields, to: &report) }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Text / .ics importieren")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } } }
            .fileImporter(isPresented: $importer, allowedContentTypes: [UTType(filenameExtension: "ics") ?? .data]) { result in
                do {
                    let url = try result.get(); let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let data = try Data(contentsOf: url)
                    guard data.count <= 2_000_000, let text = String(data: data, encoding: .utf8) else { throw ReportError.message("Datei muss UTF-8 sein und höchstens 2 MB enthalten.") }
                    events = try ICSImport.parse(text)
                } catch { self.error = error.localizedDescription }
            }
            .alert("Import", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
        }
    }
}
