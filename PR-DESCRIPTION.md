# Review: Berichtsdateien, Tabs und Kontaktspeicherung

Windows erhält bearbeitbare Berichtsdateien, getrennte Tabs, lokale Sitzungswiederherstellung und Schließwarnungen. Der Kundenwechsel ohne neue E-Mail entfernt die alte Kundenadresse. Die Sachbearbeiter-Speicherung funktioniert auch ohne ausdrücklich gesetzten Standard.

Die vorhandene iOS-App erhält Berichtstabs, unmittelbare lokale Speicherung mit Erhalt fehlgeschlagener Eingaben und die Korrektur der Standardzuordnung beim Umbenennen eines Sachbearbeiters.

Validiert: automatisierter Edge-Formulartest und echter Electron-Test mit Datei-I/O, Unterschriftswechsel und PDF-Erzeugung. Xcode ist unter Windows nicht verfügbar; iOS-Build und XCTest müssen im macOS-Workflow geprüft werden.

Zusätzlich implementiert: gemeinsames versioniertes Dateiformat mit PNG-Unterschriften, Erhalt nativer PencilKit-Daten und eingebetteter Archiv-PDF; iOS-Dateienexport und erneute Aktualisierung des Dokumentpfads per Bookmark. Diese iOS-Erweiterungen müssen noch auf macOS und Geräten geprüft werden. Eine allgemeine Bild-/Anhangsverwaltung ist in der Ausgangsanwendung nicht vorhanden. Einzelheiten und vollständige Testgrenzen siehe CHANGELOG-REPORTS.md. Die ursprünglichen Windows-Quellen bleiben unverändert; windows-app wird erstmals im Repository versioniert.
