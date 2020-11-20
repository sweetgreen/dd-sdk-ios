/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import Foundation

/// Obtains a subdirectory in `/Library/Caches` for writting RUM events.
internal func obtainRUMFeatureDirectory() throws -> Directory {
    return try Directory(withSubdirectoryPath: "com.datadoghq.rum/v1")
}

/// Creates and owns componetns enabling RUM feature.
/// Bundles dependencies for other RUM-related components created later at runtime  (i.e. `RUMMonitor`).
internal final class RUMFeature {
    /// Single, shared instance of `RUMFeature`.
    internal static var instance: RUMFeature?

    /// Tells if the feature was enabled by the user in the SDK configuration.
    static var isEnabled: Bool { instance != nil }

    // MARK: - Configuration

    let configuration: FeaturesConfiguration.RUM

    // MARK: - Dependencies

    let dateProvider: DateProvider
    let userInfoProvider: UserInfoProvider
    let networkConnectionInfoProvider: NetworkConnectionInfoProviderType
    let carrierInfoProvider: CarrierInfoProviderType

    // MARK: - Components

    static let featureName = "rum"
    /// NOTE: any change to data format requires updating the directory url to be unique
    static let dataFormat = DataFormat(prefix: "", suffix: "", separator: "\n")

    /// RUM files storage.
    let storage: FeatureStorage
    /// RUM upload worker.
    let upload: FeatureUpload

    // MARK: - Initialization

    static func createStorage(directory: Directory, commonDependencies: FeaturesCommonDependencies) -> FeatureStorage {
        return FeatureStorage(
            featureName: RUMFeature.featureName,
            dataFormat: RUMFeature.dataFormat,
            directory: directory,
            commonDependencies: commonDependencies
        )
    }

    static func createUpload(
        storage: FeatureStorage,
        directory: Directory,
        configuration: FeaturesConfiguration.RUM,
        commonDependencies: FeaturesCommonDependencies
    ) -> FeatureUpload {
        return FeatureUpload(
            featureName: RUMFeature.featureName,
            storage: storage,
            uploadHTTPHeaders: HTTPHeaders(
                headers: [
                    .contentTypeHeader(contentType: .textPlainUTF8),
                    .userAgentHeader(
                        appName: configuration.common.applicationName,
                        appVersion: configuration.common.applicationVersion,
                        device: commonDependencies.mobileDevice
                    )
                ]
            ),
            uploadURLProvider: UploadURLProvider(
                urlWithClientToken: configuration.uploadURLWithClientToken,
                queryItemProviders: [
                    .ddsource(),
                    .batchTime(using: commonDependencies.dateProvider),
                    .ddtags(
                        tags: [
                            "service:\(configuration.common.serviceName.addingPercentEncoding(withAllowedCharacters: .ddURLQueryAllowed)))",
                            "version:\(configuration.common.applicationVersion)",
                            "sdk_version:\(sdkVersion)",
                            "env:\(configuration.common.environment)"
                        ]
                    )
                ]
            ),
            commonDependencies: commonDependencies
        )
    }

    convenience init(
        directory: Directory,
        configuration: FeaturesConfiguration.RUM,
        commonDependencies: FeaturesCommonDependencies
    ) {
        let storage = RUMFeature.createStorage(directory: directory, commonDependencies: commonDependencies)
        let upload = RUMFeature.createUpload(storage: storage, directory: directory, configuration: configuration, commonDependencies: commonDependencies)
        self.init(
            storage: storage,
            upload: upload,
            configuration: configuration,
            commonDependencies: commonDependencies
        )
    }

    init(
        storage: FeatureStorage,
        upload: FeatureUpload,
        configuration: FeaturesConfiguration.RUM,
        commonDependencies: FeaturesCommonDependencies
    ) {
        // Configuration
        self.configuration = configuration

        // Bundle dependencies
        self.dateProvider = commonDependencies.dateProvider
        self.userInfoProvider = commonDependencies.userInfoProvider
        self.networkConnectionInfoProvider = commonDependencies.networkConnectionInfoProvider
        self.carrierInfoProvider = commonDependencies.carrierInfoProvider

        // Initialize stacks
        self.storage = storage
        self.upload = upload
    }
}

extension CharacterSet {
    /// Creates a CharacterSet from RFC 3986 allowed characters.
    ///
    /// RFC 3986 states that the following characters are "reserved" characters.
    ///
    /// - General Delimiters: ":", "#", "[", "]", "@", "?", "/"
    /// - Sub-Delimiters: "!", "$", "&", "'", "(", ")", "*", "+", ",", ";", "="
    ///
    /// In RFC 3986 - Section 3.4, it states that the "?" and "/" characters should not be escaped to allow
    /// query strings to include a URL. Therefore, all "reserved" characters with the exception of "?" and "/"
    /// should be percent-escaped in the query string.
    public static let ddURLQueryAllowed: CharacterSet = {
        let generalDelimitersToEncode = ":#[]@" // does not include "?" or "/" due to RFC 3986 - Section 3.4
        let subDelimitersToEncode = "!$&'()*+,;="
        let encodableDelimiters = CharacterSet(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")

        return CharacterSet.urlQueryAllowed.subtracting(encodableDelimiters)
    }()
}
