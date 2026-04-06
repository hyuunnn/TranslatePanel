import SwiftUI
import ApplicationServices

struct SettingsView: View {
    @AppStorage("llmProvider") private var providerId = "claude"
    @AppStorage("systemPrompt") private var systemPrompt = ""
    @AppStorage("speechRate") private var speechRate = 200.0
    @Environment(\.dismiss) private var dismiss

    private var currentProvider: LLMProvider {
        LLMProviderRegistry.provider(forId: providerId)
    }

    private var modelBinding: Binding<String> {
        let key = "\(providerId)Model"
        let defaultVal = currentProvider.defaultModel
        return Binding(
            get: { UserDefaults.standard.string(forKey: key) ?? defaultVal },
            set: { UserDefaults.standard.set($0, forKey: key) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L("settings.title"))
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 4) {
                Text(L("settings.permissions"))
                    .font(.headline)
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
                Text(L("settings.provider"))
                    .font(.headline)
                Picker("", selection: $providerId) {
                    ForEach(LLMProviderRegistry.all, id: \.id) { provider in
                        Text(provider.displayName).tag(provider.id)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text(L("settings.providerDesc"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(L("settings.model"))
                    .font(.headline)
                TextField(L("settings.modelPlaceholder.\(providerId)"), text: modelBinding)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                Text(L("settings.modelDesc"))
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                Text(L("settings.speechRate"))
                    .font(.headline)
                HStack {
                    Image(systemName: "tortoise")
                        .foregroundColor(.secondary)
                    Slider(value: $speechRate, in: 50...500, step: 10)
                    Image(systemName: "hare")
                        .foregroundColor(.secondary)
                    Text("\(Int(speechRate))")
                        .font(.callout.monospacedDigit())
                        .frame(width: 36, alignment: .trailing)
                }
                Text(L("settings.speechRateDesc"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(L("settings.hotkeys"))
                    .font(.headline)
                VStack(alignment: .leading, spacing: 4) {
                    Label("⌘⇧\\ \(L("menu.toggle"))", systemImage: "macwindow")
                    Label("⌘⇧, \(L("settings.selectTranslate"))", systemImage: "character.book.closed")
                    Label("⌘⇧. \(L("settings.captureTranslate"))", systemImage: "camera.viewfinder")
                    Label("⌘⇧' \(L("settings.regionCaptureTranslate"))", systemImage: "rectangle.dashed")
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
        .frame(width: 440, height: 700)
    }
}
