import AuthenticationServices
import SwiftUI

extension EnvironmentValues {
    /// Das eine Konto der Claude-Verbindung; nil, solange der Schalter aus ist (Store-Version).
    @Entry var claudeAccount: AccountState? = nil
}

/// Seite „Claude-Verbindung“ (#57 Schnitt 5a): Anmelden mit Apple, letzter Abgleich, Abmelden, Verbindung trennen.
/// Zeigt nie Token, Nonce oder Körper.
struct ClaudeSettingsView: View {
    let account: AccountState
    @State private var lastSync: Date?
    @State private var confirmDisconnect = false

    var body: some View {
        Form {
            if Self.isSignedIn(account.status) { signedIn } else { signedOut }
        }
        .navigationTitle(NSLocalizedString("Claude", comment: "Claude settings title"))
        .onAppear(perform: readLastSync)
        .onChange(of: account.status) { readLastSync() }
        .confirmationDialog(NSLocalizedString("Disconnect?", comment: "Claude disconnect question"),
                            isPresented: $confirmDisconnect, titleVisibility: .visible) {
            Button(NSLocalizedString("Disconnect", comment: "Claude disconnect confirm"), role: .destructive) {
                Task { await account.deleteAccount() }
            }
            .accessibilityIdentifier("claudeSettings.disconnectConfirm")
            Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {}
                .accessibilityIdentifier("claudeSettings.disconnectCancel")
        } message: {
            Text(NSLocalizedString("Claude will no longer see anything from this app. What Claude has already delivered stays on this iPhone.",
                                   comment: "Claude disconnect explanation"))
        }
    }

    private var signedOut: some View {
        Section {
            Text(NSLocalizedString("Sign in with Apple and Claude can deliver exercises and programs to you. Without signing in, nothing leaves this iPhone.",
                                   comment: "Claude sign-in explanation"))
            signInButton.disabled(Self.isBusy(account.status))
            if account.status == .signingIn { progress(NSLocalizedString("Signing in …", comment: "Claude sign-in progress")) }
            hintRow
        }
    }

    @ViewBuilder private var signedIn: some View {
        Section {
            row(NSLocalizedString("Signed in with Apple", comment: ""), NSLocalizedString("This iPhone", comment: ""))
                .accessibilityIdentifier("claudeSettings.status")
            row(NSLocalizedString("Last sync", comment: "Claude last sync"), Self.lastSyncText(lastSync))
                .accessibilityIdentifier("claudeSettings.lastSync")
        }
        Section {
            Button(NSLocalizedString("Sign out", comment: "Claude sign out")) { Task { await account.signOut() } }
                .accessibilityIdentifier("claudeSettings.signOut")
            Button(NSLocalizedString("Disconnect …", comment: "Claude disconnect"), role: .destructive) {
                confirmDisconnect = true
            }
            .accessibilityIdentifier("claudeSettings.disconnect")
            if account.status == .deleting { progress(NSLocalizedString("Disconnecting …", comment: "Claude disconnect progress")) }
            hintRow
        }
        .disabled(Self.isBusy(account.status))
    }

    @ViewBuilder private var signInButton: some View {
        if ClaudeWiring.usesStandIn(arguments: CommandLine.arguments) {
            Button { Task { await signInWithStandIn() } } label: { Text(verbatim: "Mit Apple anmelden (Test)") }
                .accessibilityIdentifier("claudeSettings.signInStandIn")
        } else {
            SignInWithAppleButton(.signIn, onRequest: prepare, onCompletion: finish)
                .frame(height: 44)
                .accessibilityIdentifier("claudeSettings.appleButton")
        }
    }

    @ViewBuilder private var hintRow: some View {
        if let text = Self.hint(status: account.status, lastProblem: account.lastProblem) {
            Text(text)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("claudeSettings.hint")
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        LabeledContent(title, value: value).accessibilityElement(children: .combine)
    }

    private func progress(_ text: String) -> some View {
        HStack(spacing: 8) { ProgressView(); Text(text) }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("claudeSettings.progress")
    }

    private func signInWithStandIn() async {
        guard (try? account.beginSignIn()) != nil else { return }
        await account.completeSignIn(identityToken: "uitest-token", code: "uitest-code")
    }

    private func prepare(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = []
        request.nonce = try? account.beginSignIn()
    }

    /// Erfolg: Token und Code als Text an den Dienst; jeder Fehler, auch der Abbruch, still zurück.
    private func finish(_ result: Result<ASAuthorization, any Error>) {
        guard case .success(let authorization) = result,
              let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let token = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }),
              let code = credential.authorizationCode.flatMap({ String(data: $0, encoding: .utf8) }) else {
            account.cancelSignIn()
            return
        }
        Task { await account.completeSignIn(identityToken: token, code: code) }
    }

    private func readLastSync() {
        lastSync = UserDefaults.standard.object(forKey: ClaudeSync.lastSnapshotKey) as? Date
    }

    static func isSignedIn(_ status: AccountState.Status) -> Bool { status == .signedIn || status == .deleting }

    static func isBusy(_ status: AccountState.Status) -> Bool { status == .signingIn || status == .deleting }

    static func lastSyncText(_ date: Date?) -> String {
        guard let date else { return NSLocalizedString("Not yet", comment: "Claude last sync never") }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    static func hint(status: AccountState.Status, lastProblem: AccountState.Problem?) -> String? {
        if status == .notAllowed { return NSLocalizedString("This Apple account is not allowed.", comment: "Claude hint 401") }
        guard status == .retryLater || lastProblem == .retryLater else { return nil }
        return NSLocalizedString("Service currently unreachable, try again later.", comment: "Claude hint 503")
    }
}
