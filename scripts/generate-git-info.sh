#!/bin/sh

set -eu

repo_root=${1:?"repository root is required"}
output_file=${2:?"output path is required"}

if ! command -v git >/dev/null 2>&1; then
    echo "error: git is required to generate GitInfo" >&2
    exit 1
fi

if ! git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "error: Git metadata is inaccessible from the Xcode build script" >&2
    exit 1
fi

git_description=$(git -C "$repo_root" describe --tags --always)
git_commit=$(git -C "$repo_root" rev-parse HEAD)
git_short_commit=$(git -C "$repo_root" rev-parse --short=12 HEAD)
git_branch=$(git -C "$repo_root" symbolic-ref --quiet --short HEAD || printf 'detached HEAD')
built_at=$(date -u '+%Y-%m-%d %H:%M:%S UTC')

worktree_state=clean
worktree_fingerprint=clean
if [ -n "$(git -C "$repo_root" status --porcelain --untracked-files=all)" ]; then
    worktree_state=modified
    # Hash staged and unstaged tracked changes plus the names and contents of
    # non-ignored untracked files. The generated file lives outside this tree.
    worktree_fingerprint=$(
        {
            printf 'tracked changes\n'
            git -C "$repo_root" diff --no-ext-diff --binary HEAD --
            printf 'untracked files\n'
            git -C "$repo_root" ls-files --others --exclude-standard -z |
                (cd "$repo_root" && xargs -0 -n1 shasum -a 256)
        } | shasum -a 256 | awk '{ print substr($1, 1, 12) }'
    )
    version_label="$git_short_commit - local $worktree_fingerprint"
else
    version_label="$git_short_commit - clean"
fi

swift_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

escaped_description=$(swift_escape "$git_description")
escaped_commit=$(swift_escape "$git_commit")
escaped_short_commit=$(swift_escape "$git_short_commit")
escaped_branch=$(swift_escape "$git_branch")
escaped_label=$(swift_escape "$version_label")

mkdir -p "$(dirname "$output_file")"
cat > "$output_file" <<EOF
import Foundation

enum GitInfo {
    static let commit = "$escaped_commit"
    static let shortHash = "$escaped_short_commit"
    static let branch = "$escaped_branch"
    static let gitDescription = "$escaped_description"
    static let worktreeState = "$worktree_state"
    static let worktreeFingerprint = "$worktree_fingerprint"
    static let builtAt = "$built_at"
    static let displayString = "$escaped_label"
}
EOF

echo "Wrote $output_file"
