import SwiftUI
import UIKit

/// Schritt-für-Schritt-Anleitung für die Automatisierung, die iOS erlaubt:
/// Shortcuts → Automatisierung → „App ist geöffnet“.
struct ShortcutGuideView: View {
    @EnvironmentObject private var model: AppModel

    let rule: ShortcutRule

    @State private var copiedURL = false
    @State private var copiedText = false
    @State private var returnLink: String
    @State private var savedLink: String
    @State private var linkFeedback: String?

    init(rule: ShortcutRule) {
        self.rule = rule
        let link = rule.returnURLString ?? rule.returnURL?.absoluteString ?? ""
        _returnLink = State(initialValue: link)
        _savedLink = State(initialValue: link)
    }

    private var notificationText: String {
        let reps = max(1, model.requiredReps)
        return "\(reps) \(model.exercise.unit(for: reps)) 💪"
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
                Label("PushUpTime: „Liegestütze starten“", systemImage: "arrow.up.forward.app")
                    .font(.headline)

                Text("In der Automatisierung nach „PushUpTime“ suchen und die Aktion **„Liegestütze starten“** hinzufügen. Bei „App“ wählst du „\(rule.appName)“ aus.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text("Die Aktion läuft zuerst im Hintergrund: Ist die Challenge gerade erledigt, bleibt sie still und du landest direkt in \(rule.appName). Sonst springt PushUpTime mit der Zählung auf.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text("Diese Aktion braucht iOS 26 oder neuer.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } header: {
                Text("Aktion wählen (empfohlen)")
            }

            returnSection

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
                    model.startTestChallenge()
                } label: {
                    Label("Zählung testen", systemImage: "play.circle")
                }

                Text("Der alte Weg über „URL öffnen“ startet die Zählung weiterhin, holt PushUpTime aber bei jedem Öffnen wieder nach vorn. Ein Rücksprung in die App ist damit nicht möglich.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Älterer Weg")
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

    private var returnSection: some View {
        Section {
            TextField("z. B. instagram://", text: $returnLink)
                .font(.system(.footnote, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .submitLabel(.done)
                .onSubmit(saveLink)

            HStack {
                Button("Speichern", action: saveLink)
                    .disabled(returnLink == savedLink)

                Spacer()

                Button("Testen") { openReturnLink() }
                    .disabled(returnLink.isEmpty)
            }

            if let linkFeedback {
                Text(linkFeedback)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Rücksprung in die App")
        } footer: {
            Text("Der Link, mit dem PushUpTime nach den Liegestützen zurück zu \(rule.appName) springt – z. B. instagram://, youtube:// oder tiktok://. Viele Apps haben ein eigenes Schema; ohne passenden Link bleibt es beim App-Umschalter.")
        }
    }

    private func saveLink() {
        savedLink = returnLink
        model.setReturnURL(returnLink, for: rule)
        if returnLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            linkFeedback = "Gespeichert – es bleibt beim App-Umschalter."
        } else if ShortcutRule.normalizedURL(returnLink) == nil {
            linkFeedback = "Kein gültiger Link – bitte z. B. instagram:// eintragen."
        } else {
            linkFeedback = "Gespeichert."
        }
    }

    private func openReturnLink() {
        guard let url = ShortcutRule.normalizedURL(returnLink) else {
            linkFeedback = "Kein gültiger Link."
            return
        }
        UIApplication.shared.open(url, options: [:]) { success in
            Task { @MainActor in
                linkFeedback = success ? nil : "Diese App hat den Link nicht geöffnet."
            }
        }
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
