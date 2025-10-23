#!/bin/bash
# Repository database update script (runs inside Docker container)

set -e

ARCH=${ARCH:-x86_64}
OUTPUT_DIR="/output/$ARCH"
REPO_NAME="omarchy"
DB_FILE="$OUTPUT_DIR/${REPO_NAME}.db.tar.zst"

cd "$OUTPUT_DIR"

# Remove old database files (repo-add will create new ones)
rm -f "${REPO_NAME}.db" "${REPO_NAME}.db.tar.zst"
rm -f "${REPO_NAME}.files" "${REPO_NAME}.files.tar.zst"

# Check if there are any packages
if ! ls *.pkg.tar.* 1>/dev/null 2>&1; then
  echo "==> No packages found in $OUTPUT_DIR"
  echo "==> Run bin/repo build first to build packages"
  exit 1
fi

# Add all packages to the database (excluding signature files)
echo "==> Adding packages to database..."
find . -maxdepth 1 -name "*.pkg.tar.*" ! -name "*.sig" -exec basename {} \; | xargs -n 5 repo-add "$DB_FILE" || {
  echo "==> Failed to update repository database"
  exit 1
}

# Create symlinks for compatibility
ln -sf "${REPO_NAME}.db.tar.zst" "${REPO_NAME}.db"
ln -sf "${REPO_NAME}.files.tar.zst" "${REPO_NAME}.files"

# Count packages
PACKAGE_COUNT=$(ls -1 *.pkg.tar.* 2>/dev/null | grep -v '\.sig$' | wc -l)

echo "==> Database updated successfully!"
echo "==> Total packages in repository: $PACKAGE_COUNT"

# List packages in database
echo "==> Packages in database:"
tar -tf "$DB_FILE" 2>/dev/null | grep -E "^[^/]+/$" | sed 's|/$||' | sort -u | while read -r pkg; do
  echo "  - $pkg"
done
