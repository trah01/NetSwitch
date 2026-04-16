APP_NAME = NetSwitch
BUILD_DIR = build
SWIFT_SOURCES = $(wildcard Sources/*.swift)

all: build

build:
	@echo "Building $(APP_NAME)..."
	@mkdir -p $(BUILD_DIR)/$(APP_NAME).app/Contents/MacOS
	@mkdir -p $(BUILD_DIR)/$(APP_NAME).app/Contents/Resources
	@cp Info.plist $(BUILD_DIR)/$(APP_NAME).app/Contents/Info.plist
	@swiftc -target arm64-apple-macos12 \
		-sdk $$(xcrun --show-sdk-path) \
		-framework Cocoa \
		-framework UserNotifications \
		-o $(BUILD_DIR)/$(APP_NAME).app/Contents/MacOS/$(APP_NAME) \
		$(SWIFT_SOURCES)
	@echo "Build complete: $(BUILD_DIR)/$(APP_NAME).app"

run: build
	@echo "Running $(APP_NAME)..."
	@open $(BUILD_DIR)/$(APP_NAME).app

clean:
	@rm -rf $(BUILD_DIR)

.PHONY: all build run clean
