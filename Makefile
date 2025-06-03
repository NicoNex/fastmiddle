CC = clang
CFLAGS = -Wall -O2
LDFLAGS = -framework IOKit -framework ApplicationServices -framework ServiceManagement -framework MultitouchSupport -F/System/Library/PrivateFrameworks

all: fastmiddle

.PHONY: all fastmiddle app backend dmg

fastmiddle:
	swiftc -parse-as-library -import-objc-header backend.h fastmiddle.swift backend.c -o fastmiddle $(LDFLAGS)

backend:
	clang $(CFLAGS) -DSTANDALONE backend.c -o fastmiddle $(LDFLAGS)

app: fastmiddle
	mkdir -p /tmp/FastMiddle.app/Contents/MacOS /tmp/FastMiddle.app/Contents/Resources
	cp Info.plist /tmp/FastMiddle.app/Contents
	cp fastmiddle /tmp/FastMiddle.app/Contents/MacOS
	# iconutil -c icns --output /tmp/FastMiddle.app/Contents/Resources/FastMiddle.icns FastMiddle.iconset
	cp fastmiddle.icns /tmp/FastMiddle.app/Contents/Resources/FastMiddle.icns
	xattr -rc /tmp/FastMiddle.app
	codesign --force --deep --sign - /tmp/FastMiddle.app
	cp -r /tmp/FastMiddle.app .

dmg: app
	mkdir FastMiddleApp
	mv /tmp/FastMiddle.app FastMiddleApp
	ln -s /Applications FastMiddleApp/Applications
	hdiutil create -volname "FastMiddle" -srcfolder "FastMiddleApp" -ov -format UDZO "FastMiddle.dmg"

clean:
	rm -rf fastmiddle /tmp/FastMiddle.app /tmp/FastMiddle.dmg /tmp/FastMiddleApp
