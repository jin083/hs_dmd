#!/bin/bash
set -eo pipefail
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
if [ "$(ps -o comm= -p "$PPID")" = VBoxService ]; then renice 19 -p "$PPID" >/dev/null 2>&1 || true; fi
destination="$(cd "$(dirname "$0")" && pwd)"
work=$(mktemp -d /tmp/dmd_review.XXXXXX)
cp "$destination"/*.v "$destination"/test.prj "$destination"/run.tcl "$work/"
cd "$work"
trap 'cp -f compile.log simulation.log "$destination/" 2>/dev/null || true' EXIT
fuse -prj test.prj -o review_sim work.review_tb > compile.log 2>&1
./review_sim -tclbatch run.tcl > simulation.log 2>&1
cat simulation.log
grep -q 'DONE: review boundary probes' simulation.log
! grep -q 'FAIL:' simulation.log
