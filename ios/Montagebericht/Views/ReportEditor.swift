import SwiftUI
import MessageUI

struct ReportEditor: View {
    @EnvironmentObject private var store: ReportStore
    @Environment(\.scenePhase) private var scenePhase
    @State var report: Report
    let onSelect: (UUID) -> Void
    @State private var calendar = false
    @State private var importingText = false
    @State private var preview: URL?
    @State private var share: URL?
    @State private var mail: URL?
    @State private var mailData = Data()
    @State private var error: String?
    @State private var finish = false
    @State private var saveTask: Task<Void, Never>?
    @State private var saveStatus = ""
    var body: some View {
        Form {
            if report.isFinalized {
                Section { Label("Abgeschlossen – diese Fassung ist gesperrt", systemImage: "lock.fill"); Button("Neue Bearbeitung – erneut unterschreiben") { duplicate() } }
            }
            Group {
                customerSection
                machineSection
                if report.isCompressorMaintenance { compressorSection }
                Section("Arbeitszeiten") {
                    Text(report.department == .montage ? "Anfahrt in Von/Bis berücksichtigen oder Stunden korrigieren. Mo–Fr: 8 Std. normal, danach 2 Std. mit 25 %, weitere mit 50 %. Samstag: 2 Std. mit 25 %, weitere mit 50 %. Sonntag manuell." : "Stunden aus Von/Bis abzüglich Pause; manuell korrigierbar.").font(.caption).foregroundStyle(.secondary)
                    ForEach($report.times) { $time in
                        WorkTimeView(time: $time, department: report.department)
                    }.onDelete { report.times.remove(atOffsets: $0) }
                    Button("Arbeitszeit hinzufügen", systemImage: "plus") { var time = WorkTime(); time.date = report.date; report.times.append(time) }
                    LabeledContent("Gesamtstunden", value: WorkTime.formatted(report.totalHours))
                    if report.department == .montage { LabeledContent("Kilometer", value: WorkTime.formatted(report.totalKM)) }
                }
                Section("Material & Ersatzteile") {
                    ForEach($report.parts) { $part in
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Menge", text: $part.quantity).keyboardType(.decimalPad)
                            if report.department == .karcher { TextField("Artikelnummer", text: $part.articleNumber) }
                            TextField("Bezeichnung", text: $part.description, axis: .vertical)
                        }.padding(.vertical, 6)
                    }.onDelete { report.parts.remove(atOffsets: $0) }
                    Button("Position hinzufügen", systemImage: "plus") { report.parts.append(Material()) }
                }
                Section("Kundenbestätigung") {
                    if report.department == .montage {
                        Toggle("Maschinen / Anlagen in Ordnung", isOn: $report.machineOk)
                        Toggle("Arbeiten ordnungsgemäß ausgeführt", isOn: $report.workOk)
                        Toggle("Gegen Bezahlung", isOn: $report.paid)
                    }
                    DatePicker("Datum der Bestätigung", selection: $report.confirmedDate, displayedComponents: .date)
                    TextField("Name des Kunden", text: $report.signer)
                    Toggle(Report.confirmation, isOn: $report.signatureAccepted)
                    if report.department == .karcher { SignatureSection(title: "Unterschrift Monteur", data: $report.technicianSignature, locked: report.isFinalized) }
                    SignatureSection(title: "Unterschrift Kunde", data: $report.customerSignature, locked: report.isFinalized)
                }
            }.disabled(report.isFinalized)
            Section("Bericht fertigstellen") {
                if !report.isFinalized {
                    Button("Bericht prüfen") {
                        let issues = report.validation(finalizing: true)
                        error = issues.isEmpty ? "Bericht vollständig. Du kannst ihn abschließen." : issues.joined(separator: "\n")
                    }
                    Button("Unterschriebenen Bericht abschließen", systemImage: "checkmark.seal") { finish = true }
                }
                Button("PDF anzeigen", systemImage: "doc.richtext") { perform { preview = try ReportPDF.export(report, store: store) } }
                Button("PDF teilen / in Dateien sichern", systemImage: "square.and.arrow.up") { perform { share = try ReportPDF.export(report, store: store) } }
                Button("E-Mail-Entwurf mit PDF", systemImage: "envelope") { prepareMail() }
                if let office = store.settings.resolve(report.officeContact) { Text("Vorgesehene Empfänger: \(office.name) (\(office.email))" + (report.email.isEmpty ? "" : " · " + report.email)).font(.caption) }
                else { Text("Sachbearbeiter ist nicht hinterlegt. Bitte Einstellungen prüfen.").foregroundStyle(.orange) }
                Button("JSON-Sicherung teilen") { perform { share = try store.backupURL(report) } }
                if !saveStatus.isEmpty { Text(saveStatus).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle(report.department == .montage ? "Montagebericht" : "Kärcher-Service")
        .toolbar {
            if !report.isFinalized {
                ToolbarItem(placement: .topBarTrailing) { Menu {
                    Button("Apple-Kalender") { calendar = true }
                    Button("Termindaten aus Text") { importingText = true }
                    Button("Entwurf speichern") { persist() }
                } label: { Label("Aktionen", systemImage: "ellipsis.circle") } }
            }
        }
        .sheet(isPresented: $calendar) { CalendarPicker(report: $report) }
        .sheet(isPresented: $importingText) { TextImportView(report: $report) }
        .sheet(isPresented: Binding(get: { preview != nil }, set: { if !$0 { preview = nil } })) {
            if let preview { NavigationStack { PDFPreview(url: preview).navigationTitle("PDF-Vorschau").toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { self.preview = nil } }
            } } }
        }
        .sheet(isPresented: Binding(get: { share != nil }, set: { if !$0 { share = nil } })) { if let share { ShareSheet(url: share) } }
        .sheet(isPresented: Binding(get: { mail != nil }, set: { if !$0 { mail = nil } })) {
            if let mail, let office = store.settings.resolve(report.officeContact) {
                MailDraft(url: mail, data: mailData, recipients: Array(Set([office.email, report.email])), report: report) { result in self.mail = nil; if let result { error = result } }
            }
        }
        .alert("Bericht abschließen?", isPresented: $finish) {
            Button("Abbrechen", role: .cancel) {}
            Button("Abschließen") { perform {
                saveTask?.cancel()
                let completed = try store.finalize(report, renderer: ReportPDF.render)
                onSelect(completed.id)
            } }
        } message: { Text("Die unterschriebene PDF wird lokal archiviert und diese Fassung gesperrt. Änderungen erfordern eine neue Bearbeitung und neue Unterschriften. Der ursprüngliche Entwurf bleibt erhalten.") }
        .alert("Hinweis", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
        .onChange(of: report) { _, _ in
            guard !report.isFinalized else { return }
            saveTask?.cancel()
            saveTask = Task { @MainActor in
                do { try await Task.sleep(for: .milliseconds(800)); persist() } catch {}
            }
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { saveTask?.cancel(); persist() } }
        .onDisappear { saveTask?.cancel(); persist() }
    }
    private var customerSection: some View {
        Section("Kunde & Auftrag") {
            TextField("Firma / Kunde *", text: $report.customer)
            TextField("Auftragsnummer", text: $report.order)
            TextField("Aufgabenbeschreibung aus dem Termin", text: $report.task, axis: .vertical).lineLimit(2...8)
            TextField("Kunden-E-Mail", text: $report.email).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
            TextField("Straße", text: $report.street)
            TextField("PLZ / Ort", text: $report.city)
            TextField("Telefon", text: $report.phone).keyboardType(.phonePad)
            TextField("Monteur", text: $report.technician)
            TextField("Sachbearbeiter (leer = Standard)", text: $report.officeContact)
            if report.department == .montage {
                TextField("Bestellung durch", text: $report.orderedBy)
                TextField("Bestellnummer", text: $report.purchase)
                OptionalDatePicker(title: "Bestelldatum", date: $report.purchaseDate)
            } else { TextField("Kunden-Nr.", text: $report.customerNumber) }
            DatePicker("Einsatzdatum", selection: $report.date, displayedComponents: .date)
        }
    }
    private var machineSection: some View {
        Section(report.department == .montage ? "Anlage & Tätigkeit" : "Gerät & Arbeitsbericht") {
            TextField(report.department == .montage ? "Anlage / Maschine / Antrieb" : "Gerätetyp", text: $report.machine)
            TextField(report.department == .montage ? "Typ / Teile-Nr. / Fabr.-Nr. / Inv.-Nr." : "Geräte- / Seriennummer", text: $report.machineId)
            if report.department == .montage {
                TextField("Leistung", text: $report.power)
                Picker("Art des Einsatzes", selection: $report.kind) { ForEach(["Wartung","Reparatur","Montage"], id: \.self) { Text($0).tag($0) } }
            } else {
                TextField("Zubehör", text: $report.accessories)
                TextField("Voraussichtliche Mängel", text: $report.defects, axis: .vertical)
                ForEach(["Reparatur","Wartung","UVV-/VDE-Prüfung","Kostenvoranschlag"], id: \.self) { kind in
                    Toggle(kind, isOn: Binding(get: { report.serviceKinds.contains(kind) }, set: { value in if value { if !report.serviceKinds.contains(kind) { report.serviceKinds.append(kind) } } else { report.serviceKinds.removeAll { $0 == kind } } }))
                }
            }
            TextField("Baujahr", text: $report.year).keyboardType(.numberPad)
            TextField("Ausgeführte Arbeiten", text: $report.work, axis: .vertical).lineLimit(4...20)
        }
    }
    private var compressorSection: some View {
        Section("Kompressorwartung") {
            TextField("Betriebsstunden", text: $report.compressorHours).keyboardType(.numberPad)
            TextField("Laststunden", text: $report.compressorLoadHours).keyboardType(.numberPad)
            OptionalDatePicker(title: "Nächste Wartung voraussichtlich am", date: $report.compressorNextDate)
            TextField("Nächste Wartung bei Betriebsstunden", text: $report.compressorNextHours).keyboardType(.numberPad)
        }
    }
    private func persist() {
        guard !report.isFinalized, store.reports.contains(where: { $0.id == report.id }) else { return }
        do { try store.save(report); saveStatus = "Entwurf automatisch auf diesem Gerät gespeichert." } catch { self.error = "Speichern fehlgeschlagen: \(error.localizedDescription)"; saveStatus = "Änderungen sind noch nicht gespeichert." }
    }
    private func perform(_ operation: () throws -> Void) { do { try operation() } catch { self.error = error.localizedDescription } }
    private func duplicate() { perform { let copy = report.editableCopy(); try store.save(copy); onSelect(copy.id) } }
    private func prepareMail() {
        guard let office = store.settings.resolve(report.officeContact), OfficeSettings.validEmail(office.email), OfficeSettings.validEmail(report.email) else { error = "Bitte gültige Kunden-E-Mail und Sachbearbeiter in den Einstellungen hinterlegen."; return }
        guard MFMailComposeViewController.canSendMail() else { error = "Apple Mail ist nicht eingerichtet. Verwende PDF teilen und wähle dort eine verfügbare Mail-App."; return }
        perform { let url = try ReportPDF.export(report, store: store); mailData = try Data(contentsOf: url); mail = url }
    }
}

struct OptionalDatePicker: View {
    let title: String
    @Binding var date: Date?
    var body: some View {
        Toggle(title, isOn: Binding(get: { date != nil }, set: { date = $0 ? Date() : nil }))
        if date != nil { DatePicker(title, selection: Binding(get: { date ?? Date() }, set: { date = $0 }), displayedComponents: .date) }
    }
}

struct WorkTimeView: View {
    @Binding var time: WorkTime
    let department: Department
    var body: some View {
        DisclosureGroup {
            DatePicker("Datum", selection: $time.date, displayedComponents: .date).onChange(of: time.date) { _, _ in time.distribute(department: department) }
            Toggle("Von/Bis verwenden", isOn: Binding(get: { time.from != nil && time.to != nil }, set: { active in
                if active { time.from = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: time.date); time.to = Calendar.current.date(bySettingHour: 16, minute: 0, second: 0, of: time.date) }
                else { time.from = nil; time.to = nil }
                time.calculate(department: department)
            }))
            if time.from != nil && time.to != nil {
                DatePicker("Von", selection: Binding(get: { time.from ?? Date() }, set: { time.from = $0; time.calculate(department: department) }), displayedComponents: .hourAndMinute)
                DatePicker("Bis", selection: Binding(get: { time.to ?? Date() }, set: { time.to = $0; time.calculate(department: department) }), displayedComponents: .hourAndMinute)
            }
            TextField("Pause in Minuten", text: $time.pause).keyboardType(.decimalPad).onChange(of: time.pause) { _, _ in time.calculate(department: department) }
            TextField("Stunden (manuell korrigierbar)", text: $time.hours).keyboardType(.decimalPad).onChange(of: time.hours) { _, _ in time.distribute(department: department) }
            if department == .montage {
                TextField("Kilometer", text: $time.km).keyboardType(.decimalPad)
                TextField("Normalstunden", text: $time.normal).keyboardType(.decimalPad)
                TextField("25 %", text: $time.p25).keyboardType(.decimalPad)
                TextField("50 %", text: $time.p50).keyboardType(.decimalPad)
                TextField("70 %", text: $time.p70).keyboardType(.decimalPad)
                TextField("Bemerkungen", text: $time.note, axis: .vertical)
            }
        } label: {
            HStack { Text(time.date, style: .date); Spacer(); Text("\(time.hours.isEmpty ? "0" : time.hours) Std.").foregroundStyle(.secondary) }.padding(.vertical, 8)
        }
    }
}
