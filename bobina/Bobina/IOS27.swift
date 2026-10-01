import UIKit
import ObjectiveC

/// Riparazioni per iOS 27.
enum IOS27 {

    /// Su iOS 27 `-[UIApplication statusBarHeightForOrientation:]` non fa più niente e restituisce NaN.
    /// Il pannello bluetooth di Apple (CABTMIDICentralViewController) la usa ancora per calcolare la sua
    /// altezza: con NaN la sua tabella ha un'altezza impossibile e l'app si chiude appena si tocca
    /// «cerca il TX-6» (misurato il 1/10/2026 sull'iPhone 18 Pro e nel simulatore iOS 27:
    /// «CALayer bounds contains NaN: [0 0; 402 nan]»). Qui la funzione torna a dare l'altezza vera
    /// della barra di stato, presa dalla scena. Sotto iOS 27 non si tocca niente.
    static func install() {
        guard #available(iOS 27, *) else { return }
        let selector = NSSelectorFromString("statusBarHeightForOrientation:")
        guard let method = class_getInstanceMethod(UIApplication.self, selector) else { return }
        let height: @convention(block) (AnyObject, Int) -> CGFloat = { _, _ in
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            let h = scenes.first?.statusBarManager?.statusBarFrame.height ?? 0
            return h.isFinite ? h : 0
        }
        method_setImplementation(method, imp_implementationWithBlock(height))
        trace("iOS 27: altezza della barra di stato riparata per il pannello bluetooth")
    }
}
