import ServiceManagement
import SwiftUI

// MARK: - FastMiddle
/// A class responsible for:
/// 1) Handling a background loop that enables three-finger click -> middle click.
/// 2) Exposing an `isEnabled` property to SwiftUI (via @Published).
final class FastMiddle: ObservableObject {
	// MARK: - Low-Level C State & Background Queue

	/// Pointer to the underlying state structure in C.
	private var state: UnsafeMutablePointer<fm_state>

	/// A background queue running the trackpad/mouse handling loop.
	private var runQueue: DispatchQueue?

	/// Indicates whether the loop is currently active.
	private var isRunning: Bool = false

	// MARK: - Published Property for SwiftUI

	/**
     Reflects whether the middle-click emulation is currently enabled.
     Setting this to `true` starts the loop (if not already running),
     and setting it to `false` stops the loop (if running).
     */
	@Published var isEnabled: Bool = true {
		didSet {
			if isEnabled {
				start()
			} else {
				stop()
			}
		}
	}

	// MARK: - Initialization & Deinitialization

	init() {
		// Allocate and initialize the fm_state pointer
		state = UnsafeMutablePointer<fm_state>.allocate(capacity: 1)
		state.initialize(to: new_state())

		// If default isEnabled == true, start immediately
		if isEnabled {
			start()
		}
	}

	deinit {
		// Ensure we stop before deallocation
		isRunning = false
		state_cleanup(state)
		state.deinitialize(count: 1)
		state.deallocate()
	}

	// MARK: - Start/Stop Methods

	/**
     Starts the middle-click emulation loop on a background queue if not already running.
     */
	func start() {
		guard !isRunning else { return }
		isRunning = true

		runQueue = DispatchQueue(label: "fastmiddle.loop.queue", qos: .background)
		runQueue?.async { [weak self] in
			guard let self = self else { return }
			run_click_loop(self.state)
		}
	}

	/**
     Stops the middle-click emulation loop if it is currently running.
     */
	func stop() {
		guard isRunning else { return }
		isRunning = false
		stop_click_loop(state)
	}
}

// MARK: - HoverLineHighlightButtonStyle
/// A ButtonStyle that highlights the entire row on hover using a subtle system gray color.
struct HoverLineHighlightButtonStyle: ButtonStyle {
	func makeBody(configuration: Configuration) -> some View {
		HoveringRow(configuration: configuration)
	}

	private struct HoveringRow: View {
		let configuration: Configuration
		@State private var isHovered = false

		var body: some View {
			HStack {
				configuration.label
				Spacer()
			}
			.padding(.horizontal, 6)
			.padding(.vertical, 2)
			.background(
				isHovered
					? Color(nsColor: .unemphasizedSelectedTextBackgroundColor)
					: Color.clear
			)
			.cornerRadius(6)
			.foregroundColor(.primary)
			.onHover { hover in
				isHovered = hover
			}
		}
	}
}

// MARK: - FastMiddleApp
@main
struct FastMiddleApp: App {
	// Now we only have a single class, so let's name it fastMiddle
	@StateObject private var fastMiddle = FastMiddle()
	@State private var launchAtLoginEnabled: Bool = false

	init() {
		// Check if the app is already set to launch at login
		launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
	}

	var body: some Scene {
		MenuBarExtra("FastMiddle", systemImage: "computermouse.fill") {
			VStack(alignment: .leading) {
				// Single-line label + toggle
				HStack {
					Text("FastMiddle")
						.font(.body)
						.bold()

					Spacer()

					Toggle("", isOn: $fastMiddle.isEnabled)
						.toggleStyle(.switch)
						.tint(.accentColor)  // Use system accent color (macOS 11+)
				}

				Toggle("Launch at Login", isOn: $launchAtLoginEnabled)
					.onChange(of: launchAtLoginEnabled) { _, newValue in
						if newValue {
							enableLaunchAtLogin()
						} else {
							disableLaunchAtLogin()
						}
					}

				Divider()

				// About button, providing info via an NSAlert
				Button("About") {
					NSApplication.shared.activate(ignoringOtherApps: true)
					let alert = NSAlert()
					alert.messageText = "FastMiddle"
					alert.informativeText =
						"""
						This app enables 3-finger click to emulate middle-click on your trackpad or Magic Mouse.
						Source code at: github.com/NicoNex/fastmiddle
						"""
					alert.alertStyle = .informational
					alert.addButton(withTitle: "OK")
					alert.runModal()
				}
				.buttonStyle(HoverLineHighlightButtonStyle())

				// Quit button
				Button("Quit") {
					fastMiddle.stop()
					NSApp.terminate(nil)
				}
				.buttonStyle(HoverLineHighlightButtonStyle())
			}
			.padding()
		}
		// For macOS 14+, ensures the toggle is interactive
		.menuBarExtraStyle(.window)
	}

	private func enableLaunchAtLogin() {
		do {
			try SMAppService.mainApp.register()
			print("App registered to launch at login.")
		} catch {
			print("Failed to register app for login: \(error.localizedDescription)")
		}
	}

	private func disableLaunchAtLogin() {
		do {
			try SMAppService.mainApp.unregister()
			print("App unregistered from launching at login.")
		} catch {
			print("Failed to unregister app from login: \(error.localizedDescription)")
		}
	}
}
