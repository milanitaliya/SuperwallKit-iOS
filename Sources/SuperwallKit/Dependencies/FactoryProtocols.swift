//
//  File.swift
//  
//
//  Created by Yusuf Tör on 03/01/2023.
//

import UIKit

protocol ViewControllerFactory: AnyObject {
  @MainActor
  func makePaywallViewController(for paywall: Paywall) -> PaywallViewController
  func makeDebugViewController(withDatabaseId id: String?) -> DebugViewController
}

protocol CacheFactory: AnyObject {
  func makeCache() -> PaywallCache
}

protocol VariablesFactory: AnyObject {
  func makeJsonVariables(
    productVariables: [ProductVariable]?,
    params: JSON?
  ) -> JSON
}

protocol RequestFactory: AnyObject {
  func makePaywallRequest(
    eventData: EventData?,
    responseIdentifiers: ResponseIdentifiers,
    overrides: PaywallRequest.Overrides?
  ) -> PaywallRequest

  func makePresentationRequest(
    _ presentationInfo: PresentationInfo,
    paywallOverrides: PaywallOverrides?,
    presentingViewController: UIViewController?,
    isDebuggerLaunched: Bool?,
    isUserSubscribed: Bool?,
    isPaywallPresented: Bool
  ) -> PresentationRequest
}

protocol RuleAttributesFactory: AnyObject {
  func makeRuleAttributes() -> RuleAttributes
}

protocol TriggerSessionManagerFactory: AnyObject {
  func makeTriggerSessionManager() -> TriggerSessionManager
}

protocol StoreKitCoordinatorFactory: AnyObject {
  func makeStoreKitCoordinator() -> StoreKitCoordinator
}

protocol IdentityInfoFactory: AnyObject {
  func makeIdentityInfo() -> IdentityInfo
}

protocol DeviceInfoFactory: AnyObject {
  func makeDeviceInfo() -> DeviceInfo
}

protocol ApiFactory: AnyObject {
  // TODO: Think of an alternative way such that we don't need to do this:
  // swiftlint:disable implicitly_unwrapped_optional
  var api: Api! { get }
  var storage: Storage! { get }
  var deviceHelper: DeviceHelper! { get }
  var configManager: ConfigManager! { get }
  var identityManager: IdentityManager! { get }
  // swiftlint:enable implicitly_unwrapped_optional

  func makeHeaders(
    fromRequest request: URLRequest,
    requestId: String
  ) -> [String: String]
}

protocol ProductPurchaserFactory: AnyObject {
  func makeSK1ProductPurchaser() -> ProductPurchaserSK1
}

protocol StoreTransactionFactory: AnyObject {
  func makeStoreTransaction(from transaction: SK1Transaction) async -> StoreTransaction

  @available(iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  func makeStoreTransaction(from transaction: SK2Transaction) async -> StoreTransaction
}
