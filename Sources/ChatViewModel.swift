import SwiftUI
import Vision

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    var content: String
    var providerId: String?

    enum Role {
        case user, assistant
    }
}

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var updateCounter = 0

    private var currentProcess: Process?
    private var isCancelled = false
    private var observer: Any?
    private var ocrErrorObserver: Any?

    private var currentProvider: LLMProvider {
        let id = UserDefaults.standard.string(forKey: "llmProvider") ?? "claude"
        return LLMProviderRegistry.provider(forId: id)
    }
    private func model(for provider: LLMProvider) -> String {
        UserDefaults.standard.string(forKey: "\(provider.id)Model") ?? provider.defaultModel
    }
    private var systemPrompt: String { UserDefaults.standard.string(forKey: "systemPrompt") ?? "" }
    private var sourceLang: String { UserDefaults.standard.string(forKey: "sourceLang") ?? "auto" }
    private var targetLang: String { UserDefaults.standard.string(forKey: "targetLang") ?? "ko" }

    static let langNames: [String: String] = [
        "auto": "Auto", "en": "English", "ko": "한국어", "ja": "日本語", "zh": "中文"
    ]

    private static var resolvedShells: [String: (path: String, env: [String: String])] = [:]

    private static func resolveShell(for binaryName: String) -> (path: String, env: [String: String]) {
        if let cached = resolvedShells[binaryName] { return cached }

        guard binaryName.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }) else {
            return ("/usr/local/bin/\(binaryName)", [:])
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-li", "-c", "which \(binaryName) && echo __ENV_SEPARATOR__ && env"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let parts = output.components(separatedBy: "__ENV_SEPARATOR__\n")

        let path = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "/usr/local/bin/\(binaryName)"

        var env: [String: String] = [:]
        if parts.count > 1 {
            for line in parts[1].split(separator: "\n") {
                if let idx = line.firstIndex(of: "=") {
                    env[String(line[..<idx])] = String(line[line.index(after: idx)...])
                }
            }
        }
        let result = (path.isEmpty ? "/usr/local/bin/\(binaryName)" : path, env)
        resolvedShells[binaryName] = result
        return result
    }

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: .translateClipboard, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, let text = self.pasteFromClipboard(), !text.isEmpty else { return }
                self.sendWithAction(.translate, text: text)
            }
        }
        ocrErrorObserver = NotificationCenter.default.addObserver(
            forName: .ocrError, object: nil, queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.errorMessage = notification.object as? String ?? L("error.ocrFail")
            }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        if let ocrErrorObserver { NotificationCenter.default.removeObserver(ocrErrorObserver) }
    }

    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespaces).isEmpty && !isLoading
    }

    func sendMessage(_ text: String? = nil) {
        let content = (text ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        let provider = currentProvider
        cancelCurrentRequest()
        let idx = appendMessages(userContent: content, provider: provider)
        runLLM(prompt: content, responseIndex: idx, provider: provider)
    }

    func sendWithAction(_ action: QuickAction, text: String) {
        let prompt: String
        switch action {
        case .translate:
            let target = Self.langNames[targetLang] ?? targetLang
            let langInstruction: String
            if sourceLang == "auto" {
                langInstruction = "\(target)로 번역해"
            } else {
                let source = Self.langNames[sourceLang] ?? sourceLang
                langInstruction = "\(source)를 \(target)로 번역해"
            }
            prompt = "<text> 안의 텍스트만 \(langInstruction). 부연설명, 원문 반복, 메모, 태그 없이 번역 결과만 출력해.\n\n<text>\(text)</text>"
        case .summarize: prompt = "<text> 안의 텍스트를 요약만 해. 부연설명 없이 요약 결과만 출력해.\n\n<text>\(text)</text>"
        case .explain: prompt = "<text> 안의 텍스트를 쉽게 설명해줘:\n\n<text>\(text)</text>"
        }
        let provider = currentProvider
        cancelCurrentRequest()
        let idx = appendMessages(userContent: prompt, provider: provider)
        runLLM(prompt: prompt, responseIndex: idx, provider: provider)
    }

    func pasteFromClipboard() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    func clearChat() {
        cancelCurrentRequest()
        messages.removeAll()
        errorMessage = nil
    }

    enum QuickAction {
        case translate, summarize, explain
    }

    // MARK: - Image Drop OCR

    func handleDroppedImage(_ url: URL) {
        handleDroppedNSImage(NSImage(contentsOf: url))
    }

    func handleDroppedImageData(_ data: Data) {
        handleDroppedNSImage(NSImage(data: data))
    }

    private func handleDroppedNSImage(_ nsImage: NSImage?) {
        guard let nsImage,
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            errorMessage = L("error.invalidImage")
            return
        }
        ocrAndTranslate(cgImage)
    }

    private func ocrAndTranslate(_ cgImage: CGImage) {
        guard !isLoading else { return }
        errorMessage = nil

        Task.detached {
            let text: String
            do {
                text = try OCRHelper.performOCR(on: cgImage)
            } catch {
                await MainActor.run { [weak self] in
                    self?.errorMessage = L("error.ocrFail")
                }
                return
            }

            await MainActor.run { [weak self] in
                guard let self else { return }
                guard !text.isEmpty else {
                    self.errorMessage = L("error.noText")
                    return
                }
                self.sendWithAction(.translate, text: text)
            }
        }
    }

    // MARK: - Private

    private func appendMessages(userContent: String, provider: LLMProvider) -> Int {
        messages.append(ChatMessage(role: .user, content: userContent))
        inputText = ""
        isLoading = true
        isCancelled = false
        errorMessage = nil
        messages.append(ChatMessage(role: .assistant, content: "", providerId: provider.id))
        return messages.count - 1
    }

    func cancelCurrentRequest() {
        isCancelled = true
        currentProcess?.terminate()
        currentProcess = nil
        isLoading = false
    }

    private func runLLM(prompt: String, responseIndex idx: Int, provider: LLMProvider) {
        let currentModel = model(for: provider)
        let shell = Self.resolveShell(for: provider.binaryName)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell.path)
        process.environment = shell.env
        var args = provider.buildArguments(model: currentModel, systemPrompt: systemPrompt)
        let formattedPrompt = provider.formatPrompt(prompt, systemPrompt: systemPrompt)
        if provider.passesPromptViaArgument {
            args.append(formattedPrompt)
        }
        process.arguments = args

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                guard let self, self.messages.indices.contains(idx) else { return }
                self.messages[idx].content = (self.messages[idx].content + str)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                self.updateCounter += 1
            }
        }

        process.terminationHandler = { [weak self] proc in
            outputPipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false
                self.currentProcess = nil
                if proc.terminationStatus != 0,
                   !self.isCancelled,
                   self.messages.indices.contains(idx),
                   self.messages[idx].content.isEmpty {
                    let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errStr = String(data: errData, encoding: .utf8) ?? ""
                    self.errorMessage = errStr.isEmpty
                        ? L("error.cliFail") + " (exit \(proc.terminationStatus))"
                        : errStr
                    self.messages.remove(at: idx)
                }
            }
        }

        do {
            try process.run()
            currentProcess = process
            if !provider.passesPromptViaArgument {
                inputPipe.fileHandleForWriting.write(Data(formattedPrompt.utf8))
            }
            inputPipe.fileHandleForWriting.closeFile()
        } catch {
            isLoading = false
            errorMessage = L("error.cliLaunch") + ": \(error.localizedDescription)"
            if messages.indices.contains(idx) {
                messages.remove(at: idx)
            }
        }
    }
}
