# workflow
- Only implement changes explicitly requested; do not refactor, rewrite, or add features beyond what the user asked for. Confidence: 0.85
- When porting a feature from a reference codebase (mangayomi), implement the exact same architecture, patterns, and code structure ("same code and pattern") — avoid simplified reimplementations or shortcuts. Faithful verbatim porting is preferred. Confidence: 0.80
- When fixing bugs in ported code, the first step must be to re-examine the reference codebase (mangayomi) as the authoritative source of truth — understand how it solves the same problem end-to-end before writing any fixes. The reference is not just for initial porting but for all ongoing debugging and decision-making. Confidence: 0.90
- Remove non-functional features rather than leaving broken toggles/settings in place. Confidence: 0.75
- Study and deeply understand existing code architecture before implementing — the user expects thorough research of how a feature works end-to-end before any changes are made. Confidence: 0.85
- The local database should be the authoritative source of truth for all display data, not raw network API responses. Network data should be used only to populate/update the DB, and the UI should always read from the DB. Prevents issues where extensions return incomplete or misaligned metadata. Confidence: 0.80
