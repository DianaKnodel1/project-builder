## Ziel

1. Die letzte Änderung an Login/Registrierung/Passwort-vergessen wird zurückgesetzt (Stand wie vorher).
2. Statt eines fixen Designs bekommt das Mitarbeiter-Portal **mehrere auswählbare Designs**, die im Landing-Generator beim Fast-Track-Flow gewählt werden.
3. Die OTP-Gültigkeit (24 h) wird beim Deploy automatisch auf dem Backend gesetzt, statt sie manuell per Putty zu tippen.

## Schritt 1 – Rücksetzen

- `src/routes/login.tsx`, `src/routes/register.tsx`, `src/routes/forgot-password.tsx` auf den Stand vor der Umstellung zurückholen (aus der Versionshistorie, kein Nachbauen).
- `src/components/auth/AuthShell.tsx` löschen.
- Danach Typecheck, damit keine Reste übrig bleiben.

## Schritt 2 – Portal-Designs (Themes)

Vier Designs, die alle Auth-Seiten (Login, Registrierung, Passwort vergessen, Passwort neu setzen) betreffen. Farbe/Logo kommen weiter aus dem Tenant, das Design bestimmt Layout und Anmutung:

| Design | Anmutung |
| --- | --- |
| `classic` | aktuelles Design (Standard, ändert nichts an bestehenden Portalen) |
| `minimal` | ruhige, zentrierte Karte auf neutralem Hintergrund, Logo oben, keine Effekte |
| `split` | links Markenfläche mit Logo + kurzem Claim, rechts das Formular |
| `soft` | weiche, abgerundete Karte mit dezentem Farbverlauf in der Tenant-Farbe |

Umsetzung:
- Neuer Ordner `src/components/auth/themes/` mit einem Wrapper pro Design und einem `PortalAuthShell`, der anhand des aktiven Designs das passende Layout rendert. Die Formulare selbst (Logik, Felder, Fehlermeldungen) bleiben unverändert und werden nur als `children` durchgereicht.
- Alle Farben laufen über die vorhandenen Design-Tokens bzw. `primary_color` des Tenants – keine hart kodierten Farben.
- Ein Hook liest das gewählte Design aus dem Tenant (Fallback `classic`), sodass es ohne Konfiguration exakt wie heute aussieht.

## Schritt 3 – Auswahl im Landing-Generator

- Im Fast-Track-Bereich (dort, wo heute die Portal-URL abgefragt wird) eine Design-Auswahl mit vier klickbaren Vorschau-Karten (kleine Wireframe-Vorschau + Name).
- Auswahl wird an der Landing Page gespeichert (`portal_theme`) und beim Speichern zusätzlich auf den zugehörigen Tenant geschrieben, damit das Portal das Design sofort verwendet.
- Migration: Spalte `portal_theme` (Text, Default `classic`) in `landing_pages` und `tenants`, inklusive der nötigen Rechte/Policies; `portal_theme` wird im öffentlichen Tenant-Lookup mitgeliefert, damit die Auth-Seiten es ohne Login lesen können.
- Vermittlung (Broker) bekommt die Auswahl bewusst nicht angezeigt – dort gibt es kein Portal.

## Schritt 4 – OTP-Gültigkeit beim Deploy

- Deploy-Skript für Backend 123 erweitert: es setzt `GOTRUE_MAILER_OTP_EXP=86400` (24 h) in der Supabase-Env, falls nicht vorhanden bzw. abweichend, und startet nur den Auth-Container neu.
- Idempotent, d. h. mehrfaches Deployen ändert nichts zusätzlich; Ergebnis wird im Log ausgegeben.
- `RUNBOOK.md` bekommt einen kurzen Abschnitt dazu (inkl. Prüf-Befehl), falls man es doch mal manuell nachsehen will.

## Technische Details

- Kein Eingriff in Auth-Logik, Supabase-Aufrufe oder E-Mail-System – reine Präsentationsschicht plus zwei neue Spalten.
- Das Portal liest das Design serverseitig-neutral über den bestehenden Tenant-Kontext; ohne gesetztes Design bleibt alles beim heutigen Aussehen (kein Risiko für bestehende Tenants).
- Prüfung am Ende: Typecheck plus Screenshots der vier Designs auf `/login` und `/register`, damit du sie vergleichen kannst.
