import SwiftUI
import ApplicationServices

struct SettingsView: View {
    @AppStorage("claudeModel") private var model = ""
    @AppStorage("fastModel") private var fastModel = "haiku"
    @AppStorage("systemPrompt") private var systemPrompt = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L("settings.title"))
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 4) {
                Text(L("settings.permissions"))
                    .font(.headline)
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(L("settings.cliAuth"))
                        .font(.callout)
                }
                HStack(spacing: 8) {
                    Image(systemName: AXIsProcessTrusted() ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(AXIsProcessTrusted() ? .green : .secondary)
                    Text(L("settings.accessibility"))
                        .font(.callout)
                    Spacer()
                    Button(L("settings.requestAccess")) {
                        let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
                        AXIsProcessTrustedWithOptions(opts)
                    }
                    .font(.callout)
                }
                HStack(spacing: 8) {
                    Image(systemName: CGPreflightScreenCaptureAccess() ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(CGPreflightScreenCaptureAccess() ? .green : .secondary)
                    Text(L("settings.screenCapture"))
                        .font(.callout)
                    Spacer()
                    Button(L("settings.requestAccess")) {
                        CGRequestScreenCaptureAccess()
                    }
                    .font(.callout)
                }
                Text(L("settings.permDesc"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(L("settings.chatModel"))
                    .font(.headline)
                Picker("", selection: $model) {
                    Text(L("settings.defaultModel")).tag("")
                    Text("Sonnet").tag("sonnet")
                    Text("Haiku").tag("haiku")
                    Text("Opus").tag("opus")
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(L("settings.fastModel"))
                    .font(.headline)
                Picker("", selection: $fastModel) {
                    Text(L("settings.fastHaiku")).tag("haiku")
                    Text("Sonnet").tag("sonnet")
                    Text("Opus").tag("opus")
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(L("settings.systemPrompt"))
                    .font(.headline)
                TextEditor(text: $systemPrompt)
                    .font(.body)
                    .frame(height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.3))
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(L("settings.hotkeys"))
                    .font(.headline)
                VStack(alignment: .leading, spacing: 4) {
                    Label("⌘⇧\\ \(L("menu.toggle"))", systemImage: "macwindow")
                    Label("⌘⇧T \(L("settings.selectTranslate"))", systemImage: "character.book.closed")
                    Label("⌘⇧L \(L("settings.captureTranslate"))", systemImage: "camera.viewfinder")
                }
                .font(.callout)
                .foregroundColor(.secondary)
            }

            Spacer()

            HStack {
                Spacer()
                Button(L("settings.close")) { dismiss() }
                    .keyboardShortcut(.escape)
            }
        }
        .padding(20)
        .frame(width: 440, height: 560)
    }
}
