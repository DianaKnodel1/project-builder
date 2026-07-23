
# Übersicht: Alle E-Mails im Portal

Kein Code-Change — reine Bestandsaufnahme, damit du entscheiden kannst, welche Mails du als nächstes anpassen willst.

## A) Bewerber-Mails (automatisch, alle Tenants, zentrale Vorlage)

Diese sind die „neuen" zentralen Templates aus den letzten Tagen — pro Tenant nur personalisiert (Logo, Name, Recruiter), Text ist überall gleich.

| # | Mail | Trigger | Function | Kind |
|---|---|---|---|---|
| 1 | **Bewerbung eingegangen – nächster Schritt** (mit Buchungslink + „Sollten Sie bereits einen Termin gebucht haben…") | Bewerbung wird akzeptiert / Broker-Flow angenommen | `send-invitation-email` | `application_received` |
| 2 | **Termin bestätigt** (mit .ics-Anhang, Recruiter-Karte) | Direkt nach Buchung eines Interview-Slots, Cron alle 2 Min | `send-booking-confirmation` | `booking_confirmation` |
| 3 | **Interview-Einladung mit Magic-Link** (~30 Min vor Gespräch) | Cron alle 10 Min, Fenster now+25…+40 Min vor `scheduled_at` | `send-appointment-reminders` | `interview_invite_30min` |

## B) Bewerber-Reminder (automatisch, Cron)

Nutzen ebenfalls zentrale Defaults, laufen still im Hintergrund.

| # | Mail | Trigger | Function | Kind |
|---|---|---|---|---|
| 4 | **Kein Termin gebucht – 24h Erinnerung** | 24h nach Bewerbung ohne Buchung, Cron alle 30 Min | `send-application-reminders` | `no_booking_24h` |
| 5 | **Kein Termin gebucht – 72h Erinnerung** | 72h nach Bewerbung ohne Buchung | `send-application-reminders` | `no_booking_72h` |
| 6 | **No-Show – erneut buchen** | 24h nach verpasstem Termin | `send-application-reminders` | `no_show_24h` |
| 7 | **Rebook nach Absage** | Kandidat hat Termin gecancelt | send-application-reminders (rebook path) | `rebook_after_cancel` |

## C) Onboarding / Account-Mails (Mitarbeiter nach Zusage)

Tenant-SMTP, personalisierte Templates aus `tenants.*_body`.

| # | Mail | Trigger | Function |
|---|---|---|---|
| 8 | **Willkommen / Registrierungs-Einladung** (Konto anlegen) | Admin akzeptiert Bewerbung mit Zusage | `send-invitation-email` (welcome branch) |
| 9 | **E-Mail-Bestätigung** (Signup-Confirmation) | User legt Konto an | `send-signup-confirmation` |
| 10 | **E-Mail-Bestätigung erneut senden** | Manuell / Reminder-Queue | `resend-signup-confirmation` |
| 11 | **Passwort zurücksetzen** | User klickt „Passwort vergessen" | `send-password-reset` |

## D) Drip-/Reminder-Serien für neue Mitarbeiter

Cron 1× täglich, max. 5 Versuche, min. 3 Tage Abstand.

| # | Mail | Zielgruppe | Function |
|---|---|---|---|
| 12 | **Einladung noch offen** | Angenommen, aber Konto nicht angelegt | `send-reminders` (`invite`) |
| 13 | **E-Mail noch nicht bestätigt** | Konto angelegt, Bestätigung offen | `send-reminders` (`confirm_email`) |
| 14 | **Registrierung abschließen** | Bestätigt, Onboarding unvollständig | `send-reminders` (`complete_registration`) |
| 15 | **Invite-Drip-Queue** (verteilt Send-Bursts über den Tag) | Wrapper für #8/#12 | `process-invite-resend-queue` |

## E) Interne / Manuelle Mails

| # | Mail | Trigger | Function |
|---|---|---|---|
| 16 | **Chat-Erinnerung** („Du hast eine neue Nachricht von …") | Admin/Teamleiter klickt „📨 Erinnerung senden" | `send-chat-reminder` |
| 17 | **SMTP-Test** (Diagnose, kein produktiver Versand) | Admin-Panel „SMTP testen" | `smtp-test` |

## Was du daraus mitnehmen kannst

- **Zentrale Vorlagen (A + B)**: Text ändern → Code-Default anfassen, gilt sofort für alle Tenants.
- **Tenant-Vorlagen (C)**: Text ändern → im Admin-Panel unter E-Mail-Vorlagen pro Tenant, ODER Default im Code anfassen (dann nur für Tenants ohne Override).
- **Cron-Übersicht**: 2 Min = booking_confirmation, 10 Min = interview_invite_30min, 15 Min = invite-drip-queue, 30 Min = application-reminders, 1×/Tag = send-reminders.

Sag mir welche Mail du dir als nächstes vornehmen willst (Inhalt anpassen, Design, neuen Trigger, etc.), dann plane ich die konkrete Änderung.
