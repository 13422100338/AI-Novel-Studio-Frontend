"""Frontend Wave C1: selection reference protocol (bridge + facade)."""

from ai_novel_studio.ui_qml.bridge.editor_bridge import EditorBridge
from ai_novel_studio.ui_qml.bridge.mock_novel_studio_facade import MockNovelStudioFacade
from ai_novel_studio.ui_qml.bridge.models.selection_reference import (
    parse_selection_reference,
)

_VALID = (
    '{"chapterId":"chapter-1","baseRevision":3,"from":10,"to":16,'
    '"selectedText":"雾港的清晨","selectedTextHash":"fnv1a:abcdef12"}'
)


def test_parse_selection_reference_accepts_valid_payload() -> None:
    ref = parse_selection_reference(_VALID)
    assert ref is not None
    assert ref.chapter_id == "chapter-1"
    assert ref.base_revision == 3
    assert ref.from_pos == 10
    assert ref.to_pos == 16
    assert ref.selected_text == "雾港的清晨"


def test_parse_selection_reference_rejects_invalid_payloads() -> None:
    assert parse_selection_reference("not json") is None
    assert parse_selection_reference("[]") is None
    assert parse_selection_reference(
        '{"chapterId":"","baseRevision":1,"from":0,"to":1,"selectedText":"x","selectedTextHash":"fnv1a:00000000"}'
    ) is None
    assert parse_selection_reference(
        '{"chapterId":"c","baseRevision":-1,"from":0,"to":1,"selectedText":"x","selectedTextHash":"fnv1a:00000000"}'
    ) is None
    assert parse_selection_reference(
        '{"chapterId":"c","baseRevision":1,"from":3,"to":1,"selectedText":"x","selectedTextHash":"fnv1a:00000000"}'
    ) is None
    assert parse_selection_reference(
        '{"chapterId":"c","baseRevision":1,"from":0,"to":1,"selectedText":"","selectedTextHash":"fnv1a:00000000"}'
    ) is None
    assert parse_selection_reference(
        '{"chapterId":"c","baseRevision":1,"from":0,"to":1,"selectedText":"x","selectedTextHash":"bad"}'
    ) is None


def test_bridge_forwards_valid_reference_and_errors_on_invalid() -> None:
    bridge = EditorBridge()
    emitted: list[str] = []
    errors: list[tuple[str, str]] = []
    bridge.selection_reference_changed.connect(emitted.append)
    bridge.error.connect(lambda code, message: errors.append((code, message)))

    bridge.selectionReferenceChanged(_VALID)
    assert len(emitted) == 1

    bridge.selectionReferenceChanged("")
    assert len(emitted) == 2
    assert emitted[1] == ""

    bridge.selectionReferenceChanged("garbage")
    assert len(errors) == 1
    assert errors[0][0] == "INVALID_SELECTION_REFERENCE"


def test_facade_selection_reference_lifecycle() -> None:
    facade = MockNovelStudioFacade()
    assert facade.property("hasSelectionReference") is False

    facade.setSelectionReferenceJson(_VALID)
    assert facade.property("hasSelectionReference") is True
    assert "雾港的清晨" in facade.property("selectionReferencePreview")
    assert "字" in facade.property("selectionReferenceLabel")

    facade.clearSelectionReference()
    assert facade.property("hasSelectionReference") is False

    facade.setSelectionReferenceJson(_VALID)
    facade.selectChapter(1)
    assert facade.property("hasSelectionReference") is False

