cd "$1"; bin/fm-test-run.sh tests/fm-brief.test.sh 2>&1 | grep -E 'FM_TEST_END|not ok'
