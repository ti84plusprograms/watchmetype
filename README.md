<table align="center">
  <tr>
    <td>
      <p align="center"><strong>⚠️ Warning ⚠️</strong></p>
      <p>Turn off autocorrect before typing with this app. Autocorrect can interfere with realistic drafting, especially when your draft includes intentional grammar or spelling mistakes. Here's how you can disable it in <a href="https://support.google.com/docs/answer/12022089?hl=en&co=GENIE.Platform%3DDesktop">Google Docs</a> and <a href="https://support.microsoft.com/en-us/office/turn-autocorrect-on-or-off-in-word-9f5a0684-05f6-4510-b419-8f0034caefe4">Microsoft Word</a>.</p>
    </td>
  </tr>
</table>

# Watch Me Type

_because revision history is not learning_

Watch Me Type is an open-source macOS app that types text into any active window with the pacing, pauses, and imperfections of a real person. It can replay a single draft, stage a Draft 1 → Draft 2 revision, or chain a Draft 2 → Draft 3 forward pass. While it runs, it locks to the chosen window, auto-pauses on focus changes, and keeps going for at least as long as you ask.

![Watch Me Type in action](assets/thumbnail.png)

## Purpose

> TL;DR: to force those in charge in education to give teachers the resources they need to adapt to the ubiquity of AI

In the face of genAI, education systems have responded by doubling down on surveillance. Teachers are asked to rely on tools like GPTZero, document revision history, and other forms of process forensics to prove whether a piece of writing is _real_. The burden of this work is pushed downward while the underlying problem is left untouched.

This approach misunderstands both writing and learning. Students do not write in clean, traceable steps. They think out of order. They draft on phones, in notes apps, on paper, in fragments. Or, maybe since teachers just check the final product, students get something like ChatGPT to generate that for them. It's not them being deceitful or devious; _students will always take the path of least resistance._

**Watch Me Type** exists inside this mess. Not to endorse it, but to expose it. If institutions insist on authentic-looking process instead of authentic _learning_, then the process itself becomes something students must manufacture.

The solution is not better detection; it's building actual relationships with students and evaluating the growth of their skills. That requires time, trust, and institutional support for teachers to design tasks that cannot be reduced to a final product check.

**To students:**

> A calculator makes it much easier to cheat on your math test, but it doesn't mean you don't need math in your life. _Apply yourself._

**To my fellow teachers:**

> Until institutions and governing bodies provide the necessary resources for you to adapt to this new age of AI, I am sorry for the chaos this may create in your classrooms.

**To those in charge in education:**

> You put teachers through school to learn about backwards design and competency-based assessments, but without time, staffing, and institutional support, teachers have to resort to policing student work just to make sure the students _might_ be learning. _Please_ give teachers the resources they need to actually do their job well and, maybe, you just might prevent their burnout.

## Features

- simulates human typing with adjustable 40–120 WPM, thinking pauses, comma/sentence/paragraph delays, and occasional mistakes with backspaces
- three modes: single-draft typing, two-phase draft1→draft2 editing (right-to-left edits to avoid cursor drift), or three-phase draft1→draft2→draft3 chaining that adds a left-to-right forward pass with offset-tracked navigation
- duration control: auto-estimated or custom minimum typing/editing time targets ("at least") with live progress tracking and a 10-second countdown
- text clean-up tools: remove blank lines/emojis/bullets/horizontal rules and numbered list prefixes, replace em-dashes, and normalise spacing before and within punctuation when processed
- safe edits: every destructive edit verifies expected text against an internal document snapshot and aborts on mismatch, so a focus glitch or stray keystroke can't silently corrupt the target document
- focus-aware: locks to the chosen app/window; typing auto-pauses and auto-resumes when focus returns; editing aborts on focus loss for safety; overlays for countdown/typing/thinking/editing/paused/complete; compact always-on-top runtime window that resizes itself to match the number of active drafts
- completion screen: shows typing/editing/total duration, donation options, share link, and quick reset for another run
- compatible everywhere: types into any macOS text field (Docs, Word, Notes, IDEs, browsers); prevents sleep during sessions; ESC pauses typing and stops editing
- privacy & localisation: no accounts or tracking; English, Simplified Chinese, and Traditional Chinese localisation
- updates & stack: in-app updates disabled in this fork (see fork section below); built with SwiftUI + AppKit (NSTextView), CoreGraphics CGEvent keyboard simulation, Accessibility APIs, and centralised logging

## Requirements

- macOS 14.6 or newer
- Accessibility permission enabled for Watch Me Type (required for keyboard simulation and focus tracking)

## Built with

- Swift and SwiftUI for the UI shell
- AppKit (NSTextView/NSScrollView via NSViewRepresentable) for native text editing with launch focus
- CoreGraphics (CGEvent) for keyboard event injection
- macOS Accessibility APIs for focus tracking, target-window locking, and the lazy permission flow
- a pure Swift diff engine (sentence and word-level LCS), shared between the right-to-left and left-to-right edit planners
- Sparkle code remains in the upstream app, but all update functionality is disabled in this fork (see fork section below)
- centralised `os.log`-backed logging through the `appLog` global
- XCTest unit and integration tests covering the diff engine and the three-draft pipeline

## Architecture

Source layout under `Watch Me Type/`:

- `Watch_Me_TypeApp.swift` is the entry point. It hosts `ContentView`; Sparkle startup is disabled in this fork, so it does not check for or install updates.
- `ContentView.swift` carries all UI: draft 1/2/3 editors, settings, overlays, the text-cleanup pipeline, and window management. The custom equal-width column layout, the fused edit-card and editor panels, and the auto-resizing window that adapts to the number of active drafts all live here.
- `TypingManager.swift` is the `ObservableObject` state machine (`idle → countingDown → typing → editing → paused`). It owns CGEvent injection, focus lock, sleep prevention, the ESC handler, and direction-aware edit execution. The Draft 2 path walks edits backward with backspaces; the Draft 3 path walks edits forward with shift-select-then-backspace and an offset accumulator. Before each destructive edit, the manager checks the live document against an internal snapshot and aborts on mismatch.
- `EditOperationConverter.swift` is the diff engine, kept deliberately pure: free functions only, no side effects, no imports beyond `Foundation`. A hybrid sentence and word-level LCS produces positioned edits, sortable right-to-left (`.rightToLeft`) or left-to-right (`.leftToRight`) via the `EditSortDirection` enum.
- `Logger.swift` wraps `os.Logger` in an `AppLogger` singleton with a six-level model: `none`, `error`, `warning`, `info`, `debug`, `verbose`. Always log through `appLog(_:level:)`.
- `AccessibilityPermissionHelper.swift` handles the lazy permission request, triggered from the in-app explanation screen rather than at launch.

The diff pipeline runs in five steps:

1. sentence tokenisation with abbreviation awareness (so "Dr.", "etc.", single initials, and embedded periods don't break sentence boundaries)
2. sentence pairing via Jaccard similarity
3. word-level LCS diff for pairs above `SIMILARITY_THRESHOLD = 0.4`, atomic sentence replace below it
4. word tokenisation that preserves whitespace tokens, so cursor positions stay accurate
5. position mapping into the source draft, followed by direction-aware sorting:
   - **Draft 1 → 2** (right-to-left): descending position. Edits apply without offset accumulation, because each edit's position is unaffected by edits already made further right.
   - **Draft 2 → 3** (left-to-right): ascending position. An offset accumulator nudges each subsequent edit's target position by the net length change of the preceding edits.

At execution time, the manager pauses about two seconds between phases, navigates with arrow keys (roughly 0.08s per press, 0.3s settle), and applies each edit either with a backspace run (backward) or with a shift-select-then-backspace (forward). Every destructive operation first verifies `expectedText` and `expectedOldText` against the tracked document snapshot, and aborts to `idle` if anything has drifted.

Tests under `Watch Me TypeTests/` cover `EditOperationConverter` (tokenisation, similarity, LCS, both sort directions) and the three-draft pipeline end to end. UI and CGEvent behaviour are not currently unit-tested.

## Installation

1. **No fork DMG is currently published.** Compile this fork locally from source using the Xcode project below. Do not use the upstream DMG as a substitute for the fork.
2. Choose your own signing team under Xcode **Signing & Capabilities** if required, then Build/Run.
3. Debug builds use **Watch Me Type Dev** (`com.ti84plusprograms.watchmetype.dev`); Release builds use **Watch Me Type Fork** (`com.ti84plusprograms.watchmetype`). Both are distinct from the original upstream app, and from each other.
4. Grant **Accessibility** permission separately to the exact executable you run: **System Settings > Privacy & Security > Accessibility**. Previously granted permissions for upstream or a different build do not automatically apply.
5. **All in-app Sparkle update functionality is disabled** in this fork: automatic checks in the plist, updater startup, and the manual Check for Updates menu. The fork feed is intentionally empty. Do not turn update functionality back on until a signed and authorized fork release is ready.

### Build version metadata

Before compiling the app, Xcode runs `scripts/generate-git-info.sh` and writes
`GitInfo.generated.swift` to `DERIVED_FILE_DIR`. The generated source is part of
the app target. **About Watch Me Type** shows the app version, a 12-character
commit hash, and either `clean` or a short local-change ID. Its details show
the branch, full commit, nearest-tag description, UTC build time, and the path
of the running app. The local-change ID hashes staged and unstaged tracked
changes plus the names and contents of non-ignored untracked files, so two
different uncommitted worktrees can be distinguished. Ignored files are not
included. This identifies the checkout used for a build; confirming that it
matches the current remote branch still requires refreshing and comparing the
remote tracking branch. The project keeps **User Script Sandboxing** disabled
because the trusted script reads repository metadata under `.git`; the app's
runtime sandbox remains enabled. The build fails with a clear error if Git
metadata is unavailable instead of silently compiling without version
information.

### Fork signing and future update setup

This is a **pre-release checklist only**; no signing key or release is created by this branch.

- Obtain the upstream copyright holder's **written redistribution permission** before publishing modified source or binaries. The current `LICENCE.md` restricts redistribution, even for a non-commercial fork.
- On a trusted Mac, run Sparkle's bundled `generate_keys` once; the private Ed25519 key is stored in the login Keychain by default. Save the printed **public** key as `SUPublicEDKey` in `Watch-Me-Type-Info.plist`.
- The existing `scripts/sign-update.sh` expects a private key **file**, not the default Keychain location. If you choose this script, use `generate_keys -x /path/to/private-key-file` to export the Keychain key into a secured local file and set `SPARKLE_KEY` to that location; otherwise sign directly using the Keychain-aware Sparkle tooling. Never commit, distribute, or upload private-key material. Run `generate_keys -h` to confirm syntax for your installed Sparkle version.
- Sign/notarize a fork-owned release, sign its update archive with the fork key, publish and verify `docs/appcast.xml` on the fork's Pages domain, and only then restore Sparkle startup/menus and consider enabling automatic checks. Do not copy upstream signatures or keys.
- The `fork-identity-ci.yml` workflow tests the unsigned app's identity and disabled-update configuration. It cannot verify a locally signed, notarized release or actual macOS Accessibility behavior.

## Code Mode (feature branch)

The original SwiftUI layout is retained. The existing **Typing Speed** card now
includes **Code Mode**, **Thinking Pauses**, and **Simulate Mistakes** controls.
The original prose slider remains **40–120 WPM**, initially at 80 WPM with
thinking and mistakes on. Code Mode offers **40–400 WPM**, with thinking and
mistakes initially off; it retains the current numeric WPM when switched on. Slider endpoints and labels change with Code Mode. Switching modes keeps the
current numeric WPM, capped to the destination range (e.g., 120 prose → 120
code; 350 code → 120 prose). The slider thumb moves to the appropriate relative
position. Thinking and mistake preferences remain independent per mode.

**Code Mode** sends the supplied source text without running the Clean-Up
processor. Code Mode displays a compact formatting notice in place of
Clean-Up controls, protecting indentation, tabs and blank lines. Normal
prose cleanup remains available.

### Python-first code editor

Switching on **Code Mode** changes the appearance of all visible Draft editors
without changing their source strings: monospaced font, tinted editor background,
distinct border, PYTHON indicator, a scroll-synchronized line-number gutter,
and line/character counts in place of prose word counts. Returning to Normal
Mode restores the original appearance and the original macOS text-input
preferences. Code Mode disables smart quotes, smart dashes, automatic spelling
correction, text replacement, and automatic text completion inside Watch Me Type
so Python punctuation is not silently rewritten.

The Python lexer colors common keywords, definitions, decorators, built-ins,
numbers, constants, comments, and single/double/triple-quoted strings (including
simple string prefixes and f-strings). Coloring uses temporary TextKit layout
attributes, leaving the backing plain text, selection, and undo history intact.
This is *syntax highlighting*, not a compiler or full Python parser. Complex
f-string interpolation and arbitrary-language detection are not implemented.
Non-Python code remains unmodified but may receive misleading Python colors;
for now the language indicator explicitly says **PYTHON**.

The SwiftPM tests cover lexer ranges and text-preservation behavior. The
macOS CI compiles the AppKit UI and runs a separate screenshot-producing
XCUITest suite; external Accessibility injection still requires manual tests.

### Automated macOS UI testing

An XCUITest target named `WatchMeTypeUITests` is included in the shared
Watch Me Type scheme. Nine scenarios test empty and multiline Python (light and dark),
long lines, scrolling, Code Mode/Normal Mode switching, and two/three drafts.
The tests launch the actual GUI and retain a window screenshot for each case.

Fixture state is enabled **only** by the `--wmt-ui-tests` app launch argument;
`WMT_UI_FIXTURE` accepts `empty`, `python`, `wrapped`, `scroll`, `normal`,
`two-drafts`, or `three-drafts`. Setting `WMT_UI_APPEARANCE=dark` forces
Dark Mode only for an explicitly marked test launch. Normal launches keep
the original blank state and follow system appearance.
Test mode skips Accessibility onboarding and disables Start, so it cannot
issue synthetic typing or clipboard insertion into external apps.

Run on an unlocked Mac with Xcode selected, from the repository root:

```bash
xcodebuild test \
  -project "Watch Me Type.xcodeproj" \
  -scheme "Watch Me Type" \
  -configuration Debug \
  -destination 'platform=macOS' \
  -parallel-testing-enabled NO \
  -only-testing:WatchMeTypeUITests \
  -resultBundlePath "$PWD/CodeModeUITests.xcresult"

xcrun xcresulttool export attachments \
  --path "$PWD/CodeModeUITests.xcresult" \
  --output-path "$PWD/CodeModeUITestScreenshots"
```

Use a new `.xcresult` path for each run. CI uploads screenshots, the result
bundle, and logs even on UI-test failure. The multiline Python test
also samples pixels away from the gutter to catch fully invisible glyphs.
This is a coarse sanity check, not a reference-image comparison:
**inspect screenshots** for syntax coloring, caret, headers, and gutters.
No full pixel-diff baseline is enabled. GitHub-hosted macOS
runners may lack usable interactive GUI automation; in that case use a
local unlocked Mac or an authorized self-hosted macOS runner.

**Code Input** uses an extra compact control inside the existing Typing Speed
card. **Simulated** types characters individually (with a longer pause after
newlines, tabs, and brackets to give editors time to process them). In
Code Mode, simulated newlines now follow a fixed sequence, in order,
in both the initial typing pass and Draft 2/3 revision passes:
(1) a tagged synthetic Escape dismisses IDE completion so Return
cannot accept a suggestion instead of creating a newline, with the
Return deferred 0.10s and the per-newline pause at 0.25s so the Return
lands before the next character; if initial typing pauses before that
Return fires, the newline is retried on resume rather than skipped
(revision pauses cancel the deferred Return and resume re-executes
the current edit, which attempts the newline again); (2) Return;
(3) a single delayed Cmd+Left to the start of the new line
(Return 0.10s, reset 0.15s, next character 0.25s), so an IDE's
auto-indent does not compound with the source text's own
leading spaces. A second Cmd+Left was tried first and made
the staircase worse, because VS Code's Home toggles between
the first non-whitespace character and column 0. Two later
attempts were reverted before this merge: option A, a
closed-loop Accessibility cursor-column read-back that
showed no change in testing, and option B, an IDE-aware
stream that adjusted the column with Backspace — B deleted
characters from the previous line when the AX column reading
was wrong (identical truncation at 100 and 400 WPM proved
it was logic, not speed), so it was removed. The single
delayed reset still leaves about half the lines +4 in
testing, because auto-indent lands at variable latency.
(4) Closing brackets/quotes in Code Mode simulated typing
are sent as real key presses (US ANSI keycodes, Shift where
needed), not as unicode strings: VS Code auto-inserts a
closer when an opener is typed, but a unicode closer is
inserted as text and does not trigger overtype, so auto-closers
get pushed to the end of the line (e.g.
`str(sorted([3, 1, 2]))))"` in the isolated one-line test).
A real key press overtypes an auto-closer immediately before
the cursor, and simply inserts when there is none (e.g. inside
a string, where VS Code did not auto-close). Openers stay
unicode, prose is unchanged, and Exact Insert does not go
through this path.

Current state, honestly: with VS Code at its defaults —
auto-indent on, completion on, `acceptSuggestionOnEnter` on,
auto-closing brackets/quotes on, format-on-type off,
format-on-paste off — simulated typing still leaves about
half the lines +4. The reliable setup for this version is
the assistance-off settings (auto-indent off, auto-closing
off, completion off, format-on-type/paste off, macOS "Add
period with double-space" off), which the app also shows
in its Code Mode settings card as the copy-paste workspace
settings. That card's defaults JSON is the target for a
future fix, not a claim that a run with those settings has
passed. Format-on-type is off by default; if a user
explicitly enables it, the formatter can reindent a line
after `;` or `}` and this app cannot reliably undo that, so
that setting remains unsupported. Simulated typing still
does not verify that the target actually inserted a newline
— there is no Accessibility read-back of the target document
in this app, so a Return dropped while focus and state stay
normal can still join lines. That verification is a separate,
per-editor feature, not something a timing change can claim.
Verify in the target IDE first — the automated tests do not
send keystrokes to an external editor, so they cannot catch
this class of failure. Disabling completion/auto-indent
remains the reliable setup for this version, not just a
fallback.

**Exact Insert** instead issues a single standard macOS Paste command with
the complete source text. This avoids per-Return autoindent and per-character
bracket completion. The clipboard's readable formats are restored after the
IDE has time to consume the paste, provided no other process has changed the
clipboard in the meantime. Some IDEs format pasted text; disable format-on-paste
to improve fidelity. Exact Insert is one bulk insertion, not simulated typing,
does not honor Custom Typing Duration, and does not verify the resulting text.
Draft 2/3 revision phases still use simulated edits.

**Code revisions** use a deterministic line-aligned changed region, avoiding
sentence and word similarity heuristics. This is intentionally conservative:
a change spanning many lines can retype the full changed section. Prose
revisions continue using the original algorithm. This application cannot
guarantee exact behavior in every third-party editor.

**Thinking Pauses** controls random word, punctuation, and paragraph delays
during both typing and revisions. An explicit **Custom Duration** can still
introduce deliberate delays. **Simulate Mistakes** is independent of thinking.
At very high WPM some editors may drop synthetic key events: start with
160–240 WPM and check the output before increasing to 400.

**Testing checklist:** on a disposable text file, verify a function with
nested indentation, multiple blank lines, tabs, punctuation, and a trailing
newline at 80 and 240 WPM. Then verify Draft 1 → 2 with a small replacement.
Compare the final text literally, not just visually.

**Manual external-IDE checks (required — no automated test covers these):**
use a disposable file, never a real submission file, and compare the
result literally (for example with `diff` against the source text).

1. **Staircase / auto-indent check (VS Code, default auto-indent left
on):** simulated-type a short Python function with nested indentation
plus a dedented line after it into a new empty `.py` file. Every line's
leading whitespace must match the source exactly, and the dedented line
must return to column 0 — not accumulate indent from the previous line.
2. **Completion-open newline check (VS Code, completion left on):**
simulated-type independent lines that would normally trigger a
completion popup (for example `import numpy as np` followed by
`from submission import RandomForest, load_csv`) into a new empty
`.py` file. The lines must stay on separate lines — no joined lines,
and no accepted suggestion text inserted instead of a newline. Repeat
the same check for a Draft 1 → 2 revision containing a newline — revisions
now get the same Escape dismissal, via a separate deferred work item.
4. **Default-settings bracket/quote check (VS Code, auto-closing left
on, format-on-type left off as shipped):** simulated-type a line with
nested brackets and quoted strings, for example
`x = foo(bar("a", [1, 2]), "b")`, into a disposable `.py` file. The
output must contain exactly one of each closer — VS Code overtype
should absorb the app's closer, not duplicate it. Repeat in a revision.
5. **Pause-during-newline check:** start a simulated Code Mode run,
switch focus away just as a newline is due (or press Escape manually
to pause), then switch back and resume. The pending newline must be
delivered on resume, not skipped, and no character must be duplicated
or lost. For revisions, note resume re-executes the current edit, so
check the whole edit, not just the newline.

If any check fails in a given IDE, do not use simulated typing for
that IDE yet; use Exact Insert with format-on-paste disabled instead,
and record which IDE and which check failed.

**If the countdown runs but no text appears:** first try a disposable
plain-text TextEdit document, with the caret visibly inside the text area
before countdown reaches zero. An Xcode-run build may need Accessibility
permission separately from the installed DMG. Check **System Settings >
Privacy & Security > Accessibility** for the build you are actually running;
quit and reopen it after granting permission if needed. The app now rechecks
permission on Start and again when the countdown ends, and displays an
actionable error if no external target application is frontmost. If TextEdit
works but a browser editor does not, investigate the browser's text focus and
autocorrection behavior. The source cannot verify delivery into every
third-party editor.

Normal prose mode and its revision algorithm remain unchanged. Code Mode
alone uses the line-aware diff. The experimental *edit already existing Google
Doc* branch is not included.

## Usage notes

- While the app is typing, the device is effectively unavailable; switching apps auto-pauses until you return. I would recommend running this in a VM.
- Provide Draft 2 to simulate a realistic revision of Draft 1; leave it blank for a single-draft run.
- Toggle "I have a draft 3." to chain a second revision pass that walks Draft 2 left-to-right into Draft 3 (useful when a single revision cycle isn't enough to look authentic).
- Use custom durations if you need a session to last a minimum amount of time; otherwise the app estimates based on WPM and text length.
- During any editing phase, focus or window changes abort editing to avoid writing in the wrong place. If that happens, use Cmd+Z in your target app.
- ESC pauses during typing, but stops editing sessions outright.

### Text cleanup behaviour

- Click **Process** to apply cleanup to Draft 1 and, if present, Draft 2 and Draft 3.
- Toggle-controlled cleanup includes removing blank lines, emojis, horizontal rules, bullet and numbered-list prefixes, and replacing em dashes with commas.
- Space normalisation (collapsing repeated spaces and removing spaces before punctuation) always runs during processing.

### Effective use

This app works best as part of a longer writing process. Generate drafts _elsewhere_, then use Watch Me Type to reproduce how writing normally appears over time (Draft 1) and, if needed, to stage a believable revision into Draft 2 and an optional polish pass into Draft 3.

## Build from source

```bash
xcodebuild -project "Watch Me Type.xcodeproj" -scheme "Watch Me Type" -destination 'platform=macOS' build
```

## Run tests

The Xcode project currently has **no XCTest target**. The existing
`Watch Me TypeTests` source files are not connected to its scheme, so
`xcodebuild test` is **not** a valid test command for this project.

Code Mode's cross-platform parsing/diff tests are connected to a standalone
Swift package. Run them with:

```bash
swift test --package-path .
```

The `.github/workflows/macos-code-mode.yml` workflow runs that test command
and builds the macOS application with signing disabled on `macos-15` using
Xcode 26.3. It records the checked-out commit, runner, Xcode/Swift versions,
SHA-256 checksums of the evidence, and logs as run artifacts. The CI evidence
does **not** include an installable build because the project's source-available
license prohibits redistribution of modified binaries without permission.
It also cannot test whether macOS Accessibility keystrokes are accepted
inside a particular IDE; that still requires a manually authorized GUI session.

## Contributing

Issues, pull requests, and feature suggestions are welcome.

## Supporting this project

Starring and sharing the project would help this reach educators and students who may benefit from it, either for their own work or as justification to rally for institutional change.

## Licence

This project is released under a source-available licence.

You are free to view, use, and modify the source code for personal and educational purposes. Commercial use, redistribution, hosting, or selling this software, including modified versions, is not permitted without explicit permission from the author.

The source is shared to support transparency, learning, and community discussion, not to enable resale or unauthorised distribution.

For details, see [LICENCE.md](LICENCE.md).
