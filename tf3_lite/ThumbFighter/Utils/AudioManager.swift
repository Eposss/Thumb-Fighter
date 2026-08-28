import AVFoundation

class AudioManager {
    static let shared = AudioManager()
    
    private var bgmPlayer: AVAudioPlayer?
    
    // THE POOL: Stores arrays of fully decoded, ready-to-fire audio players
    private var sfxPools: [String: [AVAudioPlayer]] = [:]
    private let poolSize = 5 // We will keep 5 players loaded per sound effect
    
    private init() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
        }
        
        // Load our pool of 5 punch sounds the moment the app opens
        preloadSoundPool(filename: "punch", ext: "mp3")
    }
    
    private func preloadSoundPool(filename: String, ext: String) {
        let key = "\(filename).\(ext)"
        guard let url = Bundle.main.url(forResource: filename, withExtension: ext) else { return }
        
        var pool: [AVAudioPlayer] = []
        
        // Create 5 identical players, decode them, and put them in standby mode
        for _ in 0..<poolSize {
            if let player = try? AVAudioPlayer(contentsOf: url) {
                player.volume = 0.8
                player.prepareToPlay() // Wakes up the audio hardware
                pool.append(player)
            }
        }
        sfxPools[key] = pool
        print("✅ Pooled \(poolSize) players for: \(key)")
    }
    
    // MARK: - Background Music
    func playBGM(filename: String, ext: String) {
        guard let url = Bundle.main.url(forResource: filename, withExtension: ext) else { return }
        do {
            bgmPlayer = try AVAudioPlayer(contentsOf: url)
            bgmPlayer?.numberOfLoops = -1
            bgmPlayer?.volume = 0.4
            bgmPlayer?.prepareToPlay()
            bgmPlayer?.play()
        } catch {
            print("Error BGM: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Sound Effects
    func playSFX(filename: String, ext: String) {
        let key = "\(filename).\(ext)"
        
        // Fast path: Use our pre-loaded pool
        if let pool = sfxPools[key] {
            // Find the first player that isn't currently making noise
            if let availablePlayer = pool.first(where: { !$0.isPlaying }) {
                availablePlayer.play()
            } else {
                // If all 5 are somehow playing at once, force the oldest one to restart
                let forcedPlayer = pool[0]
                forcedPlayer.stop()
                forcedPlayer.currentTime = 0
                forcedPlayer.play()
            }
        } else {
            // Fallback just in case we forgot to preload a different sound
            guard let url = Bundle.main.url(forResource: filename, withExtension: ext) else { return }
            if let player = try? AVAudioPlayer(contentsOf: url) {
                player.volume = 0.8
                player.play()
            }
        }
    }
}
