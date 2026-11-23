
def complete_interaction(cursor, interaction_id, processing_failed=False):

    if type(processing_failed) is not bool:
        raise ValueError(
            "processing_failed must be a boolean."
        )

    cursor.execute(
        """
        EXEC aiaf.usp_CompleteInteraction
            @InteractionId = ?,
            @ProcessingFailed = ?;
        """,
        interaction_id,
        int(processing_failed)
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

    if processing_failed and (
        result["InteractionStatus"] != "FAILED"
        or result["CompletionReason"] != "PROCESSING_EXCEPTION"
        or result["CompletedAt"] is None
    ):
        raise RuntimeError(
            "Invalid failure finalization evidence."
        )

    return result
