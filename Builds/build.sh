#!/bin/sh
printf '\033c\033]0;%s\a' ProjectionMapping
base_path="$(dirname "$(realpath "$0")")"
"$base_path/build.x86_64" "$@"
