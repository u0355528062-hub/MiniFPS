#!/usr/bin/env bash
# Vérifie que les scripts de Blouse Blanche compilent, sans éditeur Unity.
# Prérequis : SDK .NET 8 et accès à nuget.org (première exécution).
# Configurations : Input System, ancien Input Manager, mode histoire (BB_STORY_MODE), éditeur.
set -u
cd "$(dirname "$0")"

dotnet restore CompileCheck.csproj --nologo -v q || exit 1

status=0
run() {
    local label="$1" defines="$2" editor="$3"
    printf '\n=== %s ===\n' "$label"
    if dotnet build CompileCheck.csproj --no-restore --no-incremental --nologo -v q -clp:NoSummary \
        -p:BBDefines="$defines" -p:BBEditor="$editor"; then
        echo "OK"
    else
        status=1
    fi
}

run "Jeu · Input System"             "ENABLE_INPUT_SYSTEM"                                        false
run "Jeu · ancien Input Manager"     "ENABLE_LEGACY_INPUT_MANAGER"                                false
run "Jeu · mode histoire"            "ENABLE_INPUT_SYSTEM%3BBB_STORY_MODE"                        false
run "Éditeur (Input System + Input Manager)" "ENABLE_INPUT_SYSTEM%3BENABLE_LEGACY_INPUT_MANAGER" true

exit $status
