import SwiftData

// MARK: - Schema Versioning

/// V1 is the initial App Store release schema.
enum GatherSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            User.self,
            Event.self,
            Guest.self,
            PartyMember.self,
            ActivityPost.self,
            MediaItem.self,
            Budget.self,
            BudgetCategory.self,
            Expense.self,
            EventFunction.self,
            FunctionInvite.self,
            TicketTier.self,
            Ticket.self,
            PromoCode.self,
            WaitlistEntry.self,
            PaymentTransaction.self,
            PaymentSplit.self,
            EventMember.self,
            AppNotification.self
        ]
    }
}

/// V2 adds SeatingTable model for persistent seating charts.
///
/// IMPORTANT: do not add a new `VersionedSchema` (e.g. a "V3") just to register
/// added *fields* on an existing model. These schemas share the live model
/// classes, so a new version with the same model list is checksum-identical to
/// V2 — and `MigrationStage.lightweight` between two identical schemas makes
/// SwiftData throw an Objective-C exception at launch (uncatchable, instant
/// crash). Additive *optional* properties (e.g. `Guest.inviteSentAt`) are
/// migrated automatically by SwiftData and need no schema version at all.
enum GatherSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        GatherSchemaV1.models + [SeatingTable.self]
    }
}

// MARK: - Migration Plan

enum GatherMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [GatherSchemaV1.self, GatherSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    /// Lightweight migration: SeatingTable is a new model with no data to transform.
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: GatherSchemaV1.self,
        toVersion: GatherSchemaV2.self
    )
}
