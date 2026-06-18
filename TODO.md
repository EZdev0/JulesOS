# Jules OS TODO List

## Immediate Fixes
- [ ] Investigate why `jules_shell -c "help"` behaves differently in the CI environment than it does locally. (Check if artifact extraction corrupts permissions, or if it relates to Node 24 action environment updates).

## Phase 2 Features (Pending)
- [ ] Implement pure Python print fallback renderer (Ticket PRO-40).
- [ ] Implement OTA `jupdate` core functionality (Ticket PRO-41).
- [ ] Integrate graphical capabilities via Wayland/VirtIO for Jules DE (Ticket PRO-42).
- [ ] Add AI integration hooks in the C++ shell for intelligent command completion.

## Security & Architecture
- [ ] Ensure all CI checks, including `flawfinder` and `cppcheck`, are clear.
- [ ] Complete automated test coverage to verify that the generated OS ISO boots correctly without manual intervention.

## Documentation
- [ ] Finish reviewing `jules-os/docs/features.md` to ensure roadmap is up-to-date and in sync with current changes.
