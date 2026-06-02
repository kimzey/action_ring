import Foundation

/// Shipped, ready-to-use ring profiles. App-specific profiles match by bundle
/// id; category defaults are the fallback when no app profile exists.
public enum BuiltInProfiles {

    private static func slot(_ p: Int, _ label: String, _ icon: String, _ action: RingAction, _ color: SlotColor) -> RingSlot {
        RingSlot(position: p, label: label, icon: icon, action: action, color: color)
    }

    private static func key(_ c: Character, _ mods: [KeyModifier]) -> RingAction {
        .keyboardShortcut(.character(c), modifiers: mods)
    }

    // MARK: - App profiles

    public static var vsCode: RingProfile {
        RingProfile(name: "VS Code", bundleId: "com.microsoft.VSCode", category: .ide, slots: [
            slot(0, "Command Palette", "command", key("p", [.command, .shift]), .blue),
            slot(1, "Quick Open", "doc.text.magnifyingglass", key("p", [.command]), .teal),
            slot(2, "Find in Files", "magnifyingglass", key("f", [.command, .shift]), .indigo),
            slot(3, "Toggle Terminal", "chevron.left.forwardslash.chevron.right", .keyboardShortcut(.character("`"), modifiers: [.control]), .gray),
            slot(4, "Go to File", "arrow.right.doc.on.clipboard", key("e", [.command]), .green),
            slot(5, "Format", "text.alignleft", key("f", [.option, .shift]), .orange),
            slot(6, "Comment", "text.bubble", .keyboardShortcut(.character("/"), modifiers: [.command]), .yellow),
            slot(7, "Close Editor", "xmark.circle", key("w", [.command]), .red),
        ], slotCount: 8, source: .builtin)
    }

    public static var cursor: RingProfile {
        RingProfile(name: "Cursor", bundleId: "com.todesktop.230313mzl4w4u92", category: .ide, slots: [
            slot(0, "AI Chat", "sparkles", key("l", [.command]), .purple),
            slot(1, "AI Edit", "wand.and.stars", key("k", [.command]), .pink),
            slot(2, "Command Palette", "command", key("p", [.command, .shift]), .blue),
            slot(3, "Toggle Terminal", "chevron.left.forwardslash.chevron.right", .keyboardShortcut(.character("`"), modifiers: [.control]), .gray),
            slot(4, "Quick Open", "doc.text.magnifyingglass", key("p", [.command]), .teal),
            slot(5, "Find in Files", "magnifyingglass", key("f", [.command, .shift]), .indigo),
            slot(6, "Comment", "text.bubble", .keyboardShortcut(.character("/"), modifiers: [.command]), .yellow),
            slot(7, "Close Editor", "xmark.circle", key("w", [.command]), .red),
        ], slotCount: 8, source: .builtin)
    }

    public static var xcode: RingProfile {
        RingProfile(name: "Xcode", bundleId: "com.apple.dt.Xcode", category: .ide, slots: [
            slot(0, "Run", "play.fill", key("r", [.command]), .green),
            slot(1, "Build", "hammer.fill", key("b", [.command]), .blue),
            slot(2, "Stop", "stop.fill", .keyboardShortcut(.character("."), modifiers: [.command]), .red),
            slot(3, "Clean", "sparkles", key("k", [.command, .shift]), .teal),
            slot(4, "Test", "checkmark.diamond.fill", key("u", [.command]), .purple),
            slot(5, "Open Quickly", "magnifyingglass", key("o", [.command, .shift]), .indigo),
            slot(6, "Find in Project", "doc.text.magnifyingglass", key("f", [.command, .shift]), .orange),
            slot(7, "Jump to Definition", "arrow.up.forward.square", .keyboardShortcut(.character("j"), modifiers: [.command, .control]), .yellow),
        ], slotCount: 8, source: .builtin)
    }

    public static var safari: RingProfile {
        RingProfile(name: "Safari", bundleId: "com.apple.Safari", category: .browser, slots: browserSlots, slotCount: 8, source: .builtin)
    }

    public static var chrome: RingProfile {
        RingProfile(name: "Chrome", bundleId: "com.google.Chrome", category: .browser, slots: browserSlots, slotCount: 8, source: .builtin)
    }

    public static var arc: RingProfile {
        RingProfile(name: "Arc", bundleId: "company.thebrowser.Browser", category: .browser, slots: [
            slot(0, "Address Bar", "location.fill", key("l", [.command]), .blue),
            slot(1, "New Tab", "plus.square", key("t", [.command]), .green),
            slot(2, "Little Arc", "macwindow.on.rectangle", key("n", [.option, .command]), .teal),
            slot(3, "Find", "magnifyingglass", key("f", [.command]), .indigo),
            slot(4, "Back", "chevron.left", .keyboardShortcut(.character("["), modifiers: [.command]), .gray),
            slot(5, "Forward", "chevron.right", .keyboardShortcut(.character("]"), modifiers: [.command]), .gray),
            slot(6, "Reload", "arrow.clockwise", key("r", [.command]), .orange),
            slot(7, "Close Tab", "xmark.square", key("w", [.command]), .red),
        ], slotCount: 8, source: .builtin)
    }

    public static var figma: RingProfile {
        RingProfile(name: "Figma", bundleId: "com.figma.Desktop", category: .design, slots: [
            slot(0, "Frame", "rectangle.dashed", .keyboardShortcut(.character("a"), modifiers: []), .blue),
            slot(1, "Rectangle", "rectangle", .keyboardShortcut(.character("r"), modifiers: []), .teal),
            slot(2, "Text", "textformat", .keyboardShortcut(.character("t"), modifiers: []), .indigo),
            slot(3, "Pen", "scribble", .keyboardShortcut(.character("p"), modifiers: []), .purple),
            slot(4, "Components", "square.on.square", key("k", [.option, .command]), .pink),
            slot(5, "Group", "square.stack.3d.up", key("g", [.command]), .orange),
            slot(6, "Export", "square.and.arrow.up", key("e", [.command, .shift]), .green),
            slot(7, "Zoom to Fit", "arrow.up.left.and.arrow.down.right", .keyboardShortcut(.character("1"), modifiers: [.shift]), .yellow),
        ], slotCount: 8, source: .builtin)
    }

    public static var terminal: RingProfile {
        RingProfile(name: "Terminal", bundleId: "com.apple.Terminal", category: .terminal, slots: terminalSlots, slotCount: 8, source: .builtin)
    }

    public static var iterm: RingProfile {
        RingProfile(name: "iTerm2", bundleId: "com.googlecode.iterm2", category: .terminal, slots: terminalSlots, slotCount: 8, source: .builtin)
    }

    public static var slack: RingProfile {
        RingProfile(name: "Slack", bundleId: "com.tinyspeck.slackmacgap", category: .communication, slots: [
            slot(0, "Quick Switcher", "arrow.left.arrow.right", key("k", [.command]), .blue),
            slot(1, "Search", "magnifyingglass", key("g", [.command]), .indigo),
            slot(2, "Unreads", "envelope.badge", .keyboardShortcut(.character("a"), modifiers: [.command, .shift]), .orange),
            slot(3, "Threads", "bubble.left.and.bubble.right", .keyboardShortcut(.character("t"), modifiers: [.command, .shift]), .teal),
            slot(4, "Mark Read", "checkmark.circle", .keyboardShortcut(.special(.escape), modifiers: [.shift]), .green),
            slot(5, "Edit Last", "pencil", .keyboardShortcut(.special(.upArrow), modifiers: []), .yellow),
            slot(6, "DMs", "person.2.fill", .keyboardShortcut(.character("k"), modifiers: [.command, .shift]), .pink),
            slot(7, "Preferences", "gearshape", .keyboardShortcut(.character(","), modifiers: [.command]), .gray),
        ], slotCount: 8, source: .builtin)
    }

    public static var notion: RingProfile {
        RingProfile(name: "Notion", bundleId: "notion.id", category: .productivity, slots: [
            slot(0, "Search", "magnifyingglass", key("p", [.command]), .indigo),
            slot(1, "New Page", "doc.badge.plus", key("n", [.command]), .green),
            slot(2, "Quick Find", "bolt.fill", key("k", [.command]), .yellow),
            slot(3, "Bold", "bold", key("b", [.command]), .gray),
            slot(4, "Toggle Sidebar", "sidebar.left", .keyboardShortcut(.character("\\"), modifiers: [.command]), .blue),
            slot(5, "Back", "chevron.left", .keyboardShortcut(.character("["), modifiers: [.command]), .teal),
            slot(6, "Forward", "chevron.right", .keyboardShortcut(.character("]"), modifiers: [.command]), .teal),
            slot(7, "Dark Mode", "moon.fill", .keyboardShortcut(.character("l"), modifiers: [.command, .shift]), .purple),
        ], slotCount: 8, source: .builtin)
    }

    public static var obsidian: RingProfile {
        RingProfile(name: "Obsidian", bundleId: "md.obsidian", category: .productivity, slots: [
            slot(0, "Command Palette", "command", key("p", [.command]), .purple),
            slot(1, "Quick Switcher", "arrow.left.arrow.right", key("o", [.command]), .blue),
            slot(2, "Search", "magnifyingglass", key("f", [.command, .shift]), .indigo),
            slot(3, "New Note", "doc.badge.plus", key("n", [.command]), .green),
            slot(4, "Graph View", "point.3.connected.trianglepath.dotted", key("g", [.command]), .pink),
            slot(5, "Toggle Edit", "pencil", .keyboardShortcut(.character("e"), modifiers: [.command]), .orange),
            slot(6, "Insert Link", "link", key("k", [.command]), .teal),
            slot(7, "Toggle Sidebar", "sidebar.left", .keyboardShortcut(.character("\\"), modifiers: [.command]), .gray),
        ], slotCount: 8, source: .builtin)
    }

    public static var finder: RingProfile {
        RingProfile(name: "Finder", bundleId: "com.apple.finder", category: .other, slots: [
            slot(0, "New Folder", "folder.badge.plus", key("n", [.command, .shift]), .blue),
            slot(1, "New Window", "macwindow.badge.plus", key("n", [.command]), .teal),
            slot(2, "Get Info", "info.circle", .keyboardShortcut(.character("i"), modifiers: [.command]), .indigo),
            slot(3, "Quick Look", "eye", .keyboardShortcut(.special(.space), modifiers: []), .green),
            slot(4, "Go to Folder", "arrow.right.to.line", .keyboardShortcut(.character("g"), modifiers: [.command, .shift]), .orange),
            slot(5, "Move to Trash", "trash", .keyboardShortcut(.special(.backspace), modifiers: [.command]), .red),
            slot(6, "Rename", "pencil", .keyboardShortcut(.special(.enter), modifiers: []), .yellow),
            slot(7, "Show Hidden", "eye.slash", .keyboardShortcut(.character("."), modifiers: [.command, .shift]), .gray),
        ], slotCount: 8, source: .builtin)
    }

    public static var spotify: RingProfile {
        RingProfile(name: "Spotify", bundleId: "com.spotify.client", category: .media, slots: [
            slot(0, "Play/Pause", "playpause.fill", .systemAction(.mediaPlayPause), .green),
            slot(1, "Next", "forward.fill", .systemAction(.mediaNext), .teal),
            slot(2, "Previous", "backward.fill", .systemAction(.mediaPrevious), .teal),
            slot(3, "Volume Up", "speaker.wave.2.fill", .systemAction(.volumeUp), .blue),
            slot(4, "Volume Down", "speaker.wave.1.fill", .systemAction(.volumeDown), .blue),
            slot(5, "Mute", "speaker.slash.fill", .systemAction(.mute), .gray),
            slot(6, "Search", "magnifyingglass", key("l", [.command]), .indigo),
            slot(7, "Like", "heart.fill", .keyboardShortcut(.character("h"), modifiers: [.option, .shift]), .pink),
        ], slotCount: 8, source: .builtin)
    }

    public static var intellij: RingProfile {
        RingProfile(name: "IntelliJ IDEA", bundleId: "com.jetbrains.intellij", category: .ide, slots: [
            slot(0, "Search Everywhere", "magnifyingglass", .keyboardShortcut(.special(.escape), modifiers: []), .indigo),
            slot(1, "Run", "play.fill", .keyboardShortcut(.character("r"), modifiers: [.control]), .green),
            slot(2, "Debug", "ladybug.fill", .keyboardShortcut(.character("d"), modifiers: [.control]), .red),
            slot(3, "Find in Files", "doc.text.magnifyingglass", key("f", [.command, .shift]), .orange),
            slot(4, "Reformat", "text.alignleft", key("l", [.command, .option]), .teal),
            slot(5, "Go to File", "arrow.right.doc.on.clipboard", key("o", [.command, .shift]), .blue),
            slot(6, "Rename", "pencil", .keyboardShortcut(.special(.f6), modifiers: [.shift]), .yellow),
            slot(7, "Commit", "checkmark.seal", key("k", [.command]), .purple),
        ], slotCount: 8, source: .builtin)
    }

    public static var discord: RingProfile {
        RingProfile(name: "Discord", bundleId: "com.hnc.Discord", category: .communication, slots: [
            slot(0, "Quick Switch", "arrow.left.arrow.right", key("k", [.command]), .blue),
            slot(1, "Search", "magnifyingglass", key("f", [.command]), .indigo),
            slot(2, "Mute Mic", "mic.slash.fill", .keyboardShortcut(.character("m"), modifiers: [.command, .shift]), .red),
            slot(3, "Deafen", "speaker.slash.fill", .keyboardShortcut(.character("d"), modifiers: [.command, .shift]), .orange),
            slot(4, "Mark Read", "checkmark.circle", .keyboardShortcut(.special(.escape), modifiers: [.shift]), .green),
            slot(5, "Prev Channel", "chevron.up", .keyboardShortcut(.special(.upArrow), modifiers: [.option]), .gray),
            slot(6, "Next Channel", "chevron.down", .keyboardShortcut(.special(.downArrow), modifiers: [.option]), .gray),
            slot(7, "Settings", "gearshape", .keyboardShortcut(.character(","), modifiers: [.command]), .teal),
        ], slotCount: 8, source: .builtin)
    }

    public static var zoom: RingProfile {
        RingProfile(name: "Zoom", bundleId: "us.zoom.xos", category: .communication, slots: [
            slot(0, "Mute / Unmute", "mic.slash.fill", .keyboardShortcut(.character("a"), modifiers: [.command, .shift]), .red),
            slot(1, "Start / Stop Video", "video.slash.fill", .keyboardShortcut(.character("v"), modifiers: [.command, .shift]), .orange),
            slot(2, "Share Screen", "rectangle.on.rectangle", .keyboardShortcut(.character("s"), modifiers: [.command, .shift]), .blue),
            slot(3, "Chat", "bubble.left.fill", .keyboardShortcut(.character("h"), modifiers: [.command, .shift]), .teal),
            slot(4, "Participants", "person.2.fill", .keyboardShortcut(.character("u"), modifiers: [.command]), .indigo),
            slot(5, "Record", "record.circle", .keyboardShortcut(.character("r"), modifiers: [.command, .shift]), .pink),
            slot(6, "Raise Hand", "hand.raised.fill", .keyboardShortcut(.character("y"), modifiers: [.option]), .yellow),
            slot(7, "Leave", "phone.down.fill", .keyboardShortcut(.character("w"), modifiers: [.command]), .gray),
        ], slotCount: 8, source: .builtin)
    }

    public static var photoshop: RingProfile {
        RingProfile(name: "Photoshop", bundleId: "com.adobe.Photoshop", category: .design, slots: [
            slot(0, "Brush", "paintbrush.pointed.fill", .keyboardShortcut(.character("b"), modifiers: []), .blue),
            slot(1, "Move", "arrow.up.and.down.and.arrow.left.and.right", .keyboardShortcut(.character("v"), modifiers: []), .teal),
            slot(2, "Marquee", "rectangle.dashed", .keyboardShortcut(.character("m"), modifiers: []), .indigo),
            slot(3, "Eraser", "eraser.fill", .keyboardShortcut(.character("e"), modifiers: []), .orange),
            slot(4, "New Layer", "square.stack.3d.up.badge.a", key("n", [.command, .shift]), .green),
            slot(5, "Deselect", "rectangle.slash", .keyboardShortcut(.character("d"), modifiers: [.command]), .gray),
            slot(6, "Free Transform", "crop.rotate", .keyboardShortcut(.character("t"), modifiers: [.command]), .purple),
            slot(7, "Export As", "square.and.arrow.up", key("w", [.command, .option, .shift]), .pink),
        ], slotCount: 8, source: .builtin)
    }

    public static var warp: RingProfile {
        RingProfile(name: "Warp", bundleId: "dev.warp.Warp-Stable", category: .terminal, slots: terminalSlots, slotCount: 8, source: .builtin)
    }

    public static var linear: RingProfile {
        RingProfile(name: "Linear", bundleId: "com.linear", category: .productivity, slots: [
            slot(0, "Command Menu", "command", .keyboardShortcut(.character("k"), modifiers: [.command]), .purple),
            slot(1, "New Issue", "plus.square.fill", .keyboardShortcut(.character("c"), modifiers: []), .green),
            slot(2, "Search", "magnifyingglass", .keyboardShortcut(.character("/"), modifiers: []), .indigo),
            slot(3, "My Issues", "person.crop.square", .keyboardShortcut(.character("g"), modifiers: []), .blue),
            slot(4, "Assign", "person.fill.badge.plus", .keyboardShortcut(.character("a"), modifiers: []), .teal),
            slot(5, "Set Status", "circle.lefthalf.filled", .keyboardShortcut(.character("s"), modifiers: []), .orange),
            slot(6, "Set Priority", "exclamationmark.triangle", .keyboardShortcut(.character("p"), modifiers: []), .yellow),
            slot(7, "Set Due Date", "calendar", .keyboardShortcut(.character("d"), modifiers: []), .pink),
        ], slotCount: 8, source: .builtin)
    }

    public static var mail: RingProfile {
        RingProfile(name: "Mail", bundleId: "com.apple.mail", category: .communication, slots: [
            slot(0, "New Message", "square.and.pencil", key("n", [.command]), .blue),
            slot(1, "Reply", "arrowshape.turn.up.left.fill", key("r", [.command]), .teal),
            slot(2, "Reply All", "arrowshape.turn.up.left.2.fill", key("r", [.command, .shift]), .indigo),
            slot(3, "Forward", "arrowshape.turn.up.right.fill", key("f", [.command, .shift]), .green),
            slot(4, "Send", "paperplane.fill", .keyboardShortcut(.character("d"), modifiers: [.command, .shift]), .orange),
            slot(5, "Archive", "archivebox.fill", .keyboardShortcut(.character("a"), modifiers: [.control, .command]), .gray),
            slot(6, "Delete", "trash.fill", .keyboardShortcut(.special(.backspace), modifiers: [.command]), .red),
            slot(7, "Search", "magnifyingglass", .keyboardShortcut(.character("f"), modifiers: [.option, .command]), .yellow),
        ], slotCount: 8, source: .builtin)
    }

    // MARK: - Shared slot sets

    private static var browserSlots: [RingSlot] {
        [
            slot(0, "Address Bar", "location.fill", key("l", [.command]), .blue),
            slot(1, "New Tab", "plus.square", key("t", [.command]), .green),
            slot(2, "Reopen Tab", "arrow.uturn.left.square", key("t", [.command, .shift]), .teal),
            slot(3, "Find", "magnifyingglass", key("f", [.command]), .indigo),
            slot(4, "Back", "chevron.left", .keyboardShortcut(.character("["), modifiers: [.command]), .gray),
            slot(5, "Forward", "chevron.right", .keyboardShortcut(.character("]"), modifiers: [.command]), .gray),
            slot(6, "Reload", "arrow.clockwise", key("r", [.command]), .orange),
            slot(7, "Close Tab", "xmark.square", key("w", [.command]), .red),
        ]
    }

    private static var terminalSlots: [RingSlot] {
        [
            slot(0, "New Tab", "plus.square", key("t", [.command]), .green),
            slot(1, "New Window", "macwindow.badge.plus", key("n", [.command]), .teal),
            slot(2, "Split", "rectangle.split.2x1", .keyboardShortcut(.character("d"), modifiers: [.command]), .blue),
            slot(3, "Clear", "clear", key("k", [.command]), .orange),
            slot(4, "Find", "magnifyingglass", key("f", [.command]), .indigo),
            slot(5, "Interrupt (^C)", "stop.circle", .keyboardShortcut(.character("c"), modifiers: [.control]), .red),
            slot(6, "Prev Tab", "chevron.left", .keyboardShortcut(.special(.leftArrow), modifiers: [.command, .shift]), .gray),
            slot(7, "Next Tab", "chevron.right", .keyboardShortcut(.special(.rightArrow), modifiers: [.command, .shift]), .gray),
        ]
    }

    // MARK: - Registries

    /// Every app-specific built-in profile.
    public static var all: [RingProfile] {
        [
            vsCode, cursor, xcode, intellij, safari, chrome, arc, figma, photoshop,
            terminal, iterm, warp, slack, discord, zoom, mail, notion, obsidian,
            linear, finder, spotify,
        ]
    }

    /// Fallback profile per category when no app-specific profile matches.
    public static var categoryDefaults: [AppCategory: RingProfile] {
        [
            .ide: profile("IDE", .ide, vsCode.slots),
            .browser: profile("Browser", .browser, browserSlots),
            .terminal: profile("Terminal", .terminal, terminalSlots),
            .design: profile("Design", .design, figma.slots),
            .productivity: profile("Productivity", .productivity, RingProfile.createDefault().slots),
            .communication: profile("Communication", .communication, slack.slots),
            .media: profile("Media", .media, spotify.slots),
        ]
    }

    private static func profile(_ name: String, _ category: AppCategory, _ slots: [RingSlot]) -> RingProfile {
        RingProfile(name: name, bundleId: nil, category: category, slots: slots, slotCount: 8, source: .builtin)
    }
}
