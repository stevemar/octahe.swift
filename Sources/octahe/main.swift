//
//  main.swift
//  
//
//  Created by Kevin Carter on 6/4/20.
//

// test args made using docs:
// https://github.com/apple/swift-argument-parser/blob/master/Documentation/

import Foundation

import ArgumentParser


struct OptionsTarget: ParsableArguments {
    // Add option parsing for target configs found within config.
    @Option(
        name: .long,
        help: "Proxy target."
    )
    var via: [String]

    @Option(
        name: .long,
        help: "Escalation binary."
    )
    var escalate: String?

    @Option(
        name: .long,
        help: "Friendly node name."
    )
    var name: String?

    @Argument(
        help: "Target host."
    )
    var target: String
}


struct OptionsAddCopy: ParsableArguments {
    // Add option parsing for target configs found within config.
    @Option(
        name: .long,
        help: "Set the owner of a file or directory."
    )
    var chown: String?

    @Option(
        name: .long,
        help: "This argument is unused and kept only for OCI file compatibility."
    )
    var from: String?

    @Argument(
        help: "File transfers, the last string in the argument is used as the destination."
    )
    var transfer: [String]
}


struct OptionsFrom: ParsableArguments {
    // Add option parsing for target configs found within config.
    @Option(
        name: .long,
        help: "Used to specify the platform of a base image."
    )
    var platform: String?

    @Argument(
        help: "Image information."
    )
    var image: String

    @Argument(
        help: "Image information."
    )
    var AS: String?

    @Argument(
        help: "Image information."
    )
    var name: String?
}


struct OptionsExpose: ParsableArguments {
    // Add option parsing for target configs found within config.
    @Argument(
        help: "Used to expose a given port"
    )
    var port: String

    @Argument(
        help: "Nat port."
    )
    var nat: String?
}


struct Octahe: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Octahe, a utility for deploying OCI compatible applications.",
        subcommands: [Deploy.self, UnDeploy.self],
        defaultSubcommand: Deploy.self
    )
    struct Options: ParsableArguments {
        // Global options used in with all subcommands.
        @Option(
            name: [.customLong("connection-key"), .customShort("k")],
            help: "Key used to initiate a connection."
        )
        var connectionKey: String?

        @Option(
            name: .shortAndLong,
            default: 1,
            help: "Limit the total number of concurrent connections per group."
        )
        var connectionQuota: Int
        
        @Flag(
            help: """
                  Dry run. This option will perform all nessisary introspection, compile an application deployment
                  plan, and validate connectivity to targets; it will NOT run the compiled application deployment
                  plan.
                  """
        )
        var dryRun: Bool

        @Option(
            name: .shortAndLong,
            help: "Escalation binary."
        )
        var escalate: String?
        
        @Option(
            name: [.customLong("escalation-pw"), .customShort("p")],
            help: "Passowrd used for privledge escallation."
        )
        var escalatePassword: String?

        @Option(
            name: .shortAndLong,
            help: """
                  Override or set targets. Any specified on the CLI will be"
                  the only targets used within a given execution.
                  """
        )
        var targets: [String]
        
        @Argument(
            help: "Configuration file(s) used to build an application deployment plan."
        )
        var configurationFiles: [String]
        
        mutating func validate() throws {
            guard !configurationFiles.isEmpty else {
                throw ValidationError(
                    "Please provide at least one OCI compatible configuration file to parse."
                )
            }
        }
    }
}


extension Octahe {
    struct Deploy: ParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Run a deployment for a given OCI compatible application."
        )

        @OptionGroup()
        var options: Octahe.Options
        
        func run() throws {
            print("Beginning deployment execution")
            try CoreRouter(parsedOptions: options, function: "deploy")
        }
    }
    
    struct UnDeploy: ParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Disable a deployment for a given OCI compatible application."
        )

        @OptionGroup()
        var options: Octahe.Options
        
        func run() throws {
            print("Beginning undeployment execution")
            try CoreRouter(parsedOptions: options, function: "undeploy")
        }
    }
}


Octahe.main()
