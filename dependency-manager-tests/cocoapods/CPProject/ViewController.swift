/*
* Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
* This product includes software developed at Datadog (https://www.datadoghq.com/).
* Copyright 2019-2020 Datadog, Inc.
*/

import UIKit
import Datadog

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        Datadog.initialize(
            appContext: .init(),
            configuration: Datadog.Configuration
                .builderUsing(clientToken: "abc")
                .build()
        )

        let logger = Logger.builder.build()
        logger.info("It works")
    }
}
