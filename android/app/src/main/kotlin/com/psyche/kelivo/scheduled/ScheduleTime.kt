package com.psyche.kelivo.scheduled

import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId

/** Wall-clock recurrence. A DST overlap fires once; a gap moves forward. */
object ScheduleTime {
    fun next(hour: Int, minute: Int, weekdays: Set<Int>, after: Long,
             zone: ZoneId = ZoneId.systemDefault(), onceDate: LocalDate? = null,
             startDate: LocalDate? = null, endDate: LocalDate? = null): Long? {
        require(hour in 0..23 && minute in 0..59)
        require(weekdays.isNotEmpty() && weekdays.all { it in 1..7 })
        require(startDate == null || endDate == null || !startDate.isAfter(endDate))
        val today = Instant.ofEpochMilli(after).atZone(zone).toLocalDate()
        fun occurrence(date: LocalDate) = date.atTime(LocalTime.of(hour, minute)).atZone(zone)
            .withEarlierOffsetAtOverlap().toInstant().toEpochMilli()
        if (onceDate != null) {
            if (startDate != null && onceDate.isBefore(startDate) ||
                endDate != null && onceDate.isAfter(endDate)) return null
            return occurrence(onceDate).takeIf { it > after }
        }
        val firstDate = if (startDate != null && startDate.isAfter(today)) startDate else today
        for (offset in 0L..7L) {
            val date = firstDate.plusDays(offset)
            if (endDate != null && date.isAfter(endDate)) return null
            if (date.dayOfWeek.value !in weekdays) continue
            val candidate = occurrence(date)
            if (candidate > after) return candidate
        }
        error("No next occurrence")
    }
}
