#!/usr/bin/env bash
# Read-only worktree prune audit. Classifies every git worktree by size, merge
# state, work that removal would lose, remote/PR state, and the most recent chat
# that operated in it. Emits a table sorted by size with a suggested bucket.
# Never deletes anything; deletion stays a human-gated step in the playbook.
# Anything the audit could not read makes the bucket `review`, never `safe`.
#
# Usage: worktree-audit.sh [-b|--base <ref>] [repo-path]
#   repo-path defaults to the current repo.
#   -b sets the ref the MERGED column checks against (e.g. origin/integration).
#   Without it the base is origin/HEAD, then origin/main, then origin/master.
#   origin/HEAD is the remote's default branch, not necessarily the branch PRs
#   merge into; pass -b when they differ.
set -u

base=""
while [ $# -gt 0 ]; do
	case "$1" in
	-b|--base) [ $# -ge 2 ] || { echo "error: $1 needs a ref" >&2; exit 2; }; base="$2"; shift 2 ;;
	-h|--help) sed -n '2,/^set -u/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
	-*) echo "error: unknown option: $1" >&2; exit 2 ;;
	*) break ;;
	esac
done

repo="${1:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -z "$repo" ] && { echo "not in a git repo; pass a repo path" >&2; exit 1; }
cd "$repo" || exit 1
git rev-parse --git-dir >/dev/null 2>&1 || { echo "error: not a git repo: $repo" >&2; exit 1; }

# Main worktree is the first entry; everything else is a candidate.
main_wt=$(git worktree list --porcelain | sed -n '1s/^worktree //p')

if [ -z "$base" ]; then
	for cand in "$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)" origin/main origin/master; do
		[ -n "$cand" ] && git rev-parse --verify --quiet "$cand^{commit}" >/dev/null && { base="$cand"; break; }
	done
	[ -z "$base" ] && { echo "error: no base ref (origin/HEAD, origin/main, origin/master all missing); pass -b <ref>" >&2; exit 1; }
	echo "warn: no -b given; MERGED checks against $base" >&2
fi

# The base drives the merge check. The fetch is best-effort (stale is fine for
# a first pass) and runs before the check, since -b may name a branch not
# fetched yet. The explicit refspec creates it even in a single-branch clone.
case "$base" in
origin/*) git fetch origin "+refs/heads/${base#origin/}:refs/remotes/$base" --quiet 2>/dev/null \
	|| echo "warn: could not fetch $base; merged column may be stale" >&2 ;;
esac
git rev-parse --verify --quiet "$base^{commit}" >/dev/null 2>&1 || { echo "error: base ref not found: $base" >&2; exit 1; }

# GNU coreutils (Linux, Homebrew gnubin) reads `stat -f` as file system status
# and `date -r` as a file, so pick the stat and date flags once.
if stat -c %Y / >/dev/null 2>&1; then
	stat_fmt=(-c '%Y %n'); fmt_day() { date -d "@$1" '+%Y-%m-%d'; }
	fmt_stamp() { date -d "@$1" '+%Y%m%d%H%M.%S'; }
else
	stat_fmt=(-f '%m %N'); fmt_day() { date -r "$1" '+%Y-%m-%d'; }
	fmt_stamp() { date -r "$1" '+%Y%m%d%H%M.%S'; }
fi

# PR state by branch, fetched once as [{number, state, head, oid}] with a
# lowercase state. A repository without a remote has no PRs. Any other failure
# is unknown.
work=$(mktemp -d "${TMPDIR:-/tmp}/pstack-audit.XXXXXX") || exit 1
trap 'rm -rf "$work"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
prs="$work/prs.json"; prs_known=yes
if [ -z "$(git remote)" ]; then echo "[]" > "$prs"
elif raw=$(gh pr list --author "@me" --state all --limit 1000 \
	--json number,state,headRefName,headRefOid 2>/dev/null) \
	&& printf '%s' "$raw" | jq '[.[] | {number, state: (.state | ascii_downcase), head: .headRefName, oid: .headRefOid}]' > "$prs" 2>/dev/null; then :
else echo "[]" > "$prs"; prs_known=no; echo "warn: could not read PRs; nothing can be safe" >&2; fi

# Export this project's newest sessions, one file each, with the file time set
# to the session's last update. A failed export, or a list cut off inside the
# recent window, leaves the chats unknown.
now=$(date +%s); recent_days=4; session_limit=200
transcripts="$work/sessions"; mkdir "$transcripts"; chats_known=yes
if opencode session list -n "$session_limit" --format json > "$work/list.json" 2>/dev/null </dev/null \
	&& jq -r '.[] | "\(.id) \(.updated / 1000 | floor)"' "$work/list.json" > "$work/list" 2>/dev/null; then
	while read -r id ts; do
		if opencode session export "$id" > "$transcripts/$id.json" 2>/dev/null </dev/null \
			&& [ -s "$transcripts/$id.json" ]; then
			touch -t "$(fmt_stamp "$ts")" "$transcripts/$id.json"
		else chats_known=no; fi
	done < "$work/list"
	if [ "$(wc -l < "$work/list")" -ge "$session_limit" ]; then
		oldest=$(awk '{print $2}' "$work/list" | sort -n | head -1)
		[ $(( (now - oldest) / 86400 )) -gt "$recent_days" ] || chats_known=no
	fi
else chats_known=no; fi
[ "$chats_known" = yes ] || echo "warn: could not read every opencode session; nothing can be safe" >&2

# Ignored paths under these names are rebuildable. Any other ignored path, such
# as .env, may exist nowhere else.
disposable='(^|/)(node_modules|dist|build|out|target|coverage|vendor/bundle|\.cache|\.next|\.nuxt|\.turbo|\.gradle|\.venv|venv|__pycache__|\.pytest_cache|\.mypy_cache|\.ruff_cache|DerivedData|\.DS_Store)(/|$)'

echo "# base: $base"
printf "SIZE\tAGE\tMERGED\tDIRTY\tREMOTE\tPR\tLAST_CHAT\tBUCKET\tWORKTREE\n"

audit_one() {
	local wt="$1" locked="$2"
	local size head head_ts age merged porcelain dirty wip untracked ignored branch remote pr pr_open pr_merged last last_ts f recent lost sub bucket

	size=$(du -sh "$wt" 2>/dev/null | awk '{print $1}')
	head=$(git -C "$wt" rev-parse HEAD 2>/dev/null)
	head_ts=$(git -C "$wt" log -1 --format='%ct' HEAD 2>/dev/null || echo 0)
	age=$([ "$head_ts" -gt 0 ] 2>/dev/null && echo "$(( (now - head_ts) / 86400 ))d" || echo "?")

	# Squash-merged branches are not ancestors of the base, so PR state is the
	# real signal; merge-base only catches fast-forward/rebase merges.
	git merge-base --is-ancestor "$head" "$base" 2>/dev/null && merged=YES || merged=no

	# What removal would lose: tracked edits, files git has never seen, and
	# ignored files that nothing can rebuild.
	wip=0; untracked=0; ignored=0; dirty=clean
	if porcelain=$(git -C "$wt" status --porcelain --untracked-files=all --ignored=matching 2>/dev/null); then
		wip=$(printf '%s\n' "$porcelain" | grep -v '^$' | grep -cv '^[?!][?!]')
		untracked=$(printf '%s\n' "$porcelain" | grep -c '^??')
		ignored=$(printf '%s\n' "$porcelain" | sed -n 's/^!! //p' | sed 's/^"//; s/"$//' | grep -cvE "$disposable")
		dirty=""
		[ "$wip" -gt 0 ] && dirty="$dirty,wip:$wip"
		[ "$untracked" -gt 0 ] && dirty="$dirty,untracked:$untracked"
		[ "$ignored" -gt 0 ] && dirty="$dirty,ignored:$ignored"
		dirty=${dirty#,}; dirty=${dirty:-clean}
	else dirty=unknown; fi

	# Commits only this worktree's HEAD reflog reaches. A commit some branch
	# reflog also lists, such as one before an amend or a rebase, is not counted.
	lost=$(comm -12 \
		<(git -C "$wt" rev-list --walk-reflogs HEAD 2>/dev/null | sort -u) \
		<(git -C "$wt" rev-list --reflog --not --branches --tags --remotes 2>/dev/null | sort -u) \
		| comm -23 - <(git -C "$wt" rev-list --walk-reflogs --branches 2>/dev/null | sort -u) | wc -l | tr -d ' ')
	[ "$lost" -gt 0 ] && { [ "$dirty" = clean ] && dirty="reflog:$lost" || dirty="$dirty,reflog:$lost"; }
	[ -f "$wt/.gitmodules" ] && sub=yes || sub=no

	branch=$(git -C "$wt" symbolic-ref --quiet --short HEAD 2>/dev/null || echo "")
	if [ -z "$branch" ]; then remote=detached
	elif git -C "$wt" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
		[ "$(git -C "$wt" rev-parse "origin/$branch" 2>/dev/null)" = "$head" ] \
			&& remote=pushed \
			|| remote="ahead$(git -C "$wt" rev-list --count "origin/$branch..HEAD" 2>/dev/null)"
	else remote=no-remote; fi

	# An open PR wins over any other PR of the branch. A merged PR counts only
	# when it merged this head.
	pr="-"; pr_open=no; pr_merged=no
	if [ -n "$branch" ]; then
		pr=$(jq -r --arg b "$branch" '[.[] | select(.head==$b)] | sort_by(.state != "open" and .state != "draft") | .[0] // empty | "#\(.number)/\(.state)"' "$prs")
		pr=${pr:--}
		case "$pr" in */open|*/draft) pr_open=yes ;; esac
		[ "$(jq -r --arg b "$branch" --arg h "$head" 'any(.[]; .head==$b and .state=="merged" and .oid==$h)' "$prs")" = true ] && pr_merged=yes
	fi

	# Most recent chat whose transcript operated in this worktree. Match path
	# followed by "/" or a quote so glint-482 does not match glint-482-r37.
	last="-"; last_ts=0
	f=$(grep -rlF -e "${wt}/" -e "${wt}\"" "$transcripts" 2>/dev/null \
		| while IFS= read -r m; do stat "${stat_fmt[@]}" "$m"; done 2>/dev/null | sort -rn | head -1)
	if [ -n "$f" ]; then last_ts=$(echo "$f" | awk '{print $1}')
		last=$(fmt_day "$last_ts" 2>/dev/null); fi
	recent=$([ "$last_ts" -gt 0 ] 2>/dev/null && [ $(( (now - last_ts) / 86400 )) -le "$recent_days" ] && echo yes || echo no)

	if [ "$locked" = yes ]; then bucket=hold-locked
	elif [ "$wip" -gt 0 ]; then bucket=hold-wip
	elif [ "$untracked" -gt 0 ]; then bucket=hold-untracked
	elif [ "$ignored" -gt 0 ]; then bucket=hold-ignored
	elif [ "$pr_open" = yes ]; then bucket=hold-open-pr
	elif [ "$recent" = yes ]; then bucket=verify-recent-chat
	elif [ "$dirty" = unknown ] || [ "$lost" -gt 0 ] || [ "$sub" = yes ] \
		|| [ "$prs_known" = no ] || [ "$chats_known" = no ] || [ -z "$head" ]; then bucket=review
	elif [ "$merged" = YES ] || [ "$pr_merged" = yes ]; then bucket=safe
	else bucket=review; fi

	printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
		"$size" "$age" "$merged" "$dirty" "$remote" "$pr" "$last" "$bucket" "$wt"
}

{ git worktree list --porcelain; echo; } > "$work/worktrees"
path=""; locked=no
while IFS= read -r line; do
	case "$line" in
	"worktree "*) path=${line#worktree }; locked=no ;;
	locked*) locked=yes ;;
	"") [ -n "$path" ] && [ "$path" != "$main_wt" ] && audit_one "$path" "$locked" </dev/null; path="" ;;
	esac
done < "$work/worktrees" | sort -t$'\t' -k1,1 -rh
