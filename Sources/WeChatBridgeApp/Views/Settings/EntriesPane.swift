import AppKit
import WeChatBridgeCore
import SwiftUI

/// What the Share menu offers, and the switches that decide which of it shows.
///
/// The list itself is fixed at build time — macOS builds that menu from signed
/// extension bundles — but which entries are live is the user's call, and it is
/// made here rather than three panes deep in System Settings. See
/// `ShareEntryProbe` for why the app is not sandboxed.
struct EntriesPane: View {
    @ObservedObject var targets: ForwardTargets
    @ObservedObject var preferences: Preferences
    @ObservedObject var authorization: AccessibilityAuthorization
    @StateObject private var probe = ShareEntryProbe()
    @State private var configuration: EntryConfiguration?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.section) {
            Text(L10n.text("选择要出现在微信「转发到其他应用」里的操作。"))
                .font(Typo.paneBody)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 460, alignment: .leading)

            // The permission is the one thing every entry below this depends
            // on, and it fails silently: a forward with no Accessibility
            // permission writes the files to the clipboard and reports a
            // failure that reads, from the user's side, as if the switch had
            // done nothing at all. Stating it here, where the switches are,
            // makes the link visible before anything has to fail.
            authorizationNotice

            ShareEntryList(
                probe: probe,
                compactDetails: true,
                obsidianVaultPath: preferences.obsidianVaultPath,
                customTargetCount: targets.targets.count
            ) { action in
                switch action {
                case .obsidian: configuration = .obsidian
                case .custom: configuration = .custom
                default: break
                }
            }

            Button {
                LoginItem.openExtensionsSettings()
            } label: {
                Label(L10n.text("入口没有出现在微信菜单里？"), systemImage: "questionmark.circle")
                    .font(Typo.paneCaption)
                    .foregroundStyle(Theme.systemBlue)
            }
            .buttonStyle(PlainPressButtonStyle(staticFeedback: true))
            .accessibilityIdentifier("entries.system-settings")
        }
        .onAppear { authorization.refresh() }
        .sheet(item: $configuration) { item in
            VStack(alignment: .leading, spacing: Space.xl) {
                HStack {
                    Text(item.title)
                        .font(Typo.paneTitle)
                        .foregroundStyle(Theme.ink)
                    Spacer(minLength: Space.l)
                    Button(L10n.text("完成")) { configuration = nil }
                        .buttonStyle(SettingsActionButtonStyle())
                        .keyboardShortcut(.defaultAction)
                }

                switch item {
                case .obsidian:
                    obsidianSettings
                case .custom:
                    ForwardTargetList(targets: targets)
                }
            }
            .padding(Space.xl)
            .frame(width: 540)
            .frame(minHeight: 220, alignment: .topLeading)
        }
        .onAppear { probe.refresh() }
        // The entries can still be changed in System Settings, and the user
        // comes straight back afterwards, so this is re-read on every
        // activation rather than once. The permission is re-read on the same
        // beat for the same reason: it is granted in System Settings too.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            probe.refresh()
            authorization.refresh()
        }
    }

    /// The status of the one permission every switch on this pane needs.
    ///
    /// Shown in both states — granted as well as missing — because this row is
    /// where the user looks to explain why pasting does not work, and a row that
    /// only appears when something is wrong reads the same as an unasked
    /// question.
    @ViewBuilder
    private var authorizationNotice: some View {
        if authorization.isTrusted {
            Notice(L10n.text("已授权"), tone: .good)
                .frame(maxWidth: 460)
        } else {
            Notice(text: L10n.text("自动粘贴需要辅助功能权限。"), tone: .warn) {
                Button(L10n.text("去授权")) { authorization.guideIfNeeded() }
                    .buttonStyle(SettingsActionButtonStyle())
            }
            .frame(maxWidth: 460)
        }
    }

    private var obsidianSettings: some View {
        VStack(spacing: 0) {
            SettingRow(
                title: L10n.text("知识库文件夹"),
                detail: preferences.obsidianVaultPath.map {
                    URL(fileURLWithPath: $0, isDirectory: true).lastPathComponent
                } ?? L10n.text("尚未选择"),
                alignment: .center
            ) {
                HStack(spacing: Space.s) {
                    if let path = preferences.obsidianVaultPath {
                        Button(L10n.text("在 Finder 中显示")) {
                            NSWorkspace.shared.activateFileViewerSelecting([
                                URL(fileURLWithPath: path, isDirectory: true)
                            ])
                        }
                        .buttonStyle(SettingsActionButtonStyle())
                    }
                    Button(L10n.text("选择文件夹…")) { chooseObsidianVault() }
                        .buttonStyle(SettingsActionButtonStyle())
                }
            }
            .padding(Space.m)

            Rectangle()
                .fill(Theme.stroke)
                .frame(height: Stroke.hairline)
                .padding(.leading, Space.m)

            SettingRow(
                title: L10n.text("子文件夹"),
                detail: L10n.text("聊天 Markdown 与原始 ZIP 会写入这个目录。"),
                alignment: .center
            ) {
                TextField(L10n.text("子文件夹"), text: $preferences.obsidianSubfolder)
                    .textFieldStyle(SettingsTextFieldStyle())
                    .frame(width: SettingsControlMetrics.actionWidth)
            }
            .padding(Space.m)
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: Stroke.hairline)
        )
    }

    private func chooseObsidianVault() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = L10n.text("选择知识库")
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        preferences.obsidianVaultPath = folder.path
    }
}

private enum EntryConfiguration: String, Identifiable {
    case obsidian
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .obsidian: L10n.text("Obsidian 沉淀")
        case .custom: L10n.text("「发送到自定义」的应用")
        }
    }
}
