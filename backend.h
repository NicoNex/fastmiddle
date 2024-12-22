#pragma once

#include "multitouch.h"

struct mt_devices {
	CFMutableArrayRef array;
	CFIndex len;
};

struct fm_state {
	struct mt_devices devices;
	IONotificationPortRef port;
	CFMachPortRef tap_event;
	CFRunLoopSourceRef run_loop_src;
};

struct fm_state new_state();
void run_click_loop(struct fm_state *state);
void stop_click_loop(struct fm_state *state);
void state_cleanup(struct fm_state *state);
