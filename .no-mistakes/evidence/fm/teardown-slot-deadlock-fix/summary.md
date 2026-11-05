# Targeted validation of 2b9d808f (fm/teardown-slot-deadlock-fix)

## Slot-deadlock teardown scenarios (tests/fm-teardown-endpoint-safety.test.sh, rc=0)
21:ok - fm-teardown backend=t3code: a reassigned pool slot keeps its claimant's Codex overlay while the task's own thread is archived
22:ok - fm-teardown: a stale record on a claimed slot retires, then the claimant tears down
26:ok - fm-teardown: a reassigned slot with a surviving claimant record deadlocks neither teardown
27:ok - fm-teardown: the claimant tears down first past a stale record naming its slot
29:ok - fm-teardown: a refused claimant teardown leaves a stale record it passed over unmarked
30:ok - fm-teardown: a leftover claim still refuses on a secondmate home
31:ok - fm-teardown: forced secondmate teardown keeps a stale child off its claimant's returned slot

## Relaunch slot-ownership refusals (tests/fm-control-relaunch.test.sh, rerun rc=0, 91 ok)
ok - fm-spawn --relaunch: refuses a pool slot another task has claimed since, proceeds on its own claim
ok - fm-spawn --relaunch: checks its slot's claim under the Treehouse project lock

## Flake note
First full run: 1 not ok in pre-existing test_prepublication_failure_keeps_concurrent_durable_metadata (2s polling window). Unchanged by branch; isolated latency HEAD ~70 ticks vs base fm-spawn.sh 66-109 ticks of 200 budget. Rerun clean.
