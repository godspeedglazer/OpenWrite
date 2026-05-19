import Foundation
import OpenWriteKit

@main
enum OpenWriteQueryMain {
    static func main() async {
        await OpenWriteCLIRunner.run(fixedCommand: "query", arguments: Array(CommandLine.arguments.dropFirst()))
    }
}
