# The former script reported PASS without compiling or running the benches.
# Do not use it as verification evidence. The real regression runner compiles
# each bench, requires a PASS marker, and rejects assertion failures/timeouts.
error "Use: python tools/ise_test.py --build C:/Temp/dmd-tests (from repository root)"
