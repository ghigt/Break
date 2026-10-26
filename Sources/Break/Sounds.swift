import AppKit

enum Sounds {
    static func warning() { play("Glass") }
    static func breakStarted() { play("Submarine") }
    static func breakFinished() { play("Hero") }

    private static func play(_ name: String) {
        guard Preferences.soundsEnabled else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }
}
