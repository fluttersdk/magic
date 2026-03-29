#!/bin/bash
# Sync Claude Code rules to GitHub Copilot instructions.
# Source of truth: .claude/rules/*.md
# Target: .github/instructions/*.instructions.md
#
# Usage: /bin/bash .github/scripts/sync-cc-to-copilot.sh

set -eo pipefail

RULES_DIR=".claude/rules"
INSTRUCTIONS_DIR=".github/instructions"

mkdir -p "$INSTRUCTIONS_DIR"

get_description() {
  case "$1" in
    auth)       echo "Authentication domain -- guards, session restore, auth events" ;;
    database)   echo "Database domain -- Eloquent ORM, QueryBuilder, migrations, seeders" ;;
    flutter)    echo "Flutter/Dart stack -- imports, naming, platform splits, IoC" ;;
    http)       echo "HTTP domain -- controllers, middleware, state management" ;;
    routing)    echo "Routing domain -- MagicRouter, route groups, layouts, navigation" ;;
    tests)      echo "Testing domain -- setUp, mocking, test structure, assertions" ;;
    ui)         echo "UI domain -- views, forms, feedback, responsive layout" ;;
    validation) echo "Validation domain -- rules, validator, form integration" ;;
    *)          echo "${1} domain conventions" ;;
  esac
}

count=0
for rule in "$RULES_DIR"/*.md; do
  name=$(basename "$rule" .md)
  target="$INSTRUCTIONS_DIR/${name}.instructions.md"

  # Extract path: from frontmatter
  apply_to=$(sed -n 's/^path: *"\(.*\)"/\1/p' "$rule")

  # Extract body (skip frontmatter between --- markers)
  body=$(awk 'BEGIN{skip=0} /^---$/{skip++; next} skip>=2{print}' "$rule")

  description=$(get_description "$name")
  cap_name="$(echo "${name:0:1}" | tr '[:lower:]' '[:upper:]')${name:1}"

  cat > "$target" <<EOF
---
name: '${cap_name} Conventions'
description: '${description}'
applyTo: '${apply_to}'
---
${body}
EOF

  echo "Synced: $rule -> $target"
  count=$((count + 1))
done

echo "Done. ${count} instruction files generated."
