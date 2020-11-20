/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import XCTest
@testable import Datadog

class RUMEventFileOutputTests: XCTestCase {
    override func setUp() {
        super.setUp()
        temporaryDirectory.create()
    }

    override func tearDown() {
        temporaryDirectory.delete()
        super.tearDown()
    }

    func testItWritesRUMEventToFileAsJSON() throws {
        let fileCreationDateProvider = RelativeDateProvider(startingFrom: .mockDecember15th2019At10AMUTC())
        let queue = DispatchQueue(label: "com.datadohq.testItWritesRUMEventToFileAsJSON")
        let builder = RUMEventBuilder(userInfoProvider: UserInfoProvider.mockAny())
        let output = RUMEventFileOutput(
            fileWriter: FileWriter(
                dataFormat: RUMFeature.dataFormat,
                orchestrator: FilesOrchestrator(
                    directory: temporaryDirectory,
                    performance: PerformancePreset.combining(
                        storagePerformance: .writeEachObjectToNewFileAndReadAllFiles,
                        uploadPerformance: .noOp
                    ),
                    dateProvider: fileCreationDateProvider
                ),
                queue: queue
            )
        )

        let dataModel1 = RUMDataModelMock(attribute: "foo")
        let dataModel2 = RUMDataModelMock(attribute: "bar")
        let event1 = builder.createRUMEvent(with: dataModel1, attributes: ["custom.attribute": "value"])
        let event2 = builder.createRUMEvent(with: dataModel2, attributes: [:])

        output.write(rumEvent: event1)
        queue.sync {} // wait on writter queue

        fileCreationDateProvider.advance(bySeconds: 1)

        output.write(rumEvent: event2)
        queue.sync {} // wait on writter queue

        let event1FileName = fileNameFrom(fileCreationDate: .mockDecember15th2019At10AMUTC())
        let event1Data = try temporaryDirectory.file(named: event1FileName).read()
        let event1Matcher = try RUMEventMatcher.fromJSONObjectData(event1Data)
        XCTAssertEqual(try event1Matcher.model(), dataModel1)

        let event2FileName = fileNameFrom(fileCreationDate: .mockDecember15th2019At10AMUTC(addingTimeInterval: 1))
        let event2Data = try temporaryDirectory.file(named: event2FileName).read()
        let event2Matcher = try RUMEventMatcher.fromJSONObjectData(event2Data)
        XCTAssertEqual(try event2Matcher.model(), dataModel2)

        // TODO: RUMM-585 Move assertion of full-json to `RUMMonitorTests`
        // same as we do for `LoggerTests` and `TracerTests`
        try event1Matcher.assertItFullyMatches(
            jsonString: """
            {
                "attribute": "foo",
                "context.custom.attribute": "value"
            }
            """
        )

        // TODO: RUMM-638 We also need to test (in `RUMMonitorTests`) that custom user attributes
        // do not overwrite values given by `RUMDataModel`.
    }
}
