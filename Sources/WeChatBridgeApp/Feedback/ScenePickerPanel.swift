import AppKit
import WeChatBridgeCore
import SwiftUI

/// Lets a group choose one scene or continue without one.
@MainActor
final class ScenePickerPanel {
    enum Answer: Sendable {
        case picked(WeChatScene)
        case cancelled
        case expired
    }

    static let visibleRows = 6
    static let rowHeight: CGFloat = 34
    static let width: CGFloat = 290

    private let state = ScenePickerState()
    private var window: ScenePickerWindow?
    private var pending: CheckedContinuation<Answer, Never>?
    private var scenes: [WeChatScene] = []
    private var deadline: Task<Void, Never>?

    func choose(from scenes: [WeChatScene], place: (NSSize) -> NSRect) async -> Answer {
        await withCheckedContinuation { continuation in
            present(scenes, place: place, continuation: continuation)
        }
    }

    private func present(
        _ scenes: [WeChatScene],
        place: (NSSize) -> NSRect,
        continuation: CheckedContinuation<Answer, Never>
    ) {
        if pending != nil { finish(.cancelled) }
        pending = continuation
        self.scenes = scenes
        state.highlighted = 0
        state.selectedID = nil

        let window = makeWindow()
        self.window = window
        let hosting = ToastHostingView(rootView: view)
        // Match the window's frame, not `measure`'s scratch frame: without an
        // autoresizing mask the content keeps whatever frame it was last laid
        // out at, and the panel ends up drawing a 720pt-wide layout through a
        // 290pt window.
        hosting.translatesAutoresizingMaskIntoConstraints = true
        hosting.autoresizingMask = [.width, .height]
        window.contentView = hosting
        // Size from the content, not from the `height(rows:)` estimate: the
        // header's height depends on the scene's summary length, and the
        // `chrome` constant under-counts it, which squeezed the list shut and
        // left the header clipped to 「每次转发只」.
        //
        // `measure` lays the hosting view out at a wide frame, so the ScrollView
        // inside reports its natural (content) width — 401pt for a long summary,
        // far past the 290pt design width. That width is not a request for a
        // wider window: the list scrolls vertically and truncates horizontally.
        // Only the measured height is used.
        let measured = FloatingCapsule.measure(hosting)
        let size = NSSize(
            width: Self.width,
            height: max(Self.height(rows: scenes.count), measured.height)
        )
        var placed = place(size)
        placed.size.width = Self.width
        placed.size.height = max(placed.size.height, measured.height)
        let screen = FloatingCapsule.visibleFrame(containing: placed.origin)
        placed.origin = FloatingCapsule.clamped(placed, in: screen).origin
        window.setFrame(placed, display: true)
        // Re-measure now that the view is in a window with the real frame:
        // `measure`'s wide scratch frame can report a different height than the
        // 290pt-wide one the panel actually draws at, and the content view is
        // what the user sees, not the scratch.
        let inWindow = hosting.fittingSize
        if inWindow.height > placed.size.height + 0.5 {
            placed.size.height = inWindow.height
            placed.origin = FloatingCapsule.clamped(placed, in: screen).origin
            window.setFrame(placed, display: true)
        }
        window.alphaValue = Motion.systemReducesMotion ? 1 : 0
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        deadline = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(BatchIntent.freshnessWindow * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.finish(.expired)
        }

        guard !Motion.systemReducesMotion else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Motion.panelIn
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }
    }

    private static func height(rows: Int) -> CGFloat {
        let padding = (Space.s + 2) * 2
        let chrome: CGFloat = 66
        let visible = CGFloat(min(max(rows, 1), visibleRows))
        return padding + chrome + rowHeight * visible
    }

    private var view: ScenePickerView {
        ScenePickerView(
            scenes: scenes,
            state: state,
            onToggle: { [weak self] index in self?.toggle(at: index) },
            onConfirm: { [weak self] in self?.finishSelection() },
            onDirect: { [weak self] in self?.finish(.cancelled) }
        )
    }

    private func makeWindow() -> ScenePickerWindow {
        let window = ScenePickerWindow()
        window.onMove = { [weak self] delta in
            guard let self else { return }
            self.state.move(by: delta, count: self.scenes.count)
        }
        window.onConfirm = { [weak self] in
            self?.finishSelection()
        }
        window.onCancel = { [weak self] in self?.finish(.cancelled) }
        return window
    }

    private func toggle(at index: Int) {
        guard scenes.indices.contains(index) else { return }
        let id = scenes[index].id
        state.selectedID = state.selectedID == id ? nil : id
    }

    private func finishSelection() {
        guard let selectedID = state.selectedID,
              let scene = scenes.first(where: { $0.id == selectedID })
        else {
            finish(.cancelled)
            return
        }
        finish(.picked(scene))
    }

    private func finish(_ answer: Answer) {
        guard let continuation = pending else { return }
        pending = nil
        deadline?.cancel()
        deadline = nil
        scenes = []
        state.selectedID = nil
        close()
        continuation.resume(returning: answer)
    }

    private func close() {
        guard let window else { return }
        self.window = nil
        guard !Motion.systemReducesMotion else {
            window.close()
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Motion.toastOut
            window.animator().alphaValue = 0
        } completionHandler: {
            window.close()
        }
    }
}

@MainActor
private final class ScenePickerState: ObservableObject {
    @Published var highlighted = 0
    @Published var selectedID: String?

    func move(by delta: Int, count: Int) {
        guard count > 0 else { return }
        highlighted = min(max(highlighted + delta, 0), count - 1)
    }
}

private final class ScenePickerWindow: NSPanel {
    var onMove: (Int) -> Void = { _ in }
    var onConfirm: () -> Void = {}
    var onCancel: () -> Void = {}

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 290, height: 150),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        FloatingCapsule.configure(self)
        becomesKeyOnlyIfNeeded = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) { onCancel() }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 125: onMove(1)
        case 126: onMove(-1)
        case 36, 76: onConfirm()
        default: super.keyDown(with: event)
        }
    }
}

private struct ScenePickerView: View {
    let scenes: [WeChatScene]
    @ObservedObject var state: ScenePickerState
    let onToggle: (Int) -> Void
    let onConfirm: () -> Void
    let onDirect: () -> Void

    @State private var hovered: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .top, spacing: Space.s) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.text("选择场景"))
                        .font(Typo.paneBodyStrong)
                    Text(L10n.text("每次转发只加载一个场景，也可以直接转发。"))
                        .font(Typo.paneCaption)
                        .foregroundStyle(Theme.inkSecondary)
                }
                Spacer(minLength: 0)
                Button(action: onDirect) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(IconButtonStyle(size: 22, staticFeedback: true))
                .accessibilityLabel(Text(L10n.text("关闭")))
            }
            .padding(.horizontal, Space.xs)
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    LazyVStack(spacing: 1) {
                        ForEach(Array(scenes.enumerated()), id: \.element.id) { index, scene in
                            Button { onToggle(index) } label: {
                                HStack(spacing: Space.s) {
                                    Image(systemName: state.selectedID == scene.id ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(state.selectedID == scene.id ? Theme.brandPrimary : Theme.inkTertiary)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(scene.name)
                                            .font(Typo.paneBodyStrong)
                                            .foregroundStyle(Theme.ink)
                                        Text(scene.summary.isEmpty ? L10n.text("没有一句话说明") : scene.summary)
                                            .font(Typo.paneCaption)
                                            .foregroundStyle(Theme.inkSecondary)
                                            .lineLimit(1)
                                    }
                                    Spacer(minLength: Space.s)
                                }
                                .padding(.horizontal, Space.s)
                                .frame(height: 34)
                                .background(
                                    state.highlighted == index || hovered == index
                                        ? Palette.rowSelected
                                        : Color.clear,
                                    in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainPressButtonStyle(staticFeedback: true))
                            .onHover { hovered = $0 ? index : nil }
                            .id(scene.id)
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .onChange(of: state.highlighted) { _, highlighted in
                    guard scenes.indices.contains(highlighted) else { return }
                    proxy.scrollTo(scenes[highlighted].id, anchor: .center)
                }
            }
            .frame(height: ScenePickerPanel.rowHeight * CGFloat(min(max(scenes.count, 1), ScenePickerPanel.visibleRows)))
            // Clamp the list to the panel's design width. Without this its
            // fittingSize reports the rows' natural width (a long summary is
            // wider than 290pt) and the capsule machinery grows the window
            // sideways off screen. The rows scroll vertically and truncate
            // horizontally, so the fixed width is the intent, not a loss.
            .frame(width: ScenePickerPanel.width - (Space.s + 2) * 2)

            HStack(spacing: Space.s) {
                Button(L10n.text("直接转发"), action: onDirect)
                    .buttonStyle(SettingsActionButtonStyle(width: nil))
                Spacer(minLength: Space.s)
                Button(L10n.text("使用此场景"), action: onConfirm)
                    .buttonStyle(SettingsActionButtonStyle(primary: true, width: nil))
                    .disabled(state.selectedID == nil)
            }
        }
        .padding(Space.s + 2)
        .frame(width: ScenePickerPanel.width)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.panel, style: .continuous)
                .strokeBorder(Palette.hairline, lineWidth: Stroke.hairline)
        )
        .fixedSize()
    }
}
