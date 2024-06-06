//
//  ContentView.swift
//  AHAPpySample
//
//  Created by Sam Roman on 5/31/24.
//

import SwiftUI
import AVFoundation
import CoreHaptics

class SoundManager {
    static let shared = SoundManager()
    
    private var players: [AVAudioPlayer] = []
    private var engine: CHHapticEngine?
    private var isPlaying = false
    
    private init() {
        initializeHapticEngine()
    }
    
    private func initializeHapticEngine() {
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("Error starting haptic engine: \(error.localizedDescription)")
        }
    }
    
    func playSound(wavFileName: String, ahapFileName: String? = nil) {
        do {
            guard let wavPath = Bundle.main.path(forResource: wavFileName, ofType:"wav") else {
                print("Invalid path")
                return
            }
            
            let wavURL = URL(fileURLWithPath: wavPath)
            
            let player = try AVAudioPlayer(contentsOf: wavURL)
            players.append(player)
            
            player.play()
            
            if let ahapFileName = ahapFileName {
                try playHapticPattern(ahapFileName)
            }
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    func playSoundWithMultipleHaptics(wavFileName: String, ahapFileNames: [String]) {
        
        do {
            guard let wavPath = Bundle.main.path(forResource: wavFileName, ofType: "wav") else {
                print("Invalid path")
                return
            }
            
            let wavURL = URL(fileURLWithPath: wavPath)
            let player = try AVAudioPlayer(contentsOf: wavURL)
            players.append(player)
            
            for ahapFileName in ahapFileNames {
                try playHapticPattern(ahapFileName)
            }
            
            player.play()
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    private func playHapticPattern(_ ahapFileName: String) throws {
        guard let engine = engine else { return }
        
        guard let ahapURL = Bundle.main.url(forResource: ahapFileName, withExtension: "ahap") else {
            print("Invalid haptic pattern path")
            return
        }
        
        let ahapPattern = try CHHapticPattern(contentsOf: ahapURL)
        let player = try engine.makeAdvancedPlayer(with: ahapPattern)
        try player.start(atTime: CHHapticTimeImmediate)
    }
    
    func playLayeredSounds(with soundData: [(wavFileName: String, ahapFileName: String?)]) {
        for sound in soundData {
            playSound(wavFileName: sound.wavFileName, ahapFileName: sound.ahapFileName)
        }
    }
    
    func playSoundsSequentially(with soundData: [(wavFileName: String, ahapFileName: String?, interval: TimeInterval)]) {
        var delay: TimeInterval = 0
        
        for sound in soundData {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.playSound(wavFileName: sound.wavFileName, ahapFileName: sound.ahapFileName)
            }
            delay += sound.interval
        }
    }
    
    
    func stopAllSoundsAndHaptics() {
        for player in players {
            player.stop()
        }
        players.removeAll()
        
        engine?.stop(completionHandler: { error in
            if let error = error {
                print("Error stopping haptic engine: \(error.localizedDescription)")
            }
        })
        
        initializeHapticEngine()
    }
    
}



struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Button(action: {
                SoundManager.shared.playSoundWithMultipleHaptics(
                    wavFileName: "Wakeup",
                    ahapFileNames: ["Wakeup_combined"]
                )
            }) {
                Text("Play Music with Haptics")
            }
            Button(action: {
                SoundManager.shared.playLayeredSounds(with: [(wavFileName: "atmosphere-1", ahapFileName: "atmosphere-1"),
                                                             (wavFileName: "musical-tap-3", ahapFileName: "musical-tap-3")])
            }) {
                Text("Play Combined SFX")
            }
            Button(action: {
                SoundManager.shared.playSoundsSequentially(with: [(wavFileName: "atmosphere-1", ahapFileName: "atmosphere-1", interval: 3.0),
                                                                  (wavFileName: "musical-tap-3", ahapFileName: "musical-tap-3", interval: 2.0),
                                                                   (wavFileName: "Success1", ahapFileName: "Success1", interval: 3.0)])
                
            }) {
                Text("Play Sequential SFX")
            }
            Button(action: {
                SoundManager.shared.stopAllSoundsAndHaptics()
            }) {
                Text("Stop All Sounds and Haptics")
            }
        }
    }
}

