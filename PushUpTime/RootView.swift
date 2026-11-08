import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    @State private var showAddRule = false
    @State private var newRuleName = ""
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            List {
                introSection
                appsSection
                challengeSection
                advancedSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("PushUpTime")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Einstellungen")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        newRuleName = ""
                        showAddRule = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("App hinzufügen")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(model)
            }
            .fullScreenCover(item: $model.challenge) { request in
                ChallengeView(request: request)
                    .environmentObject(model)
            }
            .alert(
                "Hinweis",
                isPresented: Binding(
                    get: { model.errorMessage != nil },
                    set: { if !$0 { model.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { model.errorMessage = nil }
            } message: {
                Text(model.errorMessage ?? "")
            }
        }
        .alert("App hinzufügen", isPresented: $showAddRule) {
            TextField("z. B. Instagram", text: $newRuleName)
                .textInputAutocapitalization(.words)
            Button("Hinzufügen") {
                model.addShortcutRule(appName: newRuleName)
                newRuleName = ""
            }
            Button("Abbrechen", role: .cancel) { newRuleName = "" }
        } message: {
            Text("Danach legst du in der Shortcuts-App eine Automatisierung für genau diese App an. Die Schritte und den passenden Link bekommst du direkt daneben.")
        }
    }

    // MARK: - Sections

    private var introSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("So funktioniert PushUpTime", systemImage: "bell.badge")
                    .font(.headline)

                Text("Keine App darf mitlesen, welche App du öffnest – das kann nur eine Automatisierung in der Shortcuts-App. Sie meldet sich, sobald du eine deiner Apps öffnest, und schickt dich zu den Liegestützen.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private var appsSection: some View {
        Section {
            if model.shortcutRules.isEmpty {
                Button {
                    newRuleName = ""
                    showAddRule = true
                } label: {
                    Label("Erste App hinzufügen", systemImage: "plus.circle.fill")
                }
            } else {
                ForEach(model.shortcutRules) { rule in
                    NavigationLink {
                        ShortcutGuideView(rule: rule)
                            .environmentObject(model)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "hand.tap")
                                .foregroundStyle(.orange)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(rule.appName)
                                    .font(.headline)
                                Text("Automatisierung einrichten")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        model.deleteShortcutRule(model.shortcutRules[index])
                    }
                }
            }
        } header: {
            Text("Apps mit Benachrichtigung")
        } footer: {
            Text("iOS lässt sich das Öffnen einer App nur von Shortcuts melden. Für jede App hier steht eine Anleitung bereit – mit dem Link, der direkt die Liegestütz-Zählung startet.")
        }
    }

    private var challengeSection: some View {
        Section("Challenge") {
            HStack {
                Label("Liegestütze", systemImage: "figure.strengthtraining.traditional")
                Spacer()
                Text("\(model.requiredReps)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Button {
                model.startTestChallenge()
            } label: {
                Label("Liegestütz-Zählung testen", systemImage: "camera.viewfinder")
            }
        }
    }

    private var advancedSection: some View {
        Section {
            NavigationLink {
                ScreenTimeView()
                    .environmentObject(model)
            } label: {
                Label("Bildschirmzeit-Sperren", systemImage: "lock.shield")
            }

            Text("Echtes Blockieren von Apps geht nur über Apples Screen-Time-API und braucht die von Apple genehmigte Family-Controls-Berechtigung (kostenpflichtiges Developer-Konto). Ohne diese Freigabe funktioniert der Benachrichtigungs-Modus oben.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Notaus: Wenn die App gerade gesperrt ist, hältst du in der Challenge „Notaus“ 3 Sekunden.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Optional")
        }
    }
}
