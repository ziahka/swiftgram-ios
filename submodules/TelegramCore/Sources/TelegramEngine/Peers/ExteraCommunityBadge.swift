import Foundation
import Postbox

// IDs published in exteraGram's ExteraConfig.java (isExteraDev / isExtera).
// This is a local community marker, not Telegram verification or a donor API.
private let exteraDeveloperIds: Set<Int64> = [
    963080346, 1282540315, 1374434073, 388099852, 1972014627,
    168769611, 480000401, 5307590670, 639891381, 1773117711,
    5330087923, 666154369
]

private let exteraChannelIds: Set<Int64> = [
    1233768168, 1524581881, 1571726392, 1632728092,
    1638754701, 1779596027, 1172503281, 1877362358
]

public func isExteraCommunityPeer(_ peer: EnginePeer) -> Bool {
    switch peer {
    case let .user(user):
        return exteraDeveloperIds.contains(user.id.id._internalGetInt64Value())
    case let .channel(channel):
        return exteraChannelIds.contains(channel.id.id._internalGetInt64Value())
    default:
        return false
    }
}
