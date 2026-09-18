//
//  EmojiEntry.swift
//  emojiTool
//
//  Created by Reona Monga on 2026/03/29.
//

import Foundation

struct EmojiEntry: Identifiable, Equatable, Hashable, Decodable {
    let emoji: String
    let description: String
    let aliases: [String]
    let tags: [String]
    
    var id: String { emoji }

    // This combines everything into one searchable array
    var allSearchTerms: Set<String> {
        let combined = aliases + tags + [description]
        return Set(combined.map { $0.lowercased() })
    }

    func matches(query: String) -> Bool {
        let q = query.lowercased()
        return allSearchTerms.contains { $0.localizedCaseInsensitiveContains(q) }
    }

    func bestMatchScore(for query: String, isHandBuilt: Bool) -> Int {
        let q = query.lowercased()
        
        // 1. Hand-built overrides get top billing
        if isHandBuilt && aliases.contains(where: { $0.hasPrefix(q) }) { return 10 }
        
        // 2. Exact match in aliases or tags
        if aliases.contains(q) || tags.contains(q) { return 5 }
        
        // 3. Prefix match in description
        if description.lowercased().hasPrefix(q) { return 2 }
        
        return 0
    }
}
