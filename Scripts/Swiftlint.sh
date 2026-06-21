export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
if which swiftlint >/dev/null; then
  swiftlint || echo "warning: SwiftLint found violations (treated as non-fatal so the build can proceed)"
else
  echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
fi
