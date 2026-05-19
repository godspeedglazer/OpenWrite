import Foundation
import OpenWriteKit

@main
enum OpenWriteStatsMain {
    static func main() async {
        await OpenWriteCLIRunner.run(fixedCommand: "stats", arguments: Array(CommandLine.arguments.dropFirst()))
    }
}
