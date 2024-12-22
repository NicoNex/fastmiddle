#include <IOKit/IOKitLib.h>
#include <IOKit/IOTypes.h>
#include <stdio.h>
#include <stdlib.h>

#include "multitouch.h"
#include "backend.h"

// Global variable to track the current number of fingers touching the trackpad
static int current_fingers = 0;

static inline int touch_callback(int device, struct finger *fingers, int nFingers, double timestamp, int frame) {
	current_fingers = nFingers;
	return 0;
}

static CGEventRef mouse_callback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
	static bool is_middle_click = false;

	if (current_fingers != 3 && !is_middle_click) {
		return event;
	}

	switch (type) {
	case kCGEventLeftMouseDown:
		// Convert the event to a middle-click down event
		CGEventSetType(event, kCGEventOtherMouseDown);
		CGEventSetIntegerValueField(event, kCGMouseEventButtonNumber, kCGMouseButtonCenter);
		is_middle_click = true;
		break;

	case kCGEventLeftMouseUp:
		// Convert the left mouse up to a middle mouse up
		CGEventSetType(event, kCGEventOtherMouseUp);
		CGEventSetIntegerValueField(event, kCGMouseEventButtonNumber, kCGMouseButtonCenter);
		is_middle_click = false;
		break;
	}

	return event;
}

static struct mt_devices multitouch_devices() {
	// Attempt to create a list of multitouch devices
	CFMutableArrayRef devices = MTDeviceCreateList();
	if (devices == NULL) {
		fprintf(stderr, "Failed to create device list. No multitouch device found.\n");
		exit(1);
	}

	CFIndex count = CFArrayGetCount(devices);
	if (count == 0) {
		fprintf(stderr, "No Multitouch devices found.\n");
		CFRelease(devices);
		exit(1);
	}

	return (struct mt_devices) {
		.array = devices,
		.len = count
	};
}

static inline void devices_register(struct mt_devices devices, MTContactCallback callback) {
	for (CFIndex i = 0; i < devices.len; i++) {
		MTDeviceRef device = (MTDeviceRef)CFArrayGetValueAtIndex(devices.array, i);
		if (device != NULL) {
			MTRegisterContactFrameCallback(device, touch_callback);
			MTDeviceStart(device, 0);
		}
	}
}

static inline void devices_cleanup(struct mt_devices devices) {
	for (CFIndex i = 0; i < devices.len; i++) {
		MTDeviceRef device = (MTDeviceRef)CFArrayGetValueAtIndex(devices.array, i);
		if (device != NULL) {
			MTUnregisterContactFrameCallback(device, touch_callback);
			MTDeviceStop(device);
			MTDeviceRelease(device);
		}
	}
}

static inline void devices_refresh(struct mt_devices *devices) {
	devices_cleanup(*devices);
	*devices = multitouch_devices();
	devices_register(*devices, touch_callback);
}

static void device_notification_callback(void *refcon, io_iterator_t iter) {
	devices_refresh((struct mt_devices *) refcon);
}

static inline void stop_io_notifications(struct fm_state *state) {
	if (state->port != NULL) {
		IONotificationPortDestroy(state->port);
		state->port = NULL;
	}
}

static inline kern_return_t listen_io_notification(struct fm_state *state) {
	state->port = IONotificationPortCreate(kIOMainPortDefault);

	// Set up device notifications
	CFRunLoopAddSource(
		CFRunLoopGetMain(),
		IONotificationPortGetRunLoopSource(state->port),
		kCFRunLoopDefaultMode
	);

	io_iterator_t iterator;
	kern_return_t kres = IOServiceAddMatchingNotification(
		state->port,
		kIOFirstMatchNotification,
		IOServiceMatching("AppleMultitouchDevice"),
		device_notification_callback,
		&state->devices,
		&iterator
	);

	if (kres == KERN_SUCCESS) {
		io_object_t item;
		while ((item = IOIteratorNext(iterator))) {
			IOObjectRelease(item);
		}
	}
	return kres;
}

void stop_click_loop(struct fm_state *state) {
	if (state->tap_event != NULL) {
		CGEventTapEnable(state->tap_event, false);
		CFRelease(state->tap_event);
		state->tap_event = NULL;
	}
	if (state->run_loop_src != NULL) {
		CFRunLoopRemoveSource(CFRunLoopGetCurrent(), state->run_loop_src, kCFRunLoopCommonModes);
		CFRelease(state->run_loop_src);
	}
}

static int listen_click_loop(struct fm_state *state) {
	for (int i = 0; state->tap_event == NULL && i < 300; i++) {
		// Create a global event tap to listen for left mouse down and up events
		state->tap_event = CGEventTapCreate(
			kCGHIDEventTap,
			kCGHeadInsertEventTap,
			kCGEventTapOptionDefault,
			(1 << kCGEventLeftMouseDown) | (1 << kCGEventLeftMouseUp),
			mouse_callback,
			NULL
		);
		if (state->tap_event == NULL) {
			sleep(1);
		}
	}

	if (state->tap_event == NULL) {
		fputs("Failed to create event tap. Check accessibility permissions.", stderr);
		return 1;
	}

	// Add the event tap to the current run loop
	state->run_loop_src = CFMachPortCreateRunLoopSource(NULL, state->tap_event, 0);
	if (state->run_loop_src == NULL) {
		fputs("Failed to create run loop source.", stderr);
		return 1;
	}

	CFRunLoopAddSource(CFRunLoopGetCurrent(), state->run_loop_src, kCFRunLoopCommonModes);
	CGEventTapEnable(state->tap_event, true);
	// Run the main loop to start receiving events
	CFRunLoopRun();

	// If for some reason the main loop returns we cleanup the registered events.
	stop_click_loop(state);
	return 0;
}

struct fm_state new_state() {
	return (struct fm_state) {.devices = multitouch_devices()};
}

void run_click_loop(struct fm_state *state) {
	devices_register(state->devices, touch_callback);

	if (listen_io_notification(state) != KERN_SUCCESS) {
		fputs("Failed to add device notification.", stderr);
		stop_io_notifications(state);
		devices_cleanup(state->devices);
		return;
	}

	for (;;) {
		if (listen_click_loop(state) != 0) {
			devices_cleanup(state->devices);
			stop_io_notifications(state);
			return;
		}
	}
}

void state_cleanup(struct fm_state *state) {
	stop_io_notifications(state);
	stop_click_loop(state);
	devices_cleanup(state->devices);
}

// int main() {
// 	struct fm_state state = new_state();

// 	run_click_loop(&state);
// 	state_cleanup(&state);
// }
