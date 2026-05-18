import Foundation
import JWTokensCore

struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw TestFailure(description: message)
    }
}

func testTestRunnerLoadsCoreTarget() throws {
    try expect(SpendRange.today.rawValue == "today", "SpendRange.today raw value should be stable")
}

let tests: [(String, () throws -> Void)] = [
    ("testTestRunnerLoadsCoreTarget", testTestRunnerLoadsCoreTarget)
]

var failures: [String] = []

for (name, test) in tests {
    do {
        try test()
        print("PASS \(name)")
    } catch {
        failures.append("\(name): \(error)")
        print("FAIL \(name): \(error)")
    }
}

if !failures.isEmpty {
    Foundation.exit(1)
}
