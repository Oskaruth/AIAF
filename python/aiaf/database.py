import os
from contextlib import closing

import pyodbc


def get_connection_string():

    driver = os.getenv(
        "AIAF_DB_DRIVER",
        "ODBC Driver 18 for SQL Server"
    )

    server = os.getenv(
        "AIAF_DB_SERVER",
        "localhost"
    )

    database = os.getenv(
        "AIAF_DB_NAME",
        ""
    ).strip()

    if not database:
        raise ValueError(
            "AIAF_DB_NAME must be explicitly configured."
        )

    trust_certificate = os.getenv(
        "AIAF_DB_TRUST_CERTIFICATE",
        "no"
    ).strip().lower()

    if trust_certificate not in ("yes", "no"):
        raise ValueError(
            "AIAF_DB_TRUST_CERTIFICATE must be 'yes' or 'no'."
        )

    return (
        f"DRIVER={{{driver}}};"
        f"SERVER={server};"
        f"DATABASE={database};"
        "Trusted_Connection=yes;"
        "Encrypt=yes;"
        f"TrustServerCertificate={trust_certificate};"
    )


def get_connection():

    return pyodbc.connect(
        get_connection_string(),
        autocommit=True
    )


if __name__ == "__main__":

    with closing(get_connection()) as conn:

        with closing(conn.cursor()) as cursor:

            cursor.execute("""
                SELECT
                    @@SERVERNAME AS ServerName,
                    DB_NAME() AS DatabaseName,
                    ORIGINAL_LOGIN() AS LoginName,
                    USER_NAME() AS DatabaseUser;
            """)

            print(cursor.fetchone())