import unittest

from datetime import datetime
from unittest.mock import MagicMock

from aiaf.interaction_lifecycle import complete_interaction


class TestInteractionLifecycle(unittest.TestCase):

    def setUp(self):

        self.cursor = MagicMock()

        self.interaction_id = 1001

        self.completed_at = datetime(
            2026, 11, 15, 12, 0, 0
        )

    def test_successful_completion(self):

        self.cursor.fetchone.return_value = (
            self.interaction_id,
            "COMPLETED",
            "OUTPUT_APPROVED_FOR_RELEASE",
            self.completed_at
        )

        result = complete_interaction(
            self.cursor,
            self.interaction_id
        )

        self.assertEqual(result, {
            "InteractionId": self.interaction_id,
            "InteractionStatus": "COMPLETED",
            "CompletionReason": "OUTPUT_APPROVED_FOR_RELEASE",
            "CompletedAt": self.completed_at
        })

        self.cursor.execute.assert_called_once()

        sql, parameter = self.cursor.execute.call_args.args

        self.assertIn(
            "EXEC aiaf.usp_CompleteInteraction",
            sql
        )

        self.assertIn("@InteractionId = ?", sql)
        self.assertEqual(parameter, self.interaction_id)

    def test_blocked_interaction(self):

        self.cursor.fetchone.return_value = (
            self.interaction_id,
            "BLOCKED",
            "OUTPUT_VALIDATION_BLOCKED",
            self.completed_at
        )

        result = complete_interaction(
            self.cursor,
            self.interaction_id
        )

        self.assertEqual(
            result["InteractionStatus"], "BLOCKED"
        )

        self.assertEqual(
            result["CompletionReason"],
            "OUTPUT_VALIDATION_BLOCKED"
        )

    def test_failed_interaction(self):

        self.cursor.fetchone.return_value = (
            self.interaction_id,
            "FAILED",
            "MODEL_EXECUTION_FAILED",
            self.completed_at
        )

        result = complete_interaction(
            self.cursor,
            self.interaction_id
        )

        self.assertEqual(
            result["InteractionStatus"], "FAILED"
        )

        self.assertEqual(
            result["CompletionReason"],
            "MODEL_EXECUTION_FAILED"
        )

    def test_missing_completion_evidence(self):

        self.cursor.fetchone.return_value = None

        with self.assertRaisesRegex(
            RuntimeError,
            "Interaction completion returned no evidence."
        ):

            complete_interaction(
                self.cursor,
                self.interaction_id
            )

    def test_interaction_identifier_mismatch(self):

        self.cursor.fetchone.return_value = (
            9999,
            "COMPLETED",
            "OUTPUT_APPROVED_FOR_RELEASE",
            self.completed_at
        )

        with self.assertRaisesRegex(
            RuntimeError,
            "Interaction completion identifier mismatch."
        ):

            complete_interaction(
                self.cursor,
                self.interaction_id
            )

    def test_database_exception_propagates(self):

        self.cursor.execute.side_effect = RuntimeError(
            "Simulated database failure."
        )

        with self.assertRaisesRegex(
            RuntimeError,
            "Simulated database failure."
        ):

            complete_interaction(
                self.cursor,
                self.interaction_id
            )

        self.cursor.fetchone.assert_not_called()


if __name__ == "__main__":
    unittest.main()