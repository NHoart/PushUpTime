# PushUpTime (iPhone)

iPhone-App, die dich an **Liegestütze** erinnert, bevor du in Ablenkungs-Apps
verschwindest – und die auf Wunsch Apps sperrt, bis du sie gemacht hast.

## Warum nicht einfach Bildschirmzeit?

iOS erlaubt **keiner App**, mitzulesen, welche App du gerade öffnest, und auch
keine Benachrichtigung an das Öffnen einer fremden App zu hängen. Das kann nur
Apples Screen-Time-API – und die verlangt die Berechtigung
`com.apple.developer.family-controls`, die Apple einzeln genehmigen muss.
Kostenlose persönliche Apple-Teams bekommen sie nicht.

Deshalb hat PushUpTime zwei Modi:

| Modus | Wie es funktioniert | Was du brauchst |
| --- | --- | --- |
| **Benachrichtigung über Shortcuts** (Standard) | Eine persönliche Automatisierung in der Shortcuts-App reagiert auf „App ist geöffnet“ und ruft PushUpTime auf – die Liegestütz-Zählung startet sofort. Alternativ nur eine Mitteilung. | nichts weiter |
| **Bildschirmzeit-Sperren** (optional) | Echte Blockade über Family Controls + Managed Settings, Zeitbudget pro App, eigener Sperrbildschirm. | kostenpflichtiges Apple-Developer-Konto + von Apple genehmigte Family-Controls-Berechtigung |

Der Standardweg läuft mit einem kostenlosen Apple-Team, weil der Auslöser in der
Shortcuts-App liegt und PushUpTime nur noch per URL-Schema gestartet wird.

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
  über ihr URL-Schema (z. B. `instagram://`). Ein kurzer Launch-Pass sorgt dafür,
  dass die Automatisierung dabei nicht sofort wieder PushUpTime nach vorn holt.
- **Freiwillig mit Kamera tracken:** „Mit Kamera zählen“ auf dem Startbildschirm
  startet dieselbe Kamera-Zählung wie bei einer Challenge – nur ohne Sperre und
  ohne Ziel. Übung wählen, loslegen, am Ende mit „eintragen“ speichern; die
  gezählten Wiederholungen landen im Verlauf und zählen in Statistik,
  Tages-Summen und Streak.
- **Kleine Statistik:** wie viele Challenges heute erledigt wurden, Streak über
  aufeinanderfolgende Tage und die letzte Einheit (Zeitpunkt, App, Anzahl).
- **Verlauf der letzten acht Einheiten:** Challenges und freie Trainings; zum
  Löschen nach links wischen.
- **Bildschirmzeit-Sperren (optional):** Auswahl über den System-`FamilyActivityPicker`,
  eigenes Zeitbudget pro Sperre (Standard 10 Minuten), Sperrbildschirm aus der
  Shield-Erweiterung, mehrere Sperren parallel.

## Bauen

```bash
open PushUpTime.xcodeproj
```

Zielgerät wählen, Team in den Signing-Einstellungen prüfen, starten.
Kommandozeile (Simulator, ohne Signatur):

```bash
xcodebuild -project PushUpTime.xcodeproj -scheme PushUpTime \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Auf dem Simulator gibt es keine Kamera-Zählung und kein Screen Time – zum
Ausprobieren der Challenge brauchst du ein echtes iPhone.

## Bildschirmzeit-Modus aktivieren

1. Antrag stellen: <https://developer.apple.com/contact/request/family-controls-distribution>
2. Nach der Genehmigung im Developer-Portal die Capability **Family Controls** für
   App-ID `com.noahh.pushuptime.9c31f7` sowie die beiden Erweiterungen aktivieren.
3. App-Gruppe `group.com.noahh.pushuptime.9c31f7` für alle drei Targets anlegen.

Die Bundle-IDs kannst du jederzeit in Xcode unter *Signing & Capabilities* ändern,
falls eine davon schon vergeben ist – die Erweiterungen müssen dabei immer mit der
App-ID beginnen (`<app-id>.monitor`, `<app-id>.shield`).

| Konfiguration | Entitlements | Signierbar mit | Kann Apps sperren |
| --- | --- | --- | --- |
| **Debug** | `*.Debug.entitlements` (leer) | persönlichem Team | nein |
| **Release** | `*.entitlements` (Family Controls + App Group) | bezahltem Team | ja (nach Apple-Freigabe) |

## Projektstruktur

| Pfad | Inhalt |
| --- | --- |
| `PushUpTime/` | App: SwiftUI-Oberfläche, Zustand, Kamera-Zählung, Shortcut-Anleitung |
| `PushUpTimeMonitor/` | DeviceActivity-Monitor: sperrt bei erreichtem Zeitbudget |
| `PushUpTimeShield/` | Shield-Konfiguration: Aussehen des Sperrbildschirms |
| `Shared/PushUpShared.swift` | Modell, App-Group-Speicher, Shield- und Zeitplan-Logik |

## Grenzen & Notaus

- Die Sperre ist Selbstkontrolle: iOS erlaubt es nicht, sie unumgehbar zu machen.
- Notaus in der Challenge: „Notaus“ 3 Sekunden halten entsperrt die App.
- „Überspringen“ auf dem Challenge-Screen schließt sie ohne Zählung; dieselbe App
  löst danach keine Challenge mehr aus – wie lange, steht in den Einstellungen
  unter „Überspringen“ (Standard 10 Minuten, 0 = keine Freigabe).
- Der automatische Rücksprung braucht die Aktion **„Liegestütze starten“**
  (App Intent, iOS 26+) und einen Rücksprung-Link pro App. Mit dem alten
  „URL öffnen“ bleibt es beim App-Umschalter: Jedes Öffnen per URL ist ein neues
  „App ist geöffnet“ und holt PushUpTime sofort wieder nach vorn.
- Alternativ die Sperre in iOS-Einstellungen → Bildschirmzeit deaktivieren bzw.
  PushUpTime den Bildschirmzeit-Zugriff entziehen.
- Kamera-Zählung braucht seitliches Ablegen des iPhones, sodass Schulter, Ellbogen
  und Handgelenk sichtbar sind.
