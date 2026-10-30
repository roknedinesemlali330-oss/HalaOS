// Window buttons: a small pill above the active window with its title and
// three buttons (float/tile, maximize, close).
// Runs as its own Quickshell instance, so a bug here can never break the desktop.
// Works on Hyprland (it reads the window position with "hyprctl activewindow").

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

ShellRoot {
    id: app

    property bool dark: false
    property color accent: "#4C7BDE"
    property bool wanted: true
    property bool showBar: false
    property int wx: 0
    property int wy: 0
    property int ww: 0
    property string winTitle: ""

    // ----- theme and on/off switch from the settings file -----
    function applyCfg(text) {
        try {
            var s = JSON.parse(text)
            if (s.dark !== undefined) dark = s.dark
            if (s.accent) accent = s.accent
            if (s.titlebar !== undefined) wanted = s.titlebar
        } catch (e) { }
    }
    FileView {
        id: cfg
        path: Quickshell.env("HOME") + "/.config/myos/settings.json"
        onLoaded: app.applyCfg(cfg.text())
    }
    Timer { interval: 2000; running: true; repeat: true; onTriggered: cfg.reload() }

    // ----- where is the active window? -----
    function parse(text) {
        var o
        try { o = JSON.parse(text) } catch (e) { showBar = false; return }
        if (!o || !o.at || !o.size || o.fullscreen === 2 || o.size[0] < 160) { showBar = false; return }
        wx = o.at[0]
        wy = o.at[1]
        ww = o.size[0]
        winTitle = o.title || o.class || ""
        showBar = wanted
    }
    Process {
        id: aw
        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector { onStreamFinished: app.parse(text) }
    }
    Timer {
        interval: 150; running: true; repeat: true
        onTriggered: { if (!aw.running) aw.running = true }
    }

    PanelWindow {
        id: bar
        visible: app.showBar
        anchors { top: true; left: true }
        margins {
            left: Math.max(4, app.wx + app.ww - 204)
            top: Math.max(4, app.wy - 34)
        }
        implicitWidth: 204
        implicitHeight: 28
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: app.dark ? "#2A2F40" : "#F4F6FB"
            border.width: 1
            border.color: Qt.alpha(app.accent, 0.55)

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 104
                elide: Text.ElideRight
                text: app.winTitle
                font.pixelSize: 12
                color: app.dark ? "#EEF0F6" : "#1F2433"
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Repeater {
                    model: [
                        { c: "#F0B84A", act: "float" },
                        { c: "#5BBF7A", act: "max" },
                        { c: "#E86B6B", act: "close" }
                    ]
                    delegate: Rectangle {
                        id: b
                        required property var modelData
                        width: 16; height: 16; radius: 8
                        color: modelData.c
                        scale: ma.containsMouse ? 1.25 : 1.0
                        Behavior on scale { NumberAnimation { duration: 90 } }
                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (b.modelData.act === "close") Quickshell.execDetached(["hyprctl", "dispatch", "killactive"])
                                else if (b.modelData.act === "max") Quickshell.execDetached(["hyprctl", "dispatch", "fullscreen", "1"])
                                else Quickshell.execDetached(["hyprctl", "dispatch", "togglefloating"])
                            }
                        }
                    }
                }
            }
        }
    }
}
