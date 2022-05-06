//
//  PaywallResponseLogic.swift
//  Paywall
//
//  Created by Yusuf Tör on 03/03/2022.
//

import Foundation
import StoreKit

struct TriggerResponseIdentifiers: Equatable {
  let paywallId: String?
  var experimentId: String?
  var variantId: String?
}

struct PaywallErrorResponse {
  let handlers: [PaywallResponseCompletionBlock]
  let error: NSError
}

struct ProductProcessingOutcome {
  var variables: [Variable]
  var productVariables: [ProductVariable]
  var isFreeTrialAvailable: Bool?
  var resetFreeTrialOverride: Bool
}

enum PaywallResponseLogic {
  enum PaywallCachingOutcome {
    case cachedResult(Result<PaywallResponse, NSError>)
    case enqueCompletionBlock(
      hash: String,
      completionBlocks: [PaywallResponseCompletionBlock]
    )
    case setCompletionBlock(hash: String)
  }

  static func requestHash(
    identifier: String? = nil,
    event: EventData? = nil,
    locale: String = DeviceHelper.shared.locale
  ) -> String {
    let id = identifier ?? event?.name ?? "$called_manually"
    return "\(id)_\(locale)"
  }

  // swiftlint:disable:next function_body_length
  static func handleTriggerResponse(
    withPresentationInfo presentationInfo: PresentationInfo,
    didFetchConfig: Bool,
    handleEvent: (EventData) -> HandleEventResult = TriggerManager.handleEvent,
    trackEvent: (Trackable) -> TrackingResult = Paywall.track
  ) throws -> TriggerResponseIdentifiers? {
    guard didFetchConfig else {
      // TODO: Why do we return identifier here exactly? This could influence paywall session start.
      // Also, this is before config has been fetched. Looks like we're totally ignoring an explicit trigger in this instance?
      return TriggerResponseIdentifiers(paywallId: presentationInfo.identifier)
    }

    // swiftlint:disable:next force_unwrapping
    var event: EventData!

    switch presentationInfo {
    case let .implicitTrigger(eventData),
      .explicitTrigger(let eventData):
      event = eventData
    case .fromIdentifier(let paywallId):
      return TriggerResponseIdentifiers(paywallId: paywallId)
    case .defaultPaywall:
      return nil
    }

    let triggerResponse = handleEvent(event)

    switch triggerResponse {
    case let .presentV2(_, experimentIdentifier, variantIdentifier, paywallIdentifier):
      let outcome = TriggerResponseIdentifiers(
        paywallId: paywallIdentifier,
        experimentId: experimentIdentifier,
        variantId: variantIdentifier
      )

      let triggerResult = TriggerResult.paywall(
        experiment: Experiment(
          id: experimentIdentifier,
          variantId: variantIdentifier
        ),
        paywallIdentifier: paywallIdentifier
      )
      let trackedEvent = SuperwallEvent.TriggerFire(
        triggerResult: triggerResult,
        triggerName: event.name
      )
      _ = trackEvent(trackedEvent)

      return outcome
    case let .holdout(_, experimentId, variantId):
      let userInfo: [String: Any] = [
        "experimentId": experimentId,
        "variantId": variantId,
        NSLocalizedDescriptionKey: NSLocalizedString(
          "Trigger Holdout",
          value: "This user was assigned to a holdout in a trigger experiment",
          comment: "ExperimentId: \(experimentId), VariantId: \(variantId)"
        )
      ]
      let error = NSError(
        domain: "com.superwall",
        code: 4001,
        userInfo: userInfo
      )
      let triggerResult = TriggerResult.holdout(
        experiment: Experiment(
          id: experimentId,
          variantId: variantId
        )
      )
      let trackedEvent = SuperwallEvent.TriggerFire(
        triggerResult: triggerResult,
        triggerName: event.name
      )
      _ = trackEvent(trackedEvent)
      throw error
    case .noRuleMatch:
      let userInfo: [String: Any] = [
        NSLocalizedDescriptionKey: NSLocalizedString(
          "No rule match",
          value: "The user did not match any rules configured for this trigger",
          comment: ""
        )
      ]
      let trackedEvent = SuperwallEvent.TriggerFire(
        triggerResult: TriggerResult.noRuleMatch,
        triggerName: event.name
      )
      _ = trackEvent(trackedEvent)
      let error = NSError(
        domain: "com.superwall",
        code: 4000,
        userInfo: userInfo
      )
      throw error
    case .unknownEvent:
      // create the error
      let userInfo: [String: Any] = [
        NSLocalizedDescriptionKey: NSLocalizedString(
          "Trigger Disabled",
          value: "There isn't a paywall configured to show in this context",
          comment: ""
        )
      ]
      let error = NSError(
        domain: "SWTriggerDisabled",
        code: 404,
        userInfo: userInfo
      )
      throw error
    }
  }

  // swiftlint:disable:next function_parameter_count
  static func searchForPaywallResponse(
    forEvent event: EventData?,
    withHash hash: String,
    identifiers triggerResponseIds: TriggerResponseIdentifiers?,
    inResultsCache resultsCache: [String: Result<PaywallResponse, NSError>],
    handlersCache: [String: [PaywallResponseCompletionBlock]],
    isDebuggerLaunched: Bool
  ) -> PaywallCachingOutcome {
    // If the response for request exists, return it
    if let result = resultsCache[hash],
      !isDebuggerLaunched {
        switch result {
        case .success(let response):
          var updatedResponse = response
          updatedResponse.experimentId = triggerResponseIds?.experimentId
          updatedResponse.variantId = triggerResponseIds?.variantId
          return .cachedResult(.success(updatedResponse))
        case .failure:
          return .cachedResult(result)
        }
    }

    // if the request is in progress, enque the completion handler and return
    if let handlers = handlersCache[hash] {
      return .enqueCompletionBlock(
        hash: hash,
        completionBlocks: handlers
      )
    }

    // If there are no requests in progress, store completion block and continue
    return .setCompletionBlock(hash: hash)
  }

  static func handlePaywallError(
    _ error: Error,
    forEvent event: EventData?,
    withHash hash: String,
    handlersCache: [String: [PaywallResponseCompletionBlock]],
    trackEvent: (Trackable) -> TrackingResult = Paywall.track
  ) -> PaywallErrorResponse? {
    if let error = error as? URLSession.NetworkError,
      error == .notFound {
      let trackedEvent = SuperwallEvent.PaywallResponseLoad(
        state: .notFound,
        eventData: event
      )
      _ = trackEvent(trackedEvent)
    } else {
      let trackedEvent = SuperwallEvent.PaywallResponseLoad(
        state: .fail,
        eventData: event
      )
      _ = trackEvent(trackedEvent)
    }

    if let handlers = handlersCache[hash] {
      let userInfo: [String: Any] = [
        NSLocalizedDescriptionKey: NSLocalizedString(
          "Not Found",
          value: "There isn't a paywall configured to show in this context",
          comment: ""
        )
      ]
      let error = NSError(
        domain: "SWPaywallNotFound",
        code: 404,
        userInfo: userInfo
      )

      return PaywallErrorResponse(
        handlers: handlers,
        error: error
      )
    }

    return nil
  }

  static func getVariablesAndFreeTrial(
    fromProducts products: [Product],
    productsById: [String: SKProduct],
    isFreeTrialAvailableOverride: Bool?,
    hasPurchased: @escaping (String) -> Bool = InAppReceipt().hasPurchased(productId:)
  ) -> ProductProcessingOutcome {
    var legacyVariables: [Variable] = []
    var newVariables: [ProductVariable] = []
    var isFreeTrialAvailable: Bool?
    var resetFreeTrialOverride = false

    for product in products {
      // Get skproduct
      guard let appleProduct = productsById[product.id] else {
        continue
      }

      let legacyVariable = Variable(
        key: product.type.rawValue,
        value: appleProduct.eventData
      )
      legacyVariables.append(legacyVariable)

      let productVariable = ProductVariable(
        key: product.type.rawValue,
        value: appleProduct.productVariables
      )
      newVariables.append(productVariable)

      if product.type == .primary {
        isFreeTrialAvailable = appleProduct.hasFreeTrial

        if hasPurchased(product.id),
          appleProduct.hasFreeTrial {
          isFreeTrialAvailable = false
        }
        // use the override if it is set
        if let freeTrialOverride = isFreeTrialAvailableOverride {
          isFreeTrialAvailable = freeTrialOverride
          resetFreeTrialOverride = true
        }
      }
    }

    return ProductProcessingOutcome(
      variables: legacyVariables,
      productVariables: newVariables,
      isFreeTrialAvailable: isFreeTrialAvailable,
      resetFreeTrialOverride: resetFreeTrialOverride
    )
  }
}
