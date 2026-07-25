## Ziel

Drei professionelle, schlichte Portal-Designs für Login und Registrierung erstellen, direkt als echte Screenshots zeigen und gleichzeitig das gesamte E-Mail-System samt Mail Center vor dem Massenversand technisch und praktisch absichern.

## Bestätigter aktueller Stand

- Der alte Wert von **8 Bewerber-Remindern pro Lauf ist bereits geändert**.
- Aktuell gelten **60 Mails pro Lauf und Tenant**. Bei zwei Läufen pro Stunde sind das bis zu 120 Reminder/Stunde; zusätzlich greifen die zentralen Grenzen von **150/Stunde** und **2.400/Tag je Tenant/SMTP**.
- Die vier derzeit im Code vorhandenen Portal-Varianten sind `Minimal`, `Marken-Split`, `Theme-Bild` und `Soft`.
- „Theme-Bild“ bedeutet: Ein professionelles Büro-/Branchenfoto füllt den Hintergrund, wird leicht abgedunkelt und dezent unscharf dargestellt. Das Firmenlogo steht links oben; das weiße, schlichte Formular bleibt klar lesbar im Mittelpunkt.
- Das Mail Center basiert auf dem zentralen Versandlog. Ein Status `gesendet` bestätigt derzeit die Annahme durch den SMTP-Server, aber nicht zwingend die spätere Zustellung im Postfach. Späte Bounces oder Spam-Zustellungen können ohne Rückkanal nicht sicher erkannt werden.

## 1. Drei Portal-Designs

Alle drei Varianten erhalten dieselben Formulare und Funktionen, unterscheiden sich nur in der Darstellung:

1. **Office Focus**
   - Zentriertes weißes Login-Formular
   - Professionelles Bürobild vollflächig im Hintergrund
   - Leichter Blur und dunkler Overlay für gute Lesbarkeit
   - Firmenlogo links oben

2. **Clean Corporate**
   - Sehr heller, neutraler Hintergrund ohne Foto
   - Kompakte, hochwertige Formularkarte in der Mitte
   - Firmenfarbe nur für Button, Fokus und kleine Akzente
   - Firmenlogo links oben

3. **Brand Atmosphere**
   - Unscharfes Büro-/Arbeitsweltbild mit einer ruhigen Fläche in der Tenant-Firmenfarbe
   - Zentrierte weiße Formularkarte
   - Etwas weicher als Clean Corporate, aber weiterhin professionell und ohne dekorativen Schnickschnack

Die bisherige Split-Variante wird nicht weiter ausgebaut, weil die gewünschte Grundkomposition **zentriert und minimal** ist. Bestehende Tenant-Einstellungen werden sicher auf eine passende neue Variante abgebildet.

## 2. Vorschau und Auswahl

- Die Vorschauseite `/portal-designs` stabilisieren und alle drei Varianten dort vollständig durchschaltbar machen.
- Den Design-Picker im Fast-Track-Landing-Generator auf dieselben drei Designs aktualisieren.
- Tenant-Logo und optionales eigenes Hintergrundbild verwenden; ohne eigenes Bild greift ein professionelles Standard-Bürobild aus dem Projekt.
- Desktop- und Mobilansicht prüfen.
- Anschließend echte Screenshots aller drei Designs zur Abnahme zeigen.

## 3. E-Mail-System vollständig prüfen und vereinheitlichen

- Sämtliche Versandwege inventarisieren und gegen die zentrale Limit-Konfiguration prüfen.
- Verbleibende lokale oder fest codierte Limits entfernen, sofern sie den zentralen 150/Stunde- und 2.400/Tag-Regeln widersprechen.
- Für jeden Versandweg sicherstellen, dass jede Entscheidung zentral protokolliert wird:
  - gesendet
  - fehlgeschlagen
  - übersprungen, inklusive verständlichem Grund
  - erneut gesendet
  - dauerhaft unterdrückt beziehungsweise gebounced
- Einheitliche Felder erzwingen: Tenant, Empfänger, Template-Name, Betreff, gerendertes HTML, Message-ID, Status, Fehler-/Skip-Grund und Zeitstempel.
- Retry- und Resend-Verhalten kontrollieren, damit alte Fehlversuche nicht als offene Warteschlange doppelt gezählt werden.
- Mail-Center-Whitelist und Template-Aliase gegen alle real versendeten Template-Namen abgleichen.
- Kennzahlen so benennen, dass `gesendet` als „vom Mailserver angenommen“ verständlich ist und nicht fälschlich als garantierte Zustellung erscheint.
- Prüfen, ob für späte Bounces ein verlässlicher Rückkanal des eingesetzten Mailservers verfügbar ist; falls nicht, diese technische Grenze im Mail Center klar kennzeichnen statt eine nicht messbare Zustellung vorzutäuschen.

## 4. Praktische Verifikation vor dem Massenversand

- Aktive Cron-Jobs und tatsächliche Intervalle auf dem Backend prüfen.
- Datenbankabgleich der letzten sieben Tage:
  - alle Template-Namen
  - fehlende Log-Einträge
  - Einträge ohne gespeichertes HTML
  - hängen gebliebene Retry-/Pending-Zustände
  - doppelte logische Versandversuche
- Isolierten Dry-Run aller automatischen Flows durchführen.
- Danach die vorhandene 14-Schritt-Testkette mit einer freigegebenen Testadresse ausführen.
- Im Mail Center kontrollieren, dass alle 14 Schritte mit korrektem Tenant, Template, Empfänger und Status sichtbar sind.
- Stundenlimit während des Tests berücksichtigen, damit ein SMTP-Limit nicht mit einem Softwarefehler verwechselt wird.

## 5. Aktualisierung und Deployment

- Erst Frontend und Backend lokal beziehungsweise in der Vorschau prüfen.
- Danach die betroffenen Backend-Funktionen und das Frontend über die vorhandenen Deployment-Abläufe aktualisieren.
- Nach dem Deployment nochmals prüfen:
  - Portal-Designauswahl speichert korrekt
  - alle drei Designs laden auf Login und Registrierung
  - Cron-Jobs laufen
  - Testmail erscheint im Mail Center
  - Retry/Resend funktioniert
  - keine neuen Laufzeit-, Netzwerk- oder Buildfehler

## Abnahme

Die Umsetzung gilt erst als abgeschlossen, wenn:

- alle drei Portal-Designs als Screenshots vorliegen,
- 8 Mails/Lauf nirgends mehr wirksam sind,
- jede der 14 Testmails im Mail Center nachvollziehbar ist,
- Tracking-Lücken und Einträge ohne erneut sendbares HTML aufgeführt oder behoben sind,
- Frontend und Backend aktualisiert wurden und der Nachtest erfolgreich war.