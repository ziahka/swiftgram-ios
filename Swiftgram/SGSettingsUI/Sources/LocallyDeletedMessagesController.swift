import Foundation
import Display
import Postbox
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext
import SGItemListUI
import PresentationDataUtils

private enum DeletedSection: Int32, SGItemListSection {
    case messages
}

private enum DeletedAction: Hashable {
    case clear
}

private typealias DeletedEntry = SGItemListUIEntry<DeletedSection, Int32, Int32, Int32, Int32, DeletedAction>

private func deletedMessageDate(_ timestamp: Int32) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
}

public func locallyDeletedMessagesController(context: AccountContext) -> ViewController {
    let arguments = SGItemListArguments<Int32, Int32, Int32, Int32, DeletedAction>(
        context: context,
        action: { action in
            if action == .clear {
                let _ = clearLocallyDeletedMessages(postbox: context.account.postbox).start()
            }
        }
    )

    let signal = combineLatest(
        context.sharedContext.presentationData,
        locallyDeletedMessages(postbox: context.account.postbox)
    )
    |> map { presentationData, messages -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let russian = presentationData.strings.baseLanguageCode == "ru"
        var entries: [DeletedEntry] = [
            .header(id: 0, section: .messages, text: russian ? "ЛОКАЛЬНЫЙ АРХИВ" : "LOCAL ARCHIVE", badge: nil)
        ]
        if messages.isEmpty {
            entries.append(.notice(id: 1, section: .messages, text: russian ? "Удалённых сообщений пока нет." : "No deleted messages yet."))
        } else {
            for (index, message) in messages.enumerated() {
                let sentAt = deletedMessageDate(message.sentAt)
                let deletedAt = deletedMessageDate(message.deletedAt)
                let body = message.text.isEmpty ? message.mediaDescription : message.text
                let label = "\(message.peerTitle) · \(message.authorTitle)\n\(russian ? "Отправлено" : "Sent"): \(sentAt) · \(russian ? "Удалено" : "Deleted"): \(deletedAt)\n\n\(body)"
                entries.append(.notice(id: index + 1, section: .messages, text: label))
            }
            entries.append(.action(id: messages.count + 1, section: .messages, actionType: .clear, text: russian ? "Очистить архив" : "Clear archive", kind: .destructive))
        }
        let state = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(russian ? "Удалённые сообщения" : "Deleted messages"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let list = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks)
        return (state, (list, arguments))
    }

    return ItemListController(context: context, state: signal)
}
