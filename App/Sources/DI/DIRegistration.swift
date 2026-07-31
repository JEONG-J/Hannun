import Foundation
import HannunData

/// Protocol → 구현체 등록을 모으는 지점. 앱 타깃만이 HannunData 를 알기 때문에
/// 이 파일이 구현체를 아는 유일한 곳이다 (§3).
///
/// TODO: DIContainer 도입 후 register(...) 호출로 채운다 (M2).
enum DIRegistration {
    static func registerAll() {}
}
