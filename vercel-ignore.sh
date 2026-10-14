#!/bin/bash
# Vercel Ignored Build Step Script
# Only deploy commits pushed or merged to the 'main' branch.
#
# Vercel Exit Code Semantics:
# - Exit code 1: Proceed with deployment
# - Exit code 0: Cancel / skip deployment

echo "VERCEL_GIT_COMMIT_REF: ${VERCEL_GIT_COMMIT_REF:-unknown}"

if [ "$VERCEL_GIT_COMMIT_REF" = "main" ]; then
  echo "✓ Deploying: commit is on 'main' branch."
  exit 1
else
  echo "🛑 Skipping deployment: branch '$VERCEL_GIT_COMMIT_REF' is not 'main'."
  exit 0
fi
