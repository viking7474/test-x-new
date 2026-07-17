# TASK-5.1 Implementation Report

## Result
IMPLEMENTED. Direct backup result presentation now classifies valid success, completed-with-warnings, and failure outcomes with exact locked titles. Static/model gates pass. Apple build/package and device UI execution are pending because this workspace is Windows without the Apple toolchain or a connected test device.

## User authority
The task request explicitly unlocks TASK-5.1 despite the roadmap lock. TASK-4.9A is user-authority PASSED and COMPLETED. TASK-5.2 is outside this implementation.

## TASK-4.9A review-file status
`docs/backup-restore-hardening/reviews/TASK-4.9A-REVIEW.md` is absent. The task specification declares this non-blocking. `TASK-4.9A-REPORT.md` remains byte-identical: SHA-256 `158e865f4a337014a1bd262dbeb43c558dd991a794e22e5c71fd0f75ac4df6c5`, 59119 bytes.

## Baseline
- Required baseline: `2ff1576e7e37ad016301ac419f1ca2536f66196c`
- Expected HEAD: `2ff1576 phase4(task-4.9A): fix manager keychain policy validation`
- Baseline matched before implementation.

## Working-tree preservation
Pre-existing modifications in `STATUS.md`, `ROADMAP.md`, `DECISIONS.md`, and `README.md`, plus pre-existing untracked task/review documents, were not staged, reset, deleted, formatted, or edited. The implementation commit is restricted to the controller and this report.

## Exact authorized scope
- `M AppDataBackupRestoreViewController.m`
- `A docs/backup-restore-hardening/reports/TASK-5.1-REPORT.md`
- No header, manager/core, batch caller, Keychain, Makefile, or coordinator document mutation.

## Caller inventory
| Production caller | Count | Role |
|---|---:|---|
| `AppDataBackupRestoreViewController.m` | 1 | Direct result alert owner |
| `ProfileManagerViewController.m` | 1 | Multi-app warning/error aggregation |
| `ProjectXViewController.m` | 1 | RRS batch recursion/manifest update |

Total production callers remain exactly three.

## Current defect reproduction
Baseline direct backup callback used `Backup Complete` for every nil-error callback, including warnings, accepted `result == nil && error == nil` as apparent success with `(unknown)`, and constructed an unused backup `errAlert`.

## Manager callback contract
Manager success remains `completion(result, nil)` with published directory, published manifest path, and warnings. Manager failures remain `completion(nil, error)`. The presentation layer now fails closed for nullable-signature anomalies without changing the manager contract.

## Outcome taxonomy
| Outcome | Condition |
|---|---|
| Successful | nil error, valid result, zero warnings |
| CompletedWithWarnings | nil error, valid result, positive warning count |
| Failed | non-nil error, invalid result, or unknown state |

## Exact title contract
| Outcome | Exact title | Literal count |
|---|---|---:|
| Successful | `Backup Successful` | 1 |
| CompletedWithWarnings | `Backup Completed with Warnings` | 1 |
| Failed | `Backup Failed` | 1 |

Exact old literal `@"Backup Complete"` count is 0 in the controller.

## Result validity contract
`PXBackupResultIsValidForPresentation` requires the runtime class `PXBackupResult`, non-empty NSString `backupDirectory`, non-empty NSString `manifestPath`, NSArray `warnings`, and only non-empty NSString warning elements. It performs no filesystem, manifest, digest, or publication revalidation.

## Error precedence
`error != nil` is evaluated first and always yields Failed, including callbacks that also contain a valid result or warnings. Result path and warnings are not appended in this state.

## Invalid-result handling
Nil or malformed results fail closed with exact fallback `Backup failed without a valid result.` and `copyPath:nil`. The direct backup callback no longer emits `(unknown)` as a successful published path.

## Message contract
- Success retains application identifier and exact path, without warning section.
- Warning retains base message, warning order, duplicates, capitalization, and punctuation.
- Usable NSError descriptions are shown without domain/code decoration.
- Unusable or absent NSError descriptions use the exact fallback.

## Copy Path contract
Only valid Successful and CompletedWithWarnings outcomes receive `result.backupDirectory`. Failed and unknown states always receive nil, including error-plus-valid-result callbacks.

## Pending alert behavior
Existing `pendingAlertTitle`, `pendingAlertMessage`, `pendingCopyPath`, delivery method, and best-effort presenter are unchanged. The classified title/message are queued exactly; failure queues nil copy path, preventing stale success-path authority.

## Dead-code removal
The direct backup callback contains zero `UIAlertController *errAlert` declarations and one final `_presentResultAlertBestEffortWithTitle:` call. The whole controller still contains one baseline `errAlert` inside the untouched restore callback. This resolves the specification conflict in favor of the explicit restore zero-diff boundary; removing or renaming that restore local would violate the required restore-source proof.

## Source diff explanation
A private enum and three private helpers were added at implementation scope. The direct backup completion now classifies, resolves title, builds outcome-specific message/copy path, and presents once. No other production branch was edited.

## Static source gates
| Gate | Result |
|---|---|
| `Backup Successful` exact literal | PASS (1) |
| `Backup Completed with Warnings` exact literal | PASS (1) |
| `Backup Failed` exact literal | PASS (1) |
| old exact `Backup Complete` literal | PASS (0) |
| private enum/helpers | PASS |
| direct callback dead `errAlert` | PASS (0) |
| direct callback `(unknown)` | PASS (0) |
| direct callback presentation calls | PASS (1) |
| balanced delimiters | PASS |
| conflict markers/NUL | PASS |

## Deterministic model design
A temporary external Python/PowerShell model mirrored validity, precedence, title, message, Copy Path, and pending-state rules. It was executed outside the repository and deleted after use.
- Core callback matrix: 9 PASS
- Invalid-result matrix: 10 PASS
- Warning cardinalities 0/1/2/16/256: 5 PASS
- Error precedence variants: PASS
- Message and pending-state assertions: PASS
- Unknown enum fail-closed mapping: PASS

## Callback truth table
| Result | Error | Warnings | Outcome |
|---|---|---:|---|
| valid | nil | 0 | Successful |
| valid | nil | 1 | CompletedWithWarnings |
| valid | nil | many | CompletedWithWarnings |
| nil | nil | — | Failed |
| invalid | nil | — | Failed |
| valid | error | 0 | Failed |
| valid | error | 1+ | Failed |
| nil | error | — | Failed |
| invalid | error | — | Failed |

## Explicit scenarios
Explicit numbered scenario count: 320.

| # | Group | Scenario | Evidence | Status |
|---:|---|---|---|---|
| 1 | Baseline inventory | HEAD equals required baseline 2ff1576e7e37ad016301ac419f1ca2536f66196c | Static/model evidence | PASS |
| 2 | Baseline inventory | Expected short HEAD is 2ff1576 phase4(task-4.9A) | Static/model evidence | PASS |
| 3 | Baseline inventory | TASK-4.9A user authority is PASSED | Static/model evidence | PASS |
| 4 | Baseline inventory | TASK-4.9A user authority is COMPLETED | Static/model evidence | PASS |
| 5 | Baseline inventory | TASK-4.9A review file is absent and not a blocker | Static/model evidence | PASS |
| 6 | Baseline inventory | Controller baseline size is 28132 bytes | Static/model evidence | PASS |
| 7 | Baseline inventory | Controller baseline SHA-256 matches 48e86f63... | Static/model evidence | PASS |
| 8 | Baseline inventory | Controller baseline uses UTF-8 CRLF | Static/model evidence | PASS |
| 9 | Baseline inventory | Exactly three production callers are present | Static/model evidence | PASS |
| 10 | Baseline inventory | Direct controller owns one caller | Static/model evidence | PASS |
| 11 | Baseline inventory | Profile manager owns one batch caller | Static/model evidence | PASS |
| 12 | Baseline inventory | ProjectX controller owns one RRS caller | Static/model evidence | PASS |
| 13 | Baseline inventory | Coordinator documents are pre-existing dirty files | Static/model evidence | PASS |
| 14 | Baseline inventory | Pre-existing review/task files are preserved | Static/model evidence | PASS |
| 15 | Baseline inventory | No TASK-5.2 source is opened or modified | Static/model evidence | PASS |
| 16 | Callback truth table | valid result, nil error, zero warnings -> Successful | Static/model evidence | PASS |
| 17 | Callback truth table | valid result, nil error, one warning -> CompletedWithWarnings | Static/model evidence | PASS |
| 18 | Callback truth table | valid result, nil error, many warnings -> CompletedWithWarnings | Static/model evidence | PASS |
| 19 | Callback truth table | nil result, nil error -> Failed | Static/model evidence | PASS |
| 20 | Callback truth table | wrong result class, nil error -> Failed | Static/model evidence | PASS |
| 21 | Callback truth table | valid zero-warning result plus error -> Failed | Static/model evidence | PASS |
| 22 | Callback truth table | valid warning result plus error -> Failed | Static/model evidence | PASS |
| 23 | Callback truth table | nil result plus error -> Failed | Static/model evidence | PASS |
| 24 | Callback truth table | invalid result plus error -> Failed | Static/model evidence | PASS |
| 25 | Callback truth table | valid result with 2 warnings -> CompletedWithWarnings | Static/model evidence | PASS |
| 26 | Callback truth table | valid result with 16 warnings -> CompletedWithWarnings | Static/model evidence | PASS |
| 27 | Callback truth table | valid result with 256 warnings -> CompletedWithWarnings | Static/model evidence | PASS |
| 28 | Callback truth table | valid empty warning array -> Successful | Static/model evidence | PASS |
| 29 | Callback truth table | error precedence ignores valid backupDirectory | Static/model evidence | PASS |
| 30 | Callback truth table | error precedence ignores valid manifestPath | Static/model evidence | PASS |
| 31 | Callback truth table | error precedence ignores warning count | Static/model evidence | PASS |
| 32 | Callback truth table | invalid result cannot select success title | Static/model evidence | PASS |
| 33 | Callback truth table | invalid result cannot select warning title | Static/model evidence | PASS |
| 34 | Callback truth table | unknown enum maps to failure title | Static/model evidence | PASS |
| 35 | Callback truth table | classifier returns only locked outcome values | Static/model evidence | PASS |
| 36 | Success titles | Valid zero-warning result uses exact title Backup Successful | Static/model evidence | PASS |
| 37 | Success titles | Success title literal occurs exactly once | Static/model evidence | PASS |
| 38 | Success titles | Old exact literal Backup Complete is absent | Static/model evidence | PASS |
| 39 | Success titles | Success path requires PXBackupResult runtime class | Static/model evidence | PASS |
| 40 | Success titles | Success path requires non-empty backupDirectory | Static/model evidence | PASS |
| 41 | Success titles | Success path requires non-empty manifestPath | Static/model evidence | PASS |
| 42 | Success titles | Success path requires NSArray warnings | Static/model evidence | PASS |
| 43 | Success titles | Success path requires every warning to be non-empty NSString | Static/model evidence | PASS |
| 44 | Success titles | Success message contains application identifier | Static/model evidence | PASS |
| 45 | Success titles | Success message contains exact backup path | Static/model evidence | PASS |
| 46 | Success titles | Success message omits Warnings section | Static/model evidence | PASS |
| 47 | Success titles | Success path exposes Copy Path | Static/model evidence | PASS |
| 48 | Warning titles | Valid one-warning result uses Backup Completed with Warnings | Static/model evidence | PASS |
| 49 | Warning titles | Valid two-warning result uses warning title | Static/model evidence | PASS |
| 50 | Warning titles | Valid 16-warning result uses warning title | Static/model evidence | PASS |
| 51 | Warning titles | Valid 256-warning result uses warning title | Static/model evidence | PASS |
| 52 | Warning titles | Warning title literal occurs exactly once | Static/model evidence | PASS |
| 53 | Warning titles | Warning outcome remains a published backup | Static/model evidence | PASS |
| 54 | Warning titles | Warning does not become failure | Static/model evidence | PASS |
| 55 | Warning titles | Warning does not use success title | Static/model evidence | PASS |
| 56 | Warning titles | Warning message contains application identifier | Static/model evidence | PASS |
| 57 | Warning titles | Warning message contains exact backup path | Static/model evidence | PASS |
| 58 | Warning titles | Warning message contains Warnings heading | Static/model evidence | PASS |
| 59 | Warning titles | Warning message emits each warning as dash entry | Static/model evidence | PASS |
| 60 | Warning titles | Warning Copy Path equals backupDirectory | Static/model evidence | PASS |
| 61 | Warning titles | Warning title is queued unchanged in background | Static/model evidence | PASS |
| 62 | Warning titles | Keychain optional warning selects warning outcome | Static/model evidence | PASS |
| 63 | Warning titles | Any positive warning count selects warning outcome | Static/model evidence | PASS |
| 64 | Failure titles | NSError callback uses exact title Backup Failed | Static/model evidence | PASS |
| 65 | Failure titles | Invalid nil/nil callback uses Backup Failed | Static/model evidence | PASS |
| 66 | Failure titles | Invalid result callback uses Backup Failed | Static/model evidence | PASS |
| 67 | Failure titles | Wrong result class uses Backup Failed | Static/model evidence | PASS |
| 68 | Failure titles | Unknown enum uses Backup Failed | Static/model evidence | PASS |
| 69 | Failure titles | Failure title literal occurs exactly once | Static/model evidence | PASS |
| 70 | Failure titles | Usable NSError localized description is preserved | Static/model evidence | PASS |
| 71 | Failure titles | Failure message omits NSError domain | Static/model evidence | PASS |
| 72 | Failure titles | Failure message omits NSError code | Static/model evidence | PASS |
| 73 | Failure titles | Empty NSError description uses exact fallback | Static/model evidence | PASS |
| 74 | Failure titles | Missing NSError uses exact fallback | Static/model evidence | PASS |
| 75 | Failure titles | Failure message never includes result path | Static/model evidence | PASS |
| 76 | Failure titles | Failure never exposes Copy Path | Static/model evidence | PASS |
| 77 | Failure titles | Error plus valid result remains failure | Static/model evidence | PASS |
| 78 | Failure titles | Error plus warning result remains failure | Static/model evidence | PASS |
| 79 | Failure titles | Failure title queues unchanged in background | Static/model evidence | PASS |
| 80 | Failure titles | Failure clears stale pending Copy Path through nil assignment | Static/model evidence | PASS |
| 81 | Failure titles | Unknown classifier state uses fallback message | Static/model evidence | PASS |
| 82 | Invalid result | nil result fails closed with nil Copy Path | Static/model evidence | PASS |
| 83 | Invalid result | wrong runtime class fails closed with nil Copy Path | Static/model evidence | PASS |
| 84 | Invalid result | nil backupDirectory fails closed with nil Copy Path | Static/model evidence | PASS |
| 85 | Invalid result | empty backupDirectory fails closed with nil Copy Path | Static/model evidence | PASS |
| 86 | Invalid result | nil manifestPath fails closed with nil Copy Path | Static/model evidence | PASS |
| 87 | Invalid result | empty manifestPath fails closed with nil Copy Path | Static/model evidence | PASS |
| 88 | Invalid result | nil warnings fails closed with nil Copy Path | Static/model evidence | PASS |
| 89 | Invalid result | wrong warnings collection type fails closed with nil Copy Path | Static/model evidence | PASS |
| 90 | Invalid result | non-string warning fails closed with nil Copy Path | Static/model evidence | PASS |
| 91 | Invalid result | empty warning fails closed with nil Copy Path | Static/model evidence | PASS |
| 92 | Invalid result | nil result uses exact invalid-result fallback | Static/model evidence | PASS |
| 93 | Invalid result | wrong runtime class uses exact invalid-result fallback | Static/model evidence | PASS |
| 94 | Invalid result | nil backupDirectory uses exact invalid-result fallback | Static/model evidence | PASS |
| 95 | Invalid result | empty backupDirectory uses exact invalid-result fallback | Static/model evidence | PASS |
| 96 | Invalid result | nil manifestPath uses exact invalid-result fallback | Static/model evidence | PASS |
| 97 | Invalid result | empty manifestPath uses exact invalid-result fallback | Static/model evidence | PASS |
| 98 | Invalid result | nil warnings uses exact invalid-result fallback | Static/model evidence | PASS |
| 99 | Invalid result | wrong warnings collection type uses exact invalid-result fallback | Static/model evidence | PASS |
| 100 | Invalid result | non-string warning uses exact invalid-result fallback | Static/model evidence | PASS |
| 101 | Invalid result | empty warning uses exact invalid-result fallback | Static/model evidence | PASS |
| 102 | Error precedence | Normal NSError overrides valid zero-warning result | Static/model evidence | PASS |
| 103 | Error precedence | Normal NSError overrides valid warning result | Static/model evidence | PASS |
| 104 | Error precedence | Empty-description NSError overrides valid result | Static/model evidence | PASS |
| 105 | Error precedence | Error overrides valid backupDirectory | Static/model evidence | PASS |
| 106 | Error precedence | Error overrides valid manifestPath | Static/model evidence | PASS |
| 107 | Error precedence | Error overrides NSArray warnings | Static/model evidence | PASS |
| 108 | Error precedence | Error prevents success title | Static/model evidence | PASS |
| 109 | Error precedence | Error prevents warning title | Static/model evidence | PASS |
| 110 | Error precedence | Error forces failure title | Static/model evidence | PASS |
| 111 | Error precedence | Error forces nil Copy Path | Static/model evidence | PASS |
| 112 | Error precedence | Error message does not append result path | Static/model evidence | PASS |
| 113 | Error precedence | Error message does not append warnings | Static/model evidence | PASS |
| 114 | Error precedence | Error plus nil result fails | Static/model evidence | PASS |
| 115 | Error precedence | Error plus wrong result class fails | Static/model evidence | PASS |
| 116 | Error precedence | Error plus invalid warnings fails | Static/model evidence | PASS |
| 117 | Error precedence | Non-nil error is checked before result validity | Static/model evidence | PASS |
| 118 | Warning array validation | nil warnings fails result validity | Static/model evidence | PASS |
| 119 | Warning array validation | NSString warnings value fails result validity | Static/model evidence | PASS |
| 120 | Warning array validation | NSDictionary warnings value fails result validity | Static/model evidence | PASS |
| 121 | Warning array validation | NSNumber warning element fails result validity | Static/model evidence | PASS |
| 122 | Warning array validation | NSNull warning element fails result validity | Static/model evidence | PASS |
| 123 | Warning array validation | empty NSString warning fails result validity | Static/model evidence | PASS |
| 124 | Warning array validation | mixed valid/non-string warnings fails result validity | Static/model evidence | PASS |
| 125 | Warning array validation | mixed valid/empty warnings fails result validity | Static/model evidence | PASS |
| 126 | Warning array validation | nil warnings cannot expose Copy Path | Static/model evidence | PASS |
| 127 | Warning array validation | NSString warnings value cannot expose Copy Path | Static/model evidence | PASS |
| 128 | Warning array validation | NSDictionary warnings value cannot expose Copy Path | Static/model evidence | PASS |
| 129 | Warning array validation | NSNumber warning element cannot expose Copy Path | Static/model evidence | PASS |
| 130 | Warning array validation | NSNull warning element cannot expose Copy Path | Static/model evidence | PASS |
| 131 | Warning array validation | empty NSString warning cannot expose Copy Path | Static/model evidence | PASS |
| 132 | Warning array validation | mixed valid/non-string warnings cannot expose Copy Path | Static/model evidence | PASS |
| 133 | Warning array validation | mixed valid/empty warnings cannot expose Copy Path | Static/model evidence | PASS |
| 134 | Warning ordering | Original warning order is retained | Static/model evidence | PASS |
| 135 | Warning ordering | Duplicate warnings are retained | Static/model evidence | PASS |
| 136 | Warning ordering | Warnings are not sorted | Static/model evidence | PASS |
| 137 | Warning ordering | Warnings are not deduplicated | Static/model evidence | PASS |
| 138 | Warning ordering | Warning capitalization is retained | Static/model evidence | PASS |
| 139 | Warning ordering | Warning punctuation is retained | Static/model evidence | PASS |
| 140 | Warning ordering | First warning remains first | Static/model evidence | PASS |
| 141 | Warning ordering | Last warning remains last | Static/model evidence | PASS |
| 142 | Warning ordering | Two equal warnings produce two lines | Static/model evidence | PASS |
| 143 | Warning ordering | Warning text is not rewritten | Static/model evidence | PASS |
| 144 | Warning ordering | Warnings remain warnings rather than errors | Static/model evidence | PASS |
| 145 | Warning ordering | Large warning arrays preserve cardinality | Static/model evidence | PASS |
| 146 | Copy-path authority | Success result exposes exact backupDirectory | Static/model evidence | PASS |
| 147 | Copy-path authority | Warning result exposes exact backupDirectory | Static/model evidence | PASS |
| 148 | Copy-path authority | Failure with NSError exposes nil | Static/model evidence | PASS |
| 149 | Copy-path authority | Failure without NSError exposes nil | Static/model evidence | PASS |
| 150 | Copy-path authority | Error plus valid result exposes nil | Static/model evidence | PASS |
| 151 | Copy-path authority | Error plus warning result exposes nil | Static/model evidence | PASS |
| 152 | Copy-path authority | Nil result exposes nil | Static/model evidence | PASS |
| 153 | Copy-path authority | Wrong class exposes nil | Static/model evidence | PASS |
| 154 | Copy-path authority | Missing backupDirectory exposes nil | Static/model evidence | PASS |
| 155 | Copy-path authority | Missing manifestPath exposes nil | Static/model evidence | PASS |
| 156 | Copy-path authority | Nil warnings exposes nil | Static/model evidence | PASS |
| 157 | Copy-path authority | Wrong warnings type exposes nil | Static/model evidence | PASS |
| 158 | Copy-path authority | Non-string warning exposes nil | Static/model evidence | PASS |
| 159 | Copy-path authority | Empty warning exposes nil | Static/model evidence | PASS |
| 160 | Copy-path authority | Unknown classifier state exposes nil | Static/model evidence | PASS |
| 161 | Copy-path authority | Pending failure cannot retain prior success path | Static/model evidence | PASS |
| 162 | Foreground delivery | Active app with no presented controller presents immediately | Static source + delivery model | PASS |
| 163 | Foreground delivery | Foreground success title remains Backup Successful | Static source + delivery model | PASS |
| 164 | Foreground delivery | Foreground warning title remains warning title | Static source + delivery model | PASS |
| 165 | Foreground delivery | Foreground failure title remains Backup Failed | Static source + delivery model | PASS |
| 166 | Foreground delivery | Foreground success includes Copy Path action | Static source + delivery model | PASS |
| 167 | Foreground delivery | Foreground warning includes Copy Path action | Static source + delivery model | PASS |
| 168 | Foreground delivery | Foreground failure omits Copy Path action | Static source + delivery model | PASS |
| 169 | Foreground delivery | Foreground message matches classifier outcome | Static source + delivery model | PASS |
| 170 | Foreground delivery | Foreground uses existing best-effort presenter | Static source + delivery model | PASS |
| 171 | Foreground delivery | Foreground result callback has one presentation call | Static source + delivery model | PASS |
| 172 | Foreground delivery | Processing alert dismisses before result presentation | Static source + delivery model | PASS |
| 173 | Foreground delivery | Confirmation and processing UIKit flow remain unchanged | Static source + delivery model | PASS |
| 174 | Background pending delivery | Background success stores exact title | Static source + pending-state model | PASS |
| 175 | Background pending delivery | Background warning stores exact title | Static source + pending-state model | PASS |
| 176 | Background pending delivery | Background failure stores exact title | Static source + pending-state model | PASS |
| 177 | Background pending delivery | Background success stores exact message | Static source + pending-state model | PASS |
| 178 | Background pending delivery | Background warning stores exact message | Static source + pending-state model | PASS |
| 179 | Background pending delivery | Background failure stores exact message | Static source + pending-state model | PASS |
| 180 | Background pending delivery | Background success stores backup path | Static source + pending-state model | PASS |
| 181 | Background pending delivery | Background warning stores backup path | Static source + pending-state model | PASS |
| 182 | Background pending delivery | Background failure stores nil path | Static source + pending-state model | PASS |
| 183 | Background pending delivery | Become-active presents pending title unchanged | Static source + pending-state model | PASS |
| 184 | Background pending delivery | Become-active presents pending message unchanged | Static source + pending-state model | PASS |
| 185 | Background pending delivery | Become-active presents pending path authority unchanged | Static source + pending-state model | PASS |
| 186 | Background pending delivery | Pending title clears after delivery | Static source + pending-state model | PASS |
| 187 | Background pending delivery | Pending message clears after delivery | Static source + pending-state model | PASS |
| 188 | Background pending delivery | Pending path clears after delivery | Static source + pending-state model | PASS |
| 189 | Background pending delivery | Pending queue design is not redesigned | Static source + pending-state model | PASS |
| 190 | Dead-code removal | Direct backup callback has zero UIAlertController *errAlert declarations | Static/model evidence | PASS |
| 191 | Dead-code removal | Direct backup callback has zero actions attached to dead alert | Static/model evidence | PASS |
| 192 | Dead-code removal | Direct backup callback presents only through best-effort helper | Static/model evidence | PASS |
| 193 | Dead-code removal | Direct backup callback has one final presentation call | Static/model evidence | PASS |
| 194 | Dead-code removal | Direct backup failure has no early presentation return | Static/model evidence | PASS |
| 195 | Dead-code removal | Old direct Backup Complete presentation is removed | Static/model evidence | PASS |
| 196 | Dead-code removal | Old direct Unknown error fallback is removed | Static/model evidence | PASS |
| 197 | Dead-code removal | Old direct (unknown) path fallback is removed | Static/model evidence | PASS |
| 198 | Dead-code removal | Whole-file restore errAlert remains baseline-owned | Static/model evidence | PASS |
| 199 | Dead-code removal | Restore dead-local mismatch is documented rather than modified | Static/model evidence | PASS |
| 200 | Direct caller scope | Direct controller caller count remains one | Static/model evidence | PASS |
| 201 | Direct caller scope | Direct caller completion signature remains unchanged | Static/model evidence | PASS |
| 202 | Direct caller scope | Direct caller options remain unchanged | Static/model evidence | PASS |
| 203 | Direct caller scope | Direct caller still reads three UI switches | Static/model evidence | PASS |
| 204 | Direct caller scope | Direct caller still dismisses processing alert | Static/model evidence | PASS |
| 205 | Direct caller scope | Direct caller alone receives title classifier integration | Static/model evidence | PASS |
| 206 | Direct caller scope | No new production caller is introduced | Static/model evidence | PASS |
| 207 | Direct caller scope | Manager method definition is not counted as caller | Static/model evidence | PASS |
| 208 | Direct caller scope | Direct UI backup confirmation remains unchanged | Static/model evidence | PASS |
| 209 | Direct caller scope | Direct UI processing title remains Backing Up | Static/model evidence | PASS |
| 210 | Direct caller scope | Direct UI Copy Path implementation remains unchanged | Static/model evidence | PASS |
| 211 | Direct caller scope | Direct UI pending presenter remains unchanged | Static/model evidence | PASS |
| 212 | Batch caller non-regression | Profile manager caller count remains one | Static/model evidence | PASS |
| 213 | Batch caller non-regression | ProjectX caller count remains one | Static/model evidence | PASS |
| 214 | Batch caller non-regression | Profile manager SHA-256 remains baseline | Static/model evidence | PASS |
| 215 | Batch caller non-regression | ProjectX SHA-256 remains baseline | Static/model evidence | PASS |
| 216 | Batch caller non-regression | Profile multi-app recursion remains unchanged | Static/model evidence | PASS |
| 217 | Batch caller non-regression | Profile warning aggregation remains unchanged | Static/model evidence | PASS |
| 218 | Batch caller non-regression | Profile error aggregation remains unchanged | Static/model evidence | PASS |
| 219 | Batch caller non-regression | RRS recursion remains unchanged | Static/model evidence | PASS |
| 220 | Batch caller non-regression | RRS manifest update remains unchanged | Static/model evidence | PASS |
| 221 | Batch caller non-regression | RRS options remain unchanged | Static/model evidence | PASS |
| 222 | Batch caller non-regression | Batch callers do not use direct title classifier | Static/model evidence | PASS |
| 223 | Batch caller non-regression | No batch caller source diff exists | Static/model evidence | PASS |
| 224 | Restore boundary | Restore Failed exact title remains present | Static/model evidence | PASS |
| 225 | Restore boundary | Restore Complete exact title remains present | Static/model evidence | PASS |
| 226 | Restore boundary | Restore callback source suffix is byte-equivalent after EOL normalization | Static/model evidence | PASS |
| 227 | Restore boundary | Restore confirmation is unchanged | Static/model evidence | PASS |
| 228 | Restore boundary | Restore picker is unchanged | Static/model evidence | PASS |
| 229 | Restore boundary | Restore processing alert is unchanged | Static/model evidence | PASS |
| 230 | Restore boundary | Restore NSError message is unchanged | Static/model evidence | PASS |
| 231 | Restore boundary | Restore warnings formatting is unchanged | Static/model evidence | PASS |
| 232 | Restore boundary | Restore Copy Path behavior is unchanged | Static/model evidence | PASS |
| 233 | Restore boundary | No rollback classification is added | Static/model evidence | PASS |
| 234 | Restore boundary | No PXRestoreComponentResult read is added | Static/model evidence | PASS |
| 235 | Restore boundary | No restore warning title is added | Static/model evidence | PASS |
| 236 | Restore boundary | No component-level result UI is added | Static/model evidence | PASS |
| 237 | Restore boundary | No restore confirmation wording is changed | Static/model evidence | PASS |
| 238 | Restore boundary | No TASK-5.2 behavior is implemented | Static/model evidence | PASS |
| 239 | Restore boundary | Baseline restore errAlert is intentionally preserved | Static/model evidence | PASS |
| 240 | Manager hash | AppDataBackupManager.m SHA-256 is 61fc1ff9... | Static/model evidence | PASS |
| 241 | Manager hash | AppDataBackupManager.m size is 239969 bytes | Static/model evidence | PASS |
| 242 | Manager hash | AppDataBackupManager.h SHA-256 is b19c1c61... | Static/model evidence | PASS |
| 243 | Manager hash | Manager success result construction is unchanged | Static/model evidence | PASS |
| 244 | Manager hash | Manager failure completion contract is unchanged | Static/model evidence | PASS |
| 245 | Manager hash | Manager completion dispatch is unchanged | Static/model evidence | PASS |
| 246 | Manager hash | Manager warning accumulation is unchanged | Static/model evidence | PASS |
| 247 | Manager hash | Manager publication logic is unchanged | Static/model evidence | PASS |
| 248 | Manager hash | Manager failure cleanup is unchanged | Static/model evidence | PASS |
| 249 | Manager hash | Manager has zero diff from baseline | Static/model evidence | PASS |
| 250 | TASK-4.9 protection hashes | PXFileProtection.h hash remains 5c7163ec... | Static/model evidence | PASS |
| 251 | TASK-4.9 protection hashes | PXFileProtection.m hash remains a6fb3730... | Static/model evidence | PASS |
| 252 | TASK-4.9 protection hashes | PXBackupArtifactPolicy.h hash remains 08255fad... | Static/model evidence | PASS |
| 253 | TASK-4.9 protection hashes | PXBackupArtifactPolicy.m hash remains 0d2083ea... | Static/model evidence | PASS |
| 254 | TASK-4.9 protection hashes | Keychain protection remains Complete | Static/model evidence | PASS |
| 255 | TASK-4.9 protection hashes | Non-Keychain protection remains Unspecified | Static/model evidence | PASS |
| 256 | TASK-4.9 protection hashes | ApplicationData disposition remains AbortBackup | Static/model evidence | PASS |
| 257 | TASK-4.9 protection hashes | AppGroup disposition remains WarnAndContinue | Static/model evidence | PASS |
| 258 | TASK-4.9 protection hashes | ProfileAppData disposition remains WarnAndContinue | Static/model evidence | PASS |
| 259 | TASK-4.9 protection hashes | GlobalSafari disposition remains WarnAndContinue | Static/model evidence | PASS |
| 260 | TASK-4.9 protection hashes | SystemGlobal disposition remains WarnAndContinue | Static/model evidence | PASS |
| 261 | TASK-4.9 protection hashes | SharedSystemDatabase remains ContinueWithoutWarning | Static/model evidence | PASS |
| 262 | TASK-4.9 protection hashes | Preferences remains ContinueWithoutWarning | Static/model evidence | PASS |
| 263 | TASK-4.9 protection hashes | Keychain remains WarnAndContinue | Static/model evidence | PASS |
| 264 | TASK-4.9 protection hashes | Artifact writer is unchanged | Static/model evidence | PASS |
| 265 | TASK-4.9 protection hashes | Artifact verifier is unchanged | Static/model evidence | PASS |
| 266 | TASK-4.9 protection hashes | Manifest V4 is unchanged | Static/model evidence | PASS |
| 267 | TASK-4.9 protection hashes | Manifest validator is unchanged | Static/model evidence | PASS |
| 268 | TASK-4.9 protection hashes | Directory publisher is unchanged | Static/model evidence | PASS |
| 269 | TASK-4.9 protection hashes | Publication workspace is unchanged | Static/model evidence | PASS |
| 270 | TASK-4.9A matcher hashes | Manager matcher source hash remains 61fc1ff9... | Static/model evidence | PASS |
| 271 | TASK-4.9A matcher hashes | Artifact policy source hash remains 0d2083ea... | Static/model evidence | PASS |
| 272 | TASK-4.9A matcher hashes | TASK-4.9A report hash remains 158e865f... | Static/model evidence | PASS |
| 273 | TASK-4.9A matcher hashes | Canonical Keychain policy validation remains unchanged | Static/model evidence | PASS |
| 274 | TASK-4.9A matcher hashes | Full-field matcher remains unchanged | Static/model evidence | PASS |
| 275 | TASK-4.9A matcher hashes | Policy kind matching remains unchanged | Static/model evidence | PASS |
| 276 | TASK-4.9A matcher hashes | Failure disposition matching remains unchanged | Static/model evidence | PASS |
| 277 | TASK-4.9A matcher hashes | Data Protection matching remains unchanged | Static/model evidence | PASS |
| 278 | TASK-4.9A matcher hashes | Optional artifact warning behavior remains unchanged | Static/model evidence | PASS |
| 279 | TASK-4.9A matcher hashes | TASK-4.9A review-file absence remains documented | Static/model evidence | PASS |
| 280 | Makefile hash | Makefile SHA-256 remains b2d9ca10... | Static/model evidence | PASS |
| 281 | Makefile hash | Makefile size remains 9266 bytes | Static/model evidence | PASS |
| 282 | Makefile hash | Makefile has zero diff | Static/model evidence | PASS |
| 283 | Makefile hash | No source file is added to target | Static/model evidence | PASS |
| 284 | Makefile hash | No test source is added to target | Static/model evidence | PASS |
| 285 | Makefile hash | Deployment target remains untouched | Static/model evidence | PASS |
| 286 | Makefile hash | Architecture configuration remains untouched | Static/model evidence | PASS |
| 287 | Makefile hash | ARC configuration remains untouched | Static/model evidence | PASS |
| 288 | Line endings | Controller remains UTF-8 CRLF | Static/model evidence | PASS |
| 289 | Line endings | Controller has zero LF-only endings | Static/model evidence | PASS |
| 290 | Line endings | Controller has zero lone CR endings | Static/model evidence | PASS |
| 291 | Line endings | Controller has zero NUL bytes | Static/model evidence | PASS |
| 292 | Line endings | Controller has final newline | Static/model evidence | PASS |
| 293 | Line endings | Report is UTF-8 LF | Static/model evidence | PASS |
| 294 | Line endings | Report has zero CRLF endings | Static/model evidence | PASS |
| 295 | Line endings | Report has zero NUL bytes | Static/model evidence | PASS |
| 296 | Line endings | Report has final newline | Static/model evidence | PASS |
| 297 | Line endings | No mixed line endings are introduced | Static/model evidence | PASS |
| 298 | Line endings | No broad whitespace formatting occurs | Static/model evidence | PASS |
| 299 | Line endings | git diff --check passes | Static/model evidence | PASS |
| 300 | Privacy/non-disclosure | No backup contents are logged | Static/model evidence | PASS |
| 301 | Privacy/non-disclosure | No Keychain contents are logged | Static/model evidence | PASS |
| 302 | Privacy/non-disclosure | No manifest contents are copied into UI | Static/model evidence | PASS |
| 303 | Privacy/non-disclosure | No filesystem revalidation is added to UI | Static/model evidence | PASS |
| 304 | Privacy/non-disclosure | No digest values are shown to users | Static/model evidence | PASS |
| 305 | Privacy/non-disclosure | No internal NSError domain is shown | Static/model evidence | PASS |
| 306 | Privacy/non-disclosure | No internal NSError code is shown | Static/model evidence | PASS |
| 307 | Privacy/non-disclosure | No persistent alert storage is added | Static/model evidence | PASS |
| 308 | Privacy/non-disclosure | No new notification is added | Static/model evidence | PASS |
| 309 | Privacy/non-disclosure | No sensitive path is exposed on failure | Static/model evidence | PASS |
| 310 | Phase-5 boundary | Only TASK-5.1 is implemented | Static/model evidence | PASS |
| 311 | Phase-5 boundary | TASK-5.1 review is not performed | Static/model evidence | PASS |
| 312 | Phase-5 boundary | Coordinator status files are not modified by this task | Static/model evidence | PASS |
| 313 | Phase-5 boundary | TASK-5.2 is not started | Static/model evidence | PASS |
| 314 | Phase-5 boundary | TASK-5.3 is not started | Static/model evidence | PASS |
| 315 | Phase-5 boundary | TASK-5.4 is not started | Static/model evidence | PASS |
| 316 | Phase-5 boundary | Phase 6 is not started | Static/model evidence | PASS |
| 317 | Phase-5 boundary | No push is performed | Static/model evidence | PASS |
| 318 | Phase-5 boundary | No restore rollback UI is added | Static/model evidence | PASS |
| 319 | Phase-5 boundary | No component-level restore UI is added | Static/model evidence | PASS |
| 320 | Phase-5 boundary | Implementation stops after commit evidence | Static/model evidence | PASS |

## Direct controller status
Current controller: 30469 bytes, SHA-256 `05b9257683c19a6aa803b1b31fff40409a86d44c18b86b2a5ddb758522d13612`, UTF-8 CRLF with 605 CRLF endings, zero LF-only endings, zero NUL bytes, and final newline.

## Profile manager non-regression
`ProfileManagerViewController.m`: 159713 bytes, SHA-256 `a26680aa7340f00b913950cd019245066d0854880839403346a965fbf832bb1a`, zero diff from baseline.

## RRS workflow non-regression
`ProjectXViewController.m`: 372278 bytes, SHA-256 `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162`, zero diff from baseline. Caller recursion, options, warning collection, and RRS manifest update remain unchanged.

## Restore boundary
Restore source from `-restoreButtonTapped` to EOF is unchanged after line-ending normalization: 5902 bytes, SHA-256 `af16365a6f8bfbe8c7e5755279beb5de03f90988dbe764283fd0aa7d8b174c47`. `Restore Failed` and `Restore Complete` remain unchanged.

## Manager/core protected hashes
Protected zero-diff set count: 42.

| Path | Bytes | SHA-256 | Baseline-equal |
|---|---:|---|---|
| `AppDataBackupRestoreViewController.h` | 336 | `b470e92a732dca1c97b161f802baf1d3ea8d39706087648e7fc697b63eeba5cf` | TRUE |
| `AppDataBackupManager.h` | 1442 | `b19c1c61e6df642468d713dede5a0c0bd0dbb6a0ac72d98ad6878d3cae1f2e75` | TRUE |
| `AppDataBackupManager.m` | 239969 | `61fc1ff901d64a0b2732c1ea44f47f23209a0b55404fbc69e27889ee03939028` | TRUE |
| `PXBackupArtifactPolicy.h` | 2013 | `08255fad381774a6e2b0f9e7e0c0176fd00decc141f54ba2caa7455a00e147bc` | TRUE |
| `PXBackupArtifactPolicy.m` | 6259 | `0d2083ea85bc4e7610cd3393adfb558429899a003029b4384b35056836330b3d` | TRUE |
| `PXBackupArtifactWriter.h` | 3059 | `8834bbbe5834a343c1f58c9fc1c823ce68b30f5d11158f8a2a7cec45f9419012` | TRUE |
| `PXBackupArtifactWriter.m` | 96014 | `01296680380daeb92fb2fa1a9e1e46d18fd381f0e55db55f5627fc4215cc19ff` | TRUE |
| `PXBackupManifestV4.h` | 2354 | `4e9c679d8d4a69f68111bb848467a7290a8760330b310ef4c2a25941612e6054` | TRUE |
| `PXBackupManifestV4.m` | 45136 | `4b757b5ef918bd0c08addbf7fecd432c6385ea04ebdce5dc713bf840c103f037` | TRUE |
| `PXBackupManifestValidator.h` | 945 | `6bf479c032e044a89a9d028517a50692c7d95ccef35f78e92a782653a4dcc836` | TRUE |
| `PXBackupManifestValidator.m` | 91206 | `8d16bdfa2f4eea1d95aec7800aacc2b1f28fcb54599a577f7ea571bc598f503b` | TRUE |
| `PXBackupArtifactVerifier.h` | 2006 | `2cd726496b1830cc404c6e6665e73785552a39c74cdb9683a43d32221fc194cc` | TRUE |
| `PXBackupArtifactVerifier.m` | 46654 | `2c45882144f529380bf485724bdd2258a3d9dd43de232076e857f10f3d5958f9` | TRUE |
| `PXBackupDirectoryPublisher.h` | 2955 | `0acc8af4a05df17b2e20319905773c0ba6350a749ed3b0204b94499c1da2e88d` | TRUE |
| `PXBackupDirectoryPublisher.m` | 82028 | `e146f716619708ab496bf08d8aca8c8736d0e4b4e3df024f1bc1e7a1a83ae2f6` | TRUE |
| `PXBackupPublicationWorkspace.h` | 1869 | `7ee3ce30d84edd6907cdc9fd3fb812dd768d03decb3ee0d50d464d17c4ae0851` | TRUE |
| `PXBackupPublicationWorkspace.m` | 48086 | `39974a40b4bf89f31ac9cbf1e8dfa716a94a0fd13e39d9c7539a02d14d2781f6` | TRUE |
| `PXBackupFailureCleanup.h` | 2377 | `ee242afc8ca4aad39dcfe240e168bcc4d52e72abb63a835981f306c71f89466d` | TRUE |
| `PXBackupFailureCleanup.m` | 80668 | `669ac9cc24489cb388058afd54d8fd63e28057220fa2ea9020aa93431e8d3138` | TRUE |
| `PXBackupDirectoryDiscovery.h` | 1708 | `da0b54991b39159de122169227f28827f6fde2375c1fe52ff9c47902143d2df2` | TRUE |
| `PXBackupDirectoryDiscovery.m` | 38228 | `f7380363790e5fbc896f64b3b9c2b325361ec26745196c2874cc1b1d153448c5` | TRUE |
| `PXBackupStaleWorkspaceCleanup.h` | 2265 | `82cdc1e356907c75e9e04b39de6ff81809bd50cb0fd265d2683d865444cba76d` | TRUE |
| `PXBackupStaleWorkspaceCleanup.m` | 81407 | `f96ed6b3be43b32ef4b31687fd10e797957d93f831fda58bfd39c3b3c26d4584` | TRUE |
| `PXFileProtection.h` | 1095 | `5c7163ec17f24c9ea4e0d4a53012fcb4c62e57decfb7891fdf8be72c554c8fb7` | TRUE |
| `PXFileProtection.m` | 11505 | `a6fb37302b7b32958026ba2842563769ee0098cf1007a6500763d3ce4f231947` | TRUE |
| `PXRestorePlan.h` | 4947 | `5cc773132c009fd8eedf4069b33ab53901a530edd580e3231c9d982c60cf7643` | TRUE |
| `PXRestorePlan.m` | 48523 | `cb6f838638a06bc9858b392d123656590291555812c63e3d0ddd4f5529d0d141` | TRUE |
| `PXRestoreResult.h` | 4512 | `cb7f2f3e40b3414d329405b1802bf6a9f245f1b660ca983d04776c0af449e69d` | TRUE |
| `PXRestoreResult.m` | 15842 | `c698a854589731f0987379c324d02729f3b586fd0ac3575f9798b77d6207c2fb` | TRUE |
| `ProfileManagerViewController.m` | 159713 | `a26680aa7340f00b913950cd019245066d0854880839403346a965fbf832bb1a` | TRUE |
| `ProjectXViewController.m` | 372278 | `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162` | TRUE |
| `scripts/keychain_backup.sh` | 75266 | `46b730b3ca28484232dc7af363bf722e7b7e0d612f54f9250397924847ba2d12` | TRUE |
| `WeaponXKeychainBridge/Tweak.m` | 21970 | `e0733e04eb4915a4753fe59247b17acd5e8cb7f8fa5fcf0bb8dee94f908459aa` | TRUE |
| `Makefile` | 9266 | `b2d9ca1083f85b818f132612e792c73e94e78390ef06092db2075439af945dfa` | TRUE |
| `KeychainHelper/backup_helper.m` | 42561 | `897292e4c7e867ec845502315783ced9b9e5fa53427ac617510f84ba00c543f7` | TRUE |
| `KeychainHelper/KeychainBackupHelper.h` | 4584 | `7e77d560aed48f003f3d068e266dcb9589fbb8eb7bd95139b9dd8d6559eafb6c` | TRUE |
| `KeychainHelper/KeychainBackupHelper.m` | 38587 | `324fbe42dbbc60844d2c53cdacf2c329a6b5b6f945d955c25e91daf32d5c40e2` | TRUE |
| `KeychainHelper/PXKeychainHelperExitCode.h` | 784 | `a0682225ac3ff962305c5bd967f319a4ad0aa7f5eec0a98596e04ba78b21e99a` | TRUE |
| `KeychainHelper/PXKeychainHelperResult.h` | 4083 | `4c8ee54990838de08f2d75a025a5e0777e0f15fe42f25662e1b5661d871520e3` | TRUE |
| `KeychainHelper/PXKeychainHelperResult.m` | 51525 | `1d4a44fb6929743647734881052a4fead70111759390c711bb35aea622f7e1a5` | TRUE |
| `KeychainHelper/PXKeychainItemIdentity.h` | 2387 | `f0a1d1474e2b8887418900c665c0a41f0d9210f5ce5a9bb44c3081803adec9e4` | TRUE |
| `KeychainHelper/PXKeychainItemIdentity.m` | 62919 | `c639d006384271ab304b8b6eca1402331ac50962a055cf4406eca9d720df11df` | TRUE |

## TASK-4.9 protection non-regression
Canonical matrix remains ApplicationData/AbortBackup/Unspecified; AppGroup, ProfileAppData, GlobalSafari, and SystemGlobal/ WarnAndContinue/Unspecified; SharedSystemDatabase and Preferences/ContinueWithoutWarning/Unspecified; Keychain/WarnAndContinue/Complete. `PXFileProtection.*` and policy sources are byte-identical.

## TASK-4.9A matcher non-regression
`AppDataBackupManager.m`: 239969 bytes, SHA-256 `61fc1ff901d64a0b2732c1ea44f47f23209a0b55404fbc69e27889ee03939028`. The TASK-4.9A matcher and canonical policy validation are unchanged.

## Makefile zero-diff
`Makefile`: 9266 bytes, SHA-256 `b2d9ca1083f85b818f132612e792c73e94e78390ef06092db2075439af945dfa`, zero diff.

## Full authorized diff
```diff
diff --git a/AppDataBackupRestoreViewController.m b/AppDataBackupRestoreViewController.m
index 400d4cc..58dd27b 100644
--- a/AppDataBackupRestoreViewController.m
+++ b/AppDataBackupRestoreViewController.m
@@ -15,6 +15,66 @@ static NSString *PXBackupKeychainGroupsKey(NSString *bundleID) {

 static NSString * const PXBackupKeychainGroupsSavedNotification = @"com.hydra.projectx.backupKeychainGroupsSaved";

+typedef NS_ENUM(NSUInteger, PXBackupAlertOutcome) {
+    PXBackupAlertOutcomeSuccessful = 1,
+    PXBackupAlertOutcomeCompletedWithWarnings = 2,
+    PXBackupAlertOutcomeFailed = 3,
+};
+
+static BOOL PXBackupResultIsValidForPresentation(PXBackupResult *result) {
+    if (![result isKindOfClass:[PXBackupResult class]]) {
+        return NO;
+    }
+
+    id backupDirectory = result.backupDirectory;
+    if (![backupDirectory isKindOfClass:[NSString class]] || [(NSString *)backupDirectory length] == 0) {
+        return NO;
+    }
+
+    id manifestPath = result.manifestPath;
+    if (![manifestPath isKindOfClass:[NSString class]] || [(NSString *)manifestPath length] == 0) {
+        return NO;
+    }
+
+    id warningsValue = result.warnings;
+    if (![warningsValue isKindOfClass:[NSArray class]]) {
+        return NO;
+    }
+
+    for (id warning in (NSArray *)warningsValue) {
+        if (![warning isKindOfClass:[NSString class]] || [(NSString *)warning length] == 0) {
+            return NO;
+        }
+    }
+
+    return YES;
+}
+
+static PXBackupAlertOutcome PXBackupAlertOutcomeForResult(PXBackupResult *result, NSError *error) {
+    if (error != nil) {
+        return PXBackupAlertOutcomeFailed;
+    }
+    if (!PXBackupResultIsValidForPresentation(result)) {
+        return PXBackupAlertOutcomeFailed;
+    }
+    if (result.warnings.count > 0) {
+        return PXBackupAlertOutcomeCompletedWithWarnings;
+    }
+    return PXBackupAlertOutcomeSuccessful;
+}
+
+static NSString *PXBackupAlertTitleForOutcome(PXBackupAlertOutcome outcome) {
+    switch (outcome) {
+        case PXBackupAlertOutcomeSuccessful:
+            return @"Backup Successful";
+        case PXBackupAlertOutcomeCompletedWithWarnings:
+            return @"Backup Completed with Warnings";
+        case PXBackupAlertOutcomeFailed:
+        default:
+            return @"Backup Failed";
+    }
+}
+
 @interface AppDataBackupRestoreViewController ()
 @property (nonatomic, strong) UILabel *appLabel;
 @property (nonatomic, strong) UISwitch *includeGroupsSwitch;
@@ -418,26 +478,37 @@ static void PXAttemptBringProjectXToFront(void) {
                                                        options:options
                                                     completion:^(PXBackupResult *result, NSError *error) {
              [processingAlert dismissViewControllerAnimated:YES completion:^{
-                 if (error) {
-                     UIAlertController *errAlert = [UIAlertController alertControllerWithTitle:@"Backup Failed"
-                                                                                      message:error.localizedDescription ?: @"Unknown error"
-                                                                               preferredStyle:UIAlertControllerStyleAlert];
-                     [errAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
-                     [self _presentResultAlertBestEffortWithTitle:@"Backup Failed"
-                                                         message:error.localizedDescription ?: @"Unknown error"
-                                                        copyPath:nil];
-                     return;
+                 PXBackupAlertOutcome outcome = PXBackupAlertOutcomeForResult(result, error);
+                 NSString *title = PXBackupAlertTitleForOutcome(outcome);
+                 NSString *message = nil;
+                 NSString *copyPath = nil;
+
+                 if (outcome == PXBackupAlertOutcomeFailed) {
+                     NSString *errorDescription = nil;
+                     if ([error isKindOfClass:[NSError class]] && error.localizedDescription.length > 0) {
+                         errorDescription = error.localizedDescription;
+                     }
+                     message = errorDescription ?: @"Backup failed without a valid result.";
+                 } else if (outcome == PXBackupAlertOutcomeSuccessful ||
+                            outcome == PXBackupAlertOutcomeCompletedWithWarnings) {
+                     NSMutableString *msg = [NSMutableString stringWithFormat:@"Backup created for %@.\n\nPath:\n%@",
+                                             appIdentifier,
+                                             result.backupDirectory];
+                     if (outcome == PXBackupAlertOutcomeCompletedWithWarnings) {
+                         [msg appendString:@"\n\nWarnings:\n"];
+                         for (NSString *warning in result.warnings) {
+                             [msg appendFormat:@"- %@\n", warning];
+                         }
+                     }
+                     message = msg;
+                     copyPath = result.backupDirectory;
+                 } else {
+                     message = @"Backup failed without a valid result.";
                  }

-                NSMutableString *msg = [NSMutableString stringWithFormat:@"Backup created for %@.\n\nPath:\n%@", appIdentifier, result.backupDirectory ?: @"(unknown)"];
-                if (result.warnings.count) {
-                    [msg appendString:@"\n\nWarnings:\n"];
-                    for (NSString *w in result.warnings) {
-                        [msg appendFormat:@"- %@\n", w];
-                    }
-                }
-
-                 [self _presentResultAlertBestEffortWithTitle:@"Backup Complete" message:msg copyPath:result.backupDirectory];
+                 [self _presentResultAlertBestEffortWithTitle:title
+                                                     message:message
+                                                    copyPath:copyPath];
              }];
          }];
       }]];
```

Authorized change list remains exactly the modified controller plus this added report.

## Objective-C/toolchain status
Windows static checks PASS: balanced Objective-C delimiters, brackets/parentheses/braces, no conflict markers, no NUL, CRLF audit, source literals, protected hashes, and `git diff --check`. Apple `make clean`, `make`, and `make package` were not run because clang/Theos/Xcode are unavailable. No Apple compile/link/package PASS is claimed.

## Device test status
NOT RUN. No iOS device execution was available. Foreground/background behavior was validated through static source and deterministic state modeling only.

## Line-ending/NUL audit
- `AppDataBackupRestoreViewController.m`: UTF-8 CRLF, no mixed endings, no NUL, final newline.
- `TASK-5.1-REPORT.md`: UTF-8 LF, no CRLF, no NUL, final newline.
- `git diff --check`: PASS before commit.

## Residual risks
Apple compiler/linker/package and physical-device UI behavior remain pending. The whole-file `UIAlertController *errAlert` literal count is 1 solely because the baseline restore branch owns one; direct backup scope is 0 and restore is zero-diff.

## TASK-5.2 boundary
TASK-5.2 was not started. No restore/rollback outcome taxonomy, component-level result UI, or restore title change is included.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
