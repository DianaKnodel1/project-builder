## Ziel
Den wiederholten Fehler zuverlässig beenden. Der Backend-Server führt weiterhin einen älteren Stand des SQL-Snippets aus: Im aktuellen Projekt setzt der Insert `booking_status` bereits ausdrücklich auf `'none'`, während die ausgeführte Version weiterhin `NULL` einfügt.

## Umsetzung
1. **Suite-Version erhöhen**
   - `SUITE_VERSION` auf eine neue Version setzen, damit in der Konsolenausgabe sofort erkennbar ist, ob wirklich der aktuelle Stand läuft.

2. **Preflight gegen veraltete Dateien absichern**
   - Vor dem ersten Test prüfen, dass `chain-01-application-received.sql` die Spalte `booking_status` und den Wert `'none'` enthält.
   - Bei einem alten oder unvollständig synchronisierten Snippet mit einer klaren Meldung abbrechen, bevor Daten verändert werden.

3. **Aktuelles SQL beibehalten**
   - Der Test-Insert setzt `booking_status = 'none'`, passend zum bestätigten `NOT NULL`-Constraint und den erlaubten Statuswerten.

4. **Einmal vollständig synchronisieren und prüfen**
   - Den gesamten Ordner `scripts/email-test` erneut vom Frontend auf das Backend übertragen.
   - Auf dem Backend vor dem Start die neue Suite-Version und die relevante SQL-Zeile anzeigen.
   - Anschließend den bekannten Export- und Testblock ausführen.