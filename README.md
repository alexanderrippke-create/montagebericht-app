# Montagebericht für Windows und iOS

Windows-Desktop-App mit Outlook-Kalenderimport, bearbeitbaren Berichtsdateien, getrennten Tabs und PDF-Ausgabe. Native iPhone-/iPad-App in `ios/`.

Änderungen und Prüfstatus: [CHANGELOG-REPORTS.md](CHANGELOG-REPORTS.md). Gemeinsames Dateiformat: [REPORT-FORMAT.md](REPORT-FORMAT.md). iOS-Build und Geräteinstallation: [ios/README.md](ios/README.md).

## Windows entwickeln

Im Verzeichnis `windows-app` mit Node.js und npm:

```powershell
npm ci
npm start
npm test
npm run installer
```

Der Installer liegt anschließend unter `windows-app/installer/`. Die Tests verwenden synthetische Daten in temporären Profilen. Der Formulartest benötigt standardmäßig Microsoft Edge; alternativ `BROWSER_CHANNEL` auf einen installierten Playwright-Browser setzen. Der native Test benötigt das heruntergeladene Electron. Bei übersprungenen Installationsskripten einmal `node node_modules/electron/install.js` ausführen.

Die bestehenden lokalen Installationen werden durch die Quellcodeänderungen und Tests nicht ersetzt. Installation des erzeugten Setups erfolgt separat. Berichtsdaten bleiben im bisherigen Electron-Profil; zusätzliche Berichtsdateien können offline gespeichert, wieder geöffnet und zwischen Rechnern übertragen werden.
