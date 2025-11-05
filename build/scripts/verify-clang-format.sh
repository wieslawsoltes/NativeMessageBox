#!/usr/bin/env bash
set -euo pipefail

FILES=$(git ls-files -z '*.c' '*.cpp' '*.cc' '*.mm' '*.h' '*.hpp')
if [[ -z "${FILES}" ]]; then
  exit 0
fi

clang-format --version >/dev/null

printf '%s' "${FILES}" | xargs -0 clang-format --dry-run --Werror
