/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import Foundation

internal class RUMEventBuilder {
    let userInfoProvider: UserInfoProvider

    init(userInfoProvider: UserInfoProvider) {
        self.userInfoProvider = userInfoProvider
    }

    func createRUMEvent<DM: RUMDataModel>(with model: DM, attributes: [String: Encodable]) -> RUMEvent<DM> {
        var mergedAttributes = attributes
        mergedAttributes.merge(userInfoProvider.extraInfo) { userAttr, _ in userAttr }
        return RUMEvent(model: model, attributes: mergedAttributes)
    }
}
