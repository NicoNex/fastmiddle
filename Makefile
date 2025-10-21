# Compiler settings
CC = clang
SWIFTC = swiftc
CFLAGS = -Wall -O2
LDFLAGS = -framework IOKit -framework ApplicationServices -framework ServiceManagement \
          -framework MultitouchSupport -F/System/Library/PrivateFrameworks

# Build directories
TMP_DIR = /tmp/fastmiddle-build
TMP_BINARY = $(TMP_DIR)/fastmiddle
TMP_APP_DIR = $(TMP_DIR)/FastMiddle.app
TMP_DMG_DIR = $(TMP_DIR)/dmg

# Output artifacts (in working directory)
BINARY = fastmiddle
APP_BUNDLE = FastMiddle.app
DMG_FILE = FastMiddle.dmg

# Source files
SWIFT_SOURCES = fastmiddle.swift
C_SOURCES = backend.c
HEADERS = backend.h

.PHONY: all clean app dmg backend install

all: $(BINARY)

# Build the main Swift binary
$(BINARY): $(SWIFT_SOURCES) $(C_SOURCES) $(HEADERS)
	@mkdir -p $(TMP_DIR)
	$(SWIFTC) -parse-as-library -import-objc-header $(HEADERS) \
		$(SWIFT_SOURCES) $(C_SOURCES) -o $(TMP_BINARY) $(LDFLAGS)
	@cp $(TMP_BINARY) $(BINARY)

# Build C-only backend (for testing)
backend: $(C_SOURCES)
	@mkdir -p $(TMP_DIR)
	$(CC) $(CFLAGS) -DSTANDALONE $(C_SOURCES) -o $(TMP_BINARY) $(LDFLAGS)
	@cp $(TMP_BINARY) $(BINARY)

# Build the macOS app bundle
app: $(BINARY)
	@echo "Building $(APP_BUNDLE)..."
	@mkdir -p $(TMP_APP_DIR)/Contents/{MacOS,Resources}
	@cp Info.plist $(TMP_APP_DIR)/Contents/
	@cp $(BINARY) $(TMP_APP_DIR)/Contents/MacOS/fastmiddle
	@if [ -f fastmiddle.icns ]; then \
		cp fastmiddle.icns $(TMP_APP_DIR)/Contents/Resources/FastMiddle.icns; \
	elif [ -d FastMiddle.iconset ]; then \
		iconutil -c icns --output $(TMP_APP_DIR)/Contents/Resources/FastMiddle.icns FastMiddle.iconset; \
	fi
	@xattr -rc $(TMP_APP_DIR)
	@codesign --force --deep --sign - $(TMP_APP_DIR)
	@rm -rf $(APP_BUNDLE)
	@cp -r $(TMP_APP_DIR) $(APP_BUNDLE)
	@echo "$(APP_BUNDLE) built successfully"

# Create distributable DMG
dmg: app
	@echo "Creating $(DMG_FILE)..."
	@mkdir -p $(TMP_DMG_DIR)
	@cp -r $(APP_BUNDLE) $(TMP_DMG_DIR)/
	@ln -sf /Applications $(TMP_DMG_DIR)/Applications
	@rm -f $(DMG_FILE)
	@hdiutil create -volname "FastMiddle" -srcfolder $(TMP_DMG_DIR) \
		-ov -format UDZO $(DMG_FILE)
	@echo "$(DMG_FILE) created successfully"

# Install to /Applications
install: app
	@echo "Installing to /Applications..."
	@rm -rf /Applications/$(APP_BUNDLE)
	@cp -r $(APP_BUNDLE) /Applications/
	@echo "FastMiddle installed successfully"

# Clean build artifacts
clean:
	@rm -rf $(TMP_DIR) $(BINARY) $(APP_BUNDLE) $(DMG_FILE)
	@echo "Clean complete"
