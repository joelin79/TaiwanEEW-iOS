//
//  TestText.swift
//  TaiwanEEW
//
//  Created by Joe Lin on 2023/2/15.
//

import SwiftUI

struct TestText: View{
    
    var alert: Event
    var body: some View{
        Text("id:\(alert.id) time:\(alert.eventTime) sec:\(alert.seconds) int:\(alert.intensity)")
    }
    
}
