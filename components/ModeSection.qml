import QtQuick
import qs.Commons
import qs.Ui
import "../Model.js" as Model

// Rule / Global / Direct as one mutually-exclusive row. The switch talks to
// mihomo's running core, so it is only offered while something is running —
// with nothing to switch, a chip that lit up would be describing a mode that
// is not in effect anywhere.
Column {
  id: root

  required property color textColor
  required property string panelFontFamily
  property color accentColor: Color.accent
  property string mode: "rule"
  // Not `enabled`: that is an Item property, and shadowing it would also
  // stop the section receiving input events rather than just greying out.
  property bool switchable: true
  property bool pending: false
  property string hint: ""
  property int cursorIndex: -1
  property var proxyOptions: []
  property string currentProxy: ""
  property bool selectingGlobal: false

  signal modeRequested(string value)
  signal globalRequested()
  signal proxyRequested(string value)
  signal chipHovered(int index, bool isHovered)
  signal subscriptionRequested()

  readonly property var options: Model.MODES.map(function(entry) {
    return { value: entry.value, label: entry.label, tooltip: entry.hint }
  })

  spacing: Style.space(8)

  Item {
    width: parent.width
    implicitHeight: Math.max(sectionHeader.implicitHeight, pendingLabel.implicitHeight)

    PanelSectionHeader {
      id: sectionHeader
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: "PROXY MODE"
      foreground: root.textColor
      fontFamily: root.panelFontFamily
    }

    Text {
      id: pendingLabel
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      visible: root.pending
      text: "switching…"
      color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.55)
      font.family: root.panelFontFamily
      font.pixelSize: Style.font.caption
    }
  }

  Row {
    id: modeControlRow
    width: parent.width
    spacing: Style.space(6)

    Row {
      id: group
      anchors.verticalCenter: parent.verticalCenter
      width: modeControlRow.width - subscriptionButton.width - modeControlRow.spacing
      spacing: Style.space(6)
      opacity: root.switchable ? 1.0 : 0.45
      enabled: root.switchable

      Repeater {
        model: root.options

        delegate: Rectangle {
          id: chip
          required property var modelData
          required property int index
          readonly property bool selected: String(modelData.value) === root.mode
          readonly property bool hot: chipHover.hovered || root.cursorIndex === index

          width: chipLabel.implicitWidth + Style.space(28)
          height: chipLabel.implicitHeight + Style.space(18)
          radius: Style.cornerRadius
          color: selected
            ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, hot ? 0.32 : 0.22)
            : (hot
              ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.12)
              : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.035))
          border.width: selected ? 2 : 1
          border.color: selected
            ? (hot ? Qt.lighter(root.accentColor, 1.22) : root.accentColor)
            : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, hot ? 0.55 : 0.22)

          Behavior on color { ColorAnimation { duration: 90 } }

          Text {
            id: chipLabel
            anchors.centerIn: parent
            text: String(chip.modelData.label)
            color: chip.selected
              ? (chip.hot ? Qt.lighter(root.accentColor, 1.22) : root.accentColor)
              : root.textColor
            font.family: root.panelFontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: chip.selected
          }

          HoverHandler {
            id: chipHover
            onHoveredChanged: root.chipHovered(chip.index, hovered)
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              var value = String(chip.modelData.value)
              if (value === "global") {
                root.selectingGlobal = true
                root.globalRequested()
              } else {
                root.selectingGlobal = false
                root.modeRequested(value)
              }
            }
          }
        }
      }
    }

    PanelActionButton {
      id: subscriptionButton
      anchors.verticalCenter: parent.verticalCenter
      foreground: root.textColor
      hoverColor: root.textColor
      size: Style.space(26)
      tooltipText: "Manage subscription"
      onClicked: root.subscriptionRequested()

      SettingsIcon {
        anchors.centerIn: parent
        iconSize: Style.font.body
        color: subscriptionButton._hot
          ? subscriptionButton.hoverColor
          : subscriptionButton.foreground
      }
    }
  }

  SearchableDropdown {
    width: parent.width
    visible: root.selectingGlobal || root.mode === "global"
    label: "GLOBAL CONNECTION"
    value: root.currentProxy
    options: root.proxyOptions
    placeholderText: root.proxyOptions.length > 0 ? "Choose a connection…" : "No connections available"
    emptyText: "No connections available"
    foreground: root.textColor
    accent: root.accentColor
    fontFamily: root.panelFontFamily
    onChanged: function(value) { root.proxyRequested(value) }
  }

  Text {
    width: parent.width
    visible: root.hint !== ""
    text: root.hint
    color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.55)
    font.family: root.panelFontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }
}
