@{
    ManifestVersion = '1.0.0'

    MinimumSqlServerMajorVersion = 16
    MinimumCompatibilityLevel = 160
	MinimumPowerShellVersion = '5.1'
	MinimumSqlServerModuleVersion = '22.4.5.1'

    RequiredCollation = 'Latin1_General_100_CI_AS_SC_UTF8'

    InstallationModes = @(
        'Core'
        'Demo'
        'IntegrationTest'
    )

    Schemas = @(
        'acme'
        'aiaf'
        'aiaf_governance'
        'aiaf_tool'
    )

    Roles = @(
        'AIAF_Runtime'
        'AIAF_GovernanceReader'
        'AIAF_GovernanceReviewer'
        'AIAF_GovernanceAttestor'
    )

    TestPrincipals = @(
        'AIAF_TestRuntime'
        'AIAF_TestReader'
        'AIAF_TestReviewer'
        'AIAF_TestAttestor'
    )

    Phases = @(
        @{
            Name = 'Create schemas'
            Modes = @('Core', 'Demo', 'IntegrationTest')
            Scripts = @(
                '00_setup\Schema_acme.sql'
                '00_setup\Schema_aiaf.sql'
                '00_setup\Schema_aiaf_governance.sql'
                '00_setup\Schema_aiaf_tool.sql'
            )
        }

        @{
            Name = 'Create tables'
            Modes = @('Core', 'Demo', 'IntegrationTest')
            Scripts = @(
                '01_schema\acme.Customer.sql'
                '01_schema\acme.Invoice.sql'
                '01_schema\aiaf.AIApplication.sql'
                '01_schema\aiaf.AIAuditHeartbeat.sql'
                '01_schema\aiaf.AICustomerAccess.sql'
                '01_schema\aiaf.AIDriftRule.sql'
                '01_schema\aiaf.AIInteraction.sql'
                '01_schema\aiaf.AIInteractionEvent.sql'
                '01_schema\aiaf.AIModelExecution.sql'
                '01_schema\aiaf.AIModelToolRequest.sql'
                '01_schema\aiaf.AIToolCall.sql'
                '01_schema\aiaf.AIValidation.sql'
                '01_schema\aiaf_governance.AIReview.sql'
                '01_schema\aiaf_governance.AIReviewItem.sql'
                '01_schema\aiaf_governance.AIReviewAction.sql'
                '01_schema\aiaf_governance.AIReviewAttestation.sql'
            )
        }

        @{
            Name = 'Create foreign keys'
            Modes = @('Core', 'Demo', 'IntegrationTest')
            Scripts = @(
                '03_constraints\acme.Invoice.FK_Invoice_Customer.sql'
                '03_constraints\aiaf.AICustomerAccess.FK_AICustomerAccess_AIApplication.sql'
                '03_constraints\aiaf.AICustomerAccess.FK_AICustomerAccess_Customer.sql'
                '03_constraints\aiaf.AIInteraction.FK_AIInteraction_AIApplication.sql'
                '03_constraints\aiaf.AIInteractionEvent.FK_AIInteractionEvent_AIInteraction.sql'
                '03_constraints\aiaf.AIModelExecution.FK_AIModelExecution_AIInteraction.sql'
                '03_constraints\aiaf.AIModelToolRequest.FK_AIModelToolRequest_ModelExecution.sql'
                '03_constraints\aiaf.AIToolCall.FK_AIToolCall_AIInteraction.sql'
                '03_constraints\aiaf.AIToolCall.FK_AIToolCall_ModelToolRequest.sql'
                '03_constraints\aiaf.AIValidation.FK_AIValidation_AIInteraction.sql'
                '03_constraints\aiaf.AIValidation.FK_AIValidation_AIToolCall.sql'
                '03_constraints\aiaf_governance.AIReviewAction.FK_AIReviewAction_AIReviewItem.sql'
                '03_constraints\aiaf_governance.AIReviewAttestation.FK_AIReviewAttestation_AIReview.sql'
                '03_constraints\aiaf_governance.AIReviewItem.FK_AIReviewItem_AIReview.sql'
            )
        }

        @{
            Name = 'Create indexes'
            Modes = @('Core', 'Demo', 'IntegrationTest')
            Scripts = @(
                '04_indexes\acme.Invoice.IX_Invoice_CustomerId.sql'
                '04_indexes\aiaf.AIAuditHeartbeat.IX_AIAuditHeartbeat_Pipeline_HeartbeatAt.sql'
                '04_indexes\aiaf.AIInteraction.IX_AIInteraction_Application_InteractionAt.sql'
                '04_indexes\aiaf.AIInteraction.IX_AIInteraction_Workflow_Period.sql'
                '04_indexes\aiaf.AIInteraction.UX_AIInteraction_CorrelationId.sql'
                '04_indexes\aiaf.AIInteractionEvent.IX_AIInteractionEvent_InteractionId.sql'
                '04_indexes\aiaf.AIModelExecution.IX_AIModelExecution_InteractionId.sql'
                '04_indexes\aiaf.AIModelExecution.IX_AIModelExecution_StartedAt.sql'
                '04_indexes\aiaf.AIToolCall.IX_AIToolCall_Authorization_RequestedAt.sql'
                '04_indexes\aiaf.AIToolCall.IX_AIToolCall_InteractionId.sql'
                '04_indexes\aiaf.AIToolCall.UX_AIToolCall_ModelToolRequest.sql'
                '04_indexes\aiaf.AIValidation.IX_AIValidation_InteractionId.sql'
                '04_indexes\aiaf.AIValidation.UX_AIValidation_OutputRule.sql'
                '04_indexes\aiaf_governance.AIReviewAction.IX_AIReviewAction_OpenActions.sql'
                '04_indexes\aiaf_governance.AIReviewAction.IX_AIReviewAction_ReviewItemId.sql'
                '04_indexes\aiaf_governance.AIReviewAttestation.IX_AIReviewAttestation_ReviewId.sql'
                '04_indexes\aiaf_governance.AIReviewItem.IX_AIReviewItem_ReviewId.sql'
            )
        }

        @{
            Name = 'Create views'
            Modes = @('Core', 'Demo', 'IntegrationTest')
            Scripts = @(
                '05_views\aiaf.vw_AIModelOperatingCost.sql'
            )
        }

        @{
            Name = 'Create stored procedures'
            Modes = @('Core', 'Demo', 'IntegrationTest')
            Scripts = @(
                '06_procedures\aiaf.usp_EvaluateGovernanceGate.sql'
                '06_procedures\aiaf.usp_BeginInteraction.sql'
                '06_procedures\aiaf.usp_RecordInputValidation.sql'
                '06_procedures\aiaf.usp_RecordModelExecution.sql'
                '06_procedures\aiaf.usp_RecordModelToolRequest.sql'
                '06_procedures\aiaf_tool.GetCustomerBalance.sql'
                '06_procedures\aiaf.usp_RecordOutputValidation.sql'
				'06_procedures\aiaf.usp_FailInteraction.sql'
                '06_procedures\aiaf.usp_CompleteInteraction.sql'
                '06_procedures\aiaf_governance.usp_FreezeReview.sql'
                '06_procedures\aiaf_governance.usp_AttestReview.sql'
            )
        }

        @{
            Name = 'Configure database security'
            Modes = @('Core', 'Demo', 'IntegrationTest')
            Scripts = @(
                '07_security\001_create_roles.sql'
                '07_security\002_assign_role_permissions.sql'
            )
        }

        @{
            Name = 'Install sample reference data'
            Modes = @('Demo', 'IntegrationTest')
            Scripts = @(
                '02_reference_data\001_drift_rules.sql'
            )
        }

        @{
            Name = 'Install synthetic demonstration data'
            Modes = @('Demo', 'IntegrationTest')
            Scripts = @(
                '08_seed\001_demo_applications.sql'
                '08_seed\002_acme_customers.sql'
                '08_seed\003_acme_invoices.sql'
                '08_seed\004_customer_authorizations.sql'
                '08_seed\005_governance_reviews.sql'
                '08_seed\006_governance_attestations.sql'
            )
        }

        @{
            Name = 'Create integration test principals'
            Modes = @('IntegrationTest')
            Scripts = @(
                '90_validation\001_create_test_principals.sql'
            )
        }

        @{
            Name = 'Verify security configuration'
            Modes = @('Core', 'Demo', 'IntegrationTest')
            Scripts = @(
                '90_validation\002_verify_security_configuration.sql'
            )
        }

        @{
            Name = 'Verify effective permissions'
            Modes = @('IntegrationTest')
            Scripts = @(
                '90_validation\003_verify_effective_permissions.sql'
            )
        }

		@{
			Name = 'Seed integration test fixtures'
			Modes = @('IntegrationTest')
			Scripts = @(
				'90_validation\004_seed_integration_fixtures.sql'
			)
		}
    )
}