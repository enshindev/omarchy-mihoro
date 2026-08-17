import QtQuick
import qs.Commons
import qs.Ui

// A bolt for the proxy, struck through when it is off — the same on/off idiom
// the shell's other network widgets use, so the bar reads consistently. Drawn
// natively rather than from an SVG because bar slots are ~16px and Qt's SVG
// rasteriser smears strokes at that size.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground
  property color badgeColor: Color.urgent
  property bool crossed: false
  property bool warning: false
  // Rule and Direct share the plain bolt; Global gets a ring around it, so the
  // bar can say "everything is going through the proxy" without a label.
  property bool ringed: false

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  onColorChanged: bolt.requestPaint()
  onRingedChanged: bolt.requestPaint()
  onIconSizeChanged: bolt.requestPaint()

  Canvas {
    id: bolt
    anchors.fill: parent
    antialiasing: true

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var w = width
      var h = height
      if (w <= 0 || h <= 0) return

      var inset = root.ringed ? 0.20 : 0.0
      function px(u) { return (inset + u * (1 - inset * 2)) * w }
      function py(v) { return (inset + v * (1 - inset * 2)) * h }

      ctx.fillStyle = root.color
      ctx.beginPath()
      ctx.moveTo(px(0.58), py(0.03))
      ctx.lineTo(px(0.18), py(0.57))
      ctx.lineTo(px(0.44), py(0.57))
      ctx.lineTo(px(0.40), py(0.97))
      ctx.lineTo(px(0.82), py(0.43))
      ctx.lineTo(px(0.56), py(0.43))
      ctx.closePath()
      ctx.fill()

      if (root.ringed) {
        ctx.strokeStyle = root.color
        ctx.lineWidth = Math.max(1, w * 0.09)
        ctx.beginPath()
        ctx.arc(w / 2, h / 2, (w - ctx.lineWidth) / 2, 0, Math.PI * 2)
        ctx.stroke()
      }
    }
  }

  Rectangle {
    visible: root.crossed
    anchors.centerIn: parent
    width: parent.width * 1.22
    height: Math.max(2, parent.height * 0.14)
    radius: height / 2
    color: root.color
    rotation: -45
  }

  BorderSurface {
    visible: root.warning
    width: Math.max(7, parent.width * 0.42)
    height: width
    radius: width / 2
    color: root.badgeColor
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    borderSpec: Border.flat(Color.popups.background, 1)

    Text {
      anchors.centerIn: parent
      text: "!"
      color: Color.background
      font.family: Style.font.family
      font.pixelSize: Math.max(6, parent.height * 0.72)
      font.bold: true
    }
  }
}
