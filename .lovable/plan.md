## Ziel
Stufe 1 der Test-Kette (`chain-01-application-received.sql`) läuft ohne NOT-NULL-Fehler.

## Ursache
`applications.booking_status` ist `text NOT NULL DEFAULT 'none'` (Migration `20260618100000_calendly_integration.sql`, CHECK: `none, pending, scheduled, cancelled, no_show, completed`). Das Snippet schreibt aktuell explizit `NULL` in diese Spalte → Insert bricht ab.

## Fix
In `scripts/email-test/sql-snippets/chain-01-application-received.sql`:
- Im `INSERT` den Wert für `booking_status` von `NULL` auf `'none'` ändern (der DB-Default für einen frischen Bewerber "vor Buchung").
- Rest des Snippets bleibt unverändert.

## Danach
Auf dem Frontend-Server (124) den bestehenden Sync-Befehl erneut ausführen:
```
cd /opt/apps/portal && git pull
tar -czf /tmp/email-test-suite.tgz -C scripts email-test
scp /tmp/email-test-suite.tgz root@190.97.167.123:/tmp/
ssh root@190.97.167.123 'rm -rf /opt/apps/portal-migrations/scripts/email-test && mkdir -p /opt/apps/portal-migrations/scripts && tar -xzf /tmp/email-test-suite.tgz -C /opt/apps/portal-migrations/scripts'
```
Anschließend auf Backend (123) den bekannten Export- und Testblock erneut starten.
