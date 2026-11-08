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
2. Den Eintrag antippen – dort stehen die Schritte und der fertige Link.
3. In der Shortcuts-App: **Automatisierung → + → App → „Instagram“ → „Ist geöffnet“ → „Sofort ausführen“**.
4. Aktion **„URL öffnen“** mit `pushuptime://challenge?app=Instagram` hinzufügen.
   Damit springt PushUpTime auf und startet direkt die Zählung.
   Wer in der App bleiben will, nimmt stattdessen **„Mitteilung anzeigen“** mit
   dem Text „30 Liegestütze 💪“.

Unterstützte Links:

- `pushuptime://challenge` – Challenge ohne App-Namen
- `pushuptime://challenge?app=Instagram` – Challenge mit App-Namen im Kopf

Grenzen des Modus: Die Automatisierung feuert beim Wechsel in die App, nicht bei
jedem Aufwecken des iPhones und nicht in App-Clips oder In-App-Browsern. Gesperrt
wird nichts – die Disziplin bleibt bei dir.

## Funktionen

- **Liegestütze zählen per Kamera:** Vision-Body-Pose erkennt echte
  Wiederholungen (Ellbogen unten ≤ 105°, danach gestreckt ≥ 148°).
- **Shortcut-Anleitung pro App:** Name, URL und Mitteilungstext zum Kopieren,
  inklusive „Jetzt testen“.
- **Kleine Statistik:** wie viele Challenges heute erledigt wurden, Streak über
  aufeinanderfolgende Tage und die letzte Einheit (Zeitpunkt, App, Anzahl).
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
- Alternativ die Sperre in iOS-Einstellungen → Bildschirmzeit deaktivieren bzw.
  PushUpTime den Bildschirmzeit-Zugriff entziehen.
- Kamera-Zählung braucht seitliches Ablegen des iPhones, sodass Schulter, Ellbogen
  und Handgelenk sichtbar sind.
