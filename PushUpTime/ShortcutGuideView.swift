import SwiftUI
import UIKit

/// Schritt-für-Schritt-Anleitung für die Automatisierung, die iOS erlaubt:
/// Shortcuts → Automatisierung → „App ist geöffnet“.
struct ShortcutGuideView: View {
    @EnvironmentObject private var model: AppModel

    let rule: ShortcutRule

    @State private var copiedURL = false
    @State private var copiedText = false

    private var notificationText: String {
        "\(max(1, model.requiredReps)) Liegestütze 💪"
    }

    var body: some View {
        Form {
            Section {
                Text("Der Auslöser liegt bei der Shortcuts-App, die Challenge bei PushUpTime. Beides wird hier einmal verbunden – danach läuft es ohne dich.")
                    .font(.callout)
            }

            Section {
                step(1, "Shortcuts-App öffnen und unten auf „Automatisierung“ tippen.")
                step(2, "Oben rechts auf „+“ tippen und „App“ als Auslöser wählen.")
                step(3, "„\(rule.appName)“ auswählen und „Ist geöffnet“ aktivieren.")
                step(4, "„Sofort ausführen“ wählen, damit es ohne Bestätigung läuft.")
                step(5, "„Neue leere Automatisierung“ antippen und die Aktion aus dem nächsten Abschnitt hinzufügen.")
            } header: {
                Text("Automatisierung anlegen")
            } footer: {
                Text("Die Automatisierung gilt nur auf diesem iPhone.")
            }

            Section {
                Label("PushUpTime öffnen (empfohlen)", systemImage: "arrow.up.forward.app")
                    .font(.headline)

                Text("Aktion „URL öffnen“ hinzufügen und diese Adresse einsetzen. PushUpTime springt auf und startet sofort die Zählung.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Text(rule.challengeURLString)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: 0)

                    Button(copiedURL ? "Kopiert" : "Kopieren") {
                        UIPasteboard.general.string = rule.challengeURLString
                        copiedURL = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Button {
                    if let url = rule.challengeURL {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Jetzt testen", systemImage: "play.circle")
                }
            } header: {
                Text("Aktion wählen")
            }

            Section {
                Label("Nur Benachrichtigung", systemImage: "bell")
                    .font(.headline)

                Text("Wenn du in \(rule.appName) bleiben willst, nimm stattdessen „Mitteilung anzeigen“ und setze diesen Text ein. Die Mitteilung erscheint als Banner über der App.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Text(notificationText)
                    Spacer(minLength: 0)
                    Button(copiedText ? "Kopiert" : "Kopieren") {
                        UIPasteboard.general.string = notificationText
                        copiedText = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } header: {
                Text("Alternative")
            }

            Section {
                Text("Die Automatisierung läuft beim Wechsel in die App – nicht bei jedem Aufwecken des iPhones und nicht in App-Clips oder In-App-Browsern.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text("In diesem Modus wird nichts gesperrt: Du entscheidest selbst, ob du die Liegestütze machst. Für harte Blockaden gibt es die Bildschirmzeit-Sperren.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Gut zu wissen")
            }
        }
        .navigationTitle(rule.appName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.accentColor))

            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }
}
