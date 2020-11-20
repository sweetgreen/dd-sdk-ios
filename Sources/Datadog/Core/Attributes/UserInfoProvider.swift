/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import Foundation

/// Shared user info provider.
internal class UserInfoProvider {
    /// Ensures thread-safe access to `UserInfo`.
    /// `UserInfo` can be mutated by any user thread with `Datadog.setUserInfo(id:name:email:)` - at the same
    /// time it might be accessed by different queues running in the SDK.
    private let queue = DispatchQueue(label: "com.datadoghq.user-info-provider", qos: .userInteractive)
    private var _value = UserInfo(id: nil, name: nil, email: nil)
    private var _extraInfo = [AttributeKey: AttributeValue]()

    var value: UserInfo {
        set { queue.async { self._value = newValue } }
        get { queue.sync { self._value } }
    }

    var extraInfo: [AttributeKey: AttributeValue] {
        set {
            queue.async {
                var processedInfo = newValue
                newValue.keys.forEach {
                    let value = processedInfo.removeValue(forKey: $0)
                    processedInfo["usr.\($0)"] = value
                }
                self._extraInfo = processedInfo
            }
        }
        get { queue.sync { self._extraInfo } }
    }
}

/// Information about the user.
internal struct UserInfo {
    let id: String?
    let name: String?
    let email: String?
}
