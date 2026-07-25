// Zentrale SMTP-/Versand-Limits für alle Edge Functions.
//
// Vertrag (Stand 2026-07): 150 Mails pro Stunde pro Tenant/SMTP,
// Sendefenster 06:00–22:00 Europe/Berlin → 16 × 150 = 2.400 Mails/Tag/Tenant.
//
// Nur hier ändern — die Functions importieren diese Werte.

/** Sendefenster (Europe/Berlin), inkl. Start, exkl. Ende. */
export const SEND_WINDOW_START_HOUR = 6;
export const SEND_WINDOW_END_HOUR = 22;

/** Harte SMTP-Grenze pro Tenant und Stunde. */
export const MAX_PER_1H_PER_TENANT = 150;

/** 12h-Kontingent: 12 aktive Stunden × 150. */
export const MAX_PER_12H_PER_TENANT = 1800;

/** Tageskontingent (16 Stunden Sendefenster × 150). */
export const MAX_PER_24H_PER_TENANT = 2400;

/** Bewerber-Reminder pro Cron-Lauf und Tenant (Cron alle 30 Min).
 *  60 pro Lauf × 2 Läufe/h = 120/h — bleibt unter der harten 1h-Grenze (150),
 *  die zusätzlich live aus email_send_log geprüft wird. */
export const MAX_PER_RUN_PER_TENANT = 60;

/** Onboarding-Reminder (send-reminders) pro Lauf, Tenant und Typ. */
export const MAX_SENDS_PER_RUN_PER_TENANT = 50;
