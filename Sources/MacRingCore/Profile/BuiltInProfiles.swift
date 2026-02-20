import Foundation

// MARK: - Built-in Profiles

/// Predefined profiles for common applications
public enum BuiltInProfiles {

    // MARK: - Profile Definitions

    /// VS Code profile with common development shortcuts
    public static var vsCode: RingProfile {
        RingProfile(
            name: "VS Code",
            bundleId: "com.microsoft.VSCode",
            category: .ide,
            slots: [
                // Position 0 (Right)
                RingSlot(position: 0, label: "Command Palette", icon: "text.magnifyingglass", action: .keyboardShortcut(.character("p"), modifiers: [.command, .shift])),
                // Position 1 (Up-Right)
                RingSlot(position: 1, label: "Find in Files", icon: "magnifyingglass", action: .keyboardShortcut(.character("f"), modifiers: [.command, .shift])),
                // Position 2 (Up)
                RingSlot(position: 2, label: "New File", icon: "doc.badge.plus", action: .keyboardShortcut(.character("n"), modifiers: [.command])),
                // Position 3 (Up-Left)
                RingSlot(position: 3, label: "Close Editor", icon: "xmark.circle", action: .keyboardShortcut(.character("w"), modifiers: [.command])),
                // Position 4 (Left)
                RingSlot(position: 4, label: "Toggle Terminal", icon: "chevron.left.forwardslash.chevron.right", action: .keyboardShortcut(.character("`"), modifiers: [.command])),
                // Position 5 (Down-Left)
                RingSlot(position: 5, label: "Format", icon: "text.alignleft", action: .keyboardShortcut(.character("s"), modifiers: [.command, .shift])),
                // Position 6 (Down)
                RingSlot(position: 6, label: "Go to Line", icon: "number", action: .keyboardShortcut(.character("g"), modifiers: [.command])),
                // Position 7 (Down-Right)
                RingSlot(position: 7, label: "Quick Open", icon: "folder", action: .keyboardShortcut(.character("p"), modifiers: [.command])),
            ],
            slotCount: 8,
            source: .builtin
        )
    }

    /// Xcode profile with Apple development shortcuts
    public static var xcode: RingProfile {
        RingProfile(
            name: "Xcode",
            bundleId: "com.apple.dt.Xcode",
            category: .ide,
            slots: [
                RingSlot(position: 0, label: "Build", icon: "hammer", action: .keyboardShortcut(.character("b"), modifiers: [.command])),
                RingSlot(position: 1, label: "Run", icon: "play.fill", action: .keyboardShortcut(.character("r"), modifiers: [.command])),
                RingSlot(position: 2, label: "Stop", icon: "stop.fill", action: .keyboardShortcut(.character("."), modifiers: [.command])),
                RingSlot(position: 3, label: "Clean", icon: "sparkles", action: .keyboardShortcut(.character("k"), modifiers: [.command, .shift])),
                RingSlot(position: 4, label: "Test", icon: "checkmark.circle.fill", action: .keyboardShortcut(.character("u"), modifiers: [.command])),
                RingSlot(position: 5, label: "Find", icon: "magnifyingglass", action: .keyboardShortcut(.character("f"), modifiers: [.command])),
                RingSlot(position: 6, label: "Open Quickly", icon: "folder.badge.gearshape", action: .keyboardShortcut(.character("o"), modifiers: [.command, .shift])),
                RingSlot(position: 7, label: "Assistant", icon: "info.circle", action: .keyboardShortcut(.character("a"), modifiers: [.command, .shift, .option])),
            ],
            slotCount: 8,
            source: .builtin
        )
    }

    /// Safari profile with browser shortcuts
    public static var safari: RingProfile {
        RingProfile(
            name: "Safari",
            bundleId: "com.apple.Safari",
            category: .browser,
            slots: [
                RingSlot(position: 0, label: "Address Bar", icon: "location.fill", action: .keyboardShortcut(.character("l"), modifiers: [.command])),
                RingSlot(position: 1, label: "New Tab", icon: "plus.rectangle.fill", action: .keyboardShortcut(.character("t"), modifiers: [.command])),
                RingSlot(position: 2, label: "Close Tab", icon: "xmark.rectangle.fill", action: .keyboardShortcut(.character("w"), modifiers: [.command])),
                RingSlot(position: 3, label: "Find", icon: "magnifyingglass", action: .keyboardShortcut(.character("f"), modifiers: [.command])),
                RingSlot(position: 4, label: "Back", icon: "chevron.left", action: .keyboardShortcut(.character("["), modifiers: [.command])),
                RingSlot(position: 5, label: "Forward", icon: "chevron.right", action: .keyboardShortcut(.character("]"), modifiers: [.command])),
                RingSlot(position: 6, label: "Refresh", icon: "arrow.clockwise", action: .keyboardShortcut(.character("r"), modifiers: [.command])),
                RingSlot(position: 7, label: "Private", icon: "safari", action: .keyboardShortcut(.character("n"), modifiers: [.command, .shift])),
            ],
            slotCount: 8,
            source: .builtin
        )
    }

    /// Finder profile with file management shortcuts
    public static var finder: RingProfile {
        RingProfile(
            name: "Finder",
            bundleId: "com.apple.finder",
            category: .other,
            slots: [
                RingSlot(position: 0, label: "New Window", icon: "plus.square.fill", action: .keyboardShortcut(.character("n"), modifiers: [.command])),
                RingSlot(position: 1, label: "New Folder", icon: "folder.badge.plus", action: .keyboardShortcut(.character("n"), modifiers: [.command, .shift])),
                RingSlot(position: 2, label: "Get Info", icon: "info.circle", action: .keyboardShortcut(.character("i"), modifiers: [.command])),
                RingSlot(position: 3, label: "Quick Look", icon: "eye.fill", action: .keyboardShortcut(.special(.space), modifiers: [])),
                RingSlot(position: 4, label: "Trash", icon: "trash.fill", action: .keyboardShortcut(.special(.delete), modifiers: [.command])),
                RingSlot(position: 5, label: "Duplicate", icon: "doc.on.doc", action: .keyboardShortcut(.character("d"), modifiers: [.command])),
                RingSlot(position: 6, label: "Search", icon: "magnifyingglass", action: .keyboardShortcut(.character("f"), modifiers: [.command])),
                RingSlot(position: 7, label: "Go to Folder", icon: "folder", action: .keyboardShortcut(.character("g"), modifiers: [.command, .shift])),
            ],
            slotCount: 8,
            source: .builtin
        )
    }

    /// Terminal profile with shell shortcuts
    public static var terminal: RingProfile {
        RingProfile(
            name: "Terminal",
            bundleId: "com.apple.Terminal",
            category: .terminal,
            slots: [
                RingSlot(position: 0, label: "New Tab", icon: "plus.rectangle.fill", action: .keyboardShortcut(.character("t"), modifiers: [.command])),
                RingSlot(position: 1, label: "New Window", icon: "plus.square.fill", action: .keyboardShortcut(.character("n"), modifiers: [.command])),
                RingSlot(position: 2, label: "Close Tab", icon: "xmark.rectangle.fill", action: .keyboardShortcut(.character("w"), modifiers: [.command])),
                RingSlot(position: 3, label: "Clear", icon: "clear", action: .keyboardShortcut(.character("k"), modifiers: [.command])),
                RingSlot(position: 4, label: "Select All", icon: "square.and.pencil", action: .keyboardShortcut(.character("a"), modifiers: [.command])),
                RingSlot(position: 5, label: "Copy", icon: "doc.on.doc", action: .keyboardShortcut(.character("c"), modifiers: [.command])),
                RingSlot(position: 6, label: "Paste", icon: "doc.on.clipboard", action: .keyboardShortcut(.character("v"), modifiers: [.command])),
                RingSlot(position: 7, label: "Previous Tab", icon: "chevron.left", action: .keyboardShortcut(.character("["), modifiers: [.command, .shift])),
            ],
            slotCount: 8,
            source: .builtin
        )
    }

    /// Notes profile with productivity shortcuts
    public static var notes: RingProfile {
        RingProfile(
            name: "Notes",
            bundleId: "com.apple.Notes",
            category: .productivity,
            slots: [
                RingSlot(position: 0, label: "New Note", icon: "note.text.badge.plus", action: .keyboardShortcut(.character("n"), modifiers: [.command])),
                RingSlot(position: 1, label: "Folder 1", icon: "folder.fill", action: .keyboardShortcut(.character("1"), modifiers: [.command])),
                RingSlot(position: 2, label: "Folder 2", icon: "folder.fill", action: .keyboardShortcut(.character("2"), modifiers: [.command])),
                RingSlot(position: 3, label: "Folder 3", icon: "folder.fill", action: .keyboardShortcut(.character("3"), modifiers: [.command])),
                RingSlot(position: 4, label: "Search", icon: "magnifyingglass", action: .keyboardShortcut(.character("f"), modifiers: [.command])),
                RingSlot(position: 5, label: "Share", icon: "square.and.arrow.up", action: .keyboardShortcut(.character("s"), modifiers: [.command, .shift])),
                RingSlot(position: 6, label: "Bold", icon: "bold", action: .keyboardShortcut(.character("b"), modifiers: [.command])),
                RingSlot(position: 7, label: "Italic", icon: "italic", action: .keyboardShortcut(.character("i"), modifiers: [.command])),
            ],
            slotCount: 8,
            source: .builtin
        )
    }

    /// Messages profile with communication shortcuts
    public static var messages: RingProfile {
        RingProfile(
            name: "Messages",
            bundleId: "com.apple.MobileSMS",
            category: .communication,
            slots: [
                RingSlot(position: 0, label: "New Message", icon: "square.and.pencil", action: .keyboardShortcut(.character("n"), modifiers: [.command])),
                RingSlot(position: 1, label: "Send", icon: "arrow.up.circle.fill", action: .keyboardShortcut(.special(.enter), modifiers: [])),
                RingSlot(position: 2, label: "Attach", icon: "paperclip", action: .keyboardShortcut(.character("f"), modifiers: [.command])),
                RingSlot(position: 3, label: "Emoji", icon: "face.smiling", action: .keyboardShortcut(.character("e"), modifiers: [.command, .shift])),
                RingSlot(position: 4, label: "Search", icon: "magnifyingglass", action: .keyboardShortcut(.character("f"), modifiers: [.command, .option])),
                RingSlot(position: 5, label: "Delete Chat", icon: "trash", action: .keyboardShortcut(.special(.delete), modifiers: [.command])),
                RingSlot(position: 6, label: "Details", icon: "info.circle", action: .keyboardShortcut(.character("i"), modifiers: [.command])),
                RingSlot(position: 7, label: "Next", icon: "chevron.right", action: .keyboardShortcut(.character("]"), modifiers: [.command, .shift])),
            ],
            slotCount: 8,
            source: .builtin
        )
    }

    /// Spotify profile with media shortcuts
    public static var spotify: RingProfile {
        RingProfile(
            name: "Spotify",
            bundleId: "com.spotify.client",
            category: .media,
            slots: [
                RingSlot(position: 0, label: "Play/Pause", icon: "playpause", action: .keyboardShortcut(.special(.space), modifiers: [])),
                RingSlot(position: 1, label: "Next", icon: "forward.fill", action: .keyboardShortcut(.special(.rightArrow), modifiers: [.command])),
                RingSlot(position: 2, label: "Previous", icon: "backward.fill", action: .keyboardShortcut(.special(.leftArrow), modifiers: [.command])),
                RingSlot(position: 3, label: "Volume Up", icon: "speaker.wave.2.fill", action: .keyboardShortcut(.special(.upArrow), modifiers: [.command])),
                RingSlot(position: 4, label: "Volume Down", icon: "speaker.wave.1.fill", action: .keyboardShortcut(.special(.downArrow), modifiers: [.command])),
                RingSlot(position: 5, label: "Mute", icon: "speaker.slash.fill", action: .keyboardShortcut(.character("m"), modifiers: [.command, .shift])),
                RingSlot(position: 6, label: "Shuffle", icon: "shuffle", action: .keyboardShortcut(.character("s"), modifiers: [.command])),
                RingSlot(position: 7, label: "Repeat", icon: "repeat", action: .keyboardShortcut(.character("r"), modifiers: [.command])),
            ],
            slotCount: 8,
            source: .builtin
        )
    }

    /// Slack profile with communication shortcuts
    public static var slack: RingProfile {
        RingProfile(
            name: "Slack",
            bundleId: "com.tinyspeck.slackmacgap",
            category: .communication,
            slots: [
                RingSlot(position: 0, label: "Quick Switcher", icon: "text.magnifyingglass", action: .keyboardShortcut(.character("k"), modifiers: [.command])),
                RingSlot(position: 1, label: "Search", icon: "magnifyingglass", action: .keyboardShortcut(.character("f"), modifiers: [.command])),
                RingSlot(position: 2, label: "New Message", icon: "square.and.pencil", action: .keyboardShortcut(.character("n"), modifiers: [.command, .shift])),
                RingSlot(position: 3, label: "Direct Messages", icon: "at", action: .keyboardShortcut(.character("k"), modifiers: [.command, .shift])),
                RingSlot(position: 4, label: "Status", icon: "circle.fill", action: .keyboardShortcut(.character("y"), modifiers: [.command])),
                RingSlot(position: 5, label: "Share Screen", icon: "rectangle.on.rectangle", action: .keyboardShortcut(.character("s"), modifiers: [.command, .shift])),
                RingSlot(position: 6, label: "Channel Browser", icon: "number", action: .keyboardShortcut(.character("b"), modifiers: [.command, .shift])),
                RingSlot(position: 7, label: "Huddle", icon: "waveform", action: .keyboardShortcut(.character("h"), modifiers: [.command, .shift])),
            ],
            slotCount: 8,
            source: .builtin
        )
    }

    /// System default profile with universal shortcuts
    public static var `default`: RingProfile {
        RingProfile(
            name: "System",
            bundleId: nil,
            category: .other,
            slots: [
                RingSlot(position: 0, label: "Screenshot", icon: "camera.fill", action: .keyboardShortcut(.character("4"), modifiers: [.command, .shift])),
                RingSlot(position: 1, label: "Screenshot Selection", icon: "camera.aperture", action: .keyboardShortcut(.character("5"), modifiers: [.command, .shift])),
                RingSlot(position: 2, label: "Lock Screen", icon: "lock.fill", action: .keyboardShortcut(.character("q"), modifiers: [.command, .control])),
                RingSlot(position: 3, label: "Mission Control", icon: "rectangle.split.3x3", action: .keyboardShortcut(.special(.space), modifiers: [.command])),
                RingSlot(position: 4, label: "Launchpad", icon: "app.dashed", action: .keyboardShortcut(.special(.space), modifiers: [.command, .option])),
                RingSlot(position: 5, label: "Show Desktop", icon: "rectangle.on.rectangle.slash", action: .keyboardShortcut(.character("f"), modifiers: [.command, .option])),
                RingSlot(position: 6, label: "Spotlight", icon: "spotlight", action: .keyboardShortcut(.special(.space), modifiers: [.command])),
                RingSlot(position: 7, label: "Emoji Picker", icon: "face.smiling", action: .keyboardShortcut(.special(.space), modifiers: [.command, .control])),
            ],
            slotCount: 8,
            isDefault: true,
            source: .builtin
        )
    }

    // MARK: - Collection Access

    /// All built-in profiles
    public static var all: [RingProfile] {
        [
            vsCode,
            xcode,
            safari,
            finder,
            terminal,
            notes,
            messages,
            spotify,
            slack,
            `default`,
        ]
    }

    /// Find a built-in profile by bundle ID
    /// - Parameter bundleId: The app's bundle identifier
    /// - Returns: The matching profile, or nil if not found
    public static func profile(forBundleId bundleId: String) -> RingProfile? {
        all.first { $0.bundleId == bundleId }
    }

    /// Get a profile by category
    /// - Parameter category: The app category
    /// - Returns: The first profile matching the category, or nil
    public static func profile(forCategory category: AppCategory) -> RingProfile? {
        all.first { $0.category == category && $0.bundleId != nil }
    }
}
