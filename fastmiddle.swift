import ServiceManagement
import SwiftUI

// MARK: - Permissions

/// Requests accessibility permissions from the user if not already granted.
/// This is required for the app to detect and emulate mouse clicks.
func askPermissions() {
	let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary

	guard !AXIsProcessTrustedWithOptions(options) else { return }

	// Open System Settings to Privacy & Security → Input Monitoring
	let privacyURLString = "x-apple.systempreferences:com.apple.preference.security?Privacy_InputMonitoring"
	if let url = URL(string: privacyURLString) {
		NSWorkspace.shared.open(url)
	}
}

// MARK: - FastMiddle

/// Manages the middle-click emulation functionality.
///
/// This class:
/// - Handles a background loop that enables three-finger click → middle click
/// - Exposes an `isEnabled` property to SwiftUI via `@Published`
/// - Manages C-level state for trackpad/mouse event handling
final class FastMiddle: ObservableObject {
	// MARK: - Constants

	private enum Constants {
		static let queueLabel = "com.fastmiddle.loop.queue"
	}

	// MARK: - Properties

	/// Pointer to the underlying state structure in C
	private var state: UnsafeMutablePointer<fm_state>

	/// Background queue running the trackpad/mouse handling loop
	private var runQueue: DispatchQueue?

	/// Indicates whether the loop is currently active
	private var isRunning = false

	/// Reflects whether middle-click emulation is currently enabled.
	///
	/// Setting this to `true` starts the loop (if not already running).
	/// Setting this to `false` stops the loop (if running).
	@Published var isEnabled = true {
		didSet {
			isEnabled ? start() : stop()
		}
	}

	// MARK: - Lifecycle

	init() {
		state = UnsafeMutablePointer<fm_state>.allocate(capacity: 1)
		state.initialize(to: new_state())
		askPermissions()

		if isEnabled {
			start()
		}
	}

	deinit {
		isRunning = false
		state_cleanup(state)
		state.deinitialize(count: 1)
		state.deallocate()
	}

	// MARK: - Public Methods

	/// Starts the middle-click emulation loop on a background queue if not already running.
	func start() {
		guard !isRunning else { return }
		isRunning = true

		runQueue = DispatchQueue(label: Constants.queueLabel, qos: .userInitiated)
		runQueue?.async { [weak self] in
			guard let self else { return }
			run_click_loop(self.state)
		}
	}

	/// Stops the middle-click emulation loop if it is currently running.
	func stop() {
		guard isRunning else { return }
		isRunning = false
		stop_click_loop(state)
	}
}

// MARK: - ModernButtonStyle

/// A modern button style with subtle hover effects and glass morphism design.
struct ModernButtonStyle: ButtonStyle {
	// MARK: - Constants

	private enum Constants {
		static let cornerRadius: CGFloat = 8
		static let horizontalPadding: CGFloat = 12
		static let verticalPadding: CGFloat = 8
		static let backgroundOpacity: CGFloat = 0.1
		static let strokeOpacity: CGFloat = 0.2
		static let strokeWidth: CGFloat = 0.5
		static let pressedScale: CGFloat = 0.98
		static let hoverAnimationDuration: CGFloat = 0.15
		static let pressAnimationDuration: CGFloat = 0.1
	}

	// MARK: - Properties

	private let accentColor: Color?

	// MARK: - Initialization

	init(accentColor: Color? = nil) {
		self.accentColor = accentColor
	}

	func makeBody(configuration: Configuration) -> some View {
		ModernButtonView(configuration: configuration, accentColor: accentColor)
	}

	// MARK: - ModernButtonView

	private struct ModernButtonView: View {
		let configuration: Configuration
		let accentColor: Color?
		@State private var isHovered = false

		private var effectiveAccentColor: Color {
			accentColor ?? .accentColor
		}

		var body: some View {
			HStack {
				configuration.label
				Spacer()
			}
			.padding(.horizontal, Constants.horizontalPadding)
			.padding(.vertical, Constants.verticalPadding)
			.background(backgroundView)
			.foregroundColor(isHovered ? effectiveAccentColor : .primary)
			.animation(.easeInOut(duration: Constants.hoverAnimationDuration), value: isHovered)
			.onHover { isHovered = $0 }
			.scaleEffect(configuration.isPressed ? Constants.pressedScale : 1.0)
			.animation(.easeInOut(duration: Constants.pressAnimationDuration), value: configuration.isPressed)
		}

		@ViewBuilder
		private var backgroundView: some View {
			if isHovered {
				RoundedRectangle(cornerRadius: Constants.cornerRadius)
					.fill(effectiveAccentColor.opacity(Constants.backgroundOpacity))
					.overlay(
						RoundedRectangle(cornerRadius: Constants.cornerRadius)
							.stroke(effectiveAccentColor.opacity(Constants.strokeOpacity), lineWidth: Constants.strokeWidth)
					)
			} else {
				RoundedRectangle(cornerRadius: Constants.cornerRadius)
					.fill(Color.clear)
			}
		}
	}
}

// MARK: - GlassCard

/// A container view that provides a liquid glass effect with translucent blur.
struct GlassCard<Content: View>: View {
	// MARK: - Properties

	private let content: Content

	// MARK: - Initialization

	init(@ViewBuilder content: () -> Content) {
		self.content = content()
	}

	// MARK: - Body

	var body: some View {
		content
			.padding(16)
			.background(
				RoundedRectangle(cornerRadius: 16)
					.fill(.ultraThinMaterial)
					.shadow(
						color: Color.black.opacity(0.1),
						radius: 20,
						x: 0,
						y: 10
					)
			)
	}
}

// MARK: - AboutView

/// The About window content following macOS design guidelines.
struct AboutView: View {
	// MARK: - Constants

	private enum Constants {
		static let appName = "FastMiddle"
		static let version = "1.0"
		static let iconSize: CGFloat = 128
		static let windowWidth: CGFloat = 400
		static let verticalSpacing: CGFloat = 16
		static let titleFontSize: CGFloat = 24
		static let versionFontSize: CGFloat = 13
		static let descriptionFontSize: CGFloat = 13
		static let linkFontSize: CGFloat = 13
		static let githubURL = "https://github.com/NicoNex/fastmiddle"
		static let copyrightYear = "2025"
	}

	// MARK: - Environment

	@Environment(\.dismiss) private var dismiss

	// MARK: - Body

	var body: some View {
		VStack(spacing: Constants.verticalSpacing) {
			// App Icon
			Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
				.resizable()
				.frame(width: Constants.iconSize, height: Constants.iconSize)
				.padding(.top, 20)

			// App Name
			Text(Constants.appName)
				.font(.system(size: Constants.titleFontSize, weight: .medium))

			// Version
			Text("Version \(Constants.version)")
				.font(.system(size: Constants.versionFontSize))
				.foregroundColor(.secondary)

			Divider()
				.padding(.horizontal, 40)

			// Description
			Text("Enable 3-finger click to emulate middle-click\non your trackpad or Magic Mouse")
				.font(.system(size: Constants.descriptionFontSize))
				.foregroundColor(.secondary)
				.multilineTextAlignment(.center)
				.fixedSize(horizontal: false, vertical: true)

			// GitHub Link
			Link("github.com/NicoNex/fastmiddle", destination: URL(string: Constants.githubURL)!)
				.font(.system(size: Constants.linkFontSize))

			// Copyright
			Text("Copyright © \(Constants.copyrightYear) NicoNex")
				.font(.system(size: 11))
				.foregroundColor(.secondary)
				.padding(.bottom, 20)

			// Close Button
			Button("OK") {
				dismiss()
			}
			.keyboardShortcut(.defaultAction)
			.controlSize(.large)
			.padding(.bottom, 16)
		}
		.frame(width: Constants.windowWidth)
		.background(Color(NSColor.windowBackgroundColor))
	}
}

// MARK: - FastMiddleApp

@main
struct FastMiddleApp: App {
	// MARK: - Constants

	private enum Constants {
		static let appName = "FastMiddle"
		static let menuBarIcon = "computermouse.fill"
		static let subtitle = "3-finger middle click"
		static let minWindowWidth: CGFloat = 280
		static let contentPadding: CGFloat = 16
		static let verticalSpacing: CGFloat = 12
		static let dividerPadding: CGFloat = 4
		static let headerSpacing: CGFloat = 2
		static let headerBottomPadding: CGFloat = 4
		static let titleFontSize: CGFloat = 16
		static let subtitleFontSize: CGFloat = 11
	}

	// MARK: - Properties

	@StateObject private var fastMiddle = FastMiddle()
	@State private var launchAtLoginEnabled = false

	// MARK: - Initialization

	init() {
		_launchAtLoginEnabled = State(initialValue: SMAppService.mainApp.status == .enabled)
	}

	// MARK: - Body

	var body: some Scene {
		MenuBarExtra(Constants.appName, systemImage: Constants.menuBarIcon) {
			VStack(alignment: .leading, spacing: Constants.verticalSpacing) {
				headerView
				Divider().padding(.vertical, Constants.dividerPadding)
				launchAtLoginToggle
				Divider().padding(.vertical, Constants.dividerPadding)
				aboutButton
				quitButton
			}
			.padding(Constants.contentPadding)
			.frame(minWidth: Constants.minWindowWidth)
		}
		.menuBarExtraStyle(.window)

		Window("About FastMiddle", id: "about") {
			AboutView()
		}
		.windowStyle(.hiddenTitleBar)
		.windowResizability(.contentSize)
		.defaultPosition(.center)
	}

	// MARK: - Subviews

	private var headerView: some View {
		HStack {
			VStack(alignment: .leading, spacing: Constants.headerSpacing) {
				Text(Constants.appName)
					.font(.system(size: Constants.titleFontSize, weight: .semibold))
				Text(Constants.subtitle)
					.font(.system(size: Constants.subtitleFontSize))
					.foregroundColor(.secondary)
			}

			Spacer()

			Toggle("", isOn: $fastMiddle.isEnabled)
				.toggleStyle(.switch)
				.controlSize(.regular)
		}
		.padding(.bottom, Constants.headerBottomPadding)
	}

	private var launchAtLoginToggle: some View {
		HStack {
			Text("Launch at Login")
			Spacer()
			Toggle("", isOn: $launchAtLoginEnabled)
				.toggleStyle(.switch)
				.controlSize(.small)
		}
		.onAppear {
			launchAtLoginEnabled = isLaunchAtLoginEnabled()
		}
		.onChange(of: launchAtLoginEnabled) { _, newValue in
			handleLaunchAtLoginChange(newValue)
		}
	}

	private var aboutButton: some View {
		AboutButtonView()
	}

	private struct AboutButtonView: View {
		@Environment(\.openWindow) private var openWindow

		var body: some View {
			Button("About") {
				NSApplication.shared.activate(ignoringOtherApps: true)
				openWindow(id: "about")
			}
			.buttonStyle(ModernButtonStyle())
		}
	}

	private var quitButton: some View {
		Button("Quit") {
			fastMiddle.stop()
			NSApp.terminate(nil)
		}
		.buttonStyle(ModernButtonStyle(accentColor: .red))
	}

	// MARK: - Private Methods

	private func handleLaunchAtLoginChange(_ enabled: Bool) {
		enabled ? enableLaunchAtLogin() : disableLaunchAtLogin()
	}

	private func enableLaunchAtLogin() {
		do {
			try SMAppService.mainApp.register()
		} catch {
			NSLog("Failed to register app for login: %@", error.localizedDescription)
		}
	}

	private func disableLaunchAtLogin() {
		do {
			try SMAppService.mainApp.unregister()
		} catch {
			NSLog("Failed to unregister app from login: %@", error.localizedDescription)
		}
	}

	private func isLaunchAtLoginEnabled() -> Bool {
		SMAppService.mainApp.status == .enabled
	}
}
