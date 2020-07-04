//
//  execute.swift
//
//
//  Created by Kevin Carter on 6/4/20.
//

import Foundation

// swiftlint:disable type_body_length
class Execution {
    let cliParams: OctaheCLI.Options
    let processParams: ConfigParse
    var steps: Int = 0
    var shell: String = "/bin/sh -c"
    var escallation: String?
    var environment: [String: String] = [:]
    var execUser: String?
    var execGroup: String?
    var user: String = NSUserName()
    var escalate: String?
    var escalatePassword: String?
    var workdir: String = FileManager.default.currentDirectoryPath
    var workdirURL: URL
    var target: String?
    var healthcheck: String?
    var command: String?
    var stopsignal: String?
    var documentation: [[String: String]] = [["item": "https://github.com/peznauts/octahe.swift"]]
    var interface: String?

    init(cliParameters: OctaheCLI.Options, processParams: ConfigParse) {
        self.cliParams = cliParameters
        self.processParams = processParams
        self.workdirURL = URL(fileURLWithPath: workdir)
    }

    func connect() throws {
        preconditionFailure("This method is not supported")
    }

    func probe() throws {
        // Sourced from remote target at runtime:
        //    TARGETPLATFORM - platform of the build result. Eg linux/amd64, linux/arm/v7, windows/amd64.
        //    TARGETOS - OS component of TARGETPLATFORM
        //    TARGETARCH - architecture component of TARGETPLATFORM
        //    TARGETVARIANT - variant component of TARGETPLATFORM
        preconditionFailure("This method is not supported")
    }

    func close() {
        preconditionFailure("This method is not supported")
    }

    func run(execute: String) throws {
        preconditionFailure("This method is not supported")
    }

    func runReturn(execute: String) throws -> String {
        preconditionFailure("This method is not supported")
    }

    func mkdir(workdirURL: URL) throws {
        preconditionFailure("This method is not supported")
    }

    func chown(perms: String?, path: String) throws {
        preconditionFailure("This method is not supported")
    }

    func move(fromPath: String, toPath: String) throws {
        preconditionFailure("This method is not supported")
    }

    func localExec(commandArgs: [String]) throws -> String {
        var launchArgs = commandArgs
        let task = Process()
        let pipe = Pipe()
        task.environment = self.environment
        task.executableURL = URL(fileURLWithPath: launchArgs.removeFirst())
        task.arguments = launchArgs
        task.standardError = pipe
        task.standardOutput = pipe
        pipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
        try task.run()
        task.waitUntilExit()
        let output = pipe.fileHandleForReading.availableData
        let outputInfo = String(data: output, encoding: String.Encoding.utf8)!
        if task.terminationStatus != 0 {
            throw RouterError.failedExecution(
                message: """
                         FAILED: \(commandArgs.joined(separator: " "))
                         STATUS: \(task.terminationStatus)
                         REASON: \(task.terminationReason)
                         OUTPUT: \(outputInfo)
                         """
            )
        }
        return outputInfo
    }

    func localMkdir(workdirURL: URL) throws {
        try FileManager.default.createDirectory(
            at: workdirURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    func localExecReturn(execute: String) throws -> String {
        let launchArgs = self.setLaunchArgs(execute: execute)
        return try localExec(commandArgs: launchArgs)
    }

    func createMarker(content: String) -> String {
        return String(describing: "\(String(describing: self.target))-\(content.sha1)").sha1
    }

    func localWriteTemp(content: String) throws -> URL {
        return try localTempFile(
            content: content,
            marker: self.createMarker(content: content)
        )
    }

    func setLaunchArgs(execute: String) -> [String] {
        let execTask = self.execPosixString(command: execute)
        var launchArgs = (self.shell).components(separatedBy: " ")
        launchArgs.append(execTask)
        return launchArgs
    }

    func indexFiles(basePath: URL, fromFiles: [String]) throws -> [URL] {
        func enumerateFiles(dirPath: URL, match: String = "*") {
            let enumerator = FileManager.default.enumerator(atPath: dirPath.path)
            let allObjects = enumerator?.allObjects ?? []
            for item in allObjects {
                let stringItem = String(describing: item)
                // swiftlint:disable control_statement
                if (stringItem.range(of: match, options: .regularExpression, range: nil, locale: nil) != nil) {
                    fromFileURLs.append(dirPath.appendingPathComponent(stringItem))
                }
            }
        }

        var fromFileURLs: [URL] = []
        var isDir: ObjCBool = false
        for file in fromFiles {
            let baseFile = basePath.appendingPathComponent(file)
            if FileManager.default.fileExists(atPath: baseFile.path, isDirectory: &isDir) {
                if isDir.boolValue {
                    enumerateFiles(dirPath: baseFile)
                } else {
                    fromFileURLs.append(baseFile)
                }
            } else {
                let matchItem = baseFile.lastPathComponent
                let baseFilePath = baseFile.deletingLastPathComponent()
                if FileManager.default.fileExists(atPath: baseFilePath.path, isDirectory: &isDir) {
                    let charset = CharacterSet(charactersIn: "\\^$.|?*+()[]")
                    if isDir.boolValue && matchItem.rangeOfCharacter(from: charset) != nil {
                        enumerateFiles(dirPath: baseFilePath, match: matchItem)
                    } else {
                        throw RouterError.failedExecution(
                            message: "The copy file/directory does not exist \(baseFile.path)"
                        )
                    }
                }
            }
        }
        return fromFileURLs
    }

    func copyRun(toUrl: URL, fromUrl: URL) throws -> String {
        preconditionFailure("This method is not supported")
    }

    func copy(base: URL, copyTo: String, fromFiles: [String], chown: String? = nil) throws {
        var toUrl = URL(fileURLWithPath: copyTo)
        var copyFile: String
        let indexedFiles = try self.indexFiles(basePath: base, fromFiles: fromFiles)
        guard indexedFiles.count >= fromFiles.count else {
            throw RouterError.failedExecution(
                message: "Copy files specified were not all found. Expected: \(fromFiles), Found: \(indexedFiles)"
            )
        }
        for fromUrl in indexedFiles {
            if toUrl.hasDirectoryPath {
                toUrl = toUrl.appendingPathComponent(fromUrl.lastPathComponent)
            }
            if self.escalate != nil {
                let tempUrl = URL(fileURLWithPath: "/tmp")
                let tempFileUrl = tempUrl.appendingPathComponent(fromUrl.lastPathComponent.sha1)
                _ = try self.copyRun(
                    toUrl: tempFileUrl,
                    fromUrl: fromUrl
                )
                try self.move(fromPath: tempFileUrl.path, toPath: toUrl.path)
                copyFile = toUrl.path
            } else {
                copyFile = try self.copyRun(
                    toUrl: toUrl,
                    fromUrl: fromUrl
                )
            }
            try self.chown(perms: chown, path: copyFile)
        }
    }

    // swiftlint:disable function_body_length
    func expose(nat: Int32?, port: Int32, proto: String?) throws {
        let port = port
        let proto = proto ?? "tcp"
        let commandExec: String
        let commandCheck: String
        let commandCreate: String
        let command: [String] = ["iptables"]
        if let natPort = nat {
            var commandArgs = [
                "PREROUTING",
                "-m",
                "comment",
                "--comment",
                "Octahe rule".escapeQuote,
                "-p",
                proto,
                "--dport",
                port.toString,
                "-j",
                "REDIRECT",
                "--to-port",
                natPort.toString
            ]
            if let interface = self.interface {
                commandArgs.insert("-i " + interface, at: 1)
            }
            let check = command + ["-t", "nat", "-C"] + commandArgs
            commandCheck = check.joined(separator: " ")
            let create = command + ["-t", "nat", "-I"] + commandArgs
            commandCreate = create.joined(separator: " ")
        } else {
            var commandArgs = [
                "INPUT",
                "-m",
                "comment",
                "--comment",
                "Octahe rule".escapeQuote,
                "-p",
                proto,
                "-m",
                proto,
                "--dport",
                port.toString,
                "-j",
                "ACCEPT"
            ]
            if let interface = self.interface {
                commandArgs.insert("-i " + interface, at: 1)
            }
            let check = command + ["-C"] + commandArgs
            commandCheck = check.joined(separator: " ")
            let create = command + ["-I"] + commandArgs
            commandCreate = create.joined(separator: " ")
        }
        commandExec = "\(commandCheck) || \(commandCreate)"
        try run(execute: commandExec)
    }

    private func optionFormat(options: [String: String]) -> [[String: String]] {
        var items: [[String: String]]  = []
        for (key, value) in options {
            switch key {
            case "ESCALATEPW":
                logger.debug("filtering ESCALATEPW from service options")
            case _ where key.contains("BUILD"):
                logger.debug("filtering BUILD* from service options")
            default:
                items.append(["item": "\(key)=\(value)"])
            }
        }
        return items
    }

    func serviceName(entrypoint: String) -> String {
        return "octahe-" + entrypoint.sha1 + ".service"
    }

    func serviceTemplate(entrypoint: String) throws -> String {
        // Generate a local template, and transfer it to the remote host
        var serviceData: [String: Any] = ["user": self.user, "service_command": entrypoint, "shell": self.shell]

        if self.documentation.count > 0 {
            serviceData["documentation"] = self.documentation
        }
        if self.environment.count > 0 {
            serviceData["environment"] = optionFormat(options: self.environment)
        }
        if let group = self.execGroup {
            serviceData["group"] = group
        }
        if let sigKill = self.stopsignal {
            serviceData["kill_signal"] = sigKill
        }
        serviceData["private_tmp"] = "yes"
        if self.workdir != FileManager.default.currentDirectoryPath {
            serviceData["workdir"] = self.workdir
            if self.workdir.contains("tmp") {
                serviceData["private_tmp"] = "no"
            }
        }
        return try systemdRender(data: serviceData)
    }

    func entrypointRemove(entrypoint: String) throws {
        let serviceFile = self.serviceName(entrypoint: entrypoint)
        try self.run(execute: "systemctl stop \(serviceFile)")
        try self.run(execute: "systemctl daemon-reload")
        try self.run(execute: "rm -f /etc/systemd/system/\(serviceFile)")
    }

    func entrypointStart(entrypoint: String) throws {
        let serviceFile = self.serviceName(entrypoint: entrypoint)
        let serviceRendered = try self.serviceTemplate(entrypoint: entrypoint)
        let tempServiceFile = try self.localWriteTemp(content: serviceRendered)
        defer {
            try? FileManager.default.removeItem(at: tempServiceFile)
        }
        try self.copy(
            base: tempServiceFile.deletingLastPathComponent(),
            copyTo: "/etc/systemd/system/\(serviceFile)",
            fromFiles: [tempServiceFile.lastPathComponent]
        )
        try self.run(execute: "systemctl daemon-reload")
        try self.run(execute: "systemctl restart \(serviceFile)")
    }

    func posixEncoder(item: String) -> String {
        let encoderShell = self.shell.components(separatedBy: " ").first ?? ""
        return "printf " + item.b64encode.quote + " | base64 --decode | " + encoderShell
    }

    func execPosixString(command: String) -> String {
        var execTask: String = self.posixEncoder(item: "(cd \(self.workdir); \(command))")

        if let user = self.execUser {
            execTask = self.posixEncoder(item: "su \(user) -c \(execTask.quote)")
        }

        if let escalate = self.escalate {
            if let password = self.escalatePassword {
                // Password is add to the environment.
                self.environment["ESCALATEPW"] = password
                execTask = self.posixEncoder(
                    item: "printf \"${ESCALATEPW}\" | \(escalate) --stdin -- " + self.shell + " \(execTask.quote)"
                )
            } else {
                execTask = self.posixEncoder(item: "\(escalate)" + " -- " + self.shell + " \(execTask.quote)")
            }
        }
        return execTask
    }
}
