#import "PXProfileDeletionJournal.h"
#import "PXPaths.h"

#if defined(PX_SOURCE_TRANSACTION_TESTING)
void (^PXProfileDeletionTestCheckpoint)(NSString *stage);
#endif

static BOOL PXDeletionError(NSError **error, NSInteger code, NSString *message) {
    if (error) *error = [NSError errorWithDomain:@"WeaponXProfileError" code:code userInfo:@{NSLocalizedDescriptionKey: message}];
    return NO;
}
static NSString *PXDeletionSelectionID(NSDictionary *pair) {
    NSDictionary *central = pair[PXCurrentProfileInfoPath()], *legacy = pair[PXLegacyActiveProfileInfoPath()];
    NSDictionary *info = [central[@"exists"] boolValue] ? central[@"info"] : legacy[@"info"];
    return PXValidatedProfileID(info[@"ProfileId"] ?: info[@"currentProfileId"]);
}
static BOOL PXDeletionValidPair(id pair) {
    if (![pair isKindOfClass:NSDictionary.class] || [pair count] != 2) return NO;
    for (NSString *path in @[PXCurrentProfileInfoPath(), PXLegacyActiveProfileInfoPath()]) {
        id record = pair[path];
        if (![record isKindOfClass:NSDictionary.class] || ![record[@"exists"] isKindOfClass:NSNumber.class] ||
            ![record[@"info"] isKindOfClass:NSDictionary.class] || [record count] != 2 ||
            (![record[@"exists"] boolValue] && [record[@"info"] count])) return NO;
    }
    return PXDeletionSelectionID(pair) != nil;
}
static BOOL PXDeletionValidIntent(id intent, NSError **error) {
    BOOL valid = [intent isKindOfClass:NSDictionary.class];
    if (valid) {
        valid = [intent[@"schemaVersion"] isEqual:@1] && [intent[@"operation"] isEqual:@"delete"] &&
            [intent[@"operationID"] isKindOfClass:NSString.class] && [[NSUUID alloc] initWithUUIDString:intent[@"operationID"]] != nil &&
            [PXValidatedProfileID(intent[@"targetID"]) isEqual:intent[@"targetID"]] &&
            ( [intent[@"state"] isEqual:@"prepared"] || [intent[@"state"] isEqual:@"committed"] ||
              [intent[@"state"] isEqual:@"archived"] || [intent[@"state"] isEqual:@"compensating"] );
    }
    if (valid) for (NSString *key in @[@"registryBefore", @"registryAfter"]) {
        id record = intent[key];
        if (![record isKindOfClass:NSDictionary.class] || [record count] != 2 || ![record[@"exists"] isEqual:@YES] ||
            ![record[@"bytes"] isKindOfClass:NSData.class] || ![record[@"bytes"] length]) { valid = NO; break; }
    }
    if (valid) {
        id proof = intent[@"directoryProof"];
        valid = [proof isKindOfClass:NSDictionary.class] && [proof[@"exists"] isKindOfClass:NSNumber.class];
        if (valid) valid = [proof[@"exists"] boolValue] ? ([proof count] == 3 && [proof[@"device"] isKindOfClass:NSNumber.class] &&
            [proof[@"inode"] isKindOfClass:NSNumber.class]) : [proof count] == 1;
    }
    if (valid) valid = PXDeletionValidPair(intent[@"selectionBefore"]) && PXDeletionValidPair(intent[@"selectionAfter"]);
    if (valid) {
        BOOL active = [PXDeletionSelectionID(intent[@"selectionBefore"]) isEqual:intent[@"targetID"]];
        NSDictionary *after = intent[@"selectionAfter"];
        valid = ![PXDeletionSelectionID(after) isEqual:intent[@"targetID"]];
        if (active) valid = valid && [after[PXCurrentProfileInfoPath()][@"exists"] isEqual:@YES] &&
            [after[PXCurrentProfileInfoPath()] isEqual:after[PXLegacyActiveProfileInfoPath()]] &&
            [after[PXCurrentProfileInfoPath()][@"info"][@"SelectionRevision"] isEqual:intent[@"operationID"]];
        else valid = valid && [intent[@"selectionBefore"] isEqual:after];
    }
    return valid || PXDeletionError(error, 27, @"Invalid profile deletion journal; preserving registry and files");
}
static NSDictionary *PXReadDeletionState(NSError **error) {
    __block NSDictionary *state = nil;
    BOOL ok = PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **readError) {
        BOOL exists = NO;
        NSDictionary *intent = [tx dictionaryAtPath:PXProfileDeletionJournalPath() exists:&exists error:readError];
        NSDictionary *selection = intent ? PXReadRuntimeProfileSelection(tx, PXCurrentProfileInfoPath(), PXLegacyActiveProfileInfoPath(), readError) : nil;
        if (!selection) return NO;
        state = @{ @"exists": @(exists), @"intent": intent, @"selection": selection }; return YES;
    }, error);
    return ok ? state : nil;
}
BOOL PXRequireNoPendingProfileDeletion(NSError **error) {
    NSDictionary *state = PXReadDeletionState(error);
    if (!state) return NO;
    return ![state[@"exists"] boolValue] || PXDeletionError(error, 27, @"Profile deletion recovery is pending; reload profiles before changing them");
}
BOOL PXPrepareProfileDeletion(PXProfileLifecycleLease *lease, NSDictionary *intent, PXProfileDeletionArchiveValidator validator, NSError **error) {
    if (![lease validateWithError:error] || !PXDeletionValidIntent(intent, error)) return NO;
    if (![intent[@"state"] isEqual:@"prepared"]) return PXDeletionError(error, 27, @"Expected a prepared deletion intent");
    if (!validator(intent, error)) return NO;
    if (![[lease readRegistryWithError:error] isEqual:intent[@"registryBefore"]] ||
        ![[lease directoryProofForProfileID:intent[@"targetID"] error:error] isEqual:intent[@"directoryProof"]])
        return PXDeletionError(error, 25, @"Profile deletion basis changed before preparation");
    return PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        BOOL exists = NO;
        if (![tx dictionaryAtPath:PXProfileDeletionJournalPath() exists:&exists error:writeError]) return NO;
        if (exists) return PXDeletionError(writeError, 27, @"Another profile deletion is pending recovery");
        return PXRuntimeProfileSelectionMatches(tx, intent[@"selectionBefore"], PXCurrentProfileInfoPath(), PXLegacyActiveProfileInfoPath(), writeError) &&
            [tx setDictionary:intent atPath:PXProfileDeletionJournalPath() error:writeError];
    }, error);
}
BOOL PXCommitProfileDeletion(PXProfileLifecycleLease *lease, NSDictionary *prepared, NSError **error) {
    if (![lease validateWithError:error] || !PXDeletionValidIntent(prepared, error)) return NO;
    if (![prepared[@"state"] isEqual:@"prepared"]) return PXDeletionError(error, 27, @"Expected a prepared deletion intent");
    if (![[lease readRegistryWithError:error] isEqual:prepared[@"registryBefore"]] ||
        ![[lease directoryProofForProfileID:prepared[@"targetID"] error:error] isEqual:prepared[@"directoryProof"]])
        return PXDeletionError(error, 25, @"Profile deletion basis changed before commit");
    NSMutableDictionary *committed = [prepared mutableCopy]; committed[@"state"] = @"committed";
    return PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        BOOL exists = NO;
        NSDictionary *observed = [tx dictionaryAtPath:PXProfileDeletionJournalPath() exists:&exists error:writeError];
        if (!observed) return NO;
        if (!exists || ![observed isEqual:prepared]) return PXDeletionError(writeError, 27, @"Profile deletion intent changed before commit");
        if (!PXRuntimeProfileSelectionMatches(tx, prepared[@"selectionBefore"], PXCurrentProfileInfoPath(), PXLegacyActiveProfileInfoPath(), writeError)) return NO;
        if (![prepared[@"selectionBefore"] isEqual:prepared[@"selectionAfter"]] &&
            !PXStageRuntimeProfileSelection(tx, prepared[@"selectionAfter"][PXCurrentProfileInfoPath()][@"info"], PXCurrentProfileInfoPath(), PXLegacyActiveProfileInfoPath(), writeError)) return NO;
        // The fallback pair and committed decision share one source journal.
        return [tx setDictionary:committed atPath:PXProfileDeletionJournalPath() error:writeError];
    }, error);
}
static NSDictionary *PXChangeDeletionPhase(NSDictionary *intent, NSString *phase, NSDictionary *selection, NSError **error) {
    NSMutableDictionary *next = [intent mutableCopy]; next[@"state"] = phase;
    BOOL ok = PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        BOOL exists = NO;
        NSDictionary *observed = [tx dictionaryAtPath:PXProfileDeletionJournalPath() exists:&exists error:writeError];
        if (!observed) return NO;
        if (!exists || ![observed isEqual:intent]) return PXDeletionError(writeError, 27, @"Deletion phase changed during recovery");
        return PXRuntimeProfileSelectionMatches(tx, selection, PXCurrentProfileInfoPath(), PXLegacyActiveProfileInfoPath(), writeError) &&
            [tx setDictionary:next atPath:PXProfileDeletionJournalPath() error:writeError];
    }, error);
    return ok ? [next copy] : nil;
}
BOOL PXMarkProfileDeletionArchiveWritten(PXProfileLifecycleLease *lease, NSDictionary *prepared, NSError **error) {
    if (![lease validateWithError:error] || !PXDeletionValidIntent(prepared, error)) return NO;
    if (![[lease readRegistryWithError:error] isEqual:prepared[@"registryAfter"]])
        return PXDeletionError(error, 25, @"Registry changed before recording deletion archive completion");
    NSMutableDictionary *committed = [prepared mutableCopy]; committed[@"state"] = @"committed";
    return PXChangeDeletionPhase(committed, @"archived", prepared[@"selectionAfter"], error) != nil;
}
static BOOL PXClearDeletionIntent(NSDictionary *intent, NSDictionary *selection, NSError **error) {
    return PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        BOOL exists = NO;
        NSDictionary *observed = [tx dictionaryAtPath:PXProfileDeletionJournalPath() exists:&exists error:writeError];
        if (!observed) return NO;
        if (!exists || ![observed isEqual:intent]) return PXDeletionError(writeError, 27, @"Profile deletion changed during recovery");
        return (!selection || PXRuntimeProfileSelectionMatches(tx, selection, PXCurrentProfileInfoPath(), PXLegacyActiveProfileInfoPath(), writeError)) &&
            [tx removeDictionaryAtPath:PXProfileDeletionJournalPath() error:writeError];
    }, error);
}
BOOL PXRecoverProfileDeletion(PXProfileLifecycleLease *lease, PXProfileDeletionArchiveValidator validator,
    PXProfileDeletionResolution *resolution, NSError **error) {
    *resolution = PXProfileDeletionNoPendingIntent;
    if (![lease validateWithError:error]) return NO;
    NSDictionary *state = PXReadDeletionState(error);
    if (!state) return NO;
    if (![state[@"exists"] boolValue]) return YES;
    NSDictionary *intent = state[@"intent"];
    if (!PXDeletionValidIntent(intent, error) || !validator(intent, error)) return NO;
    if ([intent[@"state"] isEqual:@"prepared"]) {
        if (!PXClearDeletionIntent(intent, nil, error)) return NO;
        *resolution = PXProfileDeletionAbortedPreparation; return YES;
    }
    NSDictionary *registry = [lease readRegistryWithError:error];
    if (!registry) return NO;
    BOOL compensating = [intent[@"state"] isEqual:@"compensating"];
    if (([intent[@"state"] isEqual:@"archived"] && ![registry isEqual:intent[@"registryAfter"]]) ||
        (![registry isEqual:intent[@"registryBefore"]] && ![registry isEqual:intent[@"registryAfter"]]))
        return PXDeletionError(error, 25, @"Unknown registry during deletion recovery; preserving it and all files");
    BOOL forward = !compensating && [state[@"selection"] isEqual:intent[@"selectionAfter"]];
    NSDictionary *desired = forward ? intent[@"registryAfter"] : intent[@"registryBefore"];
    if (!forward && (![intent[@"directoryProof"][@"exists"] boolValue] ||
        ![[lease directoryProofForProfileID:intent[@"targetID"] error:error] isEqual:intent[@"directoryProof"]]))
        return PXDeletionError(error, 27, @"Cannot compensate a deletion whose original directory is unavailable");
    if (!forward && !compensating) {
        intent = PXChangeDeletionPhase(intent, @"compensating", state[@"selection"], error);
        if (!intent) return NO;
        PXProfileDeletionCheckpoint(@"compensating");
    }
    if (![registry isEqual:desired]) {
        if (![lease writeRegistryData:desired[@"bytes"] expected:registry error:error]) return NO;
    }
    if (![[lease readRegistryWithError:error] isEqual:desired])
        return PXDeletionError(error, 25, @"Registry changed while completing deletion recovery");
    if (forward && [intent[@"state"] isEqual:@"committed"]) {
        intent = PXChangeDeletionPhase(intent, @"archived", state[@"selection"], error);
        if (!intent) return NO;
    }
    PXProfileDeletionCheckpoint(@"recovery-archive-written");
    if (!PXClearDeletionIntent(intent, state[@"selection"], error)) return NO;
    *resolution = forward ? PXProfileDeletionCompleted : PXProfileDeletionCancelledForSelectionDrift;
    // Recovery deliberately does not retry recursive removal at a stale path.
    return YES;
}
