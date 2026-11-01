cd "$1"; bash tests/fm-live-lab.test.sh 2>&1 | cut -c1-400 | tail -25; echo "exit=${PIPESTATUS[0]}"
