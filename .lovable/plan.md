## Befund: Portal-Designs

Ich habe die drei Designs unter `/portal-designs` in echten Screenshots geprüft (clean, office, atmosphere). Grundstruktur ist gut und wirkt seriös, aber vier Punkte sehen noch nicht professionell aus:

1. **Schrift-Mix**: Überschrift und Labels sind Sans, die Beschreibungstexte („Melde dich mit deinen Zugangsdaten an.“, „oder“, „Passwort vergessen…“, Impressum/Datenschutz) rendern in einer Serif-Schrift. Das wirkt wie ein Fehler, nicht wie Design.
2. **Trenner „oder“**: Das Label hat einen weißen Kasten (`bg-card`), der auf den halbtransparenten Bildkarten als sichtbares weißes Rechteck über der Linie klebt. Bei „Brand Atmosphere“ sind die Trennlinien zusätzlich asymmetrisch (links kurz, rechts lang).
3. **Office Focus**: Das Foto ist praktisch nicht abgedunkelt; die weiße Fußzeile (Impressum/Datenschutz) steht auf hellem Teppich und ist kaum lesbar. Auch die Wortmarke oben links hat zu wenig Kontrast.
4. **Brand Atmosphere**: Der Weichzeichner ist so stark, dass das Bild als Grau-Grün-Fläche endet — Markenwirkung geht verloren; die Karte wirkt dadurch gräulich statt hochwertig.

### Umsetzung Design
- Typografie in `src/lib/portal-themes.ts` vereinheitlichen (alle Text-Tokens explizit auf die UI-Schrift, keine Serif-Vererbung), Größen/Zeilenhöhen pro Theme abgestimmt.
- Trenner neu: Label ohne Kasten, Linien mit `flex-1` gleich lang, auf Bild-Themes gedämpfter Kontrast.
- Office Focus: dunkler Verlaufs-Overlay (unten stärker) statt flacher Fläche, Fußzeile und Wortmarke mit lesbarem Kontrast bzw. leichtem Schatten.
- Brand Atmosphere: Blur deutlich reduzieren, dezenter Marken-Verlauf, Karte klar weiß/neutral statt grau.
- Karten-Feinschliff: einheitliche Innenabstände, Fokus-Ringe der Felder, Button-Höhen, Logo-Zeile oben links konsistent.
- Kontrolle mit Screenshots auf Desktop **und** Mobil — nicht nur auf `/portal-designs`, sondern auch auf den echten Seiten `/login`, `/register`, `/forgot-password`.

## Befund: E-Mail-System

Geprüft: alle Versand-Funktionen, das zentrale Log `email_send_log`, die Limits und das E-Mail-Center.

**Was passt:** Zentrale Limits (150/h, 2.400/Tag, Fenster 6–22 Uhr) liegen an einer Stelle; Bewerber-Reminder und Onboarding-Reminder respektieren sie und schreiben `sent`/`failed`/`skipped` inkl. Grund ins Log. Erneut-Senden inkl. `superseded`-Markierung funktioniert.

**Lücken, die ich beheben will:**
1. **Limits gelten nur für Reminder.** Einladung, Terminbestätigung, Signup-Bestätigung (inkl. erneutes Senden), Terminerinnerung, Chat-Reminder und Passwort-Reset prüfen weder das Stundenkontingent noch das Sendefenster. Bei Lastspitzen laufen wir wieder in die SMTP-Sperre (554 5.7.1) — genau der Fehler aus den Tests.
2. **Logging nicht vollständig.** `send-password-reset` schreibt nur Erfolge, kein Fehlschlag; `send-signup-confirmation` schreibt zusätzlich in eine Alt-Tabelle `email_logs` (Altlast, doppelte Wahrheit). Ergebnis: die Zahlen im Center können zu niedrig sein.
3. **„Wie viele Mails gingen raus?“ ist nicht exakt ablesbar.** Das Center lädt max. 5.000 Zeilen und zeigt nur 100 davon, ohne echte Gesamtzahl, ohne Zeitverlauf, ohne Aufschlüsselung pro Mandant und ohne Export.

### Umsetzung E-Mail
- Gemeinsamer Versand-Guard neben `_shared/limits.ts`: zählt Stunde/Tag pro Tenant aus `email_send_log` und wird von **allen** Funktionen genutzt. Transaktionale Mails (Bestätigung, Reset, Terminbestätigung) respektieren das Stundenkontingent, aber nicht das 6–22-Uhr-Fenster; Reminder respektieren beides. Jede Blockade landet als `skipped` mit Grund im Log.
- Gemeinsamer Log-Helfer: jede Funktion protokolliert **immer** — `sent`, `failed` (mit Fehlertext), `skipped` (mit Grund) — inkl. Empfänger, Template, Absender, Mandant. Alt-Schreibpfad `email_logs` entfernen, damit es nur eine Quelle gibt.
- E-Mail-Center erweitern: exakte Gesamtzahlen per Zähl-Abfrage (nicht aus geladenen Zeilen), Tagesverlauf der Sendungen, Aufschlüsselung pro Mandant und Template, „mehr laden“ statt harter 100er-Grenze, CSV-Export für den gewählten Zeitraum.
- Abdeckungs-Check: prüfen, welche Auth-Mails ggf. noch direkt über den Auth-Dienst laufen und daher nicht im Log erscheinen; diese entweder über den eigenen Versand leiten oder sichtbar als „extern versendet“ kennzeichnen.
- Abschließend die 14-stufige Testkette einmal durchlaufen und im Center gegenprüfen, dass jeder Schritt genau eine Zeile mit korrektem Status erzeugt.

## Technische Details
- Dateien Design: `src/lib/portal-themes.ts`, `src/components/portal/PortalAuthShell.tsx`, `src/routes/portal-designs.tsx`.
- Dateien E-Mail: `supabase/functions/_shared/limits.ts` (+ neuer Guard/Log-Helfer), `send-invitation-email`, `send-booking-confirmation`, `send-signup-confirmation`, `resend-signup-confirmation`, `send-appointment-reminders`, `send-chat-reminder`, `send-password-reset`, `src/routes/admin.email-center.tsx`, `src/lib/email-stats.ts`.
- Kein Schema-Umbau nötig; `email_send_log` bleibt die einzige Quelle. Änderungen an den Edge Functions müssen wie gewohnt auf Server 123 ausgerollt werden.
