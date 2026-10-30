#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cat > "$work/main.swift" <<'SWIFT'
import Foundation

struct Case {
    let label: String
    let current: String
    let copied: String
    let expected: DocumentSnapshotCheck
}

let cases: [Case] = [
    Case(label: "exact copy", current: "hello world", copied: "hello world", expected: .exact),
    Case(label: "nonbreaking space", current: "hello world", copied: "hello\u{00A0}world", expected: .normalized),
    Case(label: "narrow NBSP", current: "hello world", copied: "hello\u{202F}world", expected: .normalized),
    Case(label: "CRLF vs LF", current: "hello\nworld", copied: "hello\r\nworld", expected: .normalized),
    Case(label: "double space must not vanish", current: "hello  world", copied: "hello world", expected: .mismatch("")),
    Case(label: "blank paragraph must not vanish", current: "hello\n\nworld", copied: "hello\nworld", expected: .mismatch("")),
    Case(label: "extra trailing newline", current: "hello", copied: "hello\n", expected: .mismatch("")),
    Case(label: "leading whitespace", current: " a", copied: "a", expected: .mismatch("")),
    Case(label: "tab is not a space", current: "hello\tworld", copied: "hello world", expected: .mismatch("")),
    Case(label: "different text of same length", current: "start", copied: "smart", expected: .mismatch(""))
]

var failures = 0
for example in cases {
    let found = DocumentSnapshotVerifier.check(expected: example.current, copied: example.copied)
    let passed: Bool
    switch (found, example.expected) {
    case (.exact, .exact), (.normalized, .normalized), (.mismatch(_), .mismatch(_)):
        passed = true
    default:
        passed = false
    }
    print("\(passed ? "PASS" : "FAIL"): \(example.label)")
    if !passed { failures += 1 }
}
if failures > 0 { exit(1) }
SWIFT

swiftc "$root/Watch Me Type/DocumentSnapshotVerifier.swift" "$work/main.swift" -o "$work/check"
"$work/check"
