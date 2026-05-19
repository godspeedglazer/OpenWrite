import Foundation
import OpenWriteKit

@main
enum OpenWriteMain {
    static func main() async {
        await OpenWriteCLIRunner.run(arguments: Array(CommandLine.arguments.dropFirst()))
    }
}
