import Foundation
import CoreGraphics
import SwiftUI

// MARK: - Eye shape vocabulary (moved from BotEngine.swift — shared renderer vocabulary,
// also consumed by IslandTypes.swift's `miniEye`)

enum EyeShape: String {
    case pill, wide, dot, line, flat, happy, closed, spiral, heart, star, tired, wink, cup
}

// MARK: - Lexy tunable constants (renamed from MochiConst, same values)

enum LexyConst {
    static let eyeH: CGFloat  = 0.27
    static let eyeSp: CGFloat = 0.37
    static let eyeP: CGFloat  = -0.12
    static let baseTop    = CGColor(red: 0.929, green: 0.929, blue: 0.937, alpha: 1)  // #EDEDEF
    static let baseBottom = CGColor(red: 0.769, green: 0.773, blue: 0.792, alpha: 1)  // #C4C5CA
    static let ink        = CGColor(red: 0.102, green: 0.082, blue: 0.071, alpha: 1)  // #1A1412
    static let miniInk    = CGColor(red: 0.063, green: 0.075, blue: 0.102, alpha: 1)  // #10131A
    // Lexy's signature accessory: a small dark navy bowtie, the one "lawyer but cute" cue.
    static let bowtieColor = CGColor(red: 0.11, green: 0.12, blue: 0.16, alpha: 1)
}

// MARK: - LexyFrame: the one snapshot type every call site builds and LexyGeometry consumes.
// No function below reaches back into BotEngine, GreetPose, or USFrame — everything it needs
// to draw one frame is in this struct.

struct LexyFrame {
    var rx: CGFloat               // body half-width (world units, already scaled by caller)
    var ry: CGFloat               // body half-height
    var morph: CGFloat            // 0 = round dot-cluster face, 1 = compact box (upload mode)
    var eye: EyeShape
    var eyeOpen: CGFloat          // 0 = fully closed (blink), 1 = fully open
    var lookX: CGFloat            // -1...1, eye-cluster offset (pupil/gaze direction)
    var lookY: CGFloat
    var yaw: CGFloat = 0          // head-turn animation (cursor tracking, scan sweep, wander)
    var pitch: CGFloat = 0        // head-tilt animation
    var roll: CGFloat = 0         // roll-through animation (dizzy spin)
    var es: CGFloat = 1           // eye-scale tween (emotes)
    var isMini: Bool = false      // mini pill bot — uses LexyConst.miniInk instead of .ink
    var tint: CGFloat             // 0...1 color wash strength (state color, e.g. "thinking" purple)
    var tintColor: CGColor?       // nil = no tint
    var bodyColor: CGColor?       // nil = default LexyConst.baseTop/baseBottom gradient
    var blush: CGFloat            // 0...1
    var showBowtie: Bool          // hidden while morphing into box mode, like the body's extras
    var handsAmount: CGFloat      // 0...1, how present the hands are (0 = none drawn)
}

// MARK: - Dot-cluster face geometry

/// The face silhouette is a loose ring of overlapping dots whose union reads as one rounded
/// face, interpolated (via `morph`) toward a tighter rectangular dot grid for "box mode"
/// (the upload/mailbox animation). Returns one CGPath that is the union of all face dots —
/// used both to fill the body and to clip the eyes/bowtie to the face.
func lexyFacePath(rx: CGFloat, ry: CGFloat, morph: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let dotRadius = min(rx, ry) * 0.30
    let roundPositions = lexyRingDotPositions(rx: rx * 0.78, ry: ry * 0.78, count: 15)
    let boxPositions = lexyGridDotPositions(rx: rx * 0.86, ry: ry * 0.86, cols: 5, rows: 3)
    let count = min(roundPositions.count, boxPositions.count)
    for i in 0..<count {
        let p0 = roundPositions[i % roundPositions.count]
        let p1 = boxPositions[i % boxPositions.count]
        let x = lerp(p0.x, p1.x, morph)
        let y = lerp(p0.y, p1.y, morph)
        let r = dotRadius * lerp(1.0, 0.82, morph)
        path.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }
    return path
}

private func lexyRingDotPositions(rx: CGFloat, ry: CGFloat, count: Int) -> [CGPoint] {
    (0..<count).map { i in
        let a = (CGFloat(i) / CGFloat(count)) * .pi * 2
        return CGPoint(x: cos(a) * rx, y: sin(a) * ry)
    }
}

private func lexyGridDotPositions(rx: CGFloat, ry: CGFloat, cols: Int, rows: Int) -> [CGPoint] {
    var points: [CGPoint] = []
    for row in 0..<rows {
        for col in 0..<cols {
            let fx = cols == 1 ? 0 : CGFloat(col) / CGFloat(cols - 1) * 2 - 1
            let fy = rows == 1 ? 0 : CGFloat(row) / CGFloat(rows - 1) * 2 - 1
            points.append(CGPoint(x: fx * rx, y: fy * ry))
        }
    }
    return points
}

// MARK: - Eyes: each EyeShape maps to a small dot arrangement, not a single pupil

private func lexyEyeDotOffsets(for shape: EyeShape) -> [CGPoint] {
    switch shape {
    case .pill, .wide, .flat:
        return [CGPoint(x: -0.05, y: 0), CGPoint(x: 0.05, y: 0)]   // two dots, side by side
    case .dot, .line, .closed, .tired:
        return [CGPoint(x: 0, y: 0)]                                // single dot
    case .happy, .wink:
        return [CGPoint(x: -0.04, y: -0.02), CGPoint(x: 0.04, y: -0.02)]
    case .spiral, .star, .heart:
        return [CGPoint(x: -0.05, y: 0), CGPoint(x: 0, y: -0.04), CGPoint(x: 0.05, y: 0)]
    case .cup:
        return [CGPoint(x: -0.05, y: 0.03), CGPoint(x: 0.05, y: 0.03)]
    }
}

/// Draws one eye-dot-cluster centered at `center`, clipped to the face path by the caller.
private func drawLexyEyeCluster(cg: CGContext, frame: LexyFrame, rx: CGFloat, ry: CGFloat, center: CGPoint) {
    let eyeDotR = min(rx, ry) * LexyConst.eyeH * 0.22 * max(0.15, frame.eyeOpen) * frame.es
    let ink = frame.isMini ? LexyConst.miniInk : LexyConst.ink
    for offset in lexyEyeDotOffsets(for: frame.eye) {
        let x = center.x + offset.x * rx
        let y = center.y + offset.y * ry
        cg.setFillColor(ink)
        cg.fillEllipse(in: CGRect(x: x - eyeDotR, y: y - eyeDotR, width: eyeDotR * 2, height: eyeDotR * 2))
    }
}

/// Draws both eye-dot-clusters, clipped to the face path, offset by lookX/lookY and by the
/// yaw/pitch/roll head-motion animation (cursor tracking, scan sweep, dizzy spin, mini wander).
func drawLexyEyes(cg: CGContext, frame: LexyFrame, rx: CGFloat, ry: CGFloat) {
    let sp = ry * LexyConst.eyeSp
    let baseY = ry * LexyConst.eyeP + frame.lookY * ry * 0.18 + sin(frame.pitch + frame.roll) * ry * 0.25
    let lookOffsetX = frame.lookX * rx * 0.12 + sin(frame.yaw) * rx * 0.25

    for side: CGFloat in [-1, 1] {
        let centerX = side * sp + lookOffsetX
        drawLexyEyeCluster(cg: cg, frame: frame, rx: rx, ry: ry, center: CGPoint(x: centerX, y: baseY))
    }
}

/// Lexy's signature bowtie: two small triangular dots either side of a center dot, drawn
/// beneath the face. Hidden while morphing into box mode, same as the rest of the "extras."
private func drawLexyBowtie(cg: CGContext, frame: LexyFrame, rx: CGFloat, ry: CGFloat) {
    guard frame.showBowtie, frame.morph < 0.5 else { return }
    let alpha = 1 - frame.morph * 2
    let bowY = ry * 0.62
    let wingR = min(rx, ry) * 0.10
    let centerR = wingR * 0.55

    cg.saveGState()
    cg.setAlpha(alpha)
    cg.setFillColor(LexyConst.bowtieColor)
    cg.fillEllipse(in: CGRect(x: -wingR * 1.6 - wingR, y: bowY - wingR, width: wingR * 2, height: wingR * 2))
    cg.fillEllipse(in: CGRect(x: wingR * 1.6 - wingR, y: bowY - wingR, width: wingR * 2, height: wingR * 2))
    cg.fillEllipse(in: CGRect(x: -centerR, y: bowY - centerR, width: centerR * 2, height: centerR * 2))
    cg.restoreGState()
}

// MARK: - Public entry point

/// Draws one frame of Lexy: body (dot cluster), tint wash, eyes, bowtie. Callers are
/// responsible for translating/rotating/scaling `cg` to the character's world position before
/// calling this — this function draws entirely in body-centered local coordinates, matching
/// how the original BotEngine.mochiPath/GreetingCanvasView.mochiPath callers already work.
func drawLexyFace(cg: CGContext, frame: LexyFrame) {
    let facePath = lexyFacePath(rx: frame.rx, ry: frame.ry, morph: frame.morph)

    cg.saveGState()
    cg.addPath(facePath)
    cg.clip()

    let topColor = frame.bodyColor ?? LexyConst.baseTop
    let bottomColor = frame.bodyColor != nil ? mixDarker(frame.bodyColor!) : LexyConst.baseBottom
    if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [topColor, bottomColor] as CFArray,
                                  locations: [0, 1]) {
        cg.drawLinearGradient(gradient,
                               start: CGPoint(x: 0, y: -frame.ry),
                               end: CGPoint(x: 0, y: frame.ry),
                               options: [])
    }

    if frame.tint > 0, let tintColor = frame.tintColor {
        cg.setFillColor(tintColor.copy(alpha: frame.tint) ?? tintColor)
        cg.addPath(facePath)
        cg.fillPath()
    }

    if frame.blush > 0.01 {
        cg.setFillColor(CGColor(red: 1, green: 0.55, blue: 0.55, alpha: Double(frame.blush) * 0.35))
        let blushR = frame.rx * 0.12
        for side: CGFloat in [-1, 1] {
            let x = side * frame.rx * 0.55
            let y = frame.ry * 0.25
            cg.fillEllipse(in: CGRect(x: x - blushR, y: y - blushR, width: blushR * 2, height: blushR * 2))
        }
    }
    cg.restoreGState()

    drawLexyEyes(cg: cg, frame: frame, rx: frame.rx, ry: frame.ry)
    drawLexyBowtie(cg: cg, frame: frame, rx: frame.rx, ry: frame.ry)
}

private func mixDarker(_ color: CGColor) -> CGColor {
    let t = cgColorToTuple(color)
    let darker = mix3(t, (0, 0, 0), 0.18)
    return CGColor(red: darker.0, green: darker.1, blue: darker.2, alpha: 1)
}

// MARK: - Hands (dot-cluster form, replaces BotEngine's ellipse hands and
// GreetingCanvasView's drawHandL/drawHandR)

/// Draws one hand at `center`, already positioned/clipped by the caller.
private func drawLexyHandAt(cg: CGContext, frame: LexyFrame, rx: CGFloat, ry: CGFloat, center: CGPoint) {
    guard frame.handsAmount > 0.01 else { return }
    let handR = min(rx, ry) * 0.16 * frame.handsAmount
    cg.setFillColor((frame.bodyColor ?? LexyConst.baseTop))
    cg.fillEllipse(in: CGRect(x: center.x - handR, y: center.y - handR, width: handR * 2, height: handR * 2))
    cg.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.08))
    cg.setLineWidth(1)
    cg.strokeEllipse(in: CGRect(x: center.x - handR, y: center.y - handR, width: handR * 2, height: handR * 2))
}

/// Draws one hand at the origin — for callers (like BotEngine's drawHandsBehind) that compute
/// each hand's own world position themselves and translate `cg` there before calling this.
func drawLexyHand(cg: CGContext, frame: LexyFrame, rx: CGFloat, ry: CGFloat) {
    drawLexyHandAt(cg: cg, frame: frame, rx: rx, ry: ry, center: .zero)
}

/// Draws both hands, mirrored left/right — for callers (like GreetingCanvasView) that pass one
/// shared body frame and let this function place both hands relative to the body.
func drawLexyHands(cg: CGContext, frame: LexyFrame, rx: CGFloat, ry: CGFloat) {
    for side: CGFloat in [-1, 1] {
        drawLexyHandAt(cg: cg, frame: frame, rx: rx, ry: ry, center: CGPoint(x: side * rx * 1.08, y: ry * 0.70))
    }
}

/// Narrow entry point for callers (like the upload sequence) that draw their own body, have
/// already translated `cg` to one eye's position, and only need a single eye-dot cluster drawn
/// at the origin — unlike `drawLexyEyes`, this draws exactly one cluster, not a left/right pair.
func drawLexyEyeDotsOnly(cg: CGContext, frame: LexyFrame, rx: CGFloat, ry: CGFloat) {
    drawLexyEyeCluster(cg: cg, frame: frame, rx: rx, ry: ry, center: .zero)
}
