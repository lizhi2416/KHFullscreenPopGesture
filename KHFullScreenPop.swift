//
//  KHFullScreenPop.swift
//  KeepHolding
//
//  Created by 理智 on 2021/9/7.
//

import Foundation

typealias KHWillAppearInjectBlock = ((_ viewController: UIViewController, _ animated: Bool) -> Void)

class KHPanGestureRecognizer: UIPanGestureRecognizer {
    
}

fileprivate struct RunTimeKey {
    static let gesturekey = UnsafeRawPointer(bitPattern: "kh_fullscreenPopGestureRecognizer_key".hashValue)!
    static let enabledkey = UnsafeRawPointer(bitPattern: "kh_viewControllerBasedNavigationBarAppearanceEnabled_key".hashValue)!
    static let popDisabledkey = UnsafeRawPointer(bitPattern: "kh_interactivePopDisabled_key".hashValue)!
    static let barHiddenkey = UnsafeRawPointer(bitPattern: "kh_prefersNavigationBarHidden_key".hashValue)!
    static let popGesZonekey = UnsafeRawPointer(bitPattern: "kh_interactivePopGesZone_key".hashValue)!
    static let colorKey = UnsafeRawPointer(bitPattern: "kh_customNavColor_key".hashValue)!
    static let gestureDelegateKey = UnsafeRawPointer(bitPattern: "kh_gestureDelegate_key".hashValue)!
    static let injectBlocKey = UnsafeRawPointer(bitPattern: "kh_injectBlocKey_key".hashValue)!
}

class khPopGestureRecognizerDelegate: NSObject, UIGestureRecognizerDelegate {
    
    weak var navigationController: UINavigationController?
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        
        guard let navigationController = navigationController else { return false }
        
        // Ignore when no view controller is pushed into the navigation stack.
        if navigationController.viewControllers.count <= 1 {
            return false
        }
        
        // Disable when the active view controller doesn't allow interactive pop.这里就先不用runtime添加属性了，放在基类里也ok
        if let currentVC = navigationController.viewControllers.last {
            if currentVC.kh_interactivePopDisabled {
                return false
            }
            if currentVC.kh_interactivePopGesZone > 0 {
                //还可以扩展手势是全屏返回还是某些固定区域返回
                if gestureRecognizer.location(in: gestureRecognizer.view).x > currentVC.kh_interactivePopGesZone {
                    return false
                }
            }
        }
        
        // Ignore pan gesture when the navigation controller is currently in transition.
        if let isTransitioning = navigationController.value(forKey: "_isTransitioning") as? NSNumber {
            if isTransitioning.boolValue {
                return false
            }
        }
        
        // Prevent calling the handler when the gesture begins in an opposite direction.
        if let panGes = gestureRecognizer as? UIPanGestureRecognizer {
            let translation = panGes.translation(in: panGes.view)
            if translation.x <= 0 {
                return false
            }
        }
        
        return true
    }
    
}

extension UINavigationController {
    
    var kh_fullscreenPopGestureRecognizer: UIPanGestureRecognizer {
        
        if let popGesture = objc_getAssociatedObject(self, RunTimeKey.gesturekey) as? KHPanGestureRecognizer {
            return popGesture
        } else {
            let panGesture = KHPanGestureRecognizer()
            panGesture.maximumNumberOfTouches = 1
            objc_setAssociatedObject(self, RunTimeKey.gesturekey, panGesture, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return panGesture
        }
        
    }
    
    var kh_popGestureRecognizerDelegate: khPopGestureRecognizerDelegate {
        if let gestureDelegate = objc_getAssociatedObject(self, RunTimeKey.gestureDelegateKey) as? khPopGestureRecognizerDelegate {
            return gestureDelegate
        } else {
            let gestureDelegate = khPopGestureRecognizerDelegate()
            gestureDelegate.navigationController = self
            objc_setAssociatedObject(self, RunTimeKey.gestureDelegateKey, gestureDelegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return gestureDelegate
        }
    }
    
    
    var kh_viewControllerBasedNavigationBarAppearanceEnabled: Bool {
        
        get {
            if let enabled = objc_getAssociatedObject(self, RunTimeKey.enabledkey) as? NSNumber {
                return enabled.boolValue
            }
            return true
        }
        
        set {
            objc_setAssociatedObject(self, RunTimeKey.enabledkey, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        
    }
    /// 记得再app启动时初始化一下
    public class func initializePushMethod(){
        let originalSelector = #selector(UINavigationController.pushViewController(_:animated:))
        let swizzledSelector = #selector(UINavigationController.kh_pushViewController(_:animated:))

        let originalMethod = class_getInstanceMethod(self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)

        //在进行 Swizzling 的时候,需要用 class_addMethod 先进行判断一下原有类中是否有要替换方法的实现
        let didAddMethod: Bool = class_addMethod(self, originalSelector, method_getImplementation(swizzledMethod!), method_getTypeEncoding(swizzledMethod!))
        //如果 class_addMethod 返回 yes,说明当前类中没有要替换方法的实现,所以需要在父类中查找,这时候就用到 method_getImplemetation 去获取 class_getInstanceMethod 里面的方法实现,然后再进行 class_replaceMethod 来实现 Swizzing
        if didAddMethod {
            class_replaceMethod(self, swizzledSelector, method_getImplementation(originalMethod!), method_getTypeEncoding(originalMethod!))
        } else {
            method_exchangeImplementations(originalMethod!, swizzledMethod!)
        }
    }

    @objc func kh_pushViewController(_ viewController: UIViewController, animated: Bool) {
        
        self.replaceSystemPopGestureWithCustom()
        
        self.kh_setupNavigationBarAppearanceBased(appearingViewController: viewController)
        
        self.kh_pushViewController(viewController, animated: animated)
    }
    
    func kh_setupNavigationBarAppearanceBased(appearingViewController: UIViewController) {
        if !self.kh_viewControllerBasedNavigationBarAppearanceEnabled {
            return
        }
        
        let block: KHWillAppearInjectBlock = { [weak self] (viewController, animated) in
            if let sself = self {
                sself.setNavigationBarHidden(viewController.kh_prefersNavigationBarHidden, animated: animated)
            }
        }
        
        appearingViewController.fd_willAppearInjectBlock = block
        
        if let disappearingViewController = self.viewControllers.last, disappearingViewController.fd_willAppearInjectBlock == nil {
            disappearingViewController.fd_willAppearInjectBlock = block
        }
        
    }
    
    func replaceSystemPopGestureWithCustom() {
        
        guard let interactivePopGes = self.interactivePopGestureRecognizer else { return }
        guard let gesView = interactivePopGes.view else { return }
        
        if gesView.gestureRecognizers?.contains(self.kh_fullscreenPopGestureRecognizer) != true {
            gesView.addGestureRecognizer(self.kh_fullscreenPopGestureRecognizer)
            
            guard let internalTargets = interactivePopGes.value(forKey: "targets") as? [NSObject] else { return }
            guard let internalTarget = internalTargets.first?.value(forKey: "target") else { return  }
            let internalAction = Selector(("handleNavigationTransition:"))
            self.kh_fullscreenPopGestureRecognizer.delegate = self.kh_popGestureRecognizerDelegate
            self.kh_fullscreenPopGestureRecognizer.addTarget(internalTarget, action: internalAction)
            
            interactivePopGes.isEnabled = false
            
        }
    }
    
}

extension UIViewController {
    
    // defult open pop gesture
    var kh_interactivePopDisabled: Bool {
        
        get {
            if let popDisabled = objc_getAssociatedObject(self, RunTimeKey.popDisabledkey) as? NSNumber {
                return popDisabled.boolValue
            }
            return false
        }
        
        set {
            objc_setAssociatedObject(self, RunTimeKey.popDisabledkey, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        
    }
    // defult appear navigationBar
    var kh_prefersNavigationBarHidden: Bool {
        
        get {
            if let barHidden = objc_getAssociatedObject(self, RunTimeKey.barHiddenkey) as? NSNumber {
                return barHidden.boolValue
            }
            return false
        }
        
        set {
            objc_setAssociatedObject(self, RunTimeKey.barHiddenkey, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        
    }
    // defult -1.0 for fullScreen pop
    var kh_interactivePopGesZone: CGFloat {
        
        get {
            if let popGesZone = objc_getAssociatedObject(self, RunTimeKey.popGesZonekey) as? NSNumber {
                return CGFloat(popGesZone.floatValue)
            }
            return -1.0
        }
        
        set {
            objc_setAssociatedObject(self, RunTimeKey.popGesZonekey, NSNumber(value: Float(newValue)), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        
    }
    /// Default to nil is equal to nav color.
    var kh_customNavColor: UIColor? {
        
        get {
            if let color = objc_getAssociatedObject(self, RunTimeKey.colorKey) as? UIColor {
                return color
            }
            return nil
        }
        
        set {
            objc_setAssociatedObject(self, RunTimeKey.colorKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        
    }
    
    var fd_willAppearInjectBlock: KHWillAppearInjectBlock? {
        
        get {
            if let block = objc_getAssociatedObject(self, RunTimeKey.injectBlocKey) as? KHWillAppearInjectBlock {
                return block
            }
            return nil
        }
        
        set {
            objc_setAssociatedObject(self, RunTimeKey.injectBlocKey, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        }
        
    }
    
    
    /// 记得再app启动时初始化一下
    public class func initializeWillAppearMethod(){
        let originalSelector = #selector(UIViewController.viewWillAppear(_:))
        let swizzledSelector = #selector(UINavigationController.kh_viewWillAppear(_:))

        let originalMethod = class_getInstanceMethod(self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)
        method_exchangeImplementations(originalMethod!, swizzledMethod!)
    }

    @objc func kh_viewWillAppear(_ animated: Bool) {
        self.kh_viewWillAppear(animated)
        self.fd_willAppearInjectBlock?(self, animated)
    }
    
}

/// app初始化调用一下，因为swift中不能直接调用load等方法
func setupPopMethodExchange() {
    UINavigationController.initializePushMethod()
    UIViewController.initializeWillAppearMethod()
}
