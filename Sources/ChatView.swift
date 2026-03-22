import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            quickActions
            Divider()
            messagesList
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }
            Divider()
            inputArea
        }
        .frame(minWidth: 320, minHeight: 400)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    private var toolbar: some View {
        HStack {
            Text("PreviewClaude")
                .font(.headline)
            Spacer()
            Button(action: { viewModel.clearChat() }) {
                Image(systemName: "plus.message")
            }
            .buttonStyle(.borderless)
            .help(L("toolbar.newChat"))

            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help(L("toolbar.settings"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var quickActions: some View {
        HStack(spacing: 8) {
            quickActionButton(L("action.translate"), action: .translate)
            quickActionButton(L("action.summarize"), action: .summarize)
            quickActionButton(L("action.explain"), action: .explain)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("⌘⇧T \(L("settings.selectTranslate"))")
                Text("⌘⇧L \(L("settings.captureTranslate"))")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func quickActionButton(_ title: String, action: ChatViewModel.QuickAction) -> some View {
        Button(title) {
            if let text = viewModel.pasteFromClipboard(), !text.isEmpty {
                viewModel.sendWithAction(action, text: text)
            } else {
                viewModel.errorMessage = L("input.noClipboard")
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(viewModel.isLoading)
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if viewModel.messages.isEmpty {
                        emptyState
                    }
                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(message: message)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.vertical, 8)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: viewModel.updateCounter) { _, _ in
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.and.wrench")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text(L("empty.guide"))
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var inputArea: some View {
        HStack(spacing: 8) {
            Button(action: {
                if let text = viewModel.pasteFromClipboard() {
                    viewModel.inputText += text
                }
            }) {
                Image(systemName: "doc.on.clipboard")
            }
            .buttonStyle(.borderless)
            .help(L("input.paste"))

            ZStack(alignment: .leading) {
                if viewModel.inputText.isEmpty {
                    Text(L("input.placeholder"))
                        .foregroundColor(.secondary.opacity(0.5))
                        .padding(.leading, 4)
                }
                TextEditor(text: $viewModel.inputText)
                    .font(.body)
                    .frame(minHeight: 20, maxHeight: 80)
                    .fixedSize(horizontal: false, vertical: true)
                    .scrollContentBackground(.hidden)
                    .onKeyPress(.return) {
                        if NSEvent.modifierFlags.contains(.shift) {
                            return .ignored
                        }
                        viewModel.sendMessage()
                        return .handled
                    }
            }

            Button(action: { viewModel.sendMessage() }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(viewModel.canSend ? .accentColor : .secondary)
            }
            .buttonStyle(.borderless)
            .disabled(!viewModel.canSend)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

private struct MessageBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .assistant { avatar("C", color: .orange) }

            Text(message.content.isEmpty ? "..." : message.content)
                .textSelection(.enabled)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(message.role == .user
                              ? Color.accentColor.opacity(0.15)
                              : Color.secondary.opacity(0.1))
                )
                .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .user { avatar("U", color: .blue) }
        }
        .padding(.horizontal, 12)
    }

    private func avatar(_ letter: String, color: Color) -> some View {
        Circle()
            .fill(color.opacity(0.8))
            .frame(width: 24, height: 24)
            .overlay(Text(letter).font(.caption2.bold()).foregroundColor(.white))
    }
}
