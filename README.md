# PushUpTime (iPhone)

iPhone-App, die dich an **Liegestütze** erinnert, bevor du in Ablenkungs-Apps
verschwindest. Der Auslöser liegt in der Shortcuts-App, gezählt wird per Kamera.
PushUpTime selbst sperrt keine Apps – du entscheidest nach der Challenge, ob du
weitermachst.

Das funktioniert mit einem **kostenlosen Apple-Account** (persönliches Team).

## Warum Shortcuts?

iOS erlaubt keiner App mitzulesen, welche App du gerade öffnest. Das kann nur
eine persönliche Automatisierung in der Shortcuts-App: Sie reagiert auf
„App ist geöffnet“ und ruft PushUpTime auf – die Zählung startet sofort.
Alternativ zeigt sie nur eine Mitteilung.

## Benachrichtigungs-Modus einrichten

1. In PushUpTime oben rechts auf „+“ tippen und die App eintragen (z. B. Instagram).
2. Den Eintrag antippen – dort stehen die Schritte, der Rücksprung-Link und die passende Aktion.
3. In der Shortcuts-App: **Automatisierung → + → App → „Instagram“ → „Ist geöffnet“ → „Sofort ausführen“**.
4. Als Aktion **PushUpTime → „Liegestütze starten“** wählen und bei „App“ den
   Eintrag aus PushUpTime auswählen. PushUpTime springt mit der Zählung auf und
   schickt dich nach den Liegestützen automatisch zurück in die App (iOS 26+).
   Wer in der App bleiben will, nimmt stattdessen **„Mitteilung anzeigen“** mit
   dem Text „30 Liegestütze 💪“.

Unterstützte Links:

- `pushuptime://challenge` – Challenge ohne App-Namen
- `pushuptime://challenge?app=Instagram` – Challenge mit App-Namen im Kopf

Grenzen des Modus: Die Automatisierung feuert beim Wechsel in die App, nicht bei
jedem Aufwecken des iPhones und nicht in App-Clips oder In-App-Browsern. Gesperrt
wird nichts – die Disziplin bleibt bei dir.

## Funktionen

- **Übung wählen:** Liegestütze (Standard 30) oder Russian Twists (Standard
  220). Die Auswahl ist der Standard; wird die App aus einer App wie Instagram
  heraus geöffnet, fragt die Challenge zuerst „Was machst du?“ und du
  entscheidest dich in dem Moment. Die Anzahl lässt sich pro Übung einstellen.
- **Bildschirm bleibt an:** Solange die Challenge offen ist, sperrt iOS den
  Bildschirm nicht automatisch – beim Verlassen des Screens gilt wieder die
  normale Auto-Sperre.
- **Wiederholungen zählen per Kamera:** Vision-Body-Pose erkennt echte
  Liegestütze (Ellbogen unten ≤ 105°, danach gestreckt ≥ 148°) und zählt bei
  Russian Twists jeden Twist zur Seite, sobald die Hände seitlich am Becken
  vorbeigehen.
- **Shortcut-Anleitung pro App:** Name, Aktion, Rücksprung-Link und
  Mitteilungstext, inklusive Test.
- **Rücksprung in die Ziel-App:** Nach den Liegestützen öffnet PushUpTime die App
  über ihr URL-Schema (z. B. `instagram://`). Bei YouTube geht es direkt in
  „Später ansehen“ (`youtube://www.youtube.com/playlist?list=WL`) statt auf die
  Startseite. Ein kurzer Launch-Pass sorgt dafür,
  dass die Automatisierung dabei nicht sofort wieder PushUpTime nach vorn holt.
- **Freiwillig mit Kamera tracken:** „Mit Kamera zählen“ auf dem Startbildschirm
  startet dieselbe Kamera-Zählung wie bei einer Challenge – nur ohne Ziel.
  Übung wählen, loslegen, am Ende auf „Fertig“ drücken; die gezählten
  Wiederholungen landen im Verlauf und zählen in Statistik, Tages-Summen und
  Streak.
- **Kleine Statistik:** wie viele Challenges heute erledigt wurden, Streak über
  aufeinanderfolgende Tage und die letzte Einheit (Zeitpunkt, App, Anzahl).
- **Verlauf-Tab mit Monatsdiagramm:** Balkendiagramm der letzten 30 Tage,
  umschaltbar zwischen Liegestützen und Russian Twists. Darunter Summe der 30
  Tage, aktive Tage und bester Tag sowie alle Einheiten (Challenges und freie
  Trainings); zum Löschen nach links wischen.
- **Ziel pro Challenge:** Bei einem App-Aufruf stellst du vor dem Start dein
  eigenes Ziel ein – ausgehend von deinem Standard (30 Liegestütze bzw. 220
  Russian Twists), nach unten und oben verstellbar. Das Ziel ist nur eine Marke:
  Du kannst früher auf „Fertig“ drücken oder darüber hinaus weitermachen.
  Eingetragen wird, was die Kamera bis zum „Fertig“-Druck gezählt hat.
- **Pause nach der Challenge:** Nach einer App-Challenge bleibt dieselbe App so
  lange ohne neue Challenge, wie die gezählten Wiederholungen hergeben. Wie viele
  Wiederholungen eine Minute bringen, steht in den Einstellungen unter „Pause
  nach der Challenge“ – standardmäßig 2 Wiederholungen pro Minute, also 15
  Minuten für 30 Liegestütze.
- **Überspringen:** Schließt die Challenge ohne Zählung. Dieselbe App löst danach
  für die eingestellte Zeit keine neue Challenge aus (Standard 10 Minuten,
  0 = sofort wieder).

## Bauen

```bash
open PushUpTime.xcodeproj
```

Zielgerät wählen, unter *Signing & Capabilities* dein persönliches Team
auswählen, starten.

Kommandozeile (Simulator, ohne Signatur):

```bash
xcodebuild -project PushUpTime.xcodeproj -target PushUpTime \
  -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

Auf dem Simulator gibt es keine Kamera-Zählung – zum Ausprobieren brauchst du
ein echtes iPhone.

## Kostenloses Apple-Team

- Das Provisioning-Profil läuft nach 7 Tagen ab; die App danach über Xcode neu
  installieren.
- Maximal 3 Apps gleichzeitig bzw. 10 App-IDs pro Woche.
- PushUpTime braucht nur die Kamera und die Shortcuts-Automatisierung.

## Projektstruktur

| Pfad | Inhalt |
| --- | --- |
| `PushUpTime/` | App: SwiftUI-Oberfläche, Zustand, Kamera-Zählung, Shortcut-Anleitung |
| `Shared/PushUpShared.swift` | Modell, Speicher, Übungsauswahl, Übergabe an Shortcuts |

## Grenzen

- Die App blockiert nichts: Selbstkontrolle.
- Der automatische Rücksprung braucht die Aktion **„Liegestütze starten“**
  (App Intent, iOS 26+) und einen Rücksprung-Link pro App. Mit dem alten
  „URL öffnen“ bleibt es beim App-Umschalter: Jedes Öffnen per URL ist ein neues
  „App ist geöffnet“ und holt PushUpTime sofort wieder nach vorn.
- Kamera-Zählung braucht seitliches Ablegen des iPhones, sodass Schulter, Ellbogen
  und Handgelenk sichtbar sind.

## Lizenz

PushUpTime ist **kein Open-Source-Projekt**. Der Quellcode ist öffentlich einsehbar, die Rechte bleiben aber beim Autor: alle Rechte vorbehalten.

- **Erlaubt** ist: den Code auf GitHub ansehen und dort forken, Änderungen als Pull Request vorschlagen, die App unentgeltlich nutzen.
- **Nicht erlaubt** ist: den Code oder Teile davon kopieren, verändern und weitergeben, in eigene Apps oder Produkte einbauen oder eigene Fassungen der App veröffentlichen.

Der vollständige Text steht in [`LICENSE`](LICENSE).
