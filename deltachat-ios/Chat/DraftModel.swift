import Foundation
import UIKit
import DcCore

public class DraftModel {
    var draftMsg: DcMsg?
    var dcContext: DcContext
    var text: String?
    let chatId: Int
    var isEditing: Bool = false
    var quoteMessage: DcMsg? {
        return draftMsg?.quoteMessage
    }
    var quoteText: String? {
        return draftMsg?.quoteText
    }
    var attachment: String? {
        return draftMsg?.fileURL?.relativePath
    }
    var attachmentMimeType: String? {
        return draftMsg?.filemime
    }
    var viewType: Int32? {
        if let viewType = draftMsg?.type {
            return Int32(viewType)
        }
        return nil
    }

    public init(dcContext: DcContext, chatId: Int) {
        self.chatId = chatId
        self.dcContext = dcContext
    }

    public func parse(draftMsg: DcMsg?) {
        self.draftMsg = draftMsg
        text = draftMsg?.text
    }

    public func setQuote(quotedMsg: DcMsg?) {
        if draftMsg == nil {
            draftMsg = dcContext.newMessage(viewType: DC_MSG_TEXT)
        }
        draftMsg?.quoteMessage = quotedMsg
    }

    public func setAttachment(viewType: Int32?, path: String?, mimetype: String? = nil) {
        if draftMsg == nil {
            draftMsg = dcContext.newMessage(viewType: viewType ?? DC_MSG_TEXT)
        }
        draftMsg?.setFile(filepath: path, mimeType: mimetype)
        save(context: dcContext)
    }

    public func clearAttachment() {
        let text = draftMsg?.text
        let quoteMsg = draftMsg?.quoteMessage
        if text != nil || quoteMsg != nil {
            draftMsg = dcContext.newMessage(viewType: DC_MSG_TEXT)
            draftMsg?.text = text
            draftMsg?.quoteMessage = quoteMsg
            save(context: dcContext)
        } else {
            draftMsg = nil
            dcContext.setDraft(chatId: chatId, message: nil)
        }
    }

    public func save(context: DcContext) {
        if (text?.isEmpty ?? true) &&
            (draftMsg == nil || quoteMessage == nil && attachment == nil) {
            self.clear()
            return
        }

        if draftMsg == nil {
            draftMsg = dcContext.newMessage(viewType: DC_MSG_TEXT)
        }
        draftMsg?.text = text
        context.setDraft(chatId: chatId, message: draftMsg)
    }

    public func canSend() -> Bool {
        return !(text?.isEmpty ?? true) || attachment != nil
    }

    public func clear() {
        text = nil
        draftMsg = nil
        dcContext.setDraft(chatId: chatId, message: nil)
    }
}
