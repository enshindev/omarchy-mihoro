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

  signal modeRequested(string value)
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

    ButtonGroup {
      id: group
      anchors.verticalCenter: parent.verticalCenter
      width: modeControlRow.width - subscriptionButton.width - modeControlRow.spacing
      options: root.options
      value: root.mode
      foreground: root.textColor
      accent: root.accentColor
      fontFamily: root.panelFontFamily
      fontSize: Style.font.bodySmall
      // The panel drives the cursor; Tab focus would give the group a second,
      // competing highlight inside a surface that already has one.
      focusable: false
      cursorIndex: root.cursorIndex
      opacity: root.switchable ? 1.0 : 0.45
      enabled: root.switchable
      onChanged: function(value) { if (root.switchable) root.modeRequested(value) }
      onHovered: function(index, isHovered) { root.chipHovered(index, isHovered) }
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
