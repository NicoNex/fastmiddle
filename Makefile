CC = clang
CFLAGS = -Wall -O2
LDFLAGS = -framework IOKit -framework ApplicationServices -framework MultitouchSupport -F/System/Library/PrivateFrameworks

all: fastmiddle

.PHONY: all fastmiddle app backend

fastmiddle:
	swiftc -parse-as-library -import-objc-header backend.h fastmiddle.swift backend.c -o fastmiddle $(LDFLAGS)

backend:
	clang $(CFLAGS) -DSTANDALONE backend.c -o fastmiddle $(LDFLAGS)

app: fastmiddle
	mkdir -p FastMiddle.app/Contents/MacOS
	cp Info.plist FastMiddle.app/Contents
	cp fastmiddle FastMiddle.app/Contents/MacOS

clean:
	rm -f fastmiddle
