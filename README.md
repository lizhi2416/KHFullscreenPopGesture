# KHFullscreenPopGesture
swift版全屏手势返回，新增返回手势作用区域设置功能

1.直接下载把KHFullScreenPop.swift拖入工程。
2.在app启动式调用setupPopMethodExchange()方法进行相关runtime方法交换操作（因为swift中无法调用load等方法）
3.涉及到多手势处理时根据KHPanGestureRecognizer类来判断处理即可，手势代理就那么几个方法。
eg:pop手势与UIScrollView共存问题，在自定义的UIScrollView类中实现一下手势相关代理方法即可

func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    if otherGestureRecognizer is KHPanGestureRecognizer {
        return true
    }
    return false
}

4.通过设置kh_interactivePopGesZone属性自定义每个控制器的pop手势返回作用区域，小于0时为全屏返回。
5.后续还将加上自定义每个控制器对应导航栏bar颜色功能（kh_customNavColor）详情请关注后续。。。

