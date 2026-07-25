## Antworten zuerst

**Warum sich die Warteschlange nicht geändert hat**
Die beiden Maßnahmen, die die alten `pending`-Zeilen auflösen, sind noch **nicht auf Backend 123 aktiv**:
1. das Cleanup-SQL (`scripts/sql/cleanup-superseded-email-log.sql`) wurde noch nicht ausgeführt,
2. die Edge Function `send-application-reminders` (setzt alte `pending`-Zeilen auf `superseded`) ist noch nicht redeployt.

Solange bleiben die alten Zeilen mit Status `pending` stehen — auch wenn die Mail längst raus ist. Die Zahl ist also aktuell überwiegend Alt-Last, kein laufender Rückstau. Bestätigen kann ich das erst mit einer Abfrage auf die echten Zeilen (Alter + Template + Empfänger), das ist Schritt 1 unten.

**SMTP-Limits, wie sie aktuell im Code stehen**

| Grenze | Wert | Wo |
|---|---|---|
| Sendefenster | 06:00–22:00 Europe/Berlin | `send-reminders` (Quiet Hours) |
| Bewerber-Reminder pro Tenant / Stunde | 150 | `send-application-reminders` |
| Bewerber-Reminder pro Tenant / 12 h | 1.800 | `send-application-reminders` |
| Pro Cron-Lauf pro Tenant | 8 | `send-application-reminders` |
| Onboarding-Reminder pro Lauf / Tenant | 50 | `send-reminders` |
| Onboarding-Reminder pro Tenant / 24 h | 140 | `send-reminders` |

Dein Vertrag erlaubt 150/Stunde × 16 Stunden = **2.400 Mails pro Tag und Tenant/SMTP**. Der Stundenwert passt (150). Zwei Werte bremsen dich unnötig aus:
- `MAX_PER_12H_PER_TENANT = 1800` → bei Volllast erreicht man 2.400/Tag nie.
- `MAX_SENDS_PER_TENANT_PER_24H = 140` in `send-reminders` → das ist ein Tageslimit, obwohl der Vertrag 2.400/Tag hergibt.

## Plan

### 1. Warteschlange verifizieren (vor jeder Änderung)
SQL-Snippet für Backend 123, das die offenen `pending`-Zeilen nach Alter, Template und Empfänger gruppiert, und zeigt, ob es zum selben Empfänger/Template später ein `sent`/`failed` gibt. Damit steht fest, was Alt-Last ist und was echter Hänger. Danach Cleanup-Skript + Redeploy.

### 2. Generischer „Erneut senden“-Button
Neue Edge Function **`email-resend`**: bekommt eine `email_send_log`-ID, lädt die Zeile, holt SMTP/Absender des Tenants über `_shared/sender-resolver.ts` und versendet den **gespeicherten** `rendered_html` / `rendered_subject` erneut. Das funktioniert für alle Mail-Typen, weil jede Funktion HTML und Subject mitloggt — kein Nachbauen von Template-Variablen, keine abgelaufenen Magic-Links werden neu erzeugt (siehe Hinweis unten).

Verhalten:
- Admin-Prüfung (Service-Role + Rolle `admin`) und Tenant-Zugehörigkeit
- Optional `to`-Override → „Testkopie an mich“ funktioniert dann für **jeden** Mail-Typ, nicht nur Einladungen
- Neuer Log-Eintrag mit `metadata.resent_from = <alte ID>` und `metadata.resent_by`
- Alte Zeile wird auf `superseded` gesetzt bzw. `acknowledged_at` gefüllt, damit sie aus Fehler/Warteschlange verschwindet
- Guard: wenn kein `rendered_html` vorhanden (sehr alte Zeilen) → klare Fehlermeldung „nicht erneut sendbar“
- SMTP-Ratelimit-Fehler werden wie in `send-application-reminders` erkannt und als „später erneut versuchen“ zurückgemeldet

### 3. UI
- **Roh-Log** (`admin.email-logs.tsx`): der bestehende „Erneut senden“-Button ruft künftig `email-resend` statt `send-invitation-email` und wird für **alle** Templates sichtbar (nicht nur `failed`/`dlq` — auch bei `sent`, mit Bestätigungsdialog „wirklich nochmal senden?“). „Testkopie an mich“ läuft über denselben Weg.
- **E-Mail-Center** (`admin.email-center.tsx`): in der Detailliste pro Zeile ein Icon „Erneut senden“ mit Bestätigungsdialog + Toast, danach Reload.
- Kein Massen-Resend-Button (Schutz vor versehentlichem Fluten); immer einzelne Mail.

### 4. Limits an den Vertrag anpassen
- `MAX_PER_12H_PER_TENANT`: 1800 → 2400 (bzw. auf Tagesfenster umstellen)
- `send-reminders` `MAX_SENDS_PER_TENANT_PER_24H`: 140 → höher, sofern du das willst (das war bewusst konservativ für Reputation/Warm-up). Sag mir, ob ich auf 1.000+ hochziehen oder konservativ lassen soll.
- Werte zentral in einer `_shared/limits.ts` bündeln, damit sie nicht an drei Stellen auseinanderlaufen. RUNBOOK aktualisieren.

### Technische Hinweise
- Magic-Link-/Token-Mails (Interview-Einladung, E-Mail-Bestätigung): das gespeicherte HTML enthält den **alten** Link. Bei Templates mit Ablauf (`bewerbung_magic_link`, `signup_confirmation`) zeigt das UI einen Warnhinweis und leitet stattdessen an die dedizierte Funktion (`resend-signup-confirmation`) weiter, wo ein frischer Token generiert wird.
- Deployment: `email-resend` muss auf Backend 123 deployt werden, das UI kommt mit dem normalen Build.
