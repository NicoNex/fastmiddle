#pragma once

#include <ApplicationServices/ApplicationServices.h>
#include <CoreFoundation/CoreFoundation.h>

/*
 * DISCLAIMER:
 * This code uses private, undocumented Multitouch APIs from Apple.
 * These APIs are not guaranteed to work on all versions of macOS.
 * They may change or break without notice, and using them in production
 * or for distribution on the Mac App Store is not allowed.
 *
 * The structure and functions shown here are based on reverse-engineered
 * information available online.
 */

struct mt_point {
	float x;
	float y;
};

struct mt_readout {
	struct mt_point pos; // normalized position
	struct mt_point vel; // velocity
};

struct finger {
	int frame;
	double timestamp;
	int identifier;               // Unique identifier for this finger/touch
	int state;                    // State of the finger (down/moving/up)
	int unknown3;                 // Unknown field (reverse-engineered placeholder)
	int unknown4;                 // Unknown field (reverse-engineered placeholder)
	struct mt_readout normalized; // Normalized coordinates and velocity
	float size;                   // Touch size (major axis of contact?)
	int zero1;                    // Reserved field
	float angle;                  // Angle of the ellipse representing the touch
	float majorAxis;              // Major axis length of the touch ellipse
	float minorAxis;              // Minor axis length of the touch ellipse
	struct mt_readout mm;         // Possibly physical size in millimeters?
	int zero2[2];                 // More reserved fields
	float unknown2;               // Another unknown field
};

// Private API declarations
typedef void* MTDeviceRef;
typedef int (*MTContactCallback)(int, struct finger*, int, double, int);

// Functions from the private Multitouch framework
extern CFMutableArrayRef MTDeviceCreateList(void);
extern void MTRegisterContactFrameCallback(MTDeviceRef, MTContactCallback);
extern void MTDeviceStart(MTDeviceRef, int);
extern void MTDeviceStop(MTDeviceRef);
extern void MTUnregisterContactFrameCallback(MTDeviceRef, MTContactCallback);
extern void MTDeviceRelease(MTDeviceRef);
