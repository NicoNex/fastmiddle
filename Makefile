CC = clang
CFLAGS = -Wall -O2
LDFLAGS = -framework Cocoa -framework IOKit -framework ApplicationServices -framework CoreFoundation -framework MultitouchSupport -F/System/Library/PrivateFrameworks

all: fastmiddle

fastmiddle: main.c
	$(CC) $(CFLAGS) main.c -o fastmiddle $(LDFLAGS)

app: fastmiddle
	mkdir -p FastMiddle.app/Contents/MacOS
	cp Info.plist FastMiddle.app/Contents
	cp fastmiddle FastMiddle.app/Contents/MacOS

clean:
	rm -f fastmiddle
