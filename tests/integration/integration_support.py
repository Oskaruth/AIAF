import os
import logging

from contextlib import closing
from unittest.mock import patch

from aiaf.database import get_connection
from aiaf.pipeline import process_request


logger = logging.getLogger(__name__)


DEFAULT_CONTEXT = {
    "application_code": "AIAF_APPROVED_TEST",
    "requesting_identity": "aiaf-functional-test-user",
    "workflow_code": "CUSTOMER_BALANCE",
    "business_purpose": "Integration testing",
    "execution_environment": "TEST"
}


def get_expected_destination():

    server = os.getenv(
        "AIAF_DB_SERVER", ""
    ).strip()

    database = os.getenv(
        "AIAF_DB_NAME", ""
    ).strip()

    if not server:
        raise RuntimeError(
            "Integration testing requires an explicitly "
            "configured AIAF_DB_SERVER."
        )

    if not database:
        raise RuntimeError(
            "Integration testing requires an explicitly "
            "configured AIAF_DB_NAME."
        )

    return server, database


def verify_runtime_connection(connection):

    expected_server, expected_database = (
        get_expected_destination()
    )

    with closing(connection.cursor()) as cursor:

        cursor.execute("""
            SELECT
                @@SERVERNAME,
                DB_NAME(),
                ORIGINAL_LOGIN(),
                USER_NAME(),
                IS_ROLEMEMBER('AIAF_Runtime'),
                IS_ROLEMEMBER('db_owner');
        """)

        evidence = cursor.fetchone()

    if evidence is None:
        raise RuntimeError(
            "Connection verification returned no evidence."
        )

    (
        actual_server,
        actual_database,
        original_login,
        database_user,
        is_runtime_member,
        is_db_owner
    ) = evidence

    if (
        actual_server is None
        or actual_server.casefold()
            != expected_server.casefold()
    ):
        raise RuntimeError(
            f"Server mismatch: expected={expected_server}, "
            f"actual={actual_server}."
        )

    if actual_database != expected_database:
        raise RuntimeError(
            f"Database mismatch: expected={expected_database}, "
            f"actual={actual_database}."
        )

    if (
        database_user != "AIAF_TestRuntime"
        or is_runtime_member != 1
        or is_db_owner != 0
    ):
        raise RuntimeError(
            "Runtime identity verification failed."
        )

    return {
        "expected_server": expected_server,
        "expected_database": expected_database,
        "actual_server": actual_server,
        "actual_database": actual_database,
        "original_login": original_login,
        "database_user": database_user,
        "is_runtime_member": is_runtime_member,
        "is_db_owner": is_db_owner
    }


def get_runtime_connection():

    get_expected_destination()

    connection = get_connection()
    impersonated = False

    try:

        with closing(connection.cursor()) as cursor:

            cursor.execute(
                "EXECUTE AS USER = 'AIAF_TestRuntime';"
            )

            impersonated = True

        evidence = verify_runtime_connection(connection)

        return RuntimeConnection(
            connection,
            evidence
        )

    except Exception:

        try:
            if impersonated:
                with closing(connection.cursor()) as cursor:
                    cursor.execute("REVERT;")
        finally:
            connection.close()

        raise


class RuntimeConnection:

    def __init__(self, connection, evidence):

        self._connection = connection
        self.evidence = evidence

    def cursor(self):

        return self._connection.cursor()

    def close(self):

        try:

            with closing(self._connection.cursor()) as cursor:

                cursor.execute("REVERT;")

        finally:

            self._connection.close()


def verify_integration_environment():

    with closing(get_runtime_connection()) as connection:

        return connection.evidence.copy()


def run_integration_request(raw_prompt, **overrides):

    context = DEFAULT_CONTEXT.copy()
    context.update(overrides)

    with patch(
        "aiaf.pipeline.get_connection",
        new=get_runtime_connection
    ):

        return process_request(
            raw_prompt,
            **context
        )