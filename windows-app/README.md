# Montagebericht für Windows

Lokale Desktop-Version mit Formular, Outlook-Text- und ICS-Import, Unterschrift, lokalem Entwurf und A4-PDF. Die Büro-Adresse ist fest auf alexander.rippke@gustav-schmidt.de eingestellt.

„Outlook-Entwurf mit PDF“ erstellt die PDF in Dokumente/Montageberichte und öffnet einen gespeicherten Entwurf im klassischen Outlook mit Büro und Kunde als Empfänger. Es wird keine E-Mail automatisch gesendet. Der Absender wird durch das eingerichtete Outlook-Profil bestimmt und muss im Entwurf geprüft werden. Neues Outlook und Outlook im Browser unterstützen die verwendete lokale COM-Anbindung nicht.

Die App ist nicht signiert. Der portable Ordner muss vollständig zusammenbleiben. Keine Microsoft-Kontodaten oder Kennwörter werden in der App gespeichert.

## Installation ab Version 0.1.1

Montagebericht-Setup-0.1.1.exe ausführen und den Installationsassistenten abschließen. Die App wird für den aktuellen Windows-Benutzer installiert, mit Desktop-Symbol und Startmenü-Eintrag. Deinstallation ist über Windows Einstellungen > Apps möglich.

Installer erstellen: pnpm install, danach pnpm installer.


## Lokale Version 0.1.2
Stunden aus Von/Bis abzüglich Pause; über Mitternacht gilt das Datum der Zeile. Mo–Fr 8 Normalstunden, danach 2 Stunden mit 25 %, Rest 50 %. Samstag erste 2 Stunden 25 %, Rest 50 %. Sonntag manuell. Zuschlagsfelder können korrigiert werden; eine Änderung von Datum oder Stunden berechnet sie erneut.
Kundenbestätigung mit Name, Funktion, Erklärung und Gerätezeit. Abschluss speichert PDF und JSON-Nachweis unter Dokumente/Montageberichte/Abgeschlossen/<Bericht-ID>. PDF-Exporte und Outlook-Anhänge verwenden anschließend diese archivierte PDF. Eine neue Bearbeitung entfernt die Unterschrift, während das Archiv erhalten bleibt. SHA-256 erkennt Änderungen an der PDF gegenüber dem lokalen Nachweis; die Ablage ist kein manipulationssicheres Archiv und die Gerätezeit kein qualifizierter Zeitstempel. Keine qualifizierte elektronische Signatur.
