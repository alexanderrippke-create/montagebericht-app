import SwiftUI
import UniformTypeIdentifiers

struct ReportListView: View {
    @EnvironmentObject private var store: ReportStore
    @State private var selection: UUID?
    @State private var query = ""
    @State private var department: Department? = nil
    @State private var deleting: Report?
    @State private var showSettings = false
    @State private var importing = false
    @State private var error: String?
    var filtered: [Report] {
        store.reports.filter { (department == nil || $0.department == department) && (query.isEmpty || ($0.customer + " " + $0.order + " " + $0.technician).localizedCaseInsensitiveContains(query)) }
    }
    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    Picker("Abteilung", selection: $department) {
                        Text("Alle Berichte").tag(nil as Department?)
                        Text("Montage").tag(Department.montage as Department?)
                        Text("Kärcher").tag(Department.karcher as Department?)
                    }
                }
                Section("Berichte auf diesem Gerät") {
                    ForEach(filtered) { report in
                        NavigationLink(value: report.id) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(report.customer.isEmpty ? "Neuer Bericht" : report.customer).font(.headline)
                                Text("\(report.department == .montage ? "Montage" : "Kärcher") · \(report.order.isEmpty ? "Ohne Auftragsnummer" : report.order)").font(.subheadline)
                                HStack { Text(report.date, style: .date); Spacer(); Label(report.isFinalized ? "Abgeschlossen" : "Entwurf", systemImage: report.isFinalized ? "lock.fill" : "pencil") }.font(.caption).foregroundStyle(.secondary)
                            }.padding(.vertical, 5)
                        }
                        .swipeActions { Button("Löschen", role: .destructive) { deleting = report } }
                        .contextMenu {
                            Button("Duplizieren / neu bearbeiten") { duplicate(report) }
                            Button("Löschen", role: .destructive) { deleting = report }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Kunde, Auftrag oder Monteur")
            .navigationTitle("Montageberichte")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button { showSettings = true } label: { Label("Einstellungen", systemImage: "gear") } }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Neuer Montagebericht") { create(.montage) }
                        Button("Neuer Kärcher-Servicebericht") { create(.karcher) }
                        Button("JSON-Sicherung importieren") { importing = true }
                    } label: { Label("Neuer Bericht", systemImage: "plus") }
                }
            }
        } detail: {
            if let selection, let report = store.reports.first(where: { $0.id == selection }) {
                ReportEditor(report: report, onSelect: { self.selection = $0 }).id(report.id)
            } else {
                ContentUnavailableView("Montagebericht", systemImage: "doc.text", description: Text("Über + einen Bericht erstellen oder einen gespeicherten Bericht auswählen."))
            }
        }
        .sheet(isPresented: $showSettings) { OfficeSettingsView(settings: store.settings) }
        .alert("Bericht löschen?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Abbrechen", role: .cancel) { deleting = nil }
            Button("Endgültig löschen", role: .destructive) {
                if let report = deleting {
                    do { try store.delete(report); if selection == report.id { selection = nil } } catch { self.error = error.localizedDescription }
                }
                deleting = nil
            }
        } message: { Text("Bericht und gegebenenfalls archivierte PDF werden von diesem Gerät gelöscht. Exportierte Kopien bleiben erhalten.") }
        .alert("Hinweis", isPresented: Binding(get: { error != nil || store.issue != nil }, set: { if !$0 { error = nil; store.issue = nil } })) {
            Button("OK") { error = nil; store.issue = nil }
        } message: { Text(error ?? store.issue ?? "") }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get(); let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                selection = try store.importBackup(url).id
            } catch { self.error = "Sicherung konnte nicht importiert werden: \(error.localizedDescription)" }
        }
    }
    private func create(_ department: Department) {
        var report = Report(); report.department = department
        do { try store.save(report); selection = report.id } catch { self.error = error.localizedDescription }
    }
    private func duplicate(_ source: Report) {
        let report = source.editableCopy()
        do { try store.save(report); selection = report.id } catch { self.error = error.localizedDescription }
    }
}

struct OfficeSettingsView: View {
    @EnvironmentObject private var store: ReportStore
    @Environment(\.dismiss) private var dismiss
    @State var settings: OfficeSettings
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Sachbearbeiter") {
                    ForEach($settings.contacts) { $contact in
                        VStack(alignment: .leading) {
                            TextField("Name", text: $contact.name)
                            TextField("E-Mail", text: $contact.email).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                        }
                    }.onDelete { settings.contacts.remove(atOffsets: $0) }
                    Button("Sachbearbeiter hinzufügen") { settings.contacts.append(OfficeContact(name: "", email: "")) }
                    Picker("Standardempfänger", selection: $settings.defaultName) {
                        ForEach(settings.contacts) { Text($0.name).tag($0.name) }
                    }
                }
                Section("Datenschutz & Sicherung") {
                    Text("Berichte, Unterschriften und Kontakte werden lokal auf diesem Gerät gespeichert. Es gibt keine automatische Synchronisation und keinen automatischen E-Mail-Versand. Kalenderzugriff wird erst beim Laden von Terminen angefordert.")
                    Text("PDFs und JSON-Sicherungen über Teilen in Dateien ablegen. Ein JSON-Import erstellt eine neue Bearbeitung ohne Unterschriften. Die abgeschlossene Original-PDF bitte separat sichern. App-Deinstallation löscht lokale Berichte.")
                }
                Section("App-Version") { Text("iOS 0.1.0 · Mindestens iOS / iPadOS 17") }
            }
            .navigationTitle("Einstellungen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Speichern") {
                    do { try store.saveSettings(settings); dismiss() } catch { self.error = error.localizedDescription }
                } }
            }
            .alert("Einstellungen", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
        }
    }
}
