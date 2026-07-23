## Problem

Stufe 1/14 (`send-invitation-email`) bricht mit `curl: (22) The requested URL returned error: 400` ab. `invoke_fn` nutzt aktuell `curl -fsS`, wodurch bei HTTP 4xx die Antwort-Body verworfen wird — wir sehen nicht, warum die Edge Function 400 antwortet.

Ohne den Fehlertext ist keine seriöse Diagnose möglich (Kandidaten: Payload-Validation, `resolveSender`, gesperrte Domain, fehlende Tenant-Felder, ...). Erster Schritt: Skript so umbauen, dass es die Antwort immer zeigt, dann gezielt fixen.

## Änderungen

**`scripts/email-test/run-full-chain.sh`**
1. `invoke_fn` umschreiben:
   - `curl -sS -w '\nHTTP_STATUS:%{http_code}'` (kein `-f` mehr).
   - Antwort splitten in `HTTP_STATUS` + Body.
   - Bei Status ≥ 400: `❌ HTTP <code> from <fn>: <body>` auf stderr, non-zero return.
   - Sonst: nur den Body auf stdout schreiben (kompatibel zu `require_success_response`/`jq`).
2. `SUITE_VERSION` auf `2026-07-23.4` heben und Preflight-Grep so anpassen, dass Läufe mit altem Skript sofort auffallen.

## Anwenden

Nach dem Fix wieder Frontend → Backend syncen (tar/scp wie gewohnt) und Testblock erneut starten. Die Ausgabe wird jetzt bei Stufe 1 den echten Fehlertext der Edge Function enthalten — den schickst du mir, dann fixe ich die eigentliche Ursache.
