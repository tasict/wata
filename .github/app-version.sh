#!/usr/bin/env bash
# Puts the version on the App Store into version.json and into every
# <span class="app-version"> of the pages. Leaves them as they are when the
# lookup fails or answers with an older version (Apple's servers can
# disagree for a while after a release).
set -euo pipefail
cd "$(dirname "$0")/.."

lookup="https://itunes.apple.com/lookup?id=6826999730&country=tw"
live=$(curl -fsS --retry 3 --max-time 30 "$lookup" | jq -r '.results[0].version // empty') || live=""
current=$(jq -r .version version.json)

if ! [[ $live =~ ^[0-9]+(\.[0-9]+){1,3}$ ]]; then
  echo "::warning::No version from the App Store (got '$live'), the pages stay at $current"
  exit 0
fi
newer=$(jq -n --arg a "$live" --arg b "$current" '($a | split(".") | map(tonumber)) > ($b | split(".") | map(tonumber))')
if [ "$newer" != true ]; then
  echo "The App Store has $live, the pages say $current"
  exit 0
fi

jq --arg v "$live" '.version = $v' version.json > version.json.new
mv version.json.new version.json
find . -name '*.html' -not -path './.git/*' -print0 |
  xargs -0 sed -i -E "s#(<span class=\"app-version\">)[^<]*(</span>)#\\1${live}\\2#g"
echo "Now $live (was $current)"
echo "version=$live" >> "${GITHUB_OUTPUT:-/dev/null}"
