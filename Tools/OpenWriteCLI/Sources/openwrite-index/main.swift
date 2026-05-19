import Foundation
import OpenWriteKit

@main
enum OpenWriteIndexMain {
    static func main() async {
        await OpenWriteCLIRunner.run(fixedCommand: "index", arguments: Array(CommandLine.arguments.dropFirst()))
    }
}
