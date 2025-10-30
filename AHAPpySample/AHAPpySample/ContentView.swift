import SwiftUI
import UniformTypeIdentifiers
import AHAPpy

struct ContentView: View {
    private let haptics = HapticManager.shared
    @State private var isImporting = false
    @State private var importedAudioURL: URL?
    @State private var selectedMode: HapticManager.Mode = .music
    @State private var importMessage: String?
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [.blue.opacity(0.22), .purple.opacity(0.28), .black.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    
                    sectionCard(title: "Built-in Demos", subtitle: "Preview layered, sequential, and music-driven haptics.") {
                        VStack(spacing: 16) {
                            Button {
                                try? haptics.playAudioNamed("Wakeup", withExtension: "wav", mode: .music)
                            } label: {
                                DemoButtonLabel(title: "Wake Up", caption: "Music mode • auto intensity")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(FilledButtonStyle(tint: .indigo))
                            
                            Button {
                                playLayeredEffects()
                            } label: {
                                DemoButtonLabel(title: "Layered Atmospheres", caption: "Blend ambient + tap SFX")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(FilledButtonStyle(tint: .mint))
                            
                            Button {
                                playSequentialEffects()
                            } label: {
                                DemoButtonLabel(title: "Sequenced Moments", caption: "Timed transitions demo")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(FilledButtonStyle(tint: .orange))
                        }
                    }
                    
                    sectionCard(title: "Bring Your Own Audio", subtitle: "Drop in any Core Audio compatible file and feel the live-generated haptics.") {
                        VStack(alignment: .leading, spacing: 16) {
                            Picker("Processing Mode", selection: $selectedMode) {
                                Text("Music")
                                    .tag(HapticManager.Mode.music)
                                Text("SFX")
                                    .tag(HapticManager.Mode.sfx)
                            }
                            .pickerStyle(.segmented)
                            
                            Button {
                                isImporting = true
                            } label: {
                                Label("Import Audio", systemImage: "square.and.arrow.down")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(FilledButtonStyle(tint: .accentColor))
                            
                            if let url = importedAudioURL {
                                VStack(alignment: .leading, spacing: 6) {
                                    Label(url.lastPathComponent, systemImage: "waveform")
                                        .font(.subheadline.weight(.medium))
                                    Text("Stored locally and ready to play.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemBackground).opacity(0.8))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            
                            Button {
                                playImportedAudio()
                            } label: {
                                Label("Play Imported Audio", systemImage: "play.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(FilledButtonStyle(tint: .pink))
                            .disabled(importedAudioURL == nil)
                            .opacity(importedAudioURL == nil ? 0.5 : 1)
                        }
                    }
                    
                    if let message = importMessage {
                        StatusBanner(message: message, isError: true)
                    }
                    
                    Button {
                        haptics.stopAll()
                    } label: {
                        Label("Stop All Playback", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(StrokeButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.audio]) { result in
            switch result {
            case .success(let url):
                self.storeImportedAudio(from: url)
            case .failure(let error):
                self.importMessage = "Import failed: \(error.localizedDescription)"
            }
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("AHAPpy Playground")
                    .font(.largeTitle.bold())
            } icon: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 52, height: 52)
                    Image(systemName: "waveform.path.ecg.rectangle")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            Text("Turn any audio into Core Haptics patterns in real time. Test quick demos or bring your own clips and feel the difference instantly.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.82))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
    
    private func sectionCard<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            content()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.94))
                .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 16)
        )
    }
    
    private func storeImportedAudio(from sourceURL: URL) {
        let needsAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if needsAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ??
            FileManager.default.temporaryDirectory
            let destination = documents.appendingPathComponent(sourceURL.lastPathComponent)
            
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
    
    private func playImportedAudio() {
        guard let url = importedAudioURL else { return }
        
        do {
            try haptics.playAudio(at: url, mode: selectedMode)
            importMessage = nil
        } catch {
            importMessage = "Playback failed: \(error.localizedDescription)"
        }
    }
    
    private func playLayeredEffects() {
        do {
            try haptics.playAudioNamed("atmosphere-1", withExtension: "wav", mode: .music)
            try haptics.playAudioNamed("musical-tap-3", withExtension: "wav", mode: .sfx)
        } catch {
            importMessage = "Layered playback error: \(error.localizedDescription)"
        }
    }
    
    private func playSequentialEffects() {
        let items: [(name: String, mode: HapticManager.Mode, delay: TimeInterval)] = [
            ("atmosphere-1", .music, 0),
            ("musical-tap-3", .sfx, 2),
            ("Success1", .sfx, 4)
        ]
        
        for item in items {
            DispatchQueue.main.asyncAfter(deadline: .now() + item.delay) {
                do {
                    try self.haptics.playAudioNamed(item.name, withExtension: "wav", mode: item.mode)
                } catch {
                    self.importMessage = "Sequential playback error: \(error.localizedDescription)"
                }
            }
        }
    }
}

private struct DemoButtonLabel: View {
    let title: String
    let caption: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
    }
}

private struct FilledButtonStyle: ButtonStyle {
    let tint: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(tint.gradient)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(configuration.isPressed ? 0.35 : 0.12), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

private struct StrokeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.systemBackground).opacity(configuration.isPressed ? 0.3 : 0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1.2)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .foregroundStyle(.white.opacity(0.9))
            .font(.headline)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private struct StatusBanner: View {
    let message: String
    var isError: Bool = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                .font(.title3)
                .foregroundStyle(isError ? Color.red : Color.green)
                .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(isError ? "Heads up" : "All set")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.95))
                .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 10)
        )
    }
}
