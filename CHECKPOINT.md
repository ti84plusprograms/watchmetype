# Checkpoint: Code Mode usable with IDE assistance disabled; newline reliability unresolved

**Date:** November 4, 2026  
**Baseline Git commit:** `4d8d6858018cc44402d8a7c81ce0505807e0a42b` (merge of PR #2 into `main`)  
**Status:** Working baseline with known limitations — **not a release or a fully verified compatibility milestone**.

## Observed working behavior

- Code Mode is merged, including Python-focused editing UI, syntax highlighting, line numbers, and simulated/exact insertion strategies.
- Simulated Code Mode typing is **substantially usable** in a VS Code-style Python editor when editor assistance is reduced or disabled.
- Turning off macOS **“Add period with double-space”** eliminated the spurious periods in the user's observed test.
- The PR #2 checks passed on the tested commit: **18 SwiftPM unit tests, 9 macOS UI tests, and unsigned Debug/Release builds**. Those tests do **not** establish real-world simulated typing reliability in an external IDE.

## Known defect

Synthetic Return/Enter events are sometimes not reflected in the destination editor. In particular, independent Python lines such as:

```python
import numpy as np
from submission import RandomForest, load_csv
```

have been observed joined into one line, including after disabling auto-pairing and indentation behavior. The unexpected period no longer appears, but the missing newline persists.

In `TypingManager.swift`, simulated typing sends a synthetic Return key-down/key-up event for newline characters and advances through the source without checking that the target inserted the newline. This is a **plausible cause / reliability gap**, not a proven root cause; editor suggestions and input-event timing may also contribute.

## Next development goal

Improve simulated typing so it works reliably with **normal IDE defaults**. Do not require users to disable autocomplete, formatting, or text assistance.

Focus on reproducing missed newline events, testing input-event timing and suggestion interception, comparing Simulated Typing versus Exact Insert, and adding regression coverage and target-editor verification/recovery where feasible.

## Checkpoint usage

This branch preserves the implementation at the PR #2 merge as its parent commit. This `CHECKPOINT.md` documents the baseline only; no application source files are changed on this branch. Do not merge this checkpoint documentation into `main` as a feature fix.
