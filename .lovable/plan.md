## Ursache

Die Datenbankstufe funktioniert jetzt. Der Abbruch entsteht, weil auf dem Backend-Server `jq` fehlt. Dadurch wird der JSON-Request für die Mail-Funktion nicht erzeugt; der leere/ungültige Request verursacht anschließend HTTP 400.

## Vorgehen

1. Auf dem Backend-Server `jq` installieren:
   ```bash
   apt-get update && apt-get install -y jq
   ```
2. Prüfen:
   ```bash
   jq --version
   ```
3. In derselben SSH-Sitzung den Test erneut starten; die bereits gesetzten Variablen bleiben erhalten:
   ```bash
   cd /opt/apps/portal-migrations
   export PAGER=cat PSQL_PAGER=cat
   bash scripts/email-test/run-full-chain.sh
   ```
4. Im Testskript zusätzlich einen frühen Vorabcheck für `jq`, `curl` und `psql` ergänzen, damit künftig eine klare Meldung erscheint, bevor Testdaten angelegt oder Funktionen aufgerufen werden.

Nach der Installation sollte Schritt 1 den korrekten JSON-Request senden; falls danach weiterhin HTTP 400 erscheint, wird die vollständige Funktionsantwort separat sichtbar gemacht und anhand dieser konkreten Meldung korrigiert.