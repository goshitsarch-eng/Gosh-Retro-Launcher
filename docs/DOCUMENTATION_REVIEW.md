# Documentation Review

This note tracks the current documentation cleanup.

## Current State

1. The app version is 1.0.6 in `package.json` and `package-lock.json`.
2. The About dialog displays the Electron app version through `app.getVersion()`, so it follows the package version.
3. The README is now a short human guide instead of a long source audit.
4. The User Guide keeps the practical workflows and no longer ends with a generated research log.
5. The Architecture and API docs keep the useful technical details and drop the audit trail sections.

## Things To Keep In Sync

1. Update `package.json` and `package-lock.json` together for each release.
2. Add a short entry to `CHANGELOG.md` for each version.
3. Keep README wording friendly and brief.
4. Put deep implementation details in `docs/ARCHITECTURE.md` or `docs/API_REFERENCE.md`, not in the README.
5. Avoid exact counts in prose unless they are easy to verify from source.

## Verified

1. Package metadata uses version 1.0.6.
2. The About dialog reads the version from the main process.
3. Documentation links in the README and User Guide point to existing files.
4. The license is AGPL v3.
