# Änderungen vom 09.10.2026

Branch: `codex/report-files-tabs`, Basis: `ios-app` (`eba2d6f`). Die bisherigen lokalen Windows-Quellen und installierten Programme bleiben unverändert. Die bearbeitbare Windows-Quelle wurde erstmals als `windows-app/` in das gemeinsame Repository aufgenommen; Installationen, alte Builds und Kundendaten werden nicht eingecheckt.

## Implementiert

Windows:
- Versionierte JSON-Berichtsdateien (`.montagebericht`, format=montagebericht, schemaVersion=1), native Datei-Dialoge, Öffnen, Speichern und Speichern unter. Schreiben über temporäre Datei und atomare Umbenennung. Bestehende Snapshot-JSON-Dateien bleiben importierbar.
- Formularfelder, Zeiten, Material, Sachbearbeiterwahl und eingebettete Unterschriften werden gespeichert. Abgeschlossene Berichte enthalten zusätzlich die geprüfte Archiv-PDF mit SHA-256, damit sie auf einem anderen Windows-Rechner ausgegeben werden können.
- Obere Tab-Leiste mit Kunde, Änderungsmarkierung, Plus, Öffnen und Schließen. Jeder Tab besitzt eigenen Snapshot, Dateipfad und Speicherstand. Die vorhandenen Formulare und Abschlussfunktionen werden bei einem Wechsel frisch aus dem gewählten Snapshot aufgebaut.
- Lokale Offline-Sitzung inklusive nicht als Datei gespeicherter Eingaben, aktive Abteilung und offene Tabs werden wiederhergestellt. Dateispeicherung bleibt unabhängig von dieser lokalen Wiederherstellung.
- Schließwarnung für ungespeicherte Tabs und Fenster. Auch inaktive Tabs können beim Schließen direkt unabhängig gespeichert werden.
- Unterschrift wird vor dem Wiederherstellen gelöscht; verspätete Bild-Ladevorgänge dürfen keinen anderen Bericht verändern.
- Beim Kundenwechsel im Terminimport ohne neue E-Mail wird die bisherige Kundenadresse gelöscht. Die vorherige Zuordnung war nicht mehr verlässlich.
- Sachbearbeiter werden nicht mehr allein wegen fehlender Standardauswahl am Speichern gehindert; der erste gültige Kontakt wird Standard. Ungültige Kontakte werden weiterhin abgelehnt. Frühere Namen werden bei Umbenennung als Alias erhalten, damit bestehende Berichte weiterhin den richtigen Kontakt finden. Neue Namen dürfen nicht mit früheren Namen anderer Kontakte kollidieren. Eine Auswahlliste ergänzt das vorhandene Windows-Kontaktfeld.

Native iOS-App:
- Beim Kalender-/Textimport eines anderen Kunden ohne E-Mail wird dieselbe Altadress-Zuordnung wie unter Windows verhindert; eigener Regressionstest.
- Touchfähige horizontale Berichtstabs mit Plus-Menü, Einzel-Schließen und Wiederherstellung der offenen IDs/aktiven Auswahl. Auf dem iPhone horizontal scrollbar, auf dem iPad im Detailbereich.
- Unmittelbares automatisches Speichern statt 800-ms-Verzögerung. Nicht gespeicherte Fassungen bei Schreibfehlern bleiben im Arbeitsspeicher, werden mit Stern markiert und verhindern das Schließen ihres Tabs. Beim Zurückwechseln wird diese Fassung wieder verwendet.
- Umbenennen des Standard-Sachbearbeiters erhält die Standardzuordnung über seine bestehende ID. Frühere Namen bleiben als Alias erhalten, damit vorhandene Berichtszuordnungen funktionieren. Neue Kontakte bleiben nach Speichern und Neustart verfügbar; Regressionstest hinzugefügt.

## Tests und Build

Tatsächlich erfolgreich ausgeführt unter Windows:
- `tests/workspace.cjs`: Edge/Playwright, zwei getrennte Berichte, unabhängige Texte/E-Mail, Speichern/Öffnen, Wiederherstellung ungespeicherter Eingaben nach Reload, Sachbearbeiter-Speicherung nach Reload, Import eines anderen Kunden ohne E-Mail, Druckinhalt.
- `tests/native.cjs`: echte Electron-App, native IPC-Dateispeicherung, JSON-Inhalt mit PNG-Unterschrift, leere Unterschrift im neuen Tab, Wiederherstellung im anderen Tab und echte PDF-Erzeugung aus erneut geöffnetem Bericht. Synthetische Testdaten in temporären Profilen; keine echten Kundendaten verwendet.
- JavaScript-Syntaxprüfungen und `git diff --check`.
- Xcode-Projektgenerator ausgeführt; neue PortableReport.swift im Projekt aufgenommen. Lokaler Projekt-/Quellprüfer erfolgreich: alle 35 ursprünglichen Windows-Referenzdateien behalten ihre SHA-256-Hashes; Firmenlogo unverändert; Projekt reproduzierbar.

Tests starten mit Node und installiertem Playwright (`PLAYWRIGHT_MODULE` optional für den absoluten Modulpfad). Der Formulartest verwendet standardmäßig installiertes Edge; `BROWSER_CHANNEL` kann geändert werden. Electron muss einschließlich Installationsskript installiert sein. In dieser Umgebung musste das Electron-Installationsskript separat gestartet werden. npm-Aufrufe über CMD im OneDrive-Pfad mit `&` benötigen korrekt zitierte absolute Aufrufe.

Ein echter Electron-Prozessneustart wurde mit synthetischen Testdaten erfolgreich geprüft, einschließlich hinzugefügter und bearbeiteter Sachbearbeiter sowie Bericht/Archiv. Native iOS-Builds, XCTest, Simulator, iPhone-/iPad-Bedienung und reale Outlook-Integration sind lokal unter Windows nicht ausführbar. Die vorhandene macOS-GitHub-Actions-Prüfung läuft bei iOS-Pull-Requests. Die ergänzten XCTest-Fälle sind lokal unter Windows nicht ausführbar. Auf dem macOS-Runner bestand bereits der erste iPad-Testlauf inklusive Dateiaustausch; der abschließende iPhone-/iPad-/Geräte-Build-Status ist im Pull Request / GitHub Actions dokumentiert.

## Offen / Grenzen

- Gemeinsamer Windows/iOS-Dateiaustausch ist implementiert, aber die iOS-Seite benötigt noch den nativen Build-/XCTest-Nachweis: versionierte Hülle mit Formularfeldern, Zeiten, Material, PNG-Unterschriften und optional eingebetteter Archiv-PDF. iOS-PencilKit-Daten werden zusätzlich erhalten. Importierte PNG-Unterschriften werden angezeigt und gedruckt; zum erneuten Zeichnen zuerst löschen. Der bisherige iOS-JSON-Sicherungsimport behält sein bisheriges Verhalten (neue Bearbeitung ohne Unterschriften).
- iOS erhält zusätzlich „Speichern unter / Berichtsdatei“ über den nativen Dateien-Dialog. Geöffnete/exportierte Dokumentpfade werden per Bookmark gespeichert und bei weiteren Entwurfsänderungen aktualisiert. Nicht erreichbare externe Dateien lösen einen Speicherfehler aus; die lokale Fassung bleibt erhalten. Dateienanbieter und Bookmark-Zugriff müssen auf einem echten iPhone/iPad geprüft werden.
- Keine separate Kundenstammdatenbank und keine allgemeine Bild-/Anhangsverwaltung in den vorhandenen Quellen. Kundenfelder und bestehende Unterschriftsbilder werden erhalten; eine neue Kunden- oder Anhangsverwaltung ist nicht enthalten.
- Der ursprünglich beschriebene Windows-E-Mail-Anzeigefehler ist mangels konkretem Beispiel/Screenshot nicht eindeutig reproduziert. Behoben ist die nachgewiesene Altadress-Übernahme beim Kundenwechsel. Für weitere Fälle werden betroffene Maske, Quelladresse und erwartete Darstellung benötigt.
- iOS kann einen Betriebssystemabbruch oder Geräte-Neustart bei anhaltendem Schreibfehler nicht durch einen Dialog verhindern. Betroffene Eingaben bleiben dann nur im Arbeitsspeicher.
- Lokale Sitzungen verwenden weiterhin den vorhandenen localStorage. Bei vollem Speicher werden Fehler angezeigt; Berichtsdateien separat sichern. Keine Synchronisation eingeführt.

## Geänderte Dateien

Neu: `windows-app/` mit den bestehenden Windows-Quellen, Icons und Abhängigkeitssperrdatei. Funktionale Änderungen dort: `main.cjs`, `preload.cjs`, `ui/app.js`, `ui/import-ui.js`, `ui/office-contacts.js`, `ui/index.html`, `ui/style.css`; neu `ui/workspace.js`, `tests/workspace.cjs`, `tests/native.cjs`, `.gitignore`.

iOS: `Storage/ReportStore.swift`, `Views/ReportEditor.swift`, `Views/ReportListView.swift`, `MontageberichtTests/MontageberichtTests.swift`.

Die Windows-Funktionen sind lokal geprüft. Die iOS- und Austauschfunktionen sind implementiert, benötigen jedoch noch die native macOS-/Geräteprüfung. Keine produktive Freigabe ohne diese Prüfung.

Zusätzlich geändert: `Storage/PortableReport.swift` (neu), `Models/Report.swift`, `PDF/ReportPDF.swift`, `Signature/SignatureView.swift`, generiertes Xcode-Projekt. Windows-Version auf 0.1.5 erhöht.

Windows-NSIS-Build 0.1.5 erfolgreich. Installer unter windows-app/installer/Montagebericht-Setup-0.1.5.exe (lokales Build-Artefakt, nicht eingecheckt und nicht installiert).

Weiterhin angepasst: README.md mit Start-/Test-/Build-Befehlen, ios/scripts/verify-local.cjs für das nun gemeinsame Repository, windows-app/tests/run.cjs sowie reproduzierbare Playwright-Testabhängigkeit.
