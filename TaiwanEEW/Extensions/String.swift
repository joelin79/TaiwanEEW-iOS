//
//  String.swift
//  TaiwanEEW
//
//  Created by Albert Huang on 2026/8/24.
//


extension String {
    var localized: String {
        NSLocalizedString(self, comment: "")
    }

//    func localized(with arguments: CVarArg...) -> String {
//        withVaList(arguments) { vaList in
//            NSString(format: self.localized, locale: .current, arguments: vaList) as String
//        }
//    }
}
