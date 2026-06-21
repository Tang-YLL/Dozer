build:
	@brew bundle --no-upgrade
	@carthage bootstrap --cache-builds --platform osx
	@mkdir -p Dozer/Other/Generated
	@swiftgen
	@xcodegen 
	@xed "."

release:
	@echo "Running Fastlane deploy"
	@bundle exec fastlane release

# Build a Universal (arm64 + x86_64) Release .app with ad-hoc signing (no Developer cert needed).
# 注：依赖是 2020-2021 年锁定的旧版本，在 Xcode 14+ 上需要以下兼容处理：
#   - 直连 GitHub（no_proxy 绕开系统/全局代理，下载更稳）
#   - 抬高老依赖部署目标到 10.13（Xcode 14+ 已移除 libarclite）
#   - 关掉老依赖的 -Werror（旧 API 在新 SDK 已弃用）
#   - 依赖构建期间用 no-op swiftlint（老代码过不了现代规则）
#   - Sparkle 用官方预编译二进制（系统代理下 carthage 下载易失败）
app:
	@brew bundle --no-upgrade
	@no_proxy='*' NO_PROXY='*' carthage bootstrap --cache-builds --platform mac || true
	@find Carthage/Checkouts -name project.pbxproj -exec sed -i '' -E \
		's/MACOSX_DEPLOYMENT_TARGET = 10\.(7|8|9|10|11);/MACOSX_DEPLOYMENT_TARGET = 10.13;/g; s/GCC_TREAT_WARNINGS_AS_ERRORS = YES;/GCC_TREAT_WARNINGS_AS_ERRORS = NO;/g' {} +
	@mkdir -p /tmp/swiftlint-stub && printf '#!/bin/sh\nexit 0\n' > /tmp/swiftlint-stub/swiftlint && chmod +x /tmp/swiftlint-stub/swiftlint
	@PATH="/tmp/swiftlint-stub:$$PATH" no_proxy='*' carthage build --platform mac --cache-builds || true
	@if [ ! -d Carthage/Build/Mac/Sparkle.framework ]; then \
		curl --noproxy '*' -fsSL -o /tmp/sparkle.tar.xz \
			"https://github.com/sparkle-project/Sparkle/releases/download/1.26.0/Sparkle-1.26.0.tar.xz" && \
		rm -rf /tmp/sparkle-extract && mkdir -p /tmp/sparkle-extract && \
		tar -xf /tmp/sparkle.tar.xz -C /tmp/sparkle-extract && \
		cp -R /tmp/sparkle-extract/Sparkle.framework Carthage/Build/Mac/ && \
		cp -R /tmp/sparkle-extract/Sparkle.framework.dSYM Carthage/Build/Mac/; \
	fi
	@mkdir -p Dozer/Other/Generated
	@PATH="/opt/homebrew/bin:/usr/local/bin:$$PATH" swiftgen
	@xcodegen
	@xcodebuild -project Dozer.xcodeproj -scheme Dozer -configuration Release \
		-destination 'generic/platform=macOS' \
		CONFIGURATION_BUILD_DIR=$(CURDIR)/build \
		ONLY_ACTIVE_ARCH=NO CODE_SIGN_IDENTITY="-" build
	@echo "Built universal app: $(CURDIR)/build/Dozer.app"

# Install the built app to /Applications (overwrites any existing Dozer.app).
install:
	@cp -R $(CURDIR)/build/Dozer.app /Applications/Dozer.app
	@xattr -dr com.apple.quarantine /Applications/Dozer.app 2>/dev/null || true
	@echo "Installed to /Applications/Dozer.app (run with: open /Applications/Dozer.app)"

.PHONY: build release app install
