cd "$1"
for i in 1 2 3 4 5 6; do
  s=$(date +%s); out=$(bash tests/fm-live-lab.test.sh 2>&1); rc=$?
  echo "run $i exit=$rc elapsed=$(( $(date +%s)-s ))s ok=$(printf '%s\n' "$out" | grep -c '^ok')"
  [ $rc -eq 0 ] || printf '%s\n' "$out" | grep -vE '^ok|Killed' | cut -c1-500 | tail -8
done
