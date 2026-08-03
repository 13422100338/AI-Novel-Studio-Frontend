"""Selection reference validation (C1)."""

from __future__ import annotations

import json

from ai_novel_studio.ui_qml.bridge.dtos import SelectionReferenceDto

MAX_SELECTION_CHARACTERS = 20_000


def parse_selection_reference(payload_json: str) -> SelectionReferenceDto | None:
    """Validate a selection-reference payload from the editor.

    Returns None when the payload is invalid (the caller emits an error).
    """
    try:
        payload = json.loads(payload_json)
    except (TypeError, ValueError):
        return None
    if not isinstance(payload, dict):
        return None
    chapter_id = payload.get("chapterId")
    base_revision = payload.get("baseRevision")
    from_pos = payload.get("from")
    to_pos = payload.get("to")
    selected_text = payload.get("selectedText")
    selected_hash = payload.get("selectedTextHash")
    if not isinstance(chapter_id, str) or not chapter_id.strip():
        return None
    if not isinstance(base_revision, int) or base_revision < 0:
        return None
    if not isinstance(from_pos, int) or not isinstance(to_pos, int):
        return None
    if from_pos < 0 or to_pos < from_pos:
        return None
    if not isinstance(selected_text, str) or not selected_text:
        return None
    if len(selected_text) > MAX_SELECTION_CHARACTERS:
        return None
    if not isinstance(selected_hash, str):
        return None
    if not _hash_is_legal(selected_hash):
        return None
    return SelectionReferenceDto(
        chapter_id=chapter_id,
        base_revision=base_revision,
        from_pos=from_pos,
        to_pos=to_pos,
        selected_text=selected_text,
        selected_text_hash=selected_hash,
    )


def _hash_is_legal(value: str) -> bool:
    if value.startswith("fnv1a:"):
        return len(value) == len("fnv1a:") + 8 and all(
            char in "0123456789abcdef" for char in value[len("fnv1a:") :]
        )
    if len(value) == 64:
        return all(char in "0123456789abcdef" for char in value)
    return False
