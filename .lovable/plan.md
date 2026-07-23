## Ziel

Die in den letzten Tagen im Code gepflegten Vorlagen (`application_received` = „Bewerbung eingegangen" und `booking_confirmation` = „Terminbestätigung") sollen als **einheitliche Vorlage für alle Tenants** gelten. Personalisierung passiert weiterhin über Platzhalter (`{{tenant_name}}`, `{{first_name}}`, Logo, Buchungslink usw.) — aber Betreff/Body/Button werden nicht mehr aus tenant-spezifischen DB-Spalten überschrieben.

## Änderungen

### 1. `supabase/functions/send-invitation-email/index.ts`
Beim Zweig `templateNameOverride === "application_received"`:
- `dbSubject / dbBody / dbButton` nicht mehr aus `tenant.application_received_*` lesen — auf `null` lassen.
- Damit greift automatisch immer `DEFAULT_APPLICATION_RECEIVED_TEMPLATE` / `DEFAULT_APPLICATION_RECEIVED_SUBJECT` und der Default-Button „Jetzt Termin buchen".
- Explizit übergebene Aufruf-Overrides (`subjectOverride`, `introOverride`, `buttonLabelOverride`) bleiben respektiert (die kommen aus dem Code, nicht aus der Tenant-Konfig).

### 2. `supabase/functions/send-booking-confirmation/index.ts`
Im `renderEmail({...})`-Aufruf (Zeilen 313–321) und beim `button_label` in `vars` (Zeile 307):
- `subject: DEFAULT_SUBJECT`
- `body: DEFAULT_BODY`
- `button_label: DEFAULT_BUTTON`
- `tenant.booking_confirmation_*` nicht mehr auslesen.

### 3. Tenant-Felder unangetastet lassen
- Die DB-Spalten (`application_received_subject/body/button_label`, `booking_confirmation_subject/body/button`) bleiben bestehen — nichts wird migriert oder gelöscht, damit alte Daten nicht verloren gehen und ein späterer Rückbau möglich ist.
- Nur die Code-Pfade lesen sie nicht mehr.

### 4. Was weiterhin per Tenant personalisiert bleibt
- Tenant-Name, Logo (Broker-Flow-Priorität wie zuletzt gebaut), Absenderadresse/SMTP, Primärfarbe, Recruiter-Name/-Avatar, Buchungslink, Bewerbername — alles via Platzhalter/Brand-Objekt im Renderer.

## Nicht in Scope
- Admin-UI „E-Mail-Vorlagen" für diese beiden Templates. (Falls du willst, entferne ich die Tabs später separat — für jetzt bleiben sie sichtbar, wirken aber nicht mehr auf den Versand.)
- Welcome-Mail (`welcome_email_*`) bleibt weiterhin per Tenant überschreibbar.

## Deployment
```
cd /opt/apps/portal && git pull && bash scripts/deploy-backend.sh
```
