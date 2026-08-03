"""Frontend Wave C1: Agent timeline model and Mock Agent flow."""

import time

from ai_novel_studio.ui_qml.bridge.dtos import AgentTimelineItemDto
from ai_novel_studio.ui_qml.bridge.mock_novel_studio_facade import MockNovelStudioFacade
from ai_novel_studio.ui_qml.bridge.models.agent_timeline_model import (
    ROLE_BUSY,
    ROLE_CURRENT_TEXT,
    ROLE_DRAFT_TEXT,
    ROLE_KIND,
    ROLE_LABEL,
    ROLE_TEXT,
    AgentTimelineModel,
)


def _pump_until(app, facade: MockNovelStudioFacade, timeout: float) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline and facade.property("agentBusy"):
        app.processEvents()


def test_agent_timeline_model_roles() -> None:
    model = AgentTimelineModel()
    model.append_item(
        AgentTimelineItemDto(
            id="t1",
            kind="text_diff",
            label="修改对比",
            current_text="原文",
            draft_text="改稿",
            busy=True,
        )
    )
    index = model.index(0)
    assert model.data(index, ROLE_KIND) == "text_diff"
    assert model.data(index, ROLE_LABEL) == "修改对比"
    assert model.data(index, ROLE_CURRENT_TEXT) == "原文"
    assert model.data(index, ROLE_DRAFT_TEXT) == "改稿"
    assert model.data(index, ROLE_BUSY) is True
    assert model.data(index, ROLE_TEXT) == ""
    assert model.roleNames()[ROLE_KIND] == b"kind"


def test_mock_agent_emits_structured_timeline(qapp) -> None:
    facade = MockNovelStudioFacade()

    facade.startAgentTurn("帮我重写这段，让人物说话更自然。")
    _pump_until(qapp, facade, 3.0)

    assert facade.property("agentBusy") is False
    model = facade.property("agentTimeline")
    kinds = [
        model.data(model.index(i), ROLE_KIND) for i in range(model.rowCount())
    ]
    assert kinds[0] == "user_text"
    assert "run_status" in kinds
    assert "tool_call" in kinds
    assert "tool_result" in kinds
    assert "text_diff" in kinds
    assert "confirmation" in kinds


def test_mock_agent_uses_selection_reference_in_diff(qapp) -> None:
    facade = MockNovelStudioFacade()
    facade.setSelectionReferenceJson(
        '{"chapterId":"chapter-1","baseRevision":1,"from":0,"to":6,'
        '"selectedText":"清晨的雾港","selectedTextHash":"fnv1a:00000000"}'
    )

    facade.startAgentTurn("重写选区")
    _pump_until(qapp, facade, 3.0)

    model = facade.property("agentTimeline")
    for i in range(model.rowCount()):
        if model.data(model.index(i), ROLE_KIND) == "text_diff":
            assert "清晨的雾港" in model.data(model.index(i), ROLE_CURRENT_TEXT)
            return
    raise AssertionError("text_diff event not found")


def test_mock_agent_stop_keeps_partial_timeline(qapp) -> None:
    facade = MockNovelStudioFacade()

    facade.startAgentTurn("取消测试")
    facade.stopAgentTurn()
    _pump_until(qapp, facade, 2.0)

    assert facade.property("agentBusy") is False
    model = facade.property("agentTimeline")
    kinds = [
        model.data(model.index(i), ROLE_KIND) for i in range(model.rowCount())
    ]
    assert kinds[0] == "user_text"
    assert "warning" in kinds


def test_agent_reply_choice_and_approve_append_assistant_text() -> None:
    facade = MockNovelStudioFacade()
    facade.agentReplyChoice(0)
    facade.approveAgentChangeSet()

    model = facade.property("agentTimeline")
    assert model.rowCount() == 2
    assert model.data(model.index(0), ROLE_KIND) == "assistant_text"
    assert model.data(model.index(1), ROLE_KIND) == "assistant_text"
