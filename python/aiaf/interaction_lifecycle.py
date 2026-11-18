def complete_interaction(cursor, interaction_id):

    cursor.execute(
        """
        EXEC aiaf.usp_CompleteInteraction
            @InteractionId = ?;
        """,
        interaction_id
    )

    row = cursor.fetchone()

    if row is None:

        raise RuntimeError(
            "Interaction completion returned no evidence."
        )

    result = {
        "InteractionId": row[0],
        "InteractionStatus": row[1],
        "CompletionReason": row[2],
        "CompletedAt": row[3]
    }

    if result["InteractionId"] != interaction_id:

        raise RuntimeError(
            "Interaction completion identifier mismatch."
        )

    return result