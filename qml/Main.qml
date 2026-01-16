import QtQuick 2.15
import QtQuick.Controls 2.15

ApplicationWindow {
    width: 420
    height: 300
    visible: true
    title: qsTr("Breakpad Demo")

    Column {
        anchors.centerIn: parent
        spacing: 12

        Button {
            text: "制造崩溃 (SIGSEGV)"
            onClicked: CrashBridge.crashNow()
        }

        Button {
            text: "主动生成 dump"
            onClicked: {
                var ok = CrashBridge.writeDump()
                console.log("writeDump result:", ok)
            }
        }

        Text {
            width: 360
            wrapMode: Text.WordWrap
            text: "Dump 将写入应用可写目录 (AppDataLocation/dumps)。崩溃后使用 minidump_stackwalk + 符号解析。"
        }
    }
}

