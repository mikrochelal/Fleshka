#!/usr/bin/env bash
# Static validation for the whole project. Run from anywhere: scripts/check.sh
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p build

echo "== Workspace safety guard"
# Workspace is owned by Roblox Studio; mapping it in Rojo would overwrite the hand-built map.
if grep -q '"Workspace"' default.project.json; then
	echo "ERROR: default.project.json must not map Workspace" >&2
	exit 1
fi

echo "== rojo build"
rojo build default.project.json --output build/TheLastSignal.rbxlx

echo "== rojo sourcemap"
rojo sourcemap default.project.json --output sourcemap.json

echo "== stylua"
stylua --check src tests

echo "== selene"
selene src

echo "== unit tests"
# Pure-logic tests need the standalone Luau CLI (https://github.com/luau-lang/luau/releases).
if command -v luau >/dev/null 2>&1; then
	luau tests/run.luau
else
	echo "SKIPPED: luau CLI not installed - unit tests did not run"
fi

echo "== luau-lsp analyze"
if [ ! -f build/globalTypes.d.luau ]; then
	curl -fsSL -o build/globalTypes.d.luau \
		https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau
fi
luau-lsp analyze --sourcemap=sourcemap.json --definitions=build/globalTypes.d.luau \
	--base-luaurc=.luaurc src

echo "All checks passed."
