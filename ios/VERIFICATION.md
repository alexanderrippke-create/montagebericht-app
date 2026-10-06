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

Der erste GitHub-Actions-Lauf wurde durch den Push nach `ios-app` gestartet:
[Build iOS Test](https://github.com/alexanderrippke-create/montagebericht-app/actions).

Der Workflow führt Plist-/Projektprüfung, XCTest auf iPad und iPhone und einen unsigned arm64-Geräte-Build aus. Ein konkreter erfolgreicher Abschluss wird erst nach Sichtung der Protokolle hier dokumentiert. Die vorhandene XCTest-Suite ist keine Aussage über einen bereits bestandenen Lauf.

## Noch am echten Gerät erforderlich

Kalenderdialoge/Berechtigungswechsel, reale Kalenderdaten, Apple Pencil, Touch-Ergonomie, Share-Sheet-/Mail-Konfiguration, PDF-Sichtprüfung und die kostenlose AltStore-Signierung/Installation. Dazu `DEVICE-CHECKLIST.md` verwenden. Ohne diese Abnahme gibt es keine Behauptung einer abschließend getesteten produktiven iPad-Version.
