#!/usr/bin/env bash
set -u
here=$(cd "$(dirname "$0")" && pwd -P)
log="$here/../skills/show-me-your-work/scripts/log.sh"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
ok() { if [ "$2" = "$3" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL $1: expected '$3', got '$2'"; fi; }

for size in 200 1500 6000; do
	big=$(head -c $size /dev/zero | tr '\0' 'x'); f="$tmp/p$size.tsv"
	for i in $(seq 1 80); do bash "$log" "$f" act "row$i" "$big" ev out & done; wait
	ok "rows at $size" "$(grep -c 'row' "$f")" 80
	ok "malformed at $size" "$(awk -F'\t' 'NF!=6' "$f" | wc -l | tr -d ' ')" 0
	ok "headers at $size" "$(grep -c '^ts	' "$f")" 1
done
bash "$log" "$tmp/c.tsv" a '"q' '=1' 'x	y' z
ok "leading quote" "$(awk -F'\t' 'NR==2{print $3}' "$tmp/c.tsv")" "'\"q"
ok "formula" "$(awk -F'\t' 'NR==2{print $4}' "$tmp/c.tsv")" "'=1"
ok "tab stripped" "$(awk -F'\t' 'NR==2{print $5}' "$tmp/c.tsv")" "x y"
mkdir "$tmp/s.tsv.lock"
PSTACK_LOG_LOCK_SECONDS=1 bash "$log" "$tmp/s.tsv" a b c d e 2>"$tmp/err"; ok "stale lock exit" "$?" 1
ok "stale lock wrote nothing" "$([ -e "$tmp/s.tsv" ] && echo yes || echo no)" no
ok "stale lock names the lock" "$(grep -c 's.tsv.lock' "$tmp/err")" 1
ok "lock released" "$([ -e "$tmp/c.tsv.lock" ] && echo yes || echo no)" no
echo "log: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
