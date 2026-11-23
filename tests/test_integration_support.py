import os
import unittest

from unittest.mock import MagicMock, patch

from tests.integration.integration_support import (
    get_expected_destination,
    verify_runtime_connection,
    get_runtime_connection,
    verify_integration_environment
)

from tests.integration.run_integration_tests import main


class TestIntegrationSupport(unittest.TestCase):

    def setUp(self):

        self.environment = {
            "AIAF_DB_SERVER": "TestServer",
            "AIAF_DB_NAME": "TestDatabase"
        }

        self.environment_patch = patch.dict(
            os.environ,
            self.environment,
            clear=True
        )

        self.environment_patch.start()
        self.addCleanup(self.environment_patch.stop)

        self.connection = MagicMock()
        self.cursor = self.connection.cursor.return_value

        self.valid_evidence = (
            "TestServer",
            "TestDatabase",
            "TestLogin",
            "AIAF_TestRuntime",
            1,
            0
        )

        self.cursor.fetchone.return_value = (
            self.valid_evidence
        )

    def set_evidence(self, index, value):

        evidence = list(self.valid_evidence)
        evidence[index] = value

        self.cursor.fetchone.return_value = tuple(evidence)

    def test_explicit_destination(self):

        self.assertEqual(
            get_expected_destination(),
            ("TestServer", "TestDatabase")
        )

    def test_missing_server_rejected(self):

        del os.environ["AIAF_DB_SERVER"]

        with self.assertRaisesRegex(
            RuntimeError, "AIAF_DB_SERVER"
        ):
            get_expected_destination()

    def test_missing_database_rejected(self):

        del os.environ["AIAF_DB_NAME"]

        with self.assertRaisesRegex(
            RuntimeError, "AIAF_DB_NAME"
        ):
            get_expected_destination()

    def test_blank_server_rejected(self):

        os.environ["AIAF_DB_SERVER"] = "   "

        with self.assertRaises(RuntimeError):
            get_expected_destination()

    def test_blank_database_rejected(self):

        os.environ["AIAF_DB_NAME"] = "   "

        with self.assertRaises(RuntimeError):
            get_expected_destination()

    def test_valid_connection_evidence(self):

        result = verify_runtime_connection(self.connection)

        self.assertEqual(
            result["actual_server"], "TestServer"
        )

        self.assertEqual(
            result["actual_database"], "TestDatabase"
        )

        self.assertEqual(
            result["database_user"], "AIAF_TestRuntime"
        )

        self.assertEqual(result["is_runtime_member"], 1)
        self.assertEqual(result["is_db_owner"], 0)

        self.cursor.close.assert_called_once()

    def test_server_case_difference_allowed(self):

        self.set_evidence(0, "TESTSERVER")

        result = verify_runtime_connection(self.connection)

        self.assertEqual(
            result["actual_server"], "TESTSERVER"
        )

    def test_wrong_server_rejected(self):

        self.set_evidence(0, "WrongServer")

        with self.assertRaisesRegex(
            RuntimeError, "Server mismatch"
        ):
            verify_runtime_connection(self.connection)

    def test_unknown_server_rejected(self):

        self.set_evidence(0, None)

        with self.assertRaisesRegex(
            RuntimeError, "Server mismatch"
        ):
            verify_runtime_connection(self.connection)

    def test_wrong_database_rejected(self):

        self.set_evidence(1, "AIAF_Lab")

        with self.assertRaisesRegex(
            RuntimeError, "Database mismatch"
        ):
            verify_runtime_connection(self.connection)

    def test_unknown_database_rejected(self):

        self.set_evidence(1, None)

        with self.assertRaisesRegex(
            RuntimeError, "Database mismatch"
        ):
            verify_runtime_connection(self.connection)

    def test_no_evidence_rejected(self):

        self.cursor.fetchone.return_value = None

        with self.assertRaisesRegex(
            RuntimeError, "no evidence"
        ):
            verify_runtime_connection(self.connection)

    def test_wrong_runtime_identity_rejected(self):

        self.set_evidence(3, "dbo")

        with self.assertRaisesRegex(
            RuntimeError, "Runtime identity"
        ):
            verify_runtime_connection(self.connection)

    def test_missing_runtime_membership_rejected(self):

        self.set_evidence(4, 0)

        with self.assertRaises(RuntimeError):
            verify_runtime_connection(self.connection)

    def test_unknown_runtime_membership_rejected(self):

        self.set_evidence(4, None)

        with self.assertRaises(RuntimeError):
            verify_runtime_connection(self.connection)

    def test_db_owner_membership_rejected(self):

        self.set_evidence(5, 1)

        with self.assertRaises(RuntimeError):
            verify_runtime_connection(self.connection)

    def test_unknown_db_owner_membership_rejected(self):

        self.set_evidence(5, None)

        with self.assertRaises(RuntimeError):
            verify_runtime_connection(self.connection)

    def test_runtime_connection_cleanup_on_success(self):

        with patch(
            "tests.integration.integration_support.get_connection",
            return_value=self.connection
        ):

            runtime = get_runtime_connection()

            self.assertEqual(
                runtime.evidence["actual_database"],
                "TestDatabase"
            )

            runtime.close()

        self.cursor.execute.assert_any_call(
            "EXECUTE AS USER = 'AIAF_TestRuntime';"
        )

        self.cursor.execute.assert_any_call("REVERT;")

        self.connection.close.assert_called_once()

    def test_runtime_connection_cleanup_on_mismatch(self):

        self.set_evidence(1, "AIAF_Lab")

        with patch(
            "tests.integration.integration_support.get_connection",
            return_value=self.connection
        ):

            with self.assertRaisesRegex(
                RuntimeError, "Database mismatch"
            ):
                get_runtime_connection()

        self.cursor.execute.assert_any_call("REVERT;")

        self.connection.close.assert_called_once()

    def test_impersonation_failure_closes_connection(self):

        self.cursor.execute.side_effect = RuntimeError(
            "Impersonation failed"
        )

        with patch(
            "tests.integration.integration_support.get_connection",
            return_value=self.connection
        ):

            with self.assertRaises(RuntimeError):
                get_runtime_connection()

        self.cursor.execute.assert_called_once_with(
            "EXECUTE AS USER = 'AIAF_TestRuntime';"
        )

        self.connection.close.assert_called_once()

    def test_missing_configuration_prevents_connection(self):

        del os.environ["AIAF_DB_NAME"]

        with patch(
            "tests.integration.integration_support.get_connection"
        ) as connect:

            with self.assertRaises(RuntimeError):
                get_runtime_connection()

            connect.assert_not_called()

    def test_preflight_returns_evidence_and_closes_connection(self):

        with patch(
            "tests.integration.integration_support.get_connection",
            return_value=self.connection
        ):

            evidence = verify_integration_environment()

        self.assertEqual(
            evidence["actual_database"], "TestDatabase"
        )

        self.cursor.execute.assert_any_call("REVERT;")

        self.connection.close.assert_called_once()

    def test_failed_preflight_prevents_all_scenarios(self):

        with patch(
            "tests.integration.run_integration_tests."
            "verify_integration_environment",
            side_effect=RuntimeError("Database mismatch")
        ):

            with patch(
                "tests.integration.run_integration_tests."
                "run_scenario"
            ) as run_scenario:

                with patch("builtins.print"):

                    with self.assertLogs(
                        "tests.integration.run_integration_tests",
                        level="ERROR"
                    ):

                        result = main()

            run_scenario.assert_not_called()

        self.assertEqual(result, 2)


if __name__ == "__main__":
    unittest.main()