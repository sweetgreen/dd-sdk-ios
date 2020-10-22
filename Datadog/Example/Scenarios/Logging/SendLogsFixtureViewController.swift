/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import UIKit

let stringKey = "string-v9"

func addString(_ value: String) {
    let current = readString()
    let next = current + [value]
    UserDefaults.standard.set(next, forKey: stringKey)
    UserDefaults.standard.synchronize()
}

func readString() -> [String] {
    UserDefaults.standard.stringArray(forKey: stringKey) ?? []
}

internal class SendLogsFixtureViewController: UIViewController {
    let queue1 = DispatchQueue(label: "pl.something.background-some1")
    let queue2 = DispatchQueue(label: "com.datadoghq.background-some1")

    let session = UUID()

    override func viewDidLoad() {
        super.viewDidLoad()

        let strings = readString().map { "🧪    → \($0)" }
        print("🧪 readString() → \n\(strings.joined(separator: "\n"))")

        // Send logs

//        NotificationCenter.default
//            .addObserver(self, selector: #selector(handleWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
//
//        NotificationCenter.default
//            .addObserver(self, selector: #selector(handleDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)

//        (0..<180).forEach { iteration in
//            scheduleTimer(named: "\(iteration)s", after: TimeInterval(iteration))
//        }
//        scheduleTimer(named: "10s", after: 10)
//        scheduleTimer(named: "20s", after: 20)
//        scheduleTimer(named: "120s", after: 120)
//        scheduleTimer(named: "180s", after: 180)
//        scheduleTimer(named: "300s", after: 300)
    }

    var taskIDByName: [String: UIBackgroundTaskIdentifier] = [:]

    func scheduleTimer(named taskName: String, after deadline: TimeInterval) {
        let app = UIApplication.shared

        queue2.asyncAfter(deadline: .now() + deadline) {
            logger.debug("\(deadline)s timer, session: \(self.session.uuidString)")
        }

        let taskID = app.beginBackgroundTask(withName: taskName) {
            let taskID = self.taskIDByName[taskName]!
            app.endBackgroundTask(taskID)

            addString("Invalidating task: \(taskName), session: \(self.session.uuidString)")

            self.taskIDByName[taskName] = UIBackgroundTaskIdentifier.invalid
        }
        taskIDByName[taskName] = taskID

        queue1.asyncAfter(deadline: .now() + deadline) {
            print("🧪 fired based on ABSOLUTE time (\(deadline)s)!")

            addString("\(deadline)s timer, session: \(self.session.uuidString)")

            let taskID = self.taskIDByName[taskName]!
            app.endBackgroundTask(taskID)
            self.taskIDByName[taskName] = UIBackgroundTaskIdentifier.invalid
        }
    }

    @objc
    func handleWillResignActive() {
//        stopTimer()
        logger.debug("UIApplication.willResignActive, session: \(session.uuidString)")
    }

    @objc
    func handleDidBecomeActive() {
//        startTimer()
        logger.debug("UIApplication.didBecomeActive, session: \(session.uuidString)")
    }

    var timer: Timer!
    var counter = 0

    func startTimer() {
        timer = Timer(timeInterval: 1, repeats: true) { [unowned self] timer in
            self.counter += 1
            print("🧪 count: \(self.counter)")
            logger.debug("counter: \(self.counter)")
        }
        RunLoop.current.add(timer, forMode: .common)
    }

    func stopTimer() {
        timer.invalidate()
    }
}
