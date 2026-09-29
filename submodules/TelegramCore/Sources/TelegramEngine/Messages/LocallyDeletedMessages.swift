import Foundation
import Postbox
import SwiftSignalKit

/// Text snapshots are kept separately from Telegram's server-synchronized message history.
/// Only messages already present on this device can be captured.
public struct LocallyDeletedMessage: Codable, Equatable {
    public let id: MessageId
    public let peerTitle: String
    public let authorTitle: String
    public let text: String
    public let mediaDescription: String
    public let sentAt: Int32
    public let deletedAt: Int32

    public init(message: Message) {
        self.id = message.id
        self.peerTitle = message.peers[message.id.peerId]?.debugDisplayTitle ?? message.id.peerId.description
        self.authorTitle = message.author?.debugDisplayTitle ?? ""
        self.text = message.text
        self.mediaDescription = message.media.isEmpty ? "" : "Media (not archived)"
        self.sentAt = message.timestamp
        self.deletedAt = Int32(Date().timeIntervalSince1970)
    }
}

func archiveLocallyDeletedMessages(transaction: Transaction, ids: [MessageId]) {
    for id in ids where id.namespace == Namespaces.Message.Cloud {
        guard let message = transaction.getMessage(id) else {
            continue
        }
        let snapshot = LocallyDeletedMessage(message: message)
        guard let contents = CodableEntry(snapshot) else {
            continue
        }
        let buffer = WriteBuffer()
        var peerId = id.peerId.toInt64()
        var namespace = id.namespace
        var messageId = id.id
        buffer.write(&peerId, length: 8)
        buffer.write(&namespace, length: 4)
        buffer.write(&messageId, length: 4)
        transaction.addOrMoveToFirstPositionOrderedItemListItem(
            collectionId: Namespaces.OrderedItemList.LocallyDeletedMessages,
            item: OrderedItemListEntry(id: buffer.makeReadBufferAndReset(), contents: contents),
            removeTailIfCountExceeds: 1000
        )
    }
}

public func locallyDeletedMessages(postbox: Postbox) -> Signal<[LocallyDeletedMessage], NoError> {
    let key: PostboxViewKey = .orderedItemList(id: Namespaces.OrderedItemList.LocallyDeletedMessages)
    return postbox.combinedView(keys: [key])
    |> map { views -> [LocallyDeletedMessage] in
        guard let view = views.views[key] as? OrderedItemListView else {
            return []
        }
        return view.items.compactMap { $0.contents.get(LocallyDeletedMessage.self) }
    }
}

public func clearLocallyDeletedMessages(postbox: Postbox) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.replaceOrderedItemListItems(collectionId: Namespaces.OrderedItemList.LocallyDeletedMessages, items: [])
    }
    |> ignoreValues
}
