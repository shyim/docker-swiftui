.PHONY: build run clean release

APP_NAME = Dockable
SCHEME = $(APP_NAME)
BUILD_DIR = $(CURDIR)/build
APP_PATH = $(BUILD_DIR)/Build/Products/Debug/$(APP_NAME).app
RELEASE_APP_PATH = $(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app

build:
	xcodebuild -scheme $(SCHEME) -configuration Debug -derivedDataPath $(BUILD_DIR) build

run: build
	open $(APP_PATH)

release:
	xcodebuild -scheme $(SCHEME) \
		-configuration Release \
		-derivedDataPath $(BUILD_DIR) \
		-destination 'generic/platform=macOS' \
		ARCHS='arm64 x86_64' \
		ONLY_ACTIVE_ARCH=NO \
		build
	@lipo -info $(RELEASE_APP_PATH)/Contents/MacOS/$(APP_NAME)
	@cd $(BUILD_DIR)/Build/Products/Release && zip -r -y $(APP_NAME).zip $(APP_NAME).app
	@echo "Built: $(BUILD_DIR)/Build/Products/Release/$(APP_NAME).zip"

clean:
	rm -rf $(BUILD_DIR)
	xcodebuild -scheme $(SCHEME) clean
