# Montagebericht für Windows 0.1.6

Die Kunden-E-Mail aus Outlook wird jetzt ohne den Zusatz <mailto:…> übernommen. Beispielsweise wird „adresse@example.de <mailto:adresse@example.de>“ zu „adresse@example.de“. Das gilt auch für das Einfügen in das E-Mail-Feld und das Wiederöffnen älterer Entwürfe. Bei mehreren unterschiedlichen Adressen bleibt eine manuelle Prüfung erforderlich.

Weitere enthaltene Windows-Verbesserungen:
- Bearbeitbare Berichtsdateien: Öffnen, Speichern und Speichern unter.
- Mehrere getrennte Berichtstabs mit Änderungsmarkierung und Schließwarnungen.
- Lokale Wiederherstellung nach einem Neustart und Offline-Bearbeitung.
- Zuverlässige Sachbearbeiter-Speicherung und Erhalt der Zuordnung nach einer Umbenennung.
- Unterschriften und PDF-Ausgabe aus erneut geöffneten Berichten.

Geprüft mit automatisierten Windows-Formular- und nativen Electron-Tests einschließlich echter Dateispeicherung, Prozessneustart und PDF-Erzeugung. Der iOS-Testlauf wurde auf Benutzerwunsch beendet; diese Veröffentlichung enthält ausschließlich den Windows-Installer.

Update: In der App „Nach Updates suchen“ und anschließend „Update herunterladen“ wählen. Offene Berichte speichern und den heruntergeladenen Installer ausführen.
