# Backup / Restore Hardening Roadmap

Roadmap này chỉ là chỉ mục. Agent không được triển khai một mục chỉ vì nó xuất hiện ở đây. Chỉ task được chỉ định trong `STATUS.md` và có file specification với trạng thái `READY` mới được phép thực hiện.

## Phase 0 — Reliable Command Execution

- TASK-0.1 — Stabilize `CommandResult` contract. **COMPLETED**
- TASK-0.2 — Add opt-in total deadline, bounded capture and deterministic direct-child timeout result. **READY**
- TASK-0.3 — Configure process group at spawn time and upgrade timeout termination to the whole command group. **LOCKED**
- TASK-0.4 — Add direct executable plus argv API for critical operations. **LOCKED**
- TASK-0.5 — Add compatibility result-returning wrapper in `AppDataCleaner`. **LOCKED**

## Phase 1 — Clear Data Safety Boundary

- TASK-1.1 — Introduce immutable `PXResolvedContainer`. **LOCKED**
- TASK-1.2 — Add exact data-container resolver. **LOCKED**
- TASK-1.3 — Add canonical destructive-path validator. **LOCKED**
- TASK-1.4 — Remove writes to application bundle containers. **LOCKED**
- TASK-1.5 — Introduce typed `PXClearRequest`. **LOCKED**
- TASK-1.6 — Introduce structured `PXClearResult`. **LOCKED**
- TASK-1.7 — Migrate main data-container clear. **LOCKED**
- TASK-1.8 — Migrate extension-container clear. **LOCKED**
- TASK-1.9 — Migrate app-group clear. **LOCKED**
- TASK-1.10 — Integrate keychain clear result correctly. **LOCKED**
- TASK-1.11 — Remove unsafe permission and marker-file behavior. **LOCKED**
- TASK-1.12 — Quarantine ambiguous legacy clear APIs. **LOCKED**

## Phase 2 — Restore Preflight and Transaction

- TASK-2.1 — Add manifest schema validator. **LOCKED**
- TASK-2.2 — Enforce supported manifest versions. **LOCKED**
- TASK-2.3 — Enforce exact bundle identifier match. **LOCKED**
- TASK-2.4 — Remove manifest path and UUID destination fallback. **LOCKED**
- TASK-2.5 — Add common artifact verifier. **LOCKED**
- TASK-2.6 — Add archive-entry safety validator. **LOCKED**
- TASK-2.7 — Build immutable `PXRestorePlan`. **LOCKED**
- TASK-2.8 — Stage and validate main data. **LOCKED**
- TASK-2.9 — Stage and validate app groups. **LOCKED**
- TASK-2.10 — Stage optional components. **LOCKED**
- TASK-2.11 — Transactional commit and rollback for main data. **LOCKED**
- TASK-2.12 — Transactional commit and rollback for app groups. **LOCKED**
- TASK-2.13 — Transactional handling for advanced components. **LOCKED**
- TASK-2.14 — Add structured restore result. **LOCKED**

## Phase 3 — Atomic Backup Publication

- TASK-3.1 — Create unique partial transaction directory. **LOCKED**
- TASK-3.2 — Add per-bundle backup serialization. **LOCKED**
- TASK-3.3 — Add common verified artifact writer. **LOCKED**
- TASK-3.4 — Derive preferences inclusion from verified output. **LOCKED**
- TASK-3.5 — Define required and optional artifact policy. **LOCKED**
- TASK-3.6 — Introduce manifest schema v4. **LOCKED**
- TASK-3.7 — Write and validate manifest atomically. **LOCKED**
- TASK-3.8 — Publish completed backup atomically. **LOCKED**
- TASK-3.9 — Centralize cleanup for all failure paths. **LOCKED**
- TASK-3.10 — Harden backup discovery and stale partial cleanup. **LOCKED**

## Phase 4 — Keychain Safety

- TASK-4.1 — Add structured helper result. **LOCKED**
- TASK-4.2 — Define reliable helper exit codes. **LOCKED**
- TASK-4.3 — Remove broad pre-delete from restore. **LOCKED**
- TASK-4.4 — Define exact identity for each keychain class. **LOCKED**
- TASK-4.5 — Implement per-item upsert. **LOCKED**
- TASK-4.6 — Secure helper temporary workspace and path validation. **LOCKED**
- TASK-4.7 — Report requested and effective access groups. **LOCKED**
- TASK-4.8 — Integrate partial keychain result into manager. **LOCKED**
- TASK-4.9 — Finalize keychain backup protection policy. **LOCKED**

## Phase 5 — UI and Result State

- TASK-5.1 — Distinguish backup success, warning and failure titles. **LOCKED**
- TASK-5.2 — Distinguish restore and rollback outcomes. **LOCKED**
- TASK-5.3 — Display component-level results. **LOCKED**
- TASK-5.4 — Require explicit confirmation for advanced scopes. **LOCKED**

## Phase 6 — Legacy Quarantine and Regression Guards

- TASK-6.1 — Reduce destructive public API surface. **LOCKED**
- TASK-6.2 — Deprecate or remove ambiguous aliases. **LOCKED**
- TASK-6.3 — Add static CI regression guards. **LOCKED**
- TASK-6.4 — Add malicious archive fixtures. **LOCKED**
- TASK-6.5 — Add transaction fault-injection tests. **LOCKED**
- TASK-6.6 — Publish compatibility and safety documentation. **LOCKED**

## Opening a new task

Sau khi task hiện tại qua review và GitHub Actions:

1. Coordinator xem lại source sau thay đổi.
2. Coordinator điều chỉnh dependency và contract của task kế tiếp.
3. Coordinator tạo một file mới trong `tasks/`.
4. Coordinator cập nhật `STATUS.md`.
5. Chỉ sau đó agent mới được bắt đầu.
