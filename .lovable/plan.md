## Teil 1 — Portal-Designs überarbeiten

Richtung: schlicht wie Bild 2 (Minimal), aber wertiger. Trust-Zeile („Sicherer Login · DSGVO-orientiert · 100% online") wird komplett entfernt.

Neue Design-Auswahl (4 Varianten, gleiche Formulare, nur Rahmen/Optik):

1. **Minimal** — weiße, zentrierte Karte auf neutralem Grund. Logo klein oben links in der Kopfzeile statt zentriert über der Karte. Keine Effekte.
2. **Marken-Split** — links Markenfläche (Logo oben links, Firmenname, ein kurzer Satz), rechts das Formular. Hell, ruhig.
3. **Theme-Bild** — großflächiges Hintergrundbild (Branchen-/Theme-Bild), darüber leichter Abdunkler und die schlichte weiße Karte. Logo oben links über dem Bild.
4. **Soft** — dezenter Verlauf in der Firmenfarbe, abgerundete Karte. Bleibt als weichere Alternative.

Weitere Anpassungen:
- Kopfzeile einheitlich: Logo links, optional Firmenname; Fallback-Icon nur wenn kein Logo hinterlegt ist.
- Fußzeile schlicht: Impressum/Datenschutz-Links statt Trust-Badges.
- „Classic (Dunkel)" fliegt aus der Auswahl (Wellen-Grafik wirkt unruhig); bestehende Tenants ohne Auswahl landen auf **Minimal**.
- Hintergrundbild pro Tenant: entweder eigenes Bild (URL/Upload) oder ein neutrales Standardbild aus dem Projekt.
- Vorschau-Seite `/portal-designs` und der Design-Picker im Landing-Generator werden auf die neuen Varianten aktualisiert.

Danach zeige ich alle Varianten wieder als Screenshots zur Abnahme.

## Teil 2 — E-Mail-System-Audit (vor dem Massenversand)

Beim Durchsehen des Codes sind vier Punkte aufgefallen, die beim Hochskalieren stören:

**a) Durchsatz-Bremsen, die nicht zum 150/h-Vertrag passen**
- Bewerber-Reminder: max. 8 Mails pro Lauf und Tenant, Cron alle 30 Min → nur ~16 Mails/Stunde statt möglicher 150.
- Invite-Nachfass-Queue: eigenes, fest verdrahtetes Tageslimit von 140 Mails/Tenant — zieht nicht die zentralen Limits (2.400/Tag).
- Fix: beide auf die zentralen Werte in der Limit-Datei umstellen und die Lauf-Kontingente so setzen, dass 150/h/Tenant tatsächlich erreichbar sind, ohne die Stundengrenze zu reißen.

**b) Lücken im Tracking / Mail-Center**
- Bei Termin-Erinnerungen werden Skip-Gründe (keine E-Mail, kein Token, SMTP unvollständig, Tenant pausiert, keine Domain) nur in der Antwort zurückgegeben, aber nicht ins zentrale Log geschrieben → im Mail-Center unsichtbar.
- Fix: jede Entscheidung (sent / failed / skipped mit Grund) wird in allen Versandfunktionen ins zentrale Log geschrieben, mit Template-Name, Empfänger, Tenant und Grund.

**c) Einheitliche Log-Schreibweise**
Jede Funktion hat ihre eigene Log-Routine, teils mit unterschiedlichen Feldern (Template-Name, Message-ID, gerenderte HTML fehlt teils). Fix: eine gemeinsame Log-Hilfsfunktion im geteilten Ordner, die alle Funktionen nutzen — damit sind Statistik, Erneut-Senden (braucht das gespeicherte HTML) und Coverage-Monitor für jede Mail zuverlässig.

**d) Verifikation statt Vermutung**
- Prüfung der aktiven Cron-Jobs auf dem Backend (welche Jobs laufen wirklich, in welchem Intervall) — ein Job für Termin-Erinnerungen wurde in einer Migration abgeschaltet und muss bewertet werden.
- Abgleich in der Datenbank: alle Template-Namen der letzten 7 Tage im Log gegen die im Mail-Center freigeschalteten Namen; alle Log-Einträge ohne gespeichertes HTML (nicht erneut sendbar) auflisten.
- Kompletter Trockenlauf aller Flows (dry-run) plus ein echter Durchlauf der 14-Schritt-Kette mit einer Testadresse, danach Kontrolle: erscheint jede der 14 Mails im Mail-Center mit korrektem Status.

Ergebnis: eine kurze Freigabe-Checkliste (Durchsatz pro Tenant/Stunde, Tracking-Lücken = 0, alle 14 Templates sichtbar, Fehler-Wiederholung funktioniert).

## Technische Details

- Design: `src/lib/portal-themes.ts` (Token-Sets neu), `src/components/portal/PortalAuthShell.tsx` (Kopfzeile, Trust-Zeile entfernen, Bild-Layer), `src/routes/portal-designs.tsx`, `src/routes/admin.landing-generator.tsx`, ggf. Feld für Hintergrundbild in den Branding-Daten.
- E-Mail: `supabase/functions/_shared/limits.ts`, neue `_shared/log-send.ts`, Anpassung in `send-application-reminders`, `send-appointment-reminders`, `send-booking-confirmation`, `send-invitation-email`, `send-reminders`, `send-chat-reminder`, `send-password-reset`, `resend-signup-confirmation`, `process-invite-resend-queue`; Whitelist/Coverage in `src/routes/admin.email-center.tsx`.
- Deployment: Edge-Functions und ggf. Cron-Migration müssen auf Backend 123 ausgerollt werden (Ablauf steht im Runbook).
