# Montagebericht für iPhone und iPad

Eigenständige native Anwendung für **iOS / iPadOS 17 oder neuer**, Swift 5, SwiftUI, EventKit, PencilKit, UIKit/CoreText/PDFKit, CryptoKit und MessageUI. Keine externen App-Abhängigkeiten. Entwicklung mit Xcode 16 oder neuer; der CI-Runner verwendet die auf `macos-15` vorinstallierte Xcode-Version und protokolliert sie. Mindestversion des SDK: iOS 17. Node.js 18+ wird ausschließlich zum reproduzierbaren Erzeugen des Xcode-Projekts verwendet.

## Referenz und Windows-Schutz

Die Arbeitskopie liegt auf Branch `ios-app`. GitHub `main` und Tag `v0.1.4` zeigen auf `7b218cc406b53605f1d120a6506af30054f6a5da`; dieser Commit enthält nur eine README. Deshalb wurden die vorhandenen lokalen Windows-Dateien analysiert: `windows-app/ui/{index.html,app.js,department.js,karcher.js,completion.js,calendar.js,import-parser.js,office-contacts.js,desktop.js,reset.js,print.css}`, `main.cjs`, `package.json` und die Outlook-Skripte. Die lokale Quelle enthält bereits Kärcher-Service und Berichtsabschluss. Die Windows-App, Abhängigkeiten, Installer, Outlook-Integration und Releases wurden nicht bearbeitet. Die iOS-App liegt vollständig unter `ios/`; lediglich ihr unabhängiger Workflow liegt unter `.github/workflows/ios-test.yml`. Das Firmenlogo wurde unverändert kopiert.

Die vollständige fachliche Zuordnung steht in [FUNCTION-MATRIX.md](FUNCTION-MATRIX.md). Quellhashes und lokale Prüfungen stehen in [VERIFICATION.md](VERIFICATION.md). Ein vorbereiteter Test ist noch kein erfolgreicher Xcode-Build; den tatsächlichen Status anhand der Actions-Protokolle prüfen.

## Bedienung

- Über **+** Montagebericht oder Kärcher-Servicebericht erstellen. Die Liste lässt sich nach Abteilung filtern und nach Kunde, Auftrag oder Monteur durchsuchen.
- Kunde, Auftrag, Maschine, Tätigkeiten, Zeiten und Material erfassen. Arbeitszeitzeilen aufklappen; Von/Bis ist optional. Stunden lassen sich auch direkt eintragen. Bei Änderungen von Datum/Stunden werden die Windows-Zuschläge neu verteilt; Sonntage bleiben manuell. Fahrtzeit ist wie unter Windows in Von/Bis bzw. Gesamtstunden enthalten.
- **Aktionen → Apple-Kalender**: Zeitraum wählen, erstmals Zugriff erlauben, Termine laden, Kalender auswählen und gegebenenfalls erneut laden. Termin antippen, erkannte Angaben prüfen und übernehmen. Die Terminzeit ersetzt nach ausdrücklicher Übernahme die bisherigen Arbeitszeitzeilen. Ganztägige Termine erzeugen keine angenommenen Arbeitsstunden. Fehlende Angaben werden manuell ergänzt; leere Importwerte überschreiben keine vorhandenen Felder.
- **Termindaten aus Text** unterstützt beschrifteten Text und `.ics`-Dateien bis 2 MB/500 Termine. Normale DTSTART/DTEND, UTC, lokale Zeiten und IANA-TZID werden unterstützt. Eigene VTIMEZONE-Definitionen und RRULE-Auflösung werden nicht implementiert; wiederkehrende Termine bevorzugt über EventKit laden. Termine mit unbekannter Zeitzone werden nicht geraten.
- Entwürfe werden nach Änderungen mit kurzer Verzögerung sowie beim Verlassen/Wechsel in den Hintergrund gespeichert. **Entwurf speichern** ist zusätzlich verfügbar. Ein Speicherfehler wird angezeigt. Ein Betriebssystemabbruch innerhalb der kurzen Verzögerung kann die letzten Eingaben verlieren.
- Kunde unterschreibt mit Finger oder Apple Pencil im weißen Unterschriftsfeld. Kärcher erfordert außerdem eine Monteurunterschrift. Unterschriften können gelöscht und neu gezeichnet werden.
- Vor **Abschließen** muss der Kunde die Bestätigung aktivieren. Erforderlich sind Kunde, Auftrag, Monteur, Arbeiten, Kundenname, positive Arbeitsstunden und gültige Unterschriften. Kunden-E-Mail wird bei Eingabe validiert, ist für Abschluss wie unter Windows nicht erforderlich.
- Beim Abschluss entsteht eine gesperrte separate Fassung mit PDF, Berichts-ID, Gerätezeit und SHA-256. Der ursprüngliche Entwurf wird erst nach erfolgreicher Archivierung ersetzt. **Neue Bearbeitung** erstellt eine Kopie ohne Unterschriften; die abgeschlossene Originalfassung bleibt unverändert. SHA-256 erkennt eine veränderte PDF, ist aber keine qualifizierte elektronische Signatur und kein unabhängiger Zeitnachweis.
- **PDF anzeigen** öffnet PDFKit. **PDF teilen** öffnet das native Share Sheet für Dateien, AirDrop, installierte Mail-/Teams-/WhatsApp-Apps usw. Verfügbarkeit hängt von installierten Apps ab. **E-Mail-Entwurf** setzt eingerichtetes Apple Mail voraus und befüllt Sachbearbeiter/Kunde mit PDF-Anhang; gesendet wird nur durch den Benutzer.
- Einstellungen enthalten lokale Sachbearbeiter und einen Standardempfänger. Unbekannte Kontakte blockieren den Mail-Entwurf, nicht die manuelle Berichtserstellung.
- Löschen über Wischgeste/Kontextmenü erfordert Bestätigung. JSON-Sicherungen enthalten personenbezogene Daten; über Dateien an einem geeigneten Ort sichern. Ein JSON-Import stellt eine neue Bearbeitung **ohne Unterschriften** her. Abgeschlossene PDFs separat exportieren. Es gibt keine geräteübergreifende Synchronisation.

## Projektstruktur

```text
ios/
  Montagebericht.xcodeproj/      Projekt und gemeinsam verwendetes Scheme
  Montagebericht/
    MontageberichtApp.swift      App-Einstieg
    Models/                      Versioniertes Codable-Datenmodell und Regeln
    Views/                       Liste, adaptiver Editor, Kalender, Einstellungen
    Calendar/                    EventKit und Text-/ICS-Übernahme
    Storage/                     Lokale atomare Speicherung und Archivprüfung
    Signature/                   PencilKit für Finger/Apple Pencil
    PDF/                         Native A4-Erstellung mit Text-/Tabellenfortsetzung
    Sharing/                     PDFKit, Share Sheet, Apple-Mail-Entwurf
    Assets/                      Original-Firmenlogo und App-Icon
    Info.plist                   Kalenderberechtigung und Gerätekonfiguration
    PrivacyInfo.xcprivacy         Keine Tracking-/Übertragungsfunktionen
  MontageberichtTests/           XCTest-Fach-, Speicher-, Kalender- und PDF-Tests
  scripts/generate-project.cjs   Reproduzierbarer Projektgenerator
```

SwiftUI `NavigationSplitView` nutzt auf iPad eine Seitenleiste, auf iPhone adaptive Navigation. Native Formulare, Tastaturen, Hoch-/Querformat, Dynamic Type und Dark Mode; das Unterschriftsfeld bleibt für kontrastreiche PDF-Unterschriften weiß. Große nativen Bedienelemente statt der breiten Windows-Zeittabelle. Daten liegen im privaten Application-Support-Verzeichnis. JSON ist schema-versioniert, nicht automatisch mit dem Windows-localStorage-Format austauschbar. Keine iCloud- oder Outlook-Abhängigkeit; keine Kontakte-, Kamera-, Mikrofon- oder Fotoberechtigung. Temporäre Exportdateien liegen im App-Sandbox-Temp-Verzeichnis.

## Lokaler Build mit einem Mac

1. Xcode 16+ installieren, iOS-Plattform laden.
2. `ios/Montagebericht.xcodeproj` öffnen. Das Projekt ist bereits generiert.
3. Scheme `Montagebericht`, iPhone-/iPad-Simulator wählen und **Run** drücken.
4. Tests mit **Product → Test**. Für ein echtes Gerät Signing-Team und ggf. einen eindeutigen Bundle Identifier wählen.

Bei neuen Swift-Dateien einmal `node ios/scripts/generate-project.cjs` vom Repository-Root ausführen und Projektänderungen committen. Keine Paketauflösung erforderlich.

```bash
xcodebuild test -project ios/Montagebericht.xcodeproj -scheme Montagebericht \
  -destination 'platform=iOS Simulator,name=<verfügbares iPad>' CODE_SIGNING_ALLOWED=NO
xcodebuild build -project ios/Montagebericht.xcodeproj -scheme Montagebericht \
  -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
```

## Cloud-Build mit GitHub Actions

Workflow **Build iOS Test** läuft auf Pushs mit iOS-Änderungen nach `ios-app`/`main`, bei entsprechenden Pull Requests und manuell über **Actions → Build iOS Test → Run workflow**. Bei einem reinen Feature-Branch ohne Workflow auf dem Default-Branch kann der manuelle Button zunächst fehlen; der Push-Trigger funktioniert bereits. Danach prüft der Runner das generierte Projekt und Plists, führt XCTest auf einem verfügbaren iPad- und iPhone-Simulator aus und baut eine unsigned arm64-Geräte-App. Swift-Compilerwarnungen werden als Fehler behandelt. Der unsigned Testbetrieb benötigt **keine GitHub-Secrets**.

Artefakte:

- `Montagebericht-iOS-unsigned`: `Montagebericht-unsigned.ipa`, Erklärung und SHA-256, 14 Tage verfügbar.
- `Montagebericht-iOS-test-results`: Xcode-Protokolle, `.xcresult`-Testberichte und exportierte PDF-Testbeispiele, auch bei Fehlern hochgeladen. PDF-Beispiele entstehen aus synthetischen Testdaten.

Beim manuellen Start kann `capture_ui` optional aktiviert werden. Dies ergänzt Simulator-Screenshots. App-Start/Screenshot-Erfassung war auf einem Hosted Runner sehr langsam; der Schritt ist deshalb zeitlich begrenzt und diagnostisch, nicht Voraussetzung für erfolgreiche Fachtests und Geräte-Build. Ein iPad-Start wurde visuell geprüft; reale Bedienung bleibt Teil der Geräteabnahme.

Für lokale PDF-Sichtprüfung kann `scripts/inspect-pdf-samples.py <entpacktes Testartefakt>` verwendet werden. Dieses optionale QA-Werkzeug benötigt Python mit pdfplumber/Pillow und Poppler (`pdftoppm`); es prüft A4/Zeichenränder und rendert alle Seiten. Diese Werkzeuge sind keine Abhängigkeiten der iOS-App.

Die IPA ist eine ZIP-Hülle mit `Payload/Montagebericht.app`, **nicht signiert und nicht direkt installierbar**. AltStore muss sie mit der persönlichen Apple-ID neu signieren und provisionieren. Das ist ein Eingabepaket für diesen manuellen Schritt, keine von Apple exportierte/distributionsfähige IPA. Eine Simulator-App ist für Geräte ungeeignet. Erst nach einem grünen Geräte-Build das Geräteartefakt verwenden. Keine bestehende Windows-Aktion oder kein Release wird durch diesen Workflow ersetzt. Öffentliche Standard-Runner sind nach GitHubs aktuellen Kontobedingungen nutzbar; bei privaten Repositories Kontingent/Billing vor Ausführung prüfen.

## Kostenlos auf privatem iPad testen – Windows, ohne Mac

Voraussetzung: privates iPad mit iPadOS 17+, normale Apple-ID/Apple Account, Windows-PC, USB-Datenkabel und Internet. Diese Anleitung verwendet **AltStore Classic / AltServer**, nicht AltStore PAL. Die Herstelleranleitungen wurden am 06.10.2026 geprüft; Apple-/AltStore-Änderungen können die Schritte beeinflussen.

1. Repository mit dem iOS-Branch zu GitHub übertragen. **Actions → Build iOS Test** öffnen, grünen Lauf abwarten. Ein Fehler muss zuerst aus dem Protokoll behoben werden.
2. Unter **Artifacts** `Montagebericht-iOS-unsigned` herunterladen, ZIP entpacken. `Montagebericht-unsigned.ipa` anschließend beispielsweise über eine eigene Dateien-Ablage auf das iPad übertragen; die äußere Artefakt-ZIP nicht installieren.
3. [AltServers offizielle Windows-Anleitung](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows) öffnen. Aktuelles AltServer aus der offiziellen Quelle installieren. Die Anleitung verlangt iTunes/iCloud aus Apples Downloadangebot; bei Microsoft-Store-iCloud die vom Hersteller dokumentierten Alternativschritte lesen. Downloads über die aktuelle Herstelleranleitung beziehen.
4. AltServer starten. iPad per USB verbinden, entsperren und **Diesem Computer vertrauen** bestätigen. In iTunes das Gerät erkennen lassen und bei Bedarf WLAN-Synchronisation aktivieren.
5. Im AltServer-Symbol der Taskleiste **Install AltStore → dein iPad** wählen. Persönliche Apple-ID dort eingeben und Apples Authentifizierung durchführen. Zugangsdaten werden weder in den Quellcode noch in GitHub-Secrets eingetragen. Apple-ID nur im überprüften offiziellen Tool eingeben.
6. Auf dem iPad unter **Einstellungen → Allgemein → VPN & Geräteverwaltung** der eigenen Entwickleridentität vertrauen. Unter **Datenschutz & Sicherheit → Entwicklermodus** diesen einschalten, Neustart und Bestätigung durchführen, sofern angefordert.
7. AltStore Classic starten, Account einrichten. Unter **My Apps → +** die aus Schritt 2 gespeicherte IPA wählen. AltServer muss erreichbar bleiben. AltStore signiert/provisioniert lokal und installiert die App. Bei einem unbekannten Bundle-ID-Konflikt eindeutige Projekt-ID verwenden; keine fremden Profile oder Sicherheitsumgehungen einsetzen.
8. Montagebericht starten, einen Testbericht ausfüllen und speichern. Erst bei **Termine laden** wird Kalenderzugriff abgefragt. Auch nach Ablehnung muss die manuelle Erstellung funktionieren.
9. Mit Finger/Apple Pencil unterschreiben, PDF anzeigen, über Dateien exportieren und wieder öffnen. Testbericht abschließen und die archivierte Fassung erneut exportieren. Erst nach diesen praktischen Prüfungen für echte Einsätze verwenden.
10. Kostenlose Signierung läuft üblicherweise nach **7 Tagen** ab. In AltStore **Refresh All** rechtzeitig ausführen, während AltServer erreichbar ist. Bei Ablauf die eigene Signierung erneuern; Daten nicht durch vorschnelles Löschen der Montagebericht-App verlieren. AltStore selbst zählt zu Apples begrenzter Anzahl gleichzeitig installierter Apps. Vor Änderungen PDF/JSON sichern.

Installation, Apple-ID-Authentifizierung, Vertrauen und Entwicklermodus brauchen menschliche Schritte. GitHub Actions kann keine persönliche iPad-Testsignierung ohne Apple-Zugang/Profil erledigen. Die konkrete Installation muss auf dem privaten Gerät verifiziert werden.

Quellen: [AltStore Windows-Installation](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows), [AltStore Refresh/Begrenzungen](https://faq.altstore.io/altstore-classic/your-altstore), [Apple kostenloses Entwicklerkonto](https://developer.apple.com/help/account/basics/about-your-developer-account/), [EventKit-Kalenderzugriff](https://developer.apple.com/documentation/eventkit/accessing-the-event-store).

## Spätere reguläre Distribution und TestFlight

Die native App benötigt dafür keine Architekturänderung. Der hier angelegte Testworkflow aktiviert absichtlich noch kein Distributions-Signing.

1. Apple Developer Program auf den gewünschten Besitzer/die Firma registrieren. Die Bundle-ID `de.gustavschmidt.montagebericht` im Apple-Portal registrieren bzw. bei Konflikt anpassen; Team in Xcode setzen. Bestehende Testdaten vor einem Wechsel der App-Identität exportieren.
2. App-Store-Connect-App erstellen, Version/Buildnummer erhöhen. Für Distribution `Apple Distribution`-Zertifikat samt privatem Schlüssel und ein App-Store-Provisioning-Profile für die Bundle-ID erstellen.
3. Auf einem Mac/Xcode **Product → Archive → Distribute App → App Store Connect** verwenden. Cloud-Signing später als separaten Workflow mit temporärem Keychain, `xcodebuild archive` und `-exportArchive`/ExportOptions ergänzen. Signing-Zertifikate und Profile nie committen.
4. Nach Upload App-Store-Connect-Verarbeitung prüfen, interne TestFlight-Gruppe einrichten, Tester einladen. Externe Tests können Beta-Review benötigen. [Apple TestFlight](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/) dokumentiert die Laufzeit; TestFlight-Builds sind nicht unbegrenzt gültig. Für dauerhafte produktive Verteilung eine passende reguläre Apple-Distribution planen, z. B. App Store oder Custom Apps für Firmen.

Falls dieser spätere Workflow automatisiert wird, unter **Repository → Settings → Secrets and variables → Actions** genau diese Secrets hinterlegen:

| Secret | Erzeugung / Inhalt | Zweck |
|---|---|---|
| `IOS_DISTRIBUTION_P12_BASE64` | In Apple Developer Certificates ein Apple-Distribution-Zertifikat erstellen; auf dem Mac mit privatem Schlüssel als `.p12` exportieren und Base64-kodieren | Import in temporären CI-Keychain |
| `IOS_DISTRIBUTION_P12_PASSWORD` | Passwort beim `.p12`-Export selbst setzen | Entschlüsseln des privaten Schlüssels |
| `IOS_PROVISIONING_PROFILE_BASE64` | Apple Developer → Profiles → App Store Connect, passende Bundle-ID/Zertifikat, `.mobileprovision` laden und Base64-kodieren | Distribution-Provisioning |
| `ASC_API_PRIVATE_KEY_BASE64` | App Store Connect → Users and Access → Integrations → API Key mit erforderlichen Upload-Rechten erstellen; einmalige `.p8`-Datei Base64-kodieren | Authentifizierter Upload |
| `ASC_API_KEY_ID` | ID des erzeugten App-Store-Connect-API-Keys | Identifizierung des Upload-Keys |
| `ASC_API_ISSUER_ID` | Issuer-ID derselben App-Store-Connect-Integration | Identifizierung des Accounts |
| `APPLE_TEAM_ID` | Apple Developer → Membership details | Zuordnung des Signing-Teams (auch als Variable möglich) |

Zertifikaterzeugung setzt ein auf dem Mac/Keychain erzeugtes Schlüsselpaar und eine CSR voraus. Ein bloß heruntergeladenes `.cer` enthält keinen privaten Schlüssel. Der kostenfreie Testworkflow liest keines dieser Secrets. Vor Veröffentlichung Datenschutzauskunft, Icon, Firmenangaben und Geräteprüfung abschließen.

## Prüfungen und Grenzen

XCTest deckt Fachregeln, Codable-Roundtrip, Speichern/Laden/Löschen, beschädigte Dateien, Speicherfehler, Kontaktdaten, Abschluss/Archivprüfsumme, fehlgeschlagenen Abschluss, Sicherungsimport, Kalenderparser, Ganztag, ICS, Datum, fehlende Signaturen sowie Montage-/Kärcher-PDF und mehrseitige lange Texte/Tabellen ab. CI führt dieselben Tests auf iPhone und iPad aus. Native UI, reale EventKit-Berechtigungsdialoge, Apple Pencil, Mail-Konfiguration und AltStore-Installation bleiben echte Geräteprüfungen; siehe [DEVICE-CHECKLIST.md](DEVICE-CHECKLIST.md).
