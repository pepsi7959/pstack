#!/usr/bin/env bash
# Each case builds a throwaway repository and checks the bucket the audit prints.
set -u
here=$(cd "$(dirname "$0")" && pwd -P)
audit="$here/../skills/poteto-mode/scripts/worktree-audit.sh"
tmp=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$tmp"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
export GIT_CONFIG_GLOBAL=/dev/null
pass=0; fail=0

# Fake opencode and gh. SESSIONS holds the list, EXPORT_FAIL names an id whose export fails.
mkdir -p "$tmp/bin"
cat > "$tmp/bin/opencode" <<'S'
#!/bin/sh
[ "${OPENCODE_DOWN:-}" = 1 ] && exit 1
case "$1 $2" in
"session list") cat "$SESSIONS" ;;
"session export") [ "$3" = "${EXPORT_FAIL:-}" ] && exit 1; cat "$EXPORTS/$3.json" ;;
esac
S
cat > "$tmp/bin/gh" <<'S'
#!/bin/sh
[ "${GH_DOWN:-}" = 1 ] && exit 1
cat "$PRS"
S
chmod +x "$tmp/bin/opencode" "$tmp/bin/gh"

new_repo() {
	dir=$(mktemp -d "$tmp/case.XXXXXX"); export SESSIONS="$dir/sessions.json" EXPORTS="$dir/exports" PRS="$dir/prs.json"
	mkdir -p "$EXPORTS"; echo '[]' > "$SESSIONS"; echo '[]' > "$PRS"
	git init -q -b main "$dir/repo"; cd "$dir/repo" || exit 1
	printf '.env\nnode_modules/\n' > .gitignore; git add .; git commit -q -m base
	git remote add origin "$dir/none"
	wt="$dir/w t"; git worktree add -q "$wt" -b topic
}
run() { PATH="$tmp/bin:$PATH" bash "$audit" -b main "$dir/repo" 2>"$dir/err"; }
row() { run | awk -F'\t' -v w="$wt" '$NF==w{print $8}'; }
check() { # name expected
	local got; got=$(row)
	if [ "$got" = "$2" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL $1: expected $2, got '${got:-<no row>}'"; fi
}
now_ms() { echo "$(($(date +%s) * 1000))"; }

new_repo; check "clean and merged" safe
new_repo; echo x > "$wt/notes.md"; check "untracked file" hold-untracked
new_repo; echo x >> "$wt/.gitignore"; check "tracked edit" hold-wip
new_repo; echo S=1 > "$wt/.env"; check "ignored .env" hold-ignored
new_repo; mkdir "$wt/node_modules"; echo x > "$wt/node_modules/a"; check "ignored node_modules" safe
new_repo; git worktree lock --reason busy "$wt"; check "locked" hold-locked
new_repo; git -C "$wt" checkout -q --detach; git -C "$wt" commit -q --allow-empty -m lost; git -C "$wt" checkout -q --detach main
check "commit only the HEAD reflog reaches" review
new_repo; git -C "$wt" commit -q --allow-empty -m a; git -C "$wt" commit -q --amend --allow-empty -m b; git merge -q topic
check "amended commit on a merged branch" safe
new_repo; git -C "$wt" commit -q --allow-empty -m a; head=$(git -C "$wt" rev-parse HEAD)
echo "[{\"number\":1,\"state\":\"CLOSED\",\"headRefName\":\"topic\",\"headRefOid\":\"$head\"}]" > "$PRS"; check "PR closed without merge" review
echo "[{\"number\":1,\"state\":\"MERGED\",\"headRefName\":\"topic\",\"headRefOid\":\"$head\"}]" > "$PRS"; check "PR merged at this head" safe
git -C "$wt" commit -q --allow-empty -m later; check "commit after the PR merged" review
new_repo; git -C "$wt" commit -q --allow-empty -m a
echo '[{"number":2,"state":"MERGED","headRefName":"topic","headRefOid":"x"},{"number":1,"state":"OPEN","headRefName":"topic","headRefOid":"y"}]' > "$PRS"; check "open PR behind a merged one" hold-open-pr
new_repo; export GH_DOWN=1; check "PR state unreadable" review; unset GH_DOWN
new_repo; export OPENCODE_DOWN=1; check "sessions unreadable" review; unset OPENCODE_DOWN
new_repo; echo "[{\"id\":\"s1\",\"updated\":$(now_ms)}]" > "$SESSIONS"; echo "{\"d\":\"$wt\"}" > "$EXPORTS/s1.json"; check "recent chat" verify-recent-chat
new_repo; echo "[{\"id\":\"s1\",\"updated\":$(now_ms)},{\"id\":\"s2\",\"updated\":1}]" > "$SESSIONS"; echo '{}' > "$EXPORTS/s1.json"; echo '{}' > "$EXPORTS/s2.json"
export EXPORT_FAIL=s2; check "one export failed" review; unset EXPORT_FAIL
new_repo; n=$(now_ms); { printf '['; for i in $(seq 1 200); do [ "$i" -gt 1 ] && printf ','; printf '{"id":"s%s","updated":%s}' "$i" "$n"; echo '{}' > "$EXPORTS/s$i.json"; done; printf ']'; } > "$SESSIONS"; check "session list cut off inside the window" review
new_repo; printf '[submodule "x"]\n\tpath = x\n\turl = ./x\n' > .gitmodules; git add .gitmodules; git commit -q -m sub; git -C "$wt" merge -q main; check "worktree with submodules" review

# An interrupted run leaves no exported chats behind.
new_repo; echo "[{\"id\":\"s1\",\"updated\":$(now_ms)}]" > "$SESSIONS"; echo '{}' > "$EXPORTS/s1.json"; mkdir "$dir/t"
cat > "$dir/slow" <<'S'
#!/bin/sh
case "$1 $2" in "session list") cat "$SESSIONS" ;; "session export") cat "$EXPORTS/$3.json"; sleep 3 ;; esac
S
mkdir "$dir/bin"; mv "$dir/slow" "$dir/bin/opencode"; chmod +x "$dir/bin/opencode"
TMPDIR="$dir/t" PATH="$dir/bin:$tmp/bin:$PATH" bash "$audit" -b main "$dir/repo" >/dev/null 2>&1 & pid=$!
sleep 1; kill -TERM $pid; wait $pid 2>/dev/null
if [ -z "$(ls -A "$dir/t")" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL interrupted run left: $(ls "$dir/t")"; fi

echo "worktree-audit: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
