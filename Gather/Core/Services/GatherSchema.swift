import SwiftData

// MARK: - Schema Versioning

/// V1 is the initial App Store release schema.
/// When model changes are needed in future updates, add a new VersionedSchema
/// (e.g. GatherSchemaV2) and a corresponding MigrationStage in GatherMigrationPlan.
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

// MARK: - Migration Plan

enum GatherMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [GatherSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        // No migrations yet — V1 is the initial release.
        // When adding V2, add a migration stage here:
        // migrateV1toV2
        []
    }
}
