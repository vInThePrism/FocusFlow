import Foundation

enum LCImportError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case .invalid(let text) = self { return text }; return nil }
}

enum LCImporter {
    static func slug(_ text: String) -> String? {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = url.host?.lowercased(), ["leetcode.com", "www.leetcode.com", "leetcode.cn", "www.leetcode.cn"].contains(host),
              ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.user == nil, url.password == nil,
              url.port == nil else { return nil }
        let parts = url.path.split(separator: "/")
        guard parts.count >= 2, parts[0] == "problems" else { return nil }
        let value = String(parts[1]).lowercased()
        guard value.range(of: "^[a-z0-9]+(?:-[a-z0-9]+)*$", options: .regularExpression) != nil else { return nil }
        return value
    }

    static func known(_ text: String, existing: [LCProblem]) -> LCProblem? {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = slug(clean) ?? clean
        return (existing + LCCatalog.problems).first { $0.id == key || $0.number == key }
    }

    static func manual(url: String, title: String, difficulty: LCDifficulty, topics: String, existing: [LCProblem], number: String = "") throws -> LCProblem {
        guard let id = slug(url) else { throw LCImportError.invalid("Enter a LeetCode problem URL, for example https://leetcode.com/problems/two-sum/.") }
        let rawNumber = number.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsedNumber = Int(rawNumber)
        guard rawNumber.isEmpty || (parsedNumber != nil && parsedNumber! > 0) else {
            throw LCImportError.invalid("Problem number must be a positive integer.")
        }
        let normalizedNumber = parsedNumber.map(String.init)
        if let normalizedNumber = normalizedNumber,
           let other = (existing + LCCatalog.problems).first(where: { $0.number == normalizedNumber && $0.id != id }) {
            throw LCImportError.invalid("That number already belongs to \(other.displayTitle). Check the number or URL.")
        }
        if var p = known(url, existing: existing) {
            if let normalizedNumber = normalizedNumber, let current = p.number, current != normalizedNumber {
                throw LCImportError.invalid("The problem URL and number do not match.")
            }
            if p.number == nil { p.number = normalizedNumber }
            return p
        }
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw LCImportError.invalid("Enter the problem title. Unknown problems need a title before import.") }
        return LCProblem(id: id, number: normalizedNumber, title: name, difficulty: difficulty, topics: tags(topics))
    }

    static func tags(_ text: String) -> [String] {
        var seen = Set<String>()
        return text.components(separatedBy: CharacterSet(charactersIn: ",;|"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }

    static func preview(name: String, source: String, listID: String? = nil, problems: [LCProblem], rejected: [String] = [], existing: [LCProblem]) -> LCImportPreview {
        var seen = Set<String>(), duplicateCount = 0
        let existingIDs = Set(existing.map(\.id))
        let unique = problems.filter { p in
            let fresh = seen.insert(p.id).inserted
            if !fresh || existingIDs.contains(p.id) { duplicateCount += 1 }
            return fresh
        }
        return LCImportPreview(name: name.trimmingCharacters(in: .whitespacesAndNewlines), source: source,
                               listID: listID, problems: unique, duplicates: duplicateCount, rejected: rejected)
    }

    static func common(_ list: LCCommonList, existing: [LCProblem]) -> LCImportPreview {
        preview(name: list.name, source: LCCatalog.source, listID: list.id,
                problems: list.problemIDs.compactMap { id in LCCatalog.problems.first { $0.id == id } }, existing: existing)
    }

    /// Only the bundled, tested public list URLs are supported; never fetch arbitrary URLs.
    static func listURL(_ text: String, existing: [LCProblem]) throws -> LCImportPreview {
        guard let url = URLComponents(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["neetcode.io", "www.neetcode.io"].contains(url.host?.lowercased() ?? ""),
              url.scheme == "https", url.user == nil, url.password == nil, url.port == nil else {
            throw LCImportError.invalid("This list URL is not supported. Choose a common list, upload CSV/JSON, or paste problem links instead.")
        }
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let tab = url.queryItems?.first(where: { $0.name == "tab" })?.value
        let id: String
        if path == "practice" && (tab == nil || tab == "neetcode150") { id = "neetcode150" }
        else if path == "practice" && tab == "blind75" { id = "blind75" }
        else if path == "practice/neetcode150" { id = "neetcode150" }
        else if path == "practice/blind75" { id = "blind75" }
        else { throw LCImportError.invalid("Unsupported list URL. Use a bundled common list or CSV/JSON.") }
        guard let list = LCCatalog.lists.first(where: { $0.id == id }) else { throw LCImportError.invalid("List unavailable.") }
        return common(list, existing: existing)
    }

    static func links(_ text: String, name: String, existing: [LCProblem]) -> LCImportPreview {
        var problems: [LCProblem] = [], rejected: [String] = []
        for line in text.components(separatedBy: .newlines).map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) where !line.isEmpty {
            if let p = known(line, existing: existing) { problems.append(p) }
            else { rejected.append(line) }
        }
        return preview(name: name, source: "Pasted problem links", problems: problems, rejected: rejected, existing: existing)
    }

    static func file(_ url: URL, name: String, existing: [LCProblem]) throws -> LCImportPreview {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        guard (attrs[.size] as? NSNumber)?.intValue ?? 0 <= 5_000_000 else { throw LCImportError.invalid("Please use a file smaller than 5 MB.") }
        let data = try Data(contentsOf: url)
        var rows: [[String: Any]] = []
        var listName = name
        if url.pathExtension.lowercased() == "json" {
            let raw = try JSONSerialization.jsonObject(with: data)
            if let array = raw as? [[String: Any]] { rows = array }
            else if let object = raw as? [String: Any], let array = object["problems"] as? [[String: Any]] {
                rows = array
                listName = object["name"] as? String ?? name
            } else { throw LCImportError.invalid("JSON must be an array of problems or an object with name and problems.") }
        } else {
            guard let text = String(data: data, encoding: .utf8) else { throw LCImportError.invalid("CSV must use UTF-8 text.") }
            let table = try csv(text.replacingOccurrences(of: "\u{feff}", with: ""))
            guard let header = table.first, !header.isEmpty else { throw LCImportError.invalid("The CSV is empty.") }
            let keys = header.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            guard Set(keys).count == keys.count else { throw LCImportError.invalid("CSV column names must be unique.") }
            for fields in table.dropFirst() {
                rows.append(Dictionary(uniqueKeysWithValues: keys.enumerated().map { ($0.element, $0.offset < fields.count ? fields[$0.offset] : "") }))
            }
        }
        var problems: [LCProblem] = [], rejected: [String] = []
        for (i, row) in rows.enumerated() {
            func value(_ key: String) -> String {
                if let s = row[key] as? String { return s.trimmingCharacters(in: .whitespacesAndNewlines) }
                if let n = row[key] as? NSNumber { return n.stringValue }
                return ""
            }
            let link = value("url"), number = value("id"), rawSlug = value("slug")
            let lookup = !link.isEmpty ? link : (!rawSlug.isEmpty ? rawSlug : number)
            if let p = known(lookup, existing: existing) { problems.append(p); continue }
            let title = value("title")
            let parsedSlug = !link.isEmpty ? slug(link) : slug("https://leetcode.com/problems/\(rawSlug)/")
            guard let id = parsedSlug, !title.isEmpty else { rejected.append("Row \(i + 1): provide a valid url and title (or a known ID)."); continue }
            let difficultyText = value("difficulty")
            guard difficultyText.isEmpty || LCDifficulty.allCases.contains(where: { $0.rawValue.lowercased() == difficultyText.lowercased() }) else {
                rejected.append("Row \(i + 1): difficulty must be Easy, Medium, Hard or Unknown."); continue
            }
            let difficulty = LCDifficulty.allCases.first { $0.rawValue.lowercased() == difficultyText.lowercased() } ?? .unknown
            let topics = (row["topics"] as? [String]).map { tags($0.joined(separator: ";")) } ?? tags(value("topics"))
            do {
                let problem = try manual(url: "https://leetcode.com/problems/\(id)/", title: title,
                                         difficulty: difficulty, topics: topics.joined(separator: ";"),
                                         existing: existing + problems, number: Int(number).map(String.init) ?? "")
                problems.append(problem)
            } catch {
                rejected.append("Row \(i + 1): \(error.localizedDescription)")
            }
        }
        return preview(name: listName, source: url.lastPathComponent, problems: problems, rejected: rejected, existing: existing)
    }

    /// RFC-style quoted fields, including escaped quotes, commas and newlines.
    static func csv(_ text: String) throws -> [[String]] {
        let chars = Array(text)
        var rows: [[String]] = [], row: [String] = [], field = "", quoted = false, i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "\"" {
                if quoted && i + 1 < chars.count && chars[i + 1] == "\"" { field.append("\""); i += 1 }
                else { quoted.toggle() }
            } else if c == "," && !quoted { row.append(field); field = "" }
            else if (c == "\n" || c == "\r" || c == "\r\n") && !quoted {
                row.append(field)
                if row.contains(where: { !$0.isEmpty }) { rows.append(row) }
                row = []; field = ""
                if c == "\r" && i + 1 < chars.count && chars[i + 1] == "\n" { i += 1 }
            } else { field.append(c) }
            i += 1
        }
        guard !quoted else { throw LCImportError.invalid("CSV contains an unclosed quoted field.") }
        row.append(field)
        if row.contains(where: { !$0.isEmpty }) { rows.append(row) }
        return rows
    }
}
