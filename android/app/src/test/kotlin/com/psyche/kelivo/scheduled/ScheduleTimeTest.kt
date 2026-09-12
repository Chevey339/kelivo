package com.psyche.kelivo.scheduled

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.Instant
import java.time.ZoneId
import java.time.LocalDate

class ScheduleTimeTest {
    private val daily = (1..7).toSet()
    private fun next(hour: Int, minute: Int, now: String, zone: String, days: Set<Int> = daily) =
        Instant.ofEpochMilli(ScheduleTime.next(hour, minute, days, Instant.parse(now).toEpochMilli(), ZoneId.of(zone))!!).toString()

    @Test fun beforeAndAtTimeChooseTheCorrectDay() {
        assertEquals("2026-09-10T00:00:00Z", next(8, 0, "2026-09-09T23:59:00Z", "Asia/Shanghai"))
        assertEquals("2026-09-11T00:00:00Z", next(8, 0, "2026-09-10T00:00:00Z", "Asia/Shanghai"))
    }
    @Test fun weekdaysSkipTheWeekend() {
        assertEquals("2026-09-14T08:00:00Z", next(8, 0, "2026-09-11T08:01:00Z", "UTC", (1..5).toSet()))
    }
    @Test fun springGapMovesForwardAndAutumnOverlapDoesNotRepeat() {
        assertEquals("2026-03-08T10:30:00Z", next(2, 30, "2026-03-08T08:00:00Z", "America/Los_Angeles"))
        assertEquals("2026-11-01T08:30:00Z", next(1, 30, "2026-11-01T07:00:00Z", "America/Los_Angeles"))
        assertEquals("2026-11-02T09:30:00Z", next(1, 30, "2026-11-01T08:45:00Z", "America/Los_Angeles"))
    }
    @Test fun timezoneChangesPreserveLocalClockTime() {
        assertEquals("2026-09-10T15:00:00Z", next(8, 0, "2026-09-10T00:01:00Z", "America/Los_Angeles"))
        assertEquals("2026-09-11T00:00:00Z", next(8, 0, "2026-09-10T00:01:00Z", "Asia/Shanghai"))
    }
    @Test fun invalidSchedulesAreRejected() {
        assertThrows(IllegalArgumentException::class.java) { ScheduleTime.next(24, 0, daily, 0) }
        assertThrows(IllegalArgumentException::class.java) { ScheduleTime.next(8, 60, daily, 0) }
        assertThrows(IllegalArgumentException::class.java) { ScheduleTime.next(8, 0, emptySet(), 0) }
        assertThrows(IllegalArgumentException::class.java) { ScheduleTime.next(8, 0, setOf(0), 0) }
    }
    @Test fun onceHasAnExplicitCalendarDateAndNeverMovesToTomorrow() {
        val date = LocalDate.parse("2026-09-12")
        val due = Instant.parse("2026-09-12T08:00:00Z").toEpochMilli()
        assertEquals(due, ScheduleTime.next(8, 0, daily, due - 1, ZoneId.of("UTC"), onceDate = date))
        assertNull(ScheduleTime.next(8, 0, daily, due, ZoneId.of("UTC"), onceDate = date))
        assertNull(ScheduleTime.next(8, 0, daily, due + 86_400_000, ZoneId.of("UTC"), onceDate = date))
    }
    @Test fun activeDatesIncludeTheirBoundariesAndSkipDisallowedWeekdays() {
        val start = LocalDate.parse("2026-09-12")
        val end = LocalDate.parse("2026-09-14")
        val now = Instant.parse("2026-09-10T10:00:00Z").toEpochMilli()
        val monday = Instant.parse("2026-09-14T08:00:00Z").toEpochMilli()
        assertEquals(monday, ScheduleTime.next(8, 0, (1..5).toSet(), now, ZoneId.of("UTC"), startDate = start, endDate = end))
        assertNull(ScheduleTime.next(8, 0, (1..5).toSet(), monday, ZoneId.of("UTC"), startDate = start, endDate = end))
        assertNull(ScheduleTime.next(8, 0, (1..5).toSet(), now, ZoneId.of("UTC"), startDate = start, endDate = start))
    }
    @Test fun onceStillRespectsDstAndLocalDates() {
        val now = Instant.parse("2026-03-08T08:00:00Z").toEpochMilli()
        assertEquals(Instant.parse("2026-03-08T10:30:00Z").toEpochMilli(),
            ScheduleTime.next(2, 30, daily, now, ZoneId.of("America/Los_Angeles"), onceDate = LocalDate.parse("2026-03-08")))
    }
    @Test fun reversedActiveDatesAreRejected() {
        assertThrows(IllegalArgumentException::class.java) {
            ScheduleTime.next(8, 0, daily, 0, startDate = LocalDate.parse("2026-09-14"), endDate = LocalDate.parse("2026-09-12"))
        }
    }
}
