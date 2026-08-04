"""Frontend Wave C1.1: selection reference protocol (bridge + facade)."""

import json

from ai_novel_studio.ui_qml.bridge.editor_bridge import EditorBridge
from ai_novel_studio.ui_qml.bridge.hash_utils import fnv1a_hash, sha256
from ai_novel_studio.ui_qml.bridge.mock_novel_studio_facade import MockNovelStudioFacade
from ai_novel_studio.ui_qml.bridge.models.selection_reference import (
    MAX_SELECTION_CHARACTERS,
    parse_selection_reference,
)

_SELECTED_TEXT = "雾港的清晨"


def _valid_payload(
    *,
    chapter_id: str = "chapter-1",
    base_revision: int = 3,
    from_pos: int = 10,
    to_pos: int = 16,
    selected_text: str = _SELECTED_TEXT,
    selected_hash: str | None = None,
) -> str:
    hash_value = (
        selected_hash if selected_hash is not None else fnv1a_hash(selected_text)
    )
    return (
        f'{{"chapterId":"{chapter_id}","baseRevision":{base_revision},'
        f'"from":{from_pos},"to":{to_pos},'
        f'"selectedText":"{selected_text}","selectedTextHash":"{hash_value}"}}'
    )


def test_parse_selection_reference_accepts_valid_fnv1a_payload() -> None:
    ref = parse_selection_reference(_valid_payload())
    assert ref is not None
    assert ref.chapter_id == "chapter-1"
    assert ref.base_revision == 3
    assert ref.from_pos == 10
    assert ref.to_pos == 16
    assert ref.selected_text == _SELECTED_TEXT


def test_parse_selection_reference_accepts_valid_sha256_payload() -> None:
    ref = parse_selection_reference(
        _valid_payload(selected_hash=sha256(_SELECTED_TEXT))
    )
    assert ref is not None
    assert ref.selected_text_hash == sha256(_SELECTED_TEXT)


def test_parse_selection_reference_rejects_hash_content_mismatch() -> None:
    # Correct format, wrong digest: must be rejected by recomputing the hash.
    assert parse_selection_reference(
        _valid_payload(selected_hash="fnv1a:00000000")
    ) is None
    assert parse_selection_reference(
        _valid_payload(selected_hash="0" * 64)
    ) is None


def test_parse_selection_reference_rejects_invalid_payloads() -> None:
    assert parse_selection_reference("not json") is None
    assert parse_selection_reference("[]") is None
    assert parse_selection_reference(
        _valid_payload(chapter_id="")
    ) is None
    assert parse_selection_reference(
        _valid_payload(base_revision=-1)
    ) is None
    assert parse_selection_reference(
        _valid_payload(from_pos=3, to_pos=1)
    ) is None
    assert parse_selection_reference(
        _valid_payload(from_pos=-2, to_pos=1)
    ) is None
    assert parse_selection_reference(
        _valid_payload(selected_text="")
    ) is None
    assert parse_selection_reference(
        _valid_payload(selected_hash="bad")
    ) is None
    oversized = "字" * (MAX_SELECTION_CHARACTERS + 1)
    assert parse_selection_reference(
        _valid_payload(selected_text=oversized)
    ) is None


def test_bridge_forwards_valid_reference_and_errors_on_invalid() -> None:
    bridge = EditorBridge()
    emitted: list[str] = []
    errors: list[tuple[str, str]] = []
    bridge.selection_reference_changed.connect(emitted.append)
    bridge.error.connect(lambda code, message: errors.append((code, message)))

    bridge.selectionReferenceChanged(_valid_payload())
    assert len(emitted) == 1

    bridge.selectionReferenceChanged("")
    assert len(emitted) == 2
    assert emitted[1] == ""

    bridge.selectionReferenceChanged("garbage")
    assert len(errors) == 1
    assert errors[0][0] == "INVALID_SELECTION_REFERENCE"

    bridge.selectionReferenceChanged(
        _valid_payload(selected_hash="fnv1a:00000000")
    )
    assert len(errors) == 2
    assert errors[1][0] == "INVALID_SELECTION_REFERENCE"


def test_facade_selection_reference_lifecycle() -> None:
    facade = MockNovelStudioFacade()
    assert facade.property("hasSelectionReference") is False

    facade.setSelectionReferenceJson(_valid_payload())
    assert facade.property("hasSelectionReference") is True
    assert _SELECTED_TEXT in facade.property("selectionReferencePreview")
    assert "字" in facade.property("selectionReferenceLabel")

    facade.clearSelectionReference()
    assert facade.property("hasSelectionReference") is False

    facade.setSelectionReferenceJson(_valid_payload())
    facade.selectChapter(1)
    assert facade.property("hasSelectionReference") is False


def test_facade_preview_is_single_line_with_ellipsis_for_long_text() -> None:
    """Long or cross-paragraph selections must not overflow the reference chip.

    The preview collapses newlines to one line and truncates with an ellipsis;
    QML elide only applies on a single line.
    """
    facade = MockNovelStudioFacade()
    long_text = "first paragraph, long enough." * 20 + "\n\nsecond paragraph." + "x" * 60

    facade.setSelectionReferenceJson(
        json.dumps(
            {
                "chapterId": "chapter-1",
                "baseRevision": 3,
                "from": 10,
                "to": 16,
                "selectedText": long_text,
                "selectedTextHash": fnv1a_hash(long_text),
            }
        )
    )

    preview = facade.property("selectionReferencePreview")
    assert isinstance(preview, str)
    assert "\n" not in preview
    assert " " in preview, "newlines should collapse to a space"
    assert preview.endswith("…")
    assert len(preview) <= 81


def test_facade_rejects_stale_chapter_and_revision() -> None:
    facade = MockNovelStudioFacade()

    facade.setSelectionReferenceJson(_valid_payload(chapter_id="chapter-2"))
    assert facade.property("hasSelectionReference") is False
    assert "过期" in facade.property("saveStatusText")

    facade.setSelectionReferenceJson(_valid_payload(base_revision=2))
    assert facade.property("hasSelectionReference") is False
    assert "过期" in facade.property("saveStatusText")

    facade.setSelectionReferenceJson(_valid_payload())
    assert facade.property("hasSelectionReference") is True


def test_empty_payload_clears_reference() -> None:
    facade = MockNovelStudioFacade()
    facade.setSelectionReferenceJson(_valid_payload())
    facade.setSelectionReferenceJson("")
    assert facade.property("hasSelectionReference") is False
