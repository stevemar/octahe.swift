//
//  task.swift
//  
//
//  Created by Kevin Carter on 6/19/20.
//

import Foundation

import Spinner

enum TaskStates {
    case new, running, success, degraded, failed
}

var taskRecords: [Int: TaskRecord] = [:]

class TaskRecord {
    let task: String
    let taskItem: TypeDeploy
    var state = TaskStates.new

    init(task: String, taskItem: TypeDeploy) {
        self.task = task
        self.taskItem = taskItem
    }
}

class TaskOperations {
    lazy var tasksInProgress: [IndexPath: Operation] = [:]
    lazy var taskQueue: OperationQueue = {
    var queue = OperationQueue()
        queue.name = "Task queue"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
}

class TaskOperation: Operation {
    let taskRecord: TaskRecord
    let deployItem: (key: String, value: TypeDeploy)
    let steps: Int
    let stepIndex: Int
    let args: ConfigParse
    let options: OctaheCLI.Options
    var printStatus: Bool = true
    var mySpinner: Spinner?
    var statusLineFull: String?
    var statusLine: String?

    init(deployItem: (key: String, value: TypeDeploy), steps: Int, stepIndex: Int,
         args: ConfigParse, options: OctaheCLI.Options) {
        self.deployItem = deployItem
        self.steps = steps
        self.stepIndex = stepIndex
        self.args = args
        self.options = options
        if let taskRecordsLookup = taskRecords[stepIndex] {
            self.taskRecord = taskRecordsLookup
        } else {
            let taskRecordsLookup = TaskRecord(task: deployItem.key, taskItem: deployItem.value)
            taskRecords[stepIndex] = taskRecordsLookup
            self.taskRecord = taskRecords[stepIndex]!
        }
    }

    private func finishTask() {
        let degradedTargetStates = targetRecords.values.filter {$0.state == .failed}
        if degradedTargetStates.count == args.octaheTargets.count {
            if let spinner = self.mySpinner {
                spinner.failure(self.statusLineFull)
            }
            self.taskRecord.state = .failed
        } else if degradedTargetStates.count > 0 {
            if let spinner = self.mySpinner {
                spinner.warning(self.statusLineFull)
            }
        } else {
            if let spinner = self.mySpinner {
                spinner.succeed(self.statusLine)
            }
        }
        if let spinner = self.mySpinner {
            spinner.clear()
        }
    }

    private func queueTaskOperations(targetQueue: TargetOperations) {
        for target in args.octaheTargets {
            if let targetData = args.octaheTargetHash[target] {
                let targetOperation = TargetOperation(
                    target: targetData,
                    args: args,
                    options: options,
                    taskIndex: stepIndex
                )
                if targetRecords[target]?.state == .available {
                    if printStatus {
                        self.mySpinner = Spinner(.dots, self.statusLine ?? "Working")
                        if let spinner = self.mySpinner {
                            spinner.start()
                        }
                        printStatus = false
                    }
                    targetQueue.nodeQueue.addOperation(targetOperation)
                }
            }
        }
    }

    override func main() {
        let availableTargets = targetRecords.values.filter {$0.state == .available}
        if availableTargets.count == 0 && targetRecords.keys.count > 0 {
            return
        }
        let targetQueue = TargetOperations(connectionQuota: options.connectionQuota)
        self.statusLineFull = String(
            format: "Step \(stepIndex)/\(steps) : \(deployItem.key) \(deployItem.value.original)"
        )
        self.statusLine = statusLineFull?.trunc(length: 77)
        self.queueTaskOperations(targetQueue: targetQueue)
        targetQueue.nodeQueue.waitUntilAllOperationsAreFinished()
        self.finishTask()
    }
}
