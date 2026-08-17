import QtQuick
import qs.Commons
import qs.Ui
import "../Model.js" as Model

// URL subscriptions, which is the only kind mihoro has: `remote_config_url` in
// mihoro.toml, fetched by `mihoro update --config`. Setting a URL and fetching
// it are one action here — a saved URL that nothing has downloaded would show a
// subscription the proxy is not actually using.
//
// The URL is masked by default. It is a bearer credential: whoever has it has
// the subscription, and a bar panel is read over shoulders.
Column {
  id: root

  required property var service
  required property color textColor
  required property string panelFontFamily
  property bool revealed: false
  property bool editing: false
  property string cursorTarget: ""

  signal urlCommitted(string url)
  signal updateRequested()

  readonly property string url: service.config.remoteConfigUrl
  readonly property bool updating: service.actionKind === "update" || service.actionKind === "init"

  spacing: Style.space(8)

  function beginEdit() {
    field.text = root.url
    root.editing = true
    Qt.callLater(function() { field.forceActiveFocus(); field.selectAll() })
  }

  function cancelEdit() {
    root.editing = false
  }

  function commit() {
    if (Model.subscriptionUrlError(field.text) !== "") return
    root.editing = false
    root.urlCommitted(field.text.trim())
  }

  Item {
    width: parent.width
    implicitHeight: Math.max(sectionHeader.implicitHeight, updatedLabel.implicitHeight)

    PanelSectionHeader {
      id: sectionHeader
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: "SUBSCRIPTION"
      foreground: root.textColor
      fontFamily: root.panelFontFamily
    }

    Text {
      id: updatedLabel
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      visible: root.service.probe.configPresent
      text: "updated " + Model.formatAgo(root.service.probe.configMtime, root.service.probe.now)
      color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.55)
      font.family: root.panelFontFamily
      font.pixelSize: Style.font.caption
    }
  }

  // ---- read-only view
  CursorSurface {
    visible: !root.editing
    width: parent.width
    implicitHeight: urlText.implicitHeight + Style.spacing.rowPaddingX
    foreground: root.textColor
    hasCursor: root.cursorTarget === "url"

    Text {
      id: urlText
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      text: Model.displayUrl(root.url, root.revealed)
      color: root.url === ""
        ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.55)
        : root.textColor
      font.family: root.panelFontFamily
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WrapAnywhere
      maximumLineCount: 2
      elide: Text.ElideRight
    }

    TapHandler { onTapped: root.beginEdit() }
  }

  Row {
    visible: !root.editing
    width: parent.width
    spacing: Style.spacing.controlGap

    Button {
      text: root.updating ? "Fetching…" : "Update now"
      foreground: root.textColor
      bordered: true
      enabled: root.url !== "" && !root.service.busy
      hasCursor: root.cursorTarget === "update"
      fontSize: Style.font.bodySmall
      onClicked: root.updateRequested()
    }

    Button {
      text: root.url === "" ? "Add URL" : "Change URL"
      foreground: root.textColor
      bordered: true
      enabled: !root.service.busy
      fontSize: Style.font.bodySmall
      onClicked: root.beginEdit()
    }

    Button {
      visible: root.url !== ""
      text: root.revealed ? "Hide" : "Show"
      foreground: root.textColor
      bordered: false
      fontSize: Style.font.bodySmall
      onClicked: root.revealed = !root.revealed
    }
  }

  // ---- editor
  Column {
    visible: root.editing
    width: parent.width
    spacing: Style.space(8)

    TextField {
      id: field
      width: parent.width
      foreground: root.textColor
      placeholderText: "https://example.com/subscription"
      onAccepted: root.commit()
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          root.cancelEdit()
          event.accepted = true
        }
      }
    }

    Text {
      width: parent.width
      visible: field.text.trim() !== "" && Model.subscriptionUrlError(field.text) !== ""
      text: Model.subscriptionUrlError(field.text)
      color: Color.urgent
      font.family: root.panelFontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    Row {
      spacing: Style.spacing.controlGap

      Button {
        text: root.service.probe.configPresent ? "Save and fetch" : "Save and set up"
        foreground: root.textColor
        bordered: true
        enabled: Model.subscriptionUrlError(field.text) === "" && !root.service.busy
        fontSize: Style.font.bodySmall
        onClicked: root.commit()
      }

      Button {
        text: "Cancel"
        foreground: root.textColor
        bordered: false
        fontSize: Style.font.bodySmall
        onClicked: root.cancelEdit()
      }
    }
  }
}
