"""QAbstractListModel for the Agent timeline (C1)."""

from __future__ import annotations

from collections.abc import Sequence

from PySide6.QtCore import (
    QAbstractListModel,
    QByteArray,
    QModelIndex,
    QObject,
    QPersistentModelIndex,
    Qt,
)

from ai_novel_studio.ui_qml.bridge.dtos import AgentTimelineItemDto

ROLE_ITEM_ID = Qt.ItemDataRole.UserRole + 1
ROLE_KIND = Qt.ItemDataRole.UserRole + 2
ROLE_TEXT = Qt.ItemDataRole.UserRole + 3
ROLE_LABEL = Qt.ItemDataRole.UserRole + 4
ROLE_BUSY = Qt.ItemDataRole.UserRole + 5
ROLE_STATUS = Qt.ItemDataRole.UserRole + 6
ROLE_OPTIONS = Qt.ItemDataRole.UserRole + 7
ROLE_CURRENT_TEXT = Qt.ItemDataRole.UserRole + 8
ROLE_DRAFT_TEXT = Qt.ItemDataRole.UserRole + 9
ROLE_DATA = Qt.ItemDataRole.UserRole + 10

_INVALID_INDEX = QModelIndex()


class AgentTimelineModel(QAbstractListModel):
    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._items: list[AgentTimelineItemDto] = []

    def set_items(self, items: Sequence[AgentTimelineItemDto]) -> None:
        self.beginResetModel()
        self._items = list(items)
        self.endResetModel()

    def append_item(self, item: AgentTimelineItemDto) -> None:
        row = len(self._items)
        self.beginInsertRows(QModelIndex(), row, row)
        self._items.append(item)
        self.endInsertRows()

    def clear(self) -> None:
        self.beginResetModel()
        self._items.clear()
        self.endResetModel()

    def rowCount(
        self, parent: QModelIndex | QPersistentModelIndex = _INVALID_INDEX
    ) -> int:
        return 0 if parent.isValid() else len(self._items)

    def data(
        self,
        index: QModelIndex | QPersistentModelIndex,
        role: int = Qt.ItemDataRole.DisplayRole,
    ) -> object:
        if not index.isValid() or not (0 <= index.row() < len(self._items)):
            return None
        item = self._items[index.row()]
        if role == ROLE_ITEM_ID:
            return item.id
        if role == ROLE_KIND:
            return item.kind
        if role == ROLE_TEXT:
            return item.text
        if role == ROLE_LABEL:
            return item.label
        if role == ROLE_BUSY:
            return item.busy
        if role == ROLE_STATUS:
            return item.status
        if role == ROLE_OPTIONS:
            return list(item.options)
        if role == ROLE_CURRENT_TEXT:
            return item.current_text
        if role == ROLE_DRAFT_TEXT:
            return item.draft_text
        if role == ROLE_DATA:
            return item.data
        return None

    def roleNames(self) -> dict[int, QByteArray]:
        return {
            ROLE_ITEM_ID: QByteArray(b"itemId"),
            ROLE_KIND: QByteArray(b"kind"),
            ROLE_TEXT: QByteArray(b"text"),
            ROLE_LABEL: QByteArray(b"label"),
            ROLE_BUSY: QByteArray(b"busy"),
            ROLE_STATUS: QByteArray(b"status"),
            ROLE_OPTIONS: QByteArray(b"options"),
            ROLE_CURRENT_TEXT: QByteArray(b"currentText"),
            ROLE_DRAFT_TEXT: QByteArray(b"draftText"),
            ROLE_DATA: QByteArray(b"data"),
        }

    def items(self) -> tuple[AgentTimelineItemDto, ...]:
        return tuple(self._items)
