//
//  ItemEnumerator.swift
//  Glider
//
//  Created by Antonio García on 21/1/23.
//

import FileProvider
import os.log

class ItemEnumerator: NSObject, NSFileProviderEnumerator
{
    private let logger = Logger.createLogger(category: "ItemEnumerator")
    
    init(enumeratedItemIdentifier: NSFileProviderItemIdentifier) {
        logger.info("init")
        //self.enumeratedItemIdentifier = DomainService.ItemIdentifier(enumeratedItemIdentifier)
        super.init()
    }
    
    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        logger.info("enumerateItems: \(observer.description) startingAt: \(page.rawValue)")
        
    }
    
    func invalidate() {
        logger.info("invalidate")
    }

}
