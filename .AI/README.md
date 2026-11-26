# .AI Project Context — TeaField Capture

This directory holds AI-assistant-ready technical documentation for **TeaField Capture**, an offline-first Flutter field-collection application built for the research project:
**"Reliable Tea Leaf Disease Detection Across Sri Lankan Plantations Using Lightweight Deep Learning."**

- **Repository root:** `E:\tea leaf data collector app\`
- **Flutter application root:** [`teafield_capture/`](../teafield_capture/)
- **Source spec reference:** Implementation covers Milestones 1–10 (v1 field collection, QR pairing, ZIP/CSV export & merge, manual Google Drive backup, and two-stage Trash/purge controls). Milestone 11 (on-device LiteRT inference) is reserved for Phase 2 after training and validation.

---

## Index of Files in `.AI/`

| File | Purpose |
|---|---|
| [`README.md`](./README.md) | Directory entry point, project summary, and quick developer/AI onboarding |
| [`ARCHITECTURE.md`](./ARCHITECTURE.md) | Codebase structure, Riverpod providers, GoRouter routes, SQLite schema, storage & package formats |
| [`CONVENTIONS.md`](./CONVENTIONS.md) | Non-negotiable domain invariants, privacy/security boundaries, lint rules, and package API notes |
| [`WORKFLOWS.md`](./WORKFLOWS.md) | End-to-end mechanics for paired capture, two-phone QR merge, manual Drive backup, and Trash/purge |
| [`STATUS_AND_ROADMAP.md`](./STATUS_AND_ROADMAP.md) | Implemented scope, unverified build/test steps (Flutter SDK setup), OAuth checklist, and Phase 2 LiteRT plan |

---

## Quick Facts for AI Assistants

1. **One physical leaf = one `LeafSample`.** Upper (`adaxial`) and lower (`abaxial`) images are separate `LeafPhoto` rows linked via `sample_uuid`. Never model two leaf surfaces as separate samples.
2. **Never auto-upload or silently delete.** All Google Drive uploads and deletions are strictly user-initiated; local capture and SQLite persistence work 100% offline.
3. **Never touch `.AI/` assumptions blindly against source:** Note that the implemented folder layout inside `teafield_capture/lib/` separates `data/` (`database/`, `models/`, `repositories/`) from `core/` and `features/` (for example `features/sample/`, `features/export/`, `features/import/`, `features/trash/`, `features/data_management/`). Always verify paths in [`ARCHITECTURE.md`](./ARCHITECTURE.md) before creating imports.
4. **SDK note on current workstation:** `flutter` was not present on `PATH` when this codebase was generated, so `flutter create . --platforms=android,ios`, `flutter pub get`, `flutter analyze`, and `flutter test` have not been executed yet. See [`STATUS_AND_ROADMAP.md`](./STATUS_AND_ROADMAP.md).
