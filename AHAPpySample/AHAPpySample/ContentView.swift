import SwiftUI
import UniformTypeIdentifiers
import AHAPpy

struct ContentView: View {
    private let haptics = HapticManager.shared
    @State private var isImporting = false
    @State private var importedAudioURL: URL?
    @State private var selectedMode: HapticManager.Mode = .music
    @State private var importMessage: String?
    @State private var playbackToken = UUID()
    
    var body: some View {
        NavigationView {
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        SectionCard(
                            title: "Built-in Demos",
                            description: "Preview preloaded examples."
                        ) {
                            VStack(spacing: 10) {
                                DemoButton(title: "Wake Up", systemImage: "music.quarternote.3", variant: .prominent) {
                                    let token = resetPlayback()
                                    try? haptics.playAudioNamed("Wakeup", withExtension: "wav", mode: .music)
                                    if playbackToken == token {
                                        importMessage = nil
                                    }
                                }
                                
                                DemoButton(title: "Layered Atmospheres", systemImage: "waveform.circle") {
                                    playLayeredEffects()
                                }
                                
                                DemoButton(title: "Sequenced Moments", systemImage: "clock") {
                                    playSequentialEffects()
                                }
                            }
                        }
                        
                        SectionCard(
                            title: "Bring Your Own Audio",
                            description: "Import a file and feel the live-generated haptics."
                        ) {
                            VStack(alignment: .leading, spacing: 14) {
                                Picker("Processing Mode", selection: $selectedMode) {
                                    Text("Music").tag(HapticManager.Mode.music)
                                    Text("SFX").tag(HapticManager.Mode.sfx)
                                }
                                .pickerStyle(.segmented)
                                
                                Button {
                                    isImporting = true
                                } label: {
                                    Label("Import Audio", systemImage: "square.and.arrow.down")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(MonochromeButtonStyle(variant: .prominent))
                                
                                if let url = importedAudioURL {
                                    GroupBox {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Label(url.lastPathComponent, systemImage: "waveform")
                                                .font(.subheadline.weight(.semibold))
                                            Text("Stored locally and ready to play.")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                
                                Button {
                                    playImportedAudio()
                                } label: {
                                    Label("Play Imported Audio", systemImage: "play.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(MonochromeButtonStyle())
                                .disabled(importedAudioURL == nil)
                                .opacity(importedAudioURL == nil ? 0.4 : 1)
                            }
                        }
                        
                        if let message = importMessage {
                            StatusBanner(message: message)
                        }
                        
                        Button {
                            resetPlayback()
                            importMessage = nil
                        } label: {
                            Label("Stop All Playback", systemImage: "stop.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(MonochromeButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                    .frame(minHeight: proxy.size.height, alignment: .top)
                }
                .background(Color(.systemGroupedBackground).ignoresSafeArea())
            }
            .navigationTitle("AHAPpy")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.audio]) { result in
            switch result {
            case .success(let url):
                storeImportedAudio(from: url)
            case .failure(let error):
                importMessage = "Import failed: \(error.localizedDescription)"
            }
        }
    }
    
    private func playImportedAudio() {
        guard let url = importedAudioURL else { return }
        
        let token = resetPlayback()
        do {
            try haptics.playAudio(at: url, mode: selectedMode)
            if playbackToken == token {
                importMessage = nil
            }
        } catch {
            if playbackToken == token {
                importMessage = "Playback failed: \(error.localizedDescription)"
            }
        }
    }
    
    private func playLayeredEffects() {
        let token = resetPlayback()
        do {
            try haptics.playAudioNamed("atmosphere-1", withExtension: "wav", mode: .music)
            try haptics.playAudioNamed("musical-tap-3", withExtension: "wav", mode: .sfx)
            if playbackToken == token {
                importMessage = nil
            }
        } catch {
            if playbackToken == token {
                importMessage = "Layered playback error: \(error.localizedDescription)"
            }
        }
    }
    
    private func playSequentialEffects() {
        let items: [(name: String, mode: HapticManager.Mode, delay: TimeInterval)] = [
            ("atmosphere-1", .music, 0),
            ("musical-tap-3", .sfx, 2),
            ("Success1", .sfx, 4)
        ]
        
        let token = resetPlayback()
        for item in items {
            DispatchQueue.main.asyncAfter(deadline: .now() + item.delay) {
                guard playbackToken == token else { return }
                do {
                    try haptics.playAudioNamed(item.name, withExtension: "wav", mode: item.mode)
                } catch {
                    if playbackToken == token {
                        importMessage = "Sequential playback error: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    private func storeImportedAudio(from sourceURL: URL) {
        let needsAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if needsAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }
        
        resetPlayback()
        cleanupImportedAudioFile()
        
        do {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ??
            FileManager.default.temporaryDirectory
            let destination = documents
                .appendingPathComponent("ImportedAudio")
                .appendingPathExtension(sourceURL.pathExtension.isEmpty ? "wav" : sourceURL.pathExtension)
            
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destination)
            importedAudioURL = destination
            importMessage = nil
        } catch {
            importMessage = "Copy failed: \(error.localizedDescription)"
        }
    }
    
    private func cleanupImportedAudioFile() {
        guard let existingURL = importedAudioURL else { return }
        do {
            if FileManager.default.fileExists(atPath: existingURL.path) {
                try FileManager.default.removeItem(at: existingURL)
            }
        } catch {
            // swallow cleanup errors; we'll overwrite as needed
        }
        importedAudioURL = nil
    }
    
    @discardableResult
    private func resetPlayback() -> UUID {
        haptics.stopAll()
        let token = UUID()
        playbackToken = token
        return token
    }
}

private struct SectionCard<Content: View>: View {
    let title: String
    let description: String
    let content: Content
    
    init(title: String, description: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.description = description
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

private struct DemoButton: View {
    let title: String
    let systemImage: String
    var variant: MonochromeButtonStyle.Variant = .standard
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(MonochromeButtonStyle(variant: variant))
    }
}

private struct MonochromeButtonStyle: ButtonStyle {
    enum Variant {
        case standard
        case prominent
    }
    
    var variant: Variant = .standard
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(backgroundColor.opacity(configuration.isPressed ? 0.8 : 1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(borderColor.opacity(configuration.isPressed ? 0.6 : 0.4), lineWidth: 1)
            )
            .foregroundStyle(foregroundColor)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
    
    private var foregroundColor: Color {
        switch variant {
        case .prominent:
            return Color(.systemBackground)
        case .standard:
            return .primary
        }
    }
    
    private var backgroundColor: Color {
        switch variant {
        case .prominent:
            return Color.accentColor
        case .standard:
            return Color(.tertiarySystemBackground)
        }
    }
    
    private var borderColor: Color {
        switch variant {
        case .prominent:
            return Color.accentColor
        case .standard:
            return Color(.separator)
        }
    }
}

private struct StatusBanner: View {
    let message: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.tertiarySystemBackground))
        )
    }
}
