//
//  File.swift
//  
//
//  Created by Yusuf Tör on 06/05/2022.
//

import Foundation

struct SessionEventsRequest: Encodable {
  var triggerSessions: [TriggerSession]
  //var appSessions: [JSON]
  //var transactions: [JSON]
}

