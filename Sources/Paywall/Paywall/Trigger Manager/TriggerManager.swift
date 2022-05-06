//
//  TriggerManager.swift
//  Superwall
//
//  Created by Brian Anglin on 2/21/22.
//

import Foundation
import UIKit

enum TriggerManager {
  static func handleEvent(
    _ event: EventData
  ) -> HandleEventResult {
    // If we have the config response, all valid triggers should be in response
    let outcome = TriggerLogic.outcome(
      forEvent: event,
      v1Triggers: Storage.shared.v1Triggers,
      v2Triggers: Storage.shared.v2Triggers
    )

    if let confirmableAssignments = outcome.confirmableAssignments {
      Network.shared.confirmAssignments(
        confirmableAssignments,
        completion: nil
      )
    }

    return outcome.result
  }
}
