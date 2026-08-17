import QtQuick
import qs.Commons
import qs.Ui
import "../Model.js" as Model

// The full picture of what the proxy is doing right now: live throughput from
// mihomo's `/traffic` stream, then the facts that only change on an event —
// what systemd thinks, which core is serving, where its API is, which ports
// are open.
//
// Live speeds sit on top as the two large numbers because they are the one
// thing worth glancing at; everything below is reference.
Column {
  id: root

  required property var service
  required property color textColor
  required property string panelFontFamily

  readonly property bool live: service.apiState === "ok" && service.serviceActive

  spacing: Style.space(10)

  PanelSectionHeader {
    text: "CONNECTION"
    foreground: root.textColor
    fontFamily: root.panelFontFamily
  }

  Row {
    id: trafficRow
    width: parent.width
    spacing: Style.space(10)
    opacity: root.live ? 1.0 : 0.45

    Speed {
      width: (trafficRow.width - trafficRow.spacing) / 2
      glyph: "↓"
      label: "DOWNLOAD"
      metricColor: Color.accent
      value: Model.formatSpeed(root.service.downSpeed)
    }

    Speed {
      width: (trafficRow.width - trafficRow.spacing) / 2
      glyph: "↑"
      label: "UPLOAD"
      metricColor: Color.urgent
      value: Model.formatSpeed(root.service.upSpeed)
    }
  }

  Column {
    width: parent.width
    spacing: Style.space(6)

    StatRow {
      width: parent.width
      textColor: root.textColor
      panelFontFamily: root.panelFontFamily
      label: "Connections"
      value: root.live ? String(root.service.connectionCount) : "—"
    }

    StatRow {
      width: parent.width
      textColor: root.textColor
      panelFontFamily: root.panelFontFamily
      label: "Transferred"
      value: root.live
        ? "↓ " + Model.formatBytes(root.service.downloadTotal) + "   ↑ " + Model.formatBytes(root.service.uploadTotal)
        : "—"
    }

    StatRow {
      width: parent.width
      textColor: root.textColor
      panelFontFamily: root.panelFontFamily
      label: "Service"
      value: {
        var probe = root.service.probe
        if (!probe.unitLoaded) return "not installed"
        var autostart = probe.unitFileState === "enabled" ? "enabled" : "not enabled"
        return probe.activeState + " · " + autostart
      }
      valueColor: root.service.probe.activeState === "failed" ? Color.urgent : root.textColor
    }

    StatRow {
      width: parent.width
      textColor: root.textColor
      panelFontFamily: root.panelFontFamily
      label: "Uptime"
      value: root.service.serviceActive && root.service.probe.startedAt > 0
        ? Model.formatDuration(root.service.probe.now - root.service.probe.startedAt)
        : "—"
    }

    StatRow {
      width: parent.width
      textColor: root.textColor
      panelFontFamily: root.panelFontFamily
      label: "Core"
      value: root.service.mihomoVersion !== ""
        ? "mihomo " + root.service.mihomoVersion
        : (root.service.probe.mihomoInstalled ? "installed" : "not installed")
    }

    StatRow {
      width: parent.width
      textColor: root.textColor
      panelFontFamily: root.panelFontFamily
      label: "API"
      value: {
        if (root.service.apiBase === "") return "external-controller unset"
        if (root.service.apiState === "ok") return root.service.apiBase.replace(/^https?:\/\//, "")
        if (root.service.apiState === "unauthorized") return "secret rejected"
        if (!root.service.serviceActive) return "—"
        return "unreachable"
      }
      valueColor: root.service.apiState === "unauthorized" ? Color.urgent : root.textColor
    }

    StatRow {
      width: parent.width
      textColor: root.textColor
      panelFontFamily: root.panelFontFamily
      label: "Ports"
      value: Model.formatPorts(root.service.config, root.service.liveConfigs)
    }

    StatRow {
      width: parent.width
      textColor: root.textColor
      panelFontFamily: root.panelFontFamily
      label: "TUN"
      value: {
        var liveConfig = root.service.liveConfigs
        if (!liveConfig || liveConfig.tunEnabled === null) return "—"
        return liveConfig.tunEnabled ? "enabled" : "disabled"
      }
      valueColor: root.service.liveConfigs && root.service.liveConfigs.tunEnabled === true
        ? Color.accent
        : root.textColor
    }

    StatRow {
      width: parent.width
      textColor: root.textColor
      panelFontFamily: root.panelFontFamily
      label: "LAN access"
      value: {
        var liveConfig = root.service.liveConfigs
        var allowed = liveConfig ? liveConfig.allowLan : root.service.config.allowLan
        return allowed ? "allowed" : "local only"
      }
    }
  }

  component Speed: Item {
    id: speed
    required property string glyph
    required property string label
    required property string value
    required property color metricColor

    implicitHeight: metricContent.implicitHeight + Style.space(20)

    Column {
      id: metricContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(8)
      spacing: Style.space(3)

      Text {
        width: parent.width
        text: speed.glyph + "  " + speed.label
        color: root.textColor
        font.family: root.panelFontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
      }

      Text {
        width: parent.width
        text: speed.value
        color: speed.metricColor
        font.family: root.panelFontFamily
        font.pixelSize: Style.font.title
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
      }
    }
  }
}
