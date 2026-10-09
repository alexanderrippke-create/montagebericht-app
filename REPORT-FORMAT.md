# Gemeinsames Berichtsformat 1

Windows: `.montagebericht` oder `.json`. iOS exportiert über den Dateien-Dialog `.json` und akzeptiert beide Erweiterungen.

```json
{
  "format": "montagebericht",
  "schemaVersion": 1,
  "department": "montage",
  "report": {
    "fields": { "customer": "Beispiel", "email": "kunde@example.de", "date": "2026-10-09", "officeContact": "Alexander" },
    "times": [{ "date": "2026-10-09", "from": "08:00", "to": "10:00", "hours": "2.00" }],
    "parts": [],
    "signature": null
  }
}
```

`department` ist `montage` oder `karcher`. Feldnamen entsprechen den vorhandenen Windows-Formularfeldern. Datum ist ein Kalenderdatum `YYYY-MM-DD`, Uhrzeit `HH:mm` ohne Zeitzonenverschiebung; Zahlen werden als Zeichenketten übertragen. Unterschriften sind eingebettete `data:image/png;base64,...` (Kunde in `signature`, Monteur in `fields.technicianSignatureData`).

`iosReport` im Snapshot enthält optional die ursprüngliche native iOS-Fassung inklusive PencilKit-Zeichnungen. Windows erhält diese Zusatzdaten. iOS übernimmt beim Rückimport die aktuellen gemeinsamen Formularwerte und behält PencilKit-Zeichnungen, deren PNG nicht geändert wurde.

Abgeschlossene Berichte tragen `fields.finalizedId`, `fields.signedAt` und `archive: {pdf: <Base64>, sha256: <Hex>}`. Die PDF wird nach Prüfsummenprüfung ausgegeben. Eine abgeschlossene Fassung wird weiter gesperrt; eine neue Bearbeitung löscht Unterschriften wie bisher. Eine Prüfsumme ist kein unabhängiger Signaturnachweis.

Unbekannte Formatversionen werden abgelehnt, bestehende Originaldateien nicht migriert oder gelöscht. Windows kann außerdem bisherige direkte Snapshot-JSON-Dateien lesen. iOS unterstützt weiterhin seine bisherigen nativen JSON-Sicherungen mit deren bisherigen Regeln (Import als neue Bearbeitung ohne Unterschriften).
