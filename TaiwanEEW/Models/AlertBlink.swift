//
//  AlertBlink.swift
//  TaiwanEEW
//
//  One phase for everything on the alert screen that blinks.
//
//  Four things flash during an event — the status bar, 已抵達 in the compact card, the
//  special-case banner and the epicenter marker on the map — and they were each keeping
//  their own time. The status bar locked to the arrival time, the other two to the wall
//  clock, and the epicenter to whenever its CAAnimation happened to start. Any two of
//  them could therefore be in opposite states at the same instant, which reads as a
//  broken screen rather than an urgent one.
//
//  The phase comes from the time to arrival, so it is the same quantity the countdown
//  displays. That is what makes them agree: a new report moves the arrival time and every
//  blinker follows it in the same step, and the lit half begins exactly as the seconds
//  number changes.
//

import Foundation

enum AlertBlink {
    /// One full cycle a second.
    static let period: TimeInterval = 1
    /// Sampling interval for the timers that drive it — fine enough that an edge lands
    /// within a frame or two of the number changing.
    static let tick: TimeInterval = 0.05

    /// Lit for the first half of each second, dim for the second.
    ///
    /// `remaining` counts down, so its fractional part wraps from 0 up to 1 at each tick:
    /// just before the number changes the phase is near 0 (dim), just after it is near 1
    /// (lit). Everything is therefore bright at the moment the count changes, never dark.
    ///
    /// The absolute value keeps it running after the wave lands, which is when 已抵達 and
    /// the epicenter are still flashing and the countdown has stopped.
    static func isLit(arrivalTime: Date, now: Date = Date()) -> Bool {
        phase(arrivalTime: arrivalTime, now: now) > period / 2
    }

    /// Seconds into the current cycle counted from the lit edge, for CoreAnimation, which
    /// needs an offset rather than a boolean. Feeding this to beginTime puts a repeating
    /// animation at the same point in its cycle that isLit reports.
    static func cycleOffset(arrivalTime: Date, now: Date = Date()) -> TimeInterval {
        period - phase(arrivalTime: arrivalTime, now: now)
    }

    /// Which of two alternating messages to show, flipping every `blinks` cycles. Derived
    /// from the same countdown, so the text changes on a tick like everything else rather
    /// than on its own free-running timer.
    static func showsAlternate(arrivalTime: Date, everyBlinks blinks: Int,
                               now: Date = Date()) -> Bool {
        let cycles = Int(abs(arrivalTime.timeIntervalSince(now)) / period)
        return (cycles / max(blinks, 1)) % 2 == 1
    }

    private static func phase(arrivalTime: Date, now: Date) -> TimeInterval {
        abs(arrivalTime.timeIntervalSince(now)).truncatingRemainder(dividingBy: period)
    }
}
