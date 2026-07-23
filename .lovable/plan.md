## Ergebnis Stufen 1–2
Beide grün: Stufe 1 sendet Bewerbungsbestätigung, Stufe 2 „Termin bestätigt" (dry_run: 1 Kandidat, 1 Ziel).

## Ursache Stufe 3
`send-appointment-reminders` (Zeile 239) überspringt Kandidaten ohne `magic_token`. Die Testbewerbung wird in `chain-01-application-received.sql` ohne `magic_token` eingefügt, deshalb `reason: "no_magic_token"`. `send-application-reminders` (Rebook 24h/72h) baut den Rebook-Link ebenfalls über `magic_token` — Stufen 7/8 würden ohne Token dieselbe Lücke haben.

## Fix
- `chain-01-application-received.sql`: `magic_token` und `magic_token_expires_at` beim Insert setzen — z. B. `magic_token = encode(gen_random_bytes(24), 'hex')`, `magic_token_expires_at = now() + interval '30 days'`.
- Spalte im Insert-Header und Value-Liste ergänzen. Alle Folgestufen erben den Token automatisch, da sie nur `UPDATE` machen.
- `SUITE_VERSION` → `2026-07-23.6`.
- Vorabcheck erweitern: grep in `chain-01-application-received.sql` auf `magic_token` (verhindert veraltete Kopien auf Server 123).

Kein Edge-Function-Code wird angefasst.

## Sync + Run
```bash
# Frontend (124)
cd /opt/apps/portal && git pull
tar -czf /tmp/email-test-suite.tgz -C scripts email-test
scp /tmp/email-test-suite.tgz root@190.97.167.123:/tmp/
ssh root@190.97.167.123 \
  'rm -rf /opt/apps/portal-migrations/scripts/email-test &&
   mkdir -p /opt/apps/portal-migrations/scripts &&
   tar -xzf /tmp/email-test-suite.tgz -C /opt/apps/portal-migrations/scripts'

# Backend (123)
bash scripts/email-test/run-full-chain.sh
```

Erwartung: Stufen 1–8 laufen grün, danach kommen 9–14 (Welcome, Auth-Mails, Legacy-Invite, Complete-Registration).
