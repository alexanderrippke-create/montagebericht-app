# Prüfprotokoll

Stand: 06.10.2026. Arbeitskopie auf Branch `ios-app`, Ausgangscommit `7b218cc406b53605f1d120a6506af30054f6a5da`.

## Lokal auf Windows durchgeführt

- Originaldateien der Windows-App ausschließlich gelesen; neues Projekt liegt in separater Git-Arbeitskopie `ios-repository`.
- Git-Diff gegen Ausgangscommit beschränkt auf neue `ios/`-Dateien und `.github/workflows/ios-test.yml`. Die ursprüngliche Root-README wurde nicht geändert.
- Xcode-Projektgenerator ausgeführt; erneutes Erzeugen liefert identische Projektdateien, alle Swift-App-Dateien sind referenziert. Node.js-Syntaxprüfung bestanden.
- Original-Firmenlogo und iOS-Kopie haben denselben SHA-256.
- 35 Referenzdateien unter Windows `ui/`, `tests/` und oberster Quellenebene anhand `reference-hashes.json` erfasst und erneut geprüft. Diese Hashaufnahme wurde während der Umsetzung vorgenommen; sie ist kein behaupteter vorab erstellter vollständiger Installations-Snapshot. Es wurden keine Windows-Dateien bearbeitet und keine Windows-Installer/-Releases erzeugt oder überschrieben.
- Quell-/Konfigurationsscan ohne private Schlüssel, GitHub-Token- oder AWS-Key-Treffer. Die Platzhalternamen dokumentierter Secrets sind keine Zugangsdaten. Private Signing-Dateien sind in `ios/.gitignore` ausgeschlossen.
- Öffentliche Apple-/AltStore-Dokumentation zur Kalenderberechtigung, kostenloser Signierung, Windows-Installation und Erneuerung gelesen; Quellen in der README verlinkt.

Reproduzierbar aus Repository-Root:

```powershell
node ios/scripts/verify-local.cjs
node --check ios/scripts/generate-project.cjs
git diff --name-status 7b218cc HEAD
```

## Cloud-Prüfung

Die endgültige Codefassung `c707b02f06cb059fb91c84228a5d905c092dcb58` wurde im
[Cloud-Lauf 37424572402](https://github.com/alexanderrippke-create/montagebericht-app/actions/runs/37424572402) erfolgreich geprüft. Spätere Abschluss-Commits ändern nur Dokumentation; der App-Code entspricht diesem gebauten Stand.

- macOS-15-arm64-Runner, Xcode 16.4, Simulator iOS 18.5.
- iPad Pro 11-inch (M4): **23 Tests, 0 Fehler**.
- iPhone 16 Pro: **23 Tests, 0 Fehler**.
- Release-Build für ein generisches iOS-Gerät: **BUILD SUCCEEDED**, arm64, Mindestversion iOS 17, Gerätefamilie iPhone/iPad.
- Plist- und reproduzierbare Projektprüfung erfolgreich.
- Swift-Compilerwarnungen werden als Fehler behandelt; keine Swift-Compilerwarnungen im erfolgreichen Lauf. Xcodes Hinweis zur übersprungenen AppIntents-Metadatenextraktion und Warnungen der GitHub-Upload-Action stammen aus den Werkzeugen, nicht aus Swift-Quellwarnungen.
- Unsigned IPA und PDF-/XCTest-Artefakte erzeugt, heruntergeladen; SHA-256 gegen Runner-Ausgabe geprüft. IPA-Info.plist nennt die erwartete Bundle-ID, iOS 17, iPhone/iPad und iPhoneOS; ausführbarer Code ist arm64. Kein Provisioning-Profile enthalten.

## PDF-Sichtprüfung

Die drei finalen, direkt von der nativen iOS-Test-App erzeugten PDF-Beispiele wurden vollständig zu PNG gerendert und visuell geprüft: Kärcher **1 Seite**, Montage mit Kompressorwartung **2 Seiten**, sehr lange Texte/Tabellen/Namen **13 Seiten**. Alle 16 Seiten sind DIN A4; kein Textzeichen außerhalb der geprüften sicheren Ränder. Original-Firmenlogo, Tabellenfortsetzungen, Unterschriften und Bestätigung sind sichtbar. Endmarkierungen langer Arbeits-/Material-/Bemerkungs-/Namensfelder sind enthalten. Ein eigener Test prüft, dass Unterschrift und Bestätigungstext auf derselben Seite bleiben. PDFKit fügt bei Zeilenumbrüchen auch innerhalb langer Wörter neue Zeilen in die Textextraktion ein; Vollständigkeitstests berücksichtigen diese visuellen Umbrüche.

Ein früherer iPad-App-Start wurde im Simulator als Screenshot geprüft. Die zusätzliche Screenshot-Erfassung war auf Hosted Runnern langsam und lief bei einem Zwischenstand in ein Zeitlimit. Sie ist nun optional per `capture_ui`, zeitlich begrenzt und unabhängig von den verbindlichen Fachtests/Builds. Der endgültige grüne Lauf hat diesen optionalen Schritt nicht angefordert. Eine vollständige interaktive UI-/Pencil-/Berechtigungsabnahme wird damit nicht behauptet.

## Bereitgestellte Dateien

Im Arbeitsordner `iOS-Testpaket` liegen das geprüfte unsigned Gerätepaket, deutsche Installationskurzanleitung, SHA-256, maschinenlesbares Prüfprotokoll und drei synthetische PDF-Beispiele. Die ausführliche Anleitung liegt unter `ios/README.md`. Quellcode/Tests/Projekt/Assets/Dokumentation befinden sich ausschließlich unter `ios/`, der neue unabhängige Build unter `.github/workflows/ios-test.yml`; insgesamt 31 neue Repository-Dateien. Keine bestehenden Repository-/Windows-Dateien wurden geändert.

## Noch am echten Gerät erforderlich

Kalenderdialoge/Berechtigungswechsel, reale Kalenderdaten, Apple Pencil, Touch-Ergonomie, Share-Sheet-/Mail-Konfiguration, PDF-Sichtprüfung und die kostenlose AltStore-Signierung/Installation. Dazu `DEVICE-CHECKLIST.md` verwenden. Ohne diese Abnahme gibt es keine Behauptung einer abschließend getesteten produktiven iPad-Version.
