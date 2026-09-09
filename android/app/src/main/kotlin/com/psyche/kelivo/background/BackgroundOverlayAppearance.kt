package com.psyche.kelivo.background

import kotlin.math.max
import kotlin.math.min

/** Logical-pixel bounds match the Flutter editor. Persisted values are still
 * checked here before they become a WindowManager layout or bitmap size. */
internal data class BackgroundOverlayAppearance(private val values: Map<*, *>) {
    private fun size(key: String, fallback: Float, min: Float, max: Float): Float {
        val value = (values[key] as? Number)?.toFloat() ?: return fallback
        return if (value.isFinite()) value.coerceIn(min, max) else fallback
    }
    val width = size("width", 290f, 48f, 400f)
    val height = size("height", 84f, 48f, 180f)
    val cornerRadius = size("cornerRadius", 24f, 0f, 90f)
    val iconSize = size("iconSize", 34f, 16f, 120f)
    val progressSize = size("progressSize", 42f, 20f, 140f)
    val progressStrokeWidth = size("progressStrokeWidth", 2f, 1f, 12f)
    val showProgress = values["showProgress"] != false
    val showTitle = values["showTitle"] != false
    val showSubtitle = values["showSubtitle"] != false
    val showTime = values["showTime"] != false
    val showClose = values["showClose"] != false
    val showBackground = values["showBackground"] != false
    val showBorder = values["showBorder"] == true
    val hasText = showTitle || showSubtitle || showTime
    val iconOnly = !hasText && !showClose
    val badgeSize = if (showProgress) max(iconSize, progressSize) else iconSize

    fun layout(availableWidth: Float): OverlayGeometry {
        val width = min(width, availableWidth)
        val padding = if (iconOnly) 0f else min(10f, width / 8)
        val innerWidth = width - padding * 2
        val innerHeight = height - padding * 2
        val closeWidth = if (showClose) min(32f, innerWidth * .3f) else 0f
        val gap = if (hasText) min(9f, innerWidth * .08f) else 0f
        val textReserve = if (hasText) min(40f, innerWidth * .3f) else 0f
        val badge = min(badgeSize, min(innerHeight, innerWidth - closeWidth - gap - textReserve))
        val textHeight = (if (showTitle) 16f else 0f) +
            (if (showSubtitle) 28f else 0f) + (if (showTime) 14f else 0f)
        return OverlayGeometry(width, padding, badge, gap, closeWidth,
            if (textHeight > 0) min(1f, innerHeight / textHeight) else 1f)
    }
}

internal data class OverlayGeometry(
    val width: Float, val padding: Float, val badge: Float, val gap: Float,
    val closeWidth: Float, val textScale: Float,
)
