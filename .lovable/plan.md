## Ursache

Auf dem Backend läuft weiterhin eine alte Kopie von `chain-01-application-received.sql`. Das ist eindeutig: Die aktuelle Datei enthält kein `ON CONFLICT`; ihre Zeile 45 ist lediglich ein `SELECT`. Bisher wurden einzelne Dateien zwischen Frontend- und Backend-Server kopiert, wodurch ein gemischter Versionsstand entstanden ist.

## Plan

1. **Gesamte Testsuite synchronisieren**
   - Nicht mehr einzelne Dateien kopieren, sondern den vollständigen Ordner `scripts/email-test/` vom Frontend auf den Backend-Server übertragen.
   - Dadurch passen Runner, alle 14 SQL-Stufen und Dokumentation wieder zusammen.

2. **Versions- und Schema-Prüfung ergänzen**
   - Der Runner zeigt beim Start eine eindeutige Suite-Version an.
   - Der Vorabcheck prüft die zentralen Tabellen, Spalten und benötigten Constraints, bevor irgendeine Mail versendet wird.
   - Bei Abweichungen bricht er mit einer verständlichen Meldung ab, statt erst mitten in einer Stufe mit einem kryptischen SQL-Fehler zu scheitern.

3. **Bekannte falsche Annahmen vollständig entfernen**
   - Alle aktiven SQL-Snippets auf `ON CONFLICT`, nicht vorhandene Felder und ungesicherte Unique-Annahmen kontrollieren.
   - Für Testdaten konsequent das bereits passende Muster `DELETE` plus `INSERT` verwenden.

4. **Erneuten Lauf klar vorbereiten**
   - Einen einzigen Kopierbefehl für Server 124 → 123 bereitstellen.
   - Danach den vollständigen Startblock für Server 123 liefern; die bereits bestätigte direkte Datenbankverbindung über die Docker-IP bleibt bestehen.
   - Erst nach erfolgreichem Vorabcheck startet die 14-stufige Mailkette.