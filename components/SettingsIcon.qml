import QtQuick
import qs.Commons

// A small monochrome gear for compact panel actions. Drawing it here avoids
// the platform-dependent colour emoji used for the Unicode gear character.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  onColorChanged: gear.requestPaint()
  onIconSizeChanged: gear.requestPaint()

  Canvas {
    id: gear
    anchors.fill: parent
    antialiasing: true

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var size = Math.min(width, height)
      if (size <= 0) return

      var cx = width / 2
      var cy = height / 2
      var outer = size * 0.43
      var body = size * 0.31
      var hole = size * 0.12
      var stroke = Math.max(1.25, size * 0.11)

      ctx.strokeStyle = root.color
      ctx.lineWidth = stroke
      ctx.lineCap = "round"

      for (var i = 0; i < 8; ++i) {
        var angle = i * Math.PI / 4
        ctx.beginPath()
        ctx.moveTo(cx + Math.cos(angle) * body, cy + Math.sin(angle) * body)
        ctx.lineTo(cx + Math.cos(angle) * outer, cy + Math.sin(angle) * outer)
        ctx.stroke()
      }

      ctx.beginPath()
      ctx.arc(cx, cy, body, 0, Math.PI * 2)
      ctx.stroke()

      ctx.beginPath()
      ctx.arc(cx, cy, hole, 0, Math.PI * 2)
      ctx.stroke()
    }
  }
}
