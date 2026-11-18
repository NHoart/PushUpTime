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

## Wie die Kamera-Zählung funktioniert

Die App zählt nicht per Bewegungssensor, sondern wertet das Kamerabild aus.

- **Pose-Erkennung:** Jedes zweite Frame der Frontkamera (1280×720) läuft durch
  Apples Vision-Framework (`VNDetectHumanBodyPoseRequest`). Es liefert die
  Positionen von Schultern, Ellbogen, Handgelenken und Hüften als normalisierte
  Punkte samt Confidence; ab 0,2 gilt ein Punkt als erkannt. Da das iPhone beim
  Training oft seitlich liegt, probiert die App alle vier Bild-Orientierungen
  durch und merkt sich die beste. Geht die Pose verloren, sucht sie nach zehn
  Frames neu.
- **Liegestütze:** Gemessen wird der Ellbogen-Winkel zwischen Schulter, Ellbogen
  und Handgelenk, zeitgeglättet über rund 70 ms. „Unten“ ist bei ≤ 105° erreicht
  und muss 0,12 s lang bestätigt sein, „oben“ bei ≥ 148°. Gezählt wird beim
  Übergang von unten nach oben, höchstens eine Wiederholung alle 0,35 s.
- **Russian Twists:** Der Mittelpunkt beider Handgelenke wird relativ zur
  Beckenmitte (ersatzweise Körperwurzel) gemessen und durch die Schulterbreite
  geteilt. Ab einem Ausschlag von 0,18 Schulterbreiten zählt ein Twist; zurück
  in die Mitte (unter 0,108) lädt den nächsten. Die Hände müssen dabei über dem
  Becken liegen.
- **Grenzen:** Verdeckte Gelenke kann Vision nicht schätzen – bei Liegestützen
  müssen Schulter, Ellbogen und Handgelenk sichtbar sein, bei Twists Hände und
  Becken. Aussetzer bis 0,8 s werden überbrückt, danach startet die Erkennung
  neu. Das Modell arbeitet in 2D ohne Tiefe: Ein stark schräger Kamerawinkel
  verzerrt den projizierten Ellbogen-Winkel. Am zuverlässigsten ist das seitlich
  abgelegte iPhone. Im Simulator gibt es keine Kamera.
- **Debug-Overlay:** In der laufenden Kamera blendet der Schalter „Gelenke“
  oben rechts die erkannten Punkte und Verbindungslinien ein – hilfreich, um zu
  sehen, warum eine Wiederholung nicht zählt.

## Auf dem iPhone installieren

PushUpTime gibt es nicht im App Store – du baust die App mit Xcode direkt auf
dein iPhone. Dafür reicht ein kostenloser Apple-Account (Grenzen unter
[Kostenloses Apple-Team](#kostenloses-apple-team)). TestFlight oder eine
Ad-hoc-Verteilung würden dagegen das bezahlte Developer Program brauchen.

### Was du brauchst

- Einen Mac mit **Xcode 26 oder neuer** (kostenlos im Mac App Store, rund 10 GB).
  Ältere Xcodes kennen die Aktion „Liegestütze starten“ nicht – die ist ein App
  Intent aus iOS 26.
- Ein **iPhone ab iOS 17**. Automatischer Rücksprung in die Ziel-App und die
  Shortcut-Aktion „Liegestütze starten“ brauchen iOS 26; unter iOS 17–25 läuft
  die App, die Automatisierung zeigt dort aber nur eine Mitteilung.
- Deine **Apple-ID**, dieselbe in Xcode und auf dem iPhone.
- Ein **Kabel** (Lightning oder USB-C) für die erste Installation.

### 1. Xcode einrichten

1. Xcode aus dem Mac App Store installieren und einmal öffnen. Lizenz
   bestätigen und die Zusatzkomponenten installieren lassen.
2. **Xcode → Settings… (⌘,)** öffnen, Tab **Accounts**, auf **+** tippen und
   **Apple ID** wählen. Nach dem Anmelden steht dein Team als
   „*Dein Name* (Personal Team)“ in der Liste.
3. Im selben Tab das Team auswählen → **Manage Certificates…** → **+** →
   **iOS Development**. Meistens legt Xcode das Zertifikat beim ersten Build
   selbst an; der Schritt hilft, wenn später „No signing certificate“ kommt.

### 2. iPhone vorbereiten

1. iPhone entsperren, per Kabel an den Mac anschließen und auf dem iPhone
   „Diesem Computer vertrauen?“ mit **Vertrauen** bestätigen, dann den Code
   eingeben.
2. **Entwicklermodus einschalten:** Einstellungen → Datenschutz & Sicherheit →
   Entwicklermodus → einschalten → iPhone neu starten → nach dem Neustart
   **Einschalten** antippen und den Code eingeben.
   Der Punkt erscheint erst, nachdem das iPhone einmal mit Xcode verbunden war.
   Fehlt er, erst Schritt 3 machen, das iPhone in Xcode einmal auswählen und
   dann noch mal nachsehen.
3. In Xcode oben in der Toolbar als Zielgerät dein iPhone auswählen (statt eines
   Simulators). Fehlt es, **Window → Devices and Simulators (⇧⌘2)** öffnen und
   links das iPhone anklicken. Beim ersten Mal lädt Xcode Geräteunterstützung
   nach, das dauert ein paar Minuten.
4. Optional: dort beim iPhone **Connect via network** anhaken – danach baut und
   installiert Xcode auch über WLAN.

### 3. Projekt öffnen und signieren

```bash
open PushUpTime.xcodeproj
```

1. Links im Navigator das Projekt **PushUpTime** anklicken, unter **Targets**
   das Target **PushUpTime** wählen und den Tab **Signing & Capabilities**
   öffnen.
2. **Automatically manage signing** anhaken.
3. Bei **Team** dein persönliches Team auswählen.
4. Die **Bundle Identifier** lautet `com.noahh.pushuptime.9c31f7` und ist schon
   eindeutig. Meldet Xcode „Failed to register bundle identifier“, trage etwas
   Eigenes ein, z. B. `com.deinname.pushuptime`. Der Rücksprung-Link
   `pushuptime://` bleibt davon unberührt.

### 4. Installieren und starten

1. **⌘R** drücken (oder Product → Run). Der erste Build dauert ein paar Minuten;
   Xcode registriert dabei dein iPhone und legt das Provisioning-Profil an.
2. Beim ersten Start fragt iOS nach dem Kamerazugriff – **Erlauben**.
3. Meldet das iPhone „Nicht vertrauenswürdiger Entwickler“ oder schließt sich
   die App sofort, dann: Einstellungen → Allgemein → VPN & Geräteverwaltung →
   unter **Entwickler-App** deine Apple-ID antippen → **„… vertrauen“** →
   **Vertrauen**. Danach startet die App normal.
4. Xcode darf danach zu – die App bleibt auf dem iPhone. Für einen neuen Build
   das iPhone wieder anschließen (oder im WLAN lassen) und erneut ⌘R. Die
   gespeicherten Einheiten bleiben erhalten, solange die Bundle-ID gleich
   bleibt.

### 5. Shortcuts-Automatisierung einrichten

Jetzt fehlt nur noch der Auslöser: [Benachrichtigungs-Modus
einrichten](#benachrichtigungs-modus-einrichten) – pro App ein Eintrag in
PushUpTime und die passende Automatisierung in Shortcuts.

### Nach sieben Tagen erneuern

Mit dem kostenlosen Team läuft das Provisioning-Profil nach **7 Tagen** ab.
Danach bleibt das Icon liegen, die App startet aber nicht mehr. iPhone
anschließen, Projekt öffnen, ⌘R – die Daten bleiben. Wer nicht jede Woche
neu installieren will, braucht das bezahlte Apple Developer Program (99 $ im
Jahr); damit gilt das Profil ein Jahr.

### Kommandozeile (optional)

Wer lieber im Terminal baut:

```bash
# 1. iPhone-UDID anzeigen (iPhone verbunden und entsperrt)
xcrun devicectl list devices

# 2. Für das Gerät bauen
xcodebuild -project PushUpTime.xcodeproj -scheme PushUpTime \
  -configuration Debug -destination 'generic/platform=iOS' \
  -derivedDataPath build -allowProvisioningUpdates build

# 3. Installieren
xcrun devicectl device install app --device <UDID> \
  build/Build/Products/Debug-iphoneos/PushUpTime.app
```

`-allowProvisioningUpdates` erlaubt xcodebuild, das Profil über deinen in Xcode
angemeldeten Account zu erneuern. Der Ordner `build/` steht schon in
`.gitignore`.

### Simulator

Zum Ansehen der Oberfläche ohne iPhone in Xcode ein Simulator-Ziel wählen und
⌘R drücken. Alternativ ohne Signatur:

```bash
xcodebuild -project PushUpTime.xcodeproj -target PushUpTime \
  -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

Auf dem Simulator gibt es keine Kamera-Zählung – zum Ausprobieren brauchst du
ein echtes iPhone.

### Wenn etwas klemmt

| Meldung / Symptom | Lösung |
| --- | --- |
| `No signing certificate "iOS Development" found` | Xcode → Settings… → Accounts → Team auswählen → **Manage Certificates…** → **+** → **iOS Development**, danach noch mal ⌘R. |
| `Failed to register bundle identifier` | Die Bundle-ID ist schon vergeben. Unter *Signing & Capabilities* auf etwas Eigenes ändern, z. B. `com.deinname.pushuptime`. |
| `Unable to install "PushUpTime"` oder `application-identifier entitlement … does not match` | Auf dem iPhone liegt noch eine Installation mit anderem Team oder anderer Bundle-ID. App löschen und neu installieren. |
| iPhone erscheint nicht als Zielgerät | Entsperren, anderes Kabel bzw. anderen USB-Port probieren, Entwicklermodus prüfen und in *Devices and Simulators* nachsehen. Bei „Preparing device“ einfach warten. |
| `Device is locked` / `Developer Mode disabled` | iPhone entsperren bzw. Entwicklermodus einschalten (Schritt 2). |
| App startet nicht mehr, Icon bleibt | Profil nach 7 Tagen abgelaufen → ⌘R. Oder die Entwickler-App ist nicht vertrauenswürdig → VPN & Geräteverwaltung. |
| `The maximum number of apps for free development profiles has been reached` | Das kostenlose Team erlaubt nur 3 selbst installierte Apps gleichzeitig – eine andere löschen. |
| „Liegestütze starten“ fehlt in Shortcuts | Die Aktion gibt es erst ab iOS 26. Alternativ **„URL öffnen“** mit `pushuptime://challenge?app=…` verwenden (dann ohne automatischen Rücksprung). |
| Kamera bleibt schwarz | Im Simulator gibt es keine Kamera. Auf dem iPhone den Kamerazugriff unter Einstellungen → PushUpTime prüfen und das Gerät seitlich ablegen, sodass Schulter, Ellbogen und Handgelenk sichtbar sind. |

## Kostenloses Apple-Team

- Das Provisioning-Profil läuft nach 7 Tagen ab; die App danach über Xcode neu
  installieren (siehe [Nach sieben Tagen erneuern](#nach-sieben-tagen-erneuern)).
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
