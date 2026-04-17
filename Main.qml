import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Dialogs

Window {
    width: 640
    height: 540
    visible: true
    title: qsTr("JViewer")
    color: "white"

    FileDialog {
        id: openDialog
        title: "Open File"
        fileMode: FileDialog.OpenFile
        onAccepted: {
            placeholderText.visible = false
            statusText.text = "Opened: " + openDialog.selectedFile

            var xhr = new XMLHttpRequest()
            xhr.open("GET", openDialog.selectedFile, false)
            xhr.send()
            fileText.text = xhr.responseText
        }
    }

    FileDialog {
        id: saveDialog
        title: "Save File"
        fileMode: FileDialog.SaveFile
        onAccepted: {
            statusText.text = "Saved: " + saveDialog.selectedFile
        }
    }

    // MAIN
    Rectangle {
        id: mainBg
        anchors.fill: parent
        color: "#f8f9fa"
        border.color: "#e9ecef"
        border.width: 1

        // TOPBAR
        Rectangle {
            id: topBar
            width: parent.width
            height: 40
            anchors.top: parent.top
            color: "#ffffff"
            border.color: "#adb5bd"
            border.width: 1
        }

        // SIDEBAR
        Rectangle {
            id: sideBar
            width: 160
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            color: "#ffffff"
            border.color: "#adb5bd"
            border.width: 1
            z: 1

            // HEADER
            Rectangle {
                id: header
                width: parent.width
                height: 40
                color: "#eeeeee"
                border.color: "#adb5bd"
                border.width: 1
                Text {
                    text: "JViewer"
                    anchors.centerIn: parent
                    color: "#333"
                    font.pixelSize: 15
                    font.bold: true
                }
            }

            // MENU AREA
            Item {
                anchors.top: header.bottom
                anchors.bottom: parent.bottom
                width: parent.width

                property var menuItems: ["New File", "Load File", "Save File", "Settings", "Exit"]

                Column {
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10

                    Repeater {
                        model: parent.parent.menuItems
                        Button {
                            text: modelData
                            width: 140
                            palette.buttonText: "#333333"
                            onClicked: {
                                if (modelData === "New File") {
                                    placeholderText.text = "New file created"
                                    placeholderText.visible = true
                                    placeholderText.color = "#333333"
                                    placeholderText.font.italic = false
                                } else if (modelData === "Load File") {
                                    openDialog.open()
                                } else if (modelData === "Save File") {
                                    saveDialog.open()
                                } else if (modelData === "Settings") {
                                    placeholderText.text = "Settings — coming soon"
                                    placeholderText.visible = true
                                    placeholderText.color = "#999999"
                                    placeholderText.font.italic = true
                                } else if (modelData === "Exit") {
                                    Qt.quit()
                                }
                            }
                        }
                    }
                }
            }
        }

        // TEXT BLOC
        Rectangle {
            id: contentArea
            anchors.left: sideBar.right
            anchors.right: parent.right
            anchors.top: topBar.bottom
            anchors.bottom: parent.bottom
            anchors.margins: 12
            color: "#eeeeee"
            radius: 4
            border.color: "#adb5bd"
            border.width: 1

            // PLACEHOLDER TEXT
            Text {
                id: placeholderText
                text: "Choose a file to get started or create something new"
                anchors.centerIn: parent
                color: "#999999"
                font.pixelSize: 14
                font.italic: true
                width: parent.width * 0.8
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: true
            }

            // STATUS TEXT
            Text {
                id: statusText
                text: ""
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#666666"
                font.pixelSize: 11
                font.italic: true
            }

            // FILE TEXT {
            Text {
                id: fileText
                text: ""
                anchors.top: parent.top
                anchors.topMargin: 8
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#666666"
                font.pixelSize: 11
            }
        }

    }
}