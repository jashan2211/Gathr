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
enum GatherSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        GatherSchemaV1.models + [SeatingTable.self]
    }
}

/// V3 adds invite-delivery tracking fields to Guest (`inviteSentAt`,
/// `inviteSentVia`) so invites can be tracked on events without functions.
enum GatherSchemaV3: VersionedSchema {
    static var versionIdentifier: Schema.Version = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        GatherSchemaV2.models
    }
}

// MARK: - Migration Plan

enum GatherMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [GatherSchemaV1.self, GatherSchemaV2.self, GatherSchemaV3.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3]
    }

    /// Lightweight migration: SeatingTable is a new model with no data to transform.
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: GatherSchemaV1.self,
        toVersion: GatherSchemaV2.self
    )

    /// Lightweight migration: the new Guest fields are optional, no data to transform.
    static let migrateV2toV3 = MigrationStage.lightweight(
        fromVersion: GatherSchemaV2.self,
        toVersion: GatherSchemaV3.self
    )
}
