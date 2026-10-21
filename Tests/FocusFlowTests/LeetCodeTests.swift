import XCTest
@testable import FocusFlow

final class LeetCodeTests: XCTestCase {
    func testCatalogAndCanonicalIdentity() throws {
        XCTAssertEqual(LCCatalog.lists.map { $0.problemIDs.count }, [150, 75])
        XCTAssertEqual(Set(LCCatalog.problems.map(\.id)).count, LCCatalog.problems.count)
        XCTAssertEqual(LCImporter.slug("https://leetcode.cn/problems/two-sum/description/?x=1"), "two-sum")
        XCTAssertNil(LCImporter.slug("https://leetcode.com.evil.test/problems/two-sum"))
        XCTAssertNil(LCImporter.slug("javascript:alert(1)"))
        XCTAssertThrowsError(try LCImporter.listURL("https://leetcode.com/problem-list/private", existing: []))
        XCTAssertEqual(try LCImporter.listURL("https://neetcode.io/practice?tab=blind75", existing: []).problems.count, 75)
        XCTAssertThrowsError(try LCImporter.manual(url: "https://leetcode.com/problems/new-problem/", title: "", difficulty: .easy, topics: "", existing: []))
    }

    func testCSVAndJSONImports() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let csv = dir.appendingPathComponent("problems.csv")
        try "url,title,difficulty,topics\r\nhttps://leetcode.com/problems/test-problem/,\"A, quoted \"\"title\"\"\",Easy,Array;String\r\nhttps://evil.test/x,Invalid,Easy,Array\r\n".write(to: csv, atomically: true, encoding: .utf8)
        let preview = try LCImporter.file(csv, name: "Custom", existing: [])
        XCTAssertEqual(preview.problems.count, 1)
        XCTAssertEqual(preview.problems.first?.title, "A, quoted \"title\"")
        XCTAssertEqual(preview.problems.first?.topics, ["Array", "String"])
        XCTAssertEqual(preview.rejected.count, 1)
        XCTAssertThrowsError(try LCImporter.csv("title\n\"unclosed"))
        let json = dir.appendingPathComponent("list.json")
        try #"{"name":"Shared","problems":[{"id":1},{"url":"https://leetcode.cn/problems/two-sum/"},{"id":999999}]}"#.write(to: json, atomically: true, encoding: .utf8)
        let result = try LCImporter.file(json, name: "ignored", existing: [])
        XCTAssertEqual(result.name, "Shared")
        XCTAssertEqual(result.problems.count, 1)
        XCTAssertEqual(result.duplicates, 1)
        XCTAssertEqual(result.rejected.count, 1)
    }

    @MainActor
    func withStore(_ test: (Store, URL) throws -> Void) throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let defaults = UserDefaults.standard
        let keys = [Pref.dataFolder, "importedLegacyTomato", Pref.soundsOn, Pref.repeatExtension, Pref.intention, Pref.linkedTask]
        let old = keys.map { defaults.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, old) { if let value = value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) } }
            try? FileManager.default.removeItem(at: folder)
        }
        defaults.set(folder.path, forKey: Pref.dataFolder)
        defaults.set(true, forKey: "importedLegacyTomato")
        defaults.set(false, forKey: Pref.soundsOn)
        defaults.set(true, forKey: Pref.repeatExtension)
        try test(Store(), folder)
    }

    @MainActor
    func testSharedProgressQueueAndRoundTrip() throws {
        try withStore { store, _ in
            XCTAssertEqual(store.leetcode.lists.map(\.name), ["NeetCode 150", "Blind 75"])
            XCTAssertFalse(store.leetcode.topics.isEmpty)
            store.importProblems(LCImporter.common(LCCatalog.lists[0], existing: []))
            let id = "two-sum"
            store.setProblemNotes(id, "Keep this note")
            store.recordProblemResult(id, outcome: .yes)
            store.importProblems(LCImporter.common(LCCatalog.lists[1], existing: store.leetcode.problems))
            XCTAssertEqual(store.leetcode.problems.count, 150)
            XCTAssertEqual(store.leetcode.lists.count, 2)
            XCTAssertEqual(store.leetcode.progressFor(id).notes, "Keep this note")
            XCTAssertEqual(store.leetcode.progressFor(id).outcome, .yes)
            store.generateProblems(topic: "Any topic", count: 5)
            let queue = store.leetcode.queues[PlanLogic.key(Date())]!.problemIDs
            XCTAssertEqual(queue.count, 5)
            XCTAssertFalse(queue.contains(id))
            XCTAssertEqual(queue, store.leetcode.recommendations(topic: "Any topic", count: 5))
            store.recordProblemResult(queue[0], outcome: .hints)
            XCTAssertEqual(store.leetcode.queues[PlanLogic.key(Date())]!.problemIDs, queue)
            store.flushProblemNotes()
            let reloaded = Store()
            XCTAssertEqual(reloaded.leetcode.progressFor(id).notes, "Keep this note")
            XCTAssertEqual(reloaded.leetcode.queues[PlanLogic.key(Date())]!.problemIDs, queue)
            store.generateProblems(topic: "No such topic", count: 8)
            XCTAssertTrue(store.leetcode.queues[PlanLogic.key(Date())]!.problemIDs.isEmpty)
        }
    }

    @MainActor
    func testReviewStagesAndOverdueAcrossDST() throws {
        try withStore { store, _ in
            store.importProblems(LCImporter.common(LCCatalog.lists[0], existing: []))
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "America/Chicago")!
            let start = cal.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 12))!
            var payload = Payload()
            payload.leetcode = store.leetcode
            payload.leetcode.progress["two-sum"] = LCProgress(outcome: .yes, nextReviewDate: cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: start)), reviewStage: 0)
            store.merge(payload)
            var due = store.leetcode.progressFor("two-sum").nextReviewDate!
            XCTAssertTrue(store.leetcode.due(on: cal.date(byAdding: .day, value: 2, to: due)!, calendar: cal).contains { $0.id == "two-sum" })
            for interval in [3, 7, 14, 30] {
                store.reviewProblem("two-sum", remembered: true, now: due, calendar: cal)
                let next = store.leetcode.progressFor("two-sum").nextReviewDate!
                XCTAssertEqual(cal.dateComponents([.day], from: due, to: next).day, interval)
                XCTAssertEqual(cal.component(.hour, from: next), 0)
                due = next
            }
            store.reviewProblem("two-sum", remembered: false, now: due, calendar: cal)
            XCTAssertEqual(store.leetcode.progressFor("two-sum").reviewStage, 0)
            XCTAssertEqual(cal.dateComponents([.day], from: due, to: store.leetcode.progressFor("two-sum").nextReviewDate!).day, 1)
        }
    }

    @MainActor
    func testAttemptsDoNotDuplicateFocusOrAutoSolve() throws {
        try withStore { store, _ in
            store.importProblems(LCImporter.common(LCCatalog.lists[0], existing: []))
            let now = Date()
            let r = SessionRecord(id: UUID(), phase: .focus, intention: "", start: now.addingTimeInterval(-1500), end: now, plannedSeconds: 1500, extensionSeconds: 0, extensions: 0, activeSeconds: 1500, completed: true, problemID: "two-sum")
            store.upsert(r)
            XCTAssertEqual(store.leetcode.progressFor("two-sum").outcome, .skipped)
            store.recordProblemResult("two-sum", outcome: .skipped, sessionID: r.id)
            store.recordProblemResult("two-sum", outcome: .yes, sessionID: r.id)
            XCTAssertEqual(store.leetcode.attempts.count, 1)
            XCTAssertFalse(store.leetcode.progressFor("two-sum").outcome.solved)
            XCTAssertEqual(store.records.reduce(0) { $0 + $1.activeSeconds }, 1500)
            store.recordProblemResult("two-sum", outcome: .hints)
            XCTAssertEqual(store.leetcode.progressFor("two-sum").outcome, .hints)
            XCTAssertNotNil(store.leetcode.progressFor("two-sum").nextReviewDate)
            store.recordProblemResult("two-sum", outcome: .yes)
            store.recordProblemResult("two-sum", outcome: .notYet)
            XCTAssertEqual(store.leetcode.progressFor("two-sum").outcome, .yes)
        }
    }

    func testCrossMidnightCompletionAndStatisticsToggle() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Chicago")!
        let start = cal.date(from: DateComponents(year: 2026, month: 10, day: 17, hour: 23, minute: 50))!
        let end = cal.date(byAdding: .minute, value: 25, to: start)!
        var r = SessionRecord(id: UUID(), phase: .focus, intention: "", start: start, end: end, plannedSeconds: 1500, extensionSeconds: 0, extensions: 0, activeSeconds: 1500, completed: true, problemID: "two-sum", problemOutcome: .yes)
        var state = LCState()
        state.attempts = [LCAttempt(problemID: "two-sum", timestamp: end, outcome: .yes, sessionID: r.id)]
        XCTAssertTrue(state.completedProblemIDs(on: start, granularity: .day, records: [r], calendar: cal).isEmpty)
        XCTAssertEqual(state.completedProblemIDs(on: end, granularity: .day, records: [r], calendar: cal), ["two-sum"])
        r.countsInStats = false
        XCTAssertTrue(state.completedProblemIDs(on: end, granularity: .day, records: [r], calendar: cal).isEmpty)
    }

    @MainActor
    func testImportedAnswerReconcilesCheckpoint() throws {
        try withStore { store, _ in
            store.importProblems(LCImporter.common(LCCatalog.lists[0], existing: []))
            let now = Date()
            var r = SessionRecord(id: UUID(), phase: .focus, intention: "", start: now.addingTimeInterval(-1500), end: now, plannedSeconds: 1500, extensionSeconds: 0, extensions: 0, activeSeconds: 1500, completed: true, problemID: "two-sum")
            store.upsert(r)
            r.problemOutcome = .yes
            var backup = Payload(sessions: [r])
            backup.leetcode.attempts = [LCAttempt(problemID: "two-sum", timestamp: now, outcome: .yes, sessionID: r.id)]
            store.merge(backup)
            XCTAssertEqual(store.records[0].problemOutcome, .yes)
            store.recordProblemResult("two-sum", outcome: .skipped, sessionID: r.id)
            XCTAssertEqual(store.records[0].problemOutcome, .yes)
            XCTAssertEqual(store.leetcode.attempts.count, 1)
            let engine = Engine(store: store)
            XCTAssertNil(engine.pendingProblemSessionID)
        }
    }

    @MainActor
    func testEngineKeepsSessionAndAssociationAcrossExtensions() throws {
        try withStore { store, _ in
            store.importProblems(LCImporter.common(LCCatalog.lists[0], existing: []))
            let engine = Engine(store: store)
            let p = store.leetcode.problem("two-sum")!
            XCTAssertTrue(engine.startProblem(p))
            let id = engine.liveRecord!.id
            XCTAssertFalse(engine.startProblem(store.leetcode.problems[0]))
            engine.pause()
            for _ in 0..<6 { engine.extend(minutes: 5) }
            XCTAssertEqual(engine.liveRecord?.id, id)
            XCTAssertEqual(engine.liveRecord?.problemID, p.id)
            XCTAssertEqual(engine.extensions, 6)
            XCTAssertEqual(engine.extensionSeconds, 1800)
            engine.resume()
            engine.finishSession()
            XCTAssertEqual(engine.state, .idle)
            XCTAssertNil(engine.linkedProblemID)
            XCTAssertFalse(store.leetcode.progressFor(p.id).outcome.solved)
        }
    }

    @MainActor
    func testLegacyDecode() throws {
        let old = #"{"app":"FocusFlow","version":2,"savedAt":"2026-10-17T12:00:00Z","sessions":[{"id":"11111111-1111-1111-1111-111111111111","start":"2026-10-17T12:00:00Z","activeSeconds":1500}]}"#
        let payload = try XCTUnwrap(Store.decode(Data(old.utf8)))
        XCTAssertEqual(payload.sessions.count, 1)
        XCTAssertNil(payload.sessions[0].problemID)
        XCTAssertTrue(payload.leetcode.problems.isEmpty)
    }
}
