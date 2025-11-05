#!/usr/bin/env bash
set -euo pipefail

FILES=()
while IFS= read -r -d '' file; do
  FILES+=("$file")
done < <(git ls-files -z '*.c' '*.cpp' '*.cc' '*.mm' '*.h' '*.hpp')

if [[ ${#FILES[@]} -eq 0 ]]; then
  exit 0
fi

clang-format --version >/dev/null

clang-format --dry-run --Werror "${FILES[@]}"
