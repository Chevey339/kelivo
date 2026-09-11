package com.psyche.kelivo.scheduled

import java.time.Instant
import java.time.LocalTime
import java.time.ZoneId

/** Wall-clock recurrence. A DST overlap fires once; a gap moves forward. */
object ScheduleTime {
    fun next(hour: Int, minute: Int, weekdays: Set<Int>, after: Long,
             zone: ZoneId = ZoneId.systemDefault()): Long {
        require(hour in 0..23 && minute in 0..59)
        require(weekdays.isNotEmpty() && weekdays.all { it in 1..7 })
        val today = Instant.ofEpochMilli(after).atZone(zone).toLocalDate()
        for (offset in 0L..7L) {
            val date = today.plusDays(offset)
            if (date.dayOfWeek.value !in weekdays) continue
            val candidate = date.atTime(LocalTime.of(hour, minute)).atZone(zone)
                .withEarlierOffsetAtOverlap().toInstant().toEpochMilli()
            if (candidate > after) return candidate
        }
        error("No next occurrence")
    }
}
