# Fachliche Funktionsmatrix

Referenz: lokale produktive Windows-App, Paket 0.1.4, einschließlich der vorhandenen Kärcher-Erweiterung. Online-Commit `7b218cc` enthält nur README und liefert keine andere fachliche Implementierung. Es wurden keine frei erfundenen zusätzlichen Berichtsarten/Abrechnungsregeln eingeführt.

| Windows-Funktion / Fundstelle | Native iOS-Umsetzung | Abweichung |
|---|---|---|
| Montage und Kärcher (`department.js`) | Zwei Abteilungen, Liste und neue Berichte | Mehrere Entwürfe statt eines Entwurfs je Abteilung |
| Kunde, Auftrag, Aufgabe, Mail, Adresse, Telefon, Monteur (`index.html`) | Alle Felder im Editor/Modell/PDF | Native Formularabschnitte |
| Bestellung durch, Bestellnummer/-datum | Montage-Felder; optionales Datum | Nicht im Kärcher-Formular |
| Sachbearbeiter (`office-contacts.js`) | Lokale Kontakte, Standard und Importauflösung | Apple-Mail-Entwurf statt Outlook; Share Sheet unterstützt weitere Apps |
| Gerät/Maschine, Kennung, Leistung, Baujahr | Modell und beide PDF-Varianten | Kärcher-Gerätelabels gemäß Quelle |
| Montage/Wartung/Reparatur | Native Auswahl | Identische Werte |
| Kärcher-Kundennummer, Zubehör, Mängel | Vollständig übernommen | Native Felder |
| Kärcher-Servicearten als Mehrfachauswahl | Reparatur, Wartung, UVV-/VDE-Prüfung, Kostenvoranschlag | Toggles statt HTML-Checkboxen |
| Kompressorwartungserkennung (`app.js`) | Gleiches Muster, Groß-/Kleinschreibung ignoriert; Betriebs-/Laststunden, nächste Wartung | Datumsfelder optional |
| Tageszeiten von/bis, Pause, Stunden | Arbeitszeitzeilen, Mitternachtswechsel, manuelle Korrektur | Aufklappbare Felder statt breiter Desktop-Tabelle |
| Fahrtzeiten/Kilometer | Stunden inkl. Anfahrt und Montage-km | Keine separate Fahrtzeit erfunden |
| Normal-, 25-/50-/70-%-Stunden | Mo–Fr 8N + 2×25 + Rest50; Sa 2×25 + Rest50; So manuell | Verteilung folgt Eingabeänderungen wie Windows; keine Feiertagsautomatik |
| Materialmenge/Bezeichnung | Beliebig viele Materialzeilen | Mehrseitige Tabellenfortsetzung |
| Kärcher-Artikelnummer | Formular, Speicherung, PDF | Nur Kärcher |
| Pflichtkunde, HTML-Mailvalidierung | Kunde für PDF/Abschluss; eingegebene E-Mail validieren | Entwürfe dürfen unvollständig sein |
| Abschluss-Pflichtfelder (`completion.js`) | Auftrag, Monteur, Arbeiten, Name, positive Stunden, Kundenzeichnung und Zustimmung; Kärcher Monteurzeichnung | Kunden-E-Mail ist für Abschluss wie Quelle optional |
| Prüfen (`app.js`) | Vollständigkeitsprüfung | iOS prüft Abschlussbedingungen; kein Mailzwang für lokalen Abschluss |
| Kundenbestätigung, Häkchen, Datum/Name | Montage-Häkchen; beide Abteilungen mit Datum, Name, Zustimmung und Signaturen | Kärcher-PDF zeigt wie Quelle nur Datum/Signaturen; im iOS-Serviceformular werden die dort nicht exportierten Montage-Häkchen nicht angeboten |
| Unterschrift Kunde und Kärcher-Monteur | PencilKit, Finger/Pencil, löschen, speichern | Keine Maus erforderlich |
| Gesperrter Abschluss, neue Bearbeitung | Separate abgeschlossene Fassung; neue Kopie ohne Unterschriften | Ursprünglichen Entwurf erst nach erfolgreicher Archivierung ersetzen |
| PDF-Archiv, SHA-256 (`main.cjs`) | JSON-Nachweis und Original-PDF, Integritätsprüfung beim Export | App-Sandbox statt Windows-Dokumente; Gerätezeit bleibt Gerätezeit |
| A4-Drucklayout (`print.css`, `app.js`, `karcher.js`) | Original-Logo; gleiche Felder, Überschriften, Zeiten, Materialpaare, Signaturen, Footer | Native CoreText-Ränder/Schriftmetriken; wiederholte Seitenköpfe, keine pixelidentische HTML-Druckausgabe |
| Aufgaben-/Arbeitsbericht mit Zeilenumbrüchen | Vollständiges CoreText-Layout | Beliebig lange Texte/Feldzellen auf Folgeseiten |
| Entwurf speichern/automatisch laden | Atomare lokale JSON-Dateien, Liste, öffnen/bearbeiten | Daten sind schema-versioniert; keine Windows-Synchronisation |
| Neuer Bericht (`reset.js`) | + und Duplizieren | Keine vorherigen Entwürfe löschen |
| Kalender „Kalender“/„Iris Illian“ (`calendar.js`) | EventKit, Zeitraum und auswählbare lokale Apple-Kalender | Alle konfigurierten Kalender; kein festes Outlook-Profil |
| Import prüfen (`import-ui.js`) | Bearbeitbare Importvorschau | Optionaler Import der Start-/Endzeit ergänzt |
| Labelparser, Ortsparser, Auftragsnummer/Mail (`import-parser.js`) | Swift-Parser mit denselben fachlichen Aliasfeldern | Kein HTML; Mehrdeutigkeit bleibt manuell |
| .ics-Import | Größenlimit 2 MB/500; UTF-8; DTSTART/END mit UTC/IANA-Zone | RRULE/VTIMEZONE keine eigene Auflösung; EventKit empfohlen |
| PDF speichern | PDFKit-Vorschau + native Dateien-/Share-Auswahl | Kein Windows-Druckdialog |
| Outlook-Entwurf mit Anhang (`desktop.js`) | MessageUI-E-Mail-Entwurf mit Kunden-/Sachbearbeiter-Empfänger | Mail-Konfiguration erforderlich; alternativ Share Sheet. Für lokale native Mail-Entwürfe ist Auftrag optional; beim Berichtsabschluss bleibt er verpflichtend |
| Kein automatischer Versand | Kein automatischer Versand | Benutzer sendet explizit |
| Windows-Updateprüfung (`updates.cjs`) | iOS-Version in Einstellungen; AltStore/TestFlight/Apple-Distribution | Kein Download/Start einer Windows-EXE; Plattformupdate ersetzt |
| Fehlerdiagnose in Datei (`main.cjs`) | Verständliche sichtbare Fehlermeldungen, CI-Logs | Kein personenbezogenes Diagnose-Tracking |

## Nachvollziehbare Layoutentscheidung

Montage-PDF: Original-Firmenlogo rechts im Seitenkopf, Titel links, Kunden-/Auftragsraster in drei Spalten, Maschinenraster in zwei Spalten, Aufgaben/Kompressorfelder, elfspaltige Arbeitszeittabelle, Summen, Arbeiten, gepaarte Materialspalten, Bestätigung und Unterschriften sowie Abschlussstatus. Kärcher-PDF: textbasierter KÄRCHER-CENTER-Kopf wie in der Quelle, zwei Spalten Kunden-/Gerätefelder, Servicearten, fünf Zeitspalten, Artikelnummern und beide Unterschriften. Native Zeilenhöhen dürfen abweichen, damit Inhalte auf A4 vollständig bleiben.
