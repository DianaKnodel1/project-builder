## Ziel

Ende-zu-Ende-Test der kompletten Mail-Kette für den Vermittlungs-Flow:
Bewerber bewirbt sich auf `personalservice-gmbh.de` (Vermittlung/Broker) und wird an `bv-agentur` (Fast-Track) weitergereicht. Ergebnis: alle Mails werden korrekt vom richtigen Absender (Broker vs. Fast-Track) mit richtigem Logo verschickt.

## Warum bisher nur 1 Landing kam

Die Abfrage `WHERE tenant_id = $TEST_TENANT_ID` filtert korrekt – „personalservice“ ist ein eigener Tenant und hat genau 1 Landing. `bv-agentur` gehört zu einem anderen Tenant. Die 7–8 Landings verteilen sich also über mehrere Tenants. Für den Vermittlungs-Test brauchen wir **zwei** Landings aus zwei Tenants (Source = Broker, Target = Fast-Track).

## Änderungen

### 1) `scripts/email-test/run-full-chain.sh`
- Zwei neue Pflicht-Env-Variablen: `TEST_SOURCE_LANDING_ID` (Broker) und `TEST_TARGET_LANDING_ID` (Fast-Track). `TEST_LANDING_ID` bleibt als Kompat-Alias (falls gesetzt → für beide verwendet, alter Standard-Flow).
- Preflight erweitern:
  - beide Landings existieren
  - `source.flow_type = 'broker'`, `target.flow_type IN ('fast','classic')`
  - Verfügbarkeitskalender an der **Target-Landing** oder deren `linked_fasttrack_landing_id`
  - beide Tenants (Source-Tenant + Target-Tenant) haben SMTP-Config (Warnung falls nicht)
- `load_app_context`: `tenants.primary_domain` gibt es nicht → auf vorhandene Spalte umstellen (aus `\d tenants` verifizieren, vermutlich `domain` / `portal_domain`). Fallback: Domain aus der Target-Landing (`landing_pages.domain`).
- Terminbuchungs-Link (Stufe 1) aus der **Target-Landing-Domain** bauen, nicht aus der Tenant-Domain.

### 2) `scripts/email-test/sql-snippets/chain-01-application-received.sql`
- `source_landing_id = :source_landing_id`, `target_landing_id = :target_landing_id`
- `tenant_id` = **Broker-Tenant** (Source-Tenant), damit `applications.broker_tenant_id` beim Insert-Trigger korrekt gesetzt wird
- `flow_type = 'broker'` mitschreiben, damit `resolveSender` den Broker-Pfad wählt
- Sicherstellen, dass die Trigger-Backfill-Spalten (`broker_tenant_id`, `fasttrack_tenant_id`) nach dem Upsert gefüllt sind (SELECT zur Kontrolle mit ausgeben)

### 3) Alle weiteren Snippets, die neu inserten könnten
- Kurz durchsehen und, falls sie `applications` neu anlegen, dieselben Broker-/Fast-Track-IDs verwenden.

### 4) Vorlauf-Query (README)
- Kleiner SQL-Block in `scripts/email-test/README.md` ergänzen, der die passenden IDs für den Broker-Flow ausgibt:
  ```sql
  SELECT l.id, l.slug, l.domain, l.flow_type, l.tenant_id, t.name
  FROM landing_pages l JOIN tenants t ON t.id = l.tenant_id
  WHERE l.flow_type IN ('broker','fast')
  ORDER BY l.flow_type, t.name;
  ```
- Beispiel-Exports für personalservice → bv-agentur.

### 5) Ausführen (auf dem Portal-Server, nach `git pull`)
1. Vorlauf-Query laufen lassen → IDs von `personalservice-gmbh-de` (source, broker) und der bv-agentur-Landing (target, fast) notieren.
2. Exportieren:
   ```bash
   export TEST_TENANT_ID="<broker-tenant-id von personalservice>"
   export TEST_SOURCE_LANDING_ID="8d4a3aac-…"      # personalservice
   export TEST_TARGET_LANDING_ID="<bv-agentur-id>"
   export TEST_EMAIL="test+broker@outlook.com"
   ```
3. `bash scripts/email-test/run-full-chain.sh`
4. Nach jeder Stufe im Postfach prüfen: Logo (Broker-Logo bei Broker-Mails, Fast-Track-Logo bei `booking_confirmation`), Absender-Domain, Terminlink.

## Nicht Teil des Plans

- Keine Änderungen an den Edge-Functions (`send-invitation-email`, `send-booking-confirmation`, `sender-resolver`) – die Logo-/Sender-Priorität wurde bereits gefixt und soll durch diesen Test nur verifiziert werden.
- Kein Test-Send an echte Bewerber – der `dry_run`-Guard bleibt aktiv.
