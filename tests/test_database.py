import os
import unittest

from unittest.mock import patch

from aiaf.database import (
    get_connection_string,
    get_connection
)


class TestDatabaseConfiguration(unittest.TestCase):

    def setUp(self):

        self.environment = {
            "AIAF_DB_SERVER": "TestServer",
            "AIAF_DB_NAME": "TestDatabase"
        }

    def test_explicit_database_configuration(self):

        with patch.dict(
            os.environ, self.environment, clear=True
        ):

            result = get_connection_string()

        self.assertIn("SERVER=TestServer;", result)
        self.assertIn("DATABASE=TestDatabase;", result)

    def test_missing_database_rejected(self):

        with patch.dict(os.environ, {}, clear=True):

            with self.assertRaisesRegex(
                ValueError, "AIAF_DB_NAME"
            ):
                get_connection_string()

    def test_empty_database_rejected(self):

        environment = {
            **self.environment,
            "AIAF_DB_NAME": ""
        }

        with patch.dict(
            os.environ, environment, clear=True
        ):

            with self.assertRaises(ValueError):
                get_connection_string()

    def test_whitespace_database_rejected(self):

        environment = {
            **self.environment,
            "AIAF_DB_NAME": "   "
        }

        with patch.dict(
            os.environ, environment, clear=True
        ):

            with self.assertRaises(ValueError):
                get_connection_string()

    def test_default_driver(self):

        with patch.dict(
            os.environ, self.environment, clear=True
        ):

            self.assertIn(
                "DRIVER={ODBC Driver 18 for SQL Server};",
                get_connection_string()
            )

    def test_custom_driver(self):

        environment = {
            **self.environment,
            "AIAF_DB_DRIVER": "ODBC Driver 17 for SQL Server"
        }

        with patch.dict(
            os.environ, environment, clear=True
        ):

            self.assertIn(
                "DRIVER={ODBC Driver 17 for SQL Server};",
                get_connection_string()
            )

    def test_default_server(self):

        with patch.dict(
            os.environ,
            {"AIAF_DB_NAME": "TestDatabase"},
            clear=True
        ):

            self.assertIn(
                "SERVER=localhost;",
                get_connection_string()
            )

    def test_secure_connection_defaults(self):

        with patch.dict(
            os.environ, self.environment, clear=True
        ):

            result = get_connection_string()

        self.assertIn("Trusted_Connection=yes;", result)
        self.assertIn("Encrypt=yes;", result)
        self.assertIn("TrustServerCertificate=no;", result)

    def test_explicit_certificate_trust(self):

        environment = {
            **self.environment,
            "AIAF_DB_TRUST_CERTIFICATE": " YES "
        }

        with patch.dict(
            os.environ, environment, clear=True
        ):

            self.assertIn(
                "TrustServerCertificate=yes;",
                get_connection_string()
            )

    def test_invalid_certificate_configuration(self):

        environment = {
            **self.environment,
            "AIAF_DB_TRUST_CERTIFICATE": "maybe"
        }

        with patch.dict(
            os.environ, environment, clear=True
        ):

            with self.assertRaisesRegex(
                ValueError, "AIAF_DB_TRUST_CERTIFICATE"
            ):
                get_connection_string()

    def test_connection_uses_configured_string(self):

        with patch.dict(
            os.environ, self.environment, clear=True
        ):

            with patch(
                "aiaf.database.pyodbc.connect"
            ) as connect:

                expected = get_connection_string()

                result = get_connection()

                connect.assert_called_once_with(
                    expected,
                    autocommit=True
                )

                self.assertIs(
                    result,
                    connect.return_value
                )

    def test_invalid_configuration_prevents_connection(self):

        with patch.dict(os.environ, {}, clear=True):

            with patch(
                "aiaf.database.pyodbc.connect"
            ) as connect:

                with self.assertRaises(ValueError):
                    get_connection()

                connect.assert_not_called()


if __name__ == "__main__":
    unittest.main()