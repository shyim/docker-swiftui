.PHONY: build run clean

APP_NAME = DockerSwiftUI
SCHEME = $(APP_NAME)
BUILD_DIR = $(CURDIR)/build
APP_PATH = $(BUILD_DIR)/Build/Products/Debug/$(APP_NAME).app

build:
	xcodebuild -scheme $(SCHEME) -configuration Debug -derivedDataPath $(BUILD_DIR) build

run: build
	open $(APP_PATH)

clean:
	rm -rf $(BUILD_DIR)
	xcodebuild -scheme $(SCHEME) clean
