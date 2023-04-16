import Foundation
import ARKit

extension ARCamera.TrackingState {
	var presentationString: String {
		switch self {
        case .notAvailable:
            return "Tracking Unavailable"
        case .normal:
            return "Tracking Normal"
        case .limited(let reason):
            switch reason {
            case .excessiveMotion:
                return "Tracking Limited\nToo much camera movement"
            case .insufficientFeatures:
                return "Tracking Limited\nNot enough surface detail"
            case .initializing:
                return "Initializing AR Scene"
            case .relocalizing:
                return "Initializing AR Scene"
            @unknown default:
                return ""
            }
        }
	}
}
