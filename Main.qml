import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Dialogs



Window {
    id: appWindow
    width: 640
    height: 540
    visible: true
    title: qsTr("JViewer")
    color: "white"

    property int mouseX: 0
    property int mouseY: 0

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true

        onPositionChanged: (mouse) => {
            appWindow.mouseX = mouse.x
            appWindow.mouseY = mouse.y
        }
    }

    FileDialog {
        id: openDialog
        title: "Open File"
        fileMode: FileDialog.OpenFile



        // Update onAccepted in openDialog:
        onAccepted: {
            var fileUrl = selectedFile
            placeholderText.visible = false
            var content = fileReader.readFile(fileUrl)
            fileText.text = content
            statusText.text = "Opened: " + fileUrl

            // ← new: detect language and highlight
            var ext = fileReader.extensionOf(fileUrl)
            highlighter.setDocument(fileText.textDocument)
            highlighter.setLanguage(ext)   // "cpp", "h", "java" → matched in C++
        }

        // Update onAccepted in saveDialog:
        //onAccepted: {
            //var ok = fileReader.writeFile(selectedFile, fileText.text)
            //statusText.text = ok ? "Saved: " + selectedFile : "Error saving file"
        //}

    }

    FileDialog {
        id: saveDialog
        title: "Save File"
        fileMode: FileDialog.SaveFile

        onAccepted: {
            statusText.text = "Saved: " + selectedFile
        }
    }

    Rectangle {
        id: mainBg
        anchors.fill: parent
        color: "#f8f9fa"
        border.color: "#e9ecef"
        border.width: 1

        Rectangle {
            id: topBar
            width: parent.width
            height: 40
            anchors.top: parent.top
            color: "#ffffff"
            border.color: "#adb5bd"
            border.width: 1

            Row {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 10

                TextField {
                    id: searchField
                    placeholderText: "Search..."
                    width: 150

                    onTextChanged: {
                        if (text.length > 0) {
                            var index = fileText.text.indexOf(text)
                            if (index !== -1) {
                                fileText.select(index, index + text.length)
                                fileText.cursorPosition = index
                            }
                        }
                    }
                }

                TextField {
                    id: gotoLine
                    placeholderText: "Go to line..."
                    width: 120

                    color: "#333333"              // text color
                    placeholderTextColor: "#999999"

                    background: Rectangle {
                        color: "#ffffff"
                        border.color: "#cccccc"
                        radius: 4
                    }

                    onAccepted: {
                        var line = parseInt(text)
                        var lines = fileText.text.split("\n")

                        if (line > 0 && line <= lines.length) {
                            var pos = 0
                            for (var i = 0; i < line - 1; i++)
                                pos += lines[i].length + 1

                            fileText.cursorPosition = pos
                        }
                    }
                }


                Button {
                    text: "Theme"
                    onClicked: {
                        var dark = mainBg.color === "#f8f9fa"

                        mainBg.color = dark ? "#1e1e1e" : "#f8f9fa"
                        contentArea.color = dark ? "#2b2b2b" : "#eeeeee"
                        fileText.color = dark ? "#ffffff" : "#333333"
                        lineNumbers.color = dark ? "#aaaaaa" : "#999999"
                    }
                }
            }
        }

//
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

                            onClicked: {
                                if (modelData === "New File") {
                                    fileText.text = ""
                                    placeholderText.text = "New file created"
                                    placeholderText.visible = true
                                    placeholderText.color = "#333333"
                                    placeholderText.font.italic = false
                                }
                                else if (modelData === "Load File") {
                                    openDialog.open()
                                }
                                else if (modelData === "Save File") {
                                    saveDialog.open()
                                }
                                else if (modelData === "Settings") {
                                    placeholderText.text = "Settings — coming soon"
                                    placeholderText.visible = true
                                    placeholderText.color = "#999999"
                                    placeholderText.font.italic = true
                                }
                                else if (modelData === "Exit") {
                                    Qt.quit()
                                }
                            }
                        }
                    }
                }
            }





            Text {
                id: mousePos
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
                anchors.horizontalCenter: parent.horizontalCenter
                text: appWindow.mouseX + "," + appWindow.mouseY


            }
        }

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
                visible: fileText.text === ""
            }

            ScrollView {
                id: fileScroll
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: statusText.top
                anchors.margins: 8
                visible: fileText.text !== ""

                Row {
                    width: fileScroll.width

                    Text {
                        id: lineNumbers
                        width: 40
                        text: {
                            var count = fileText.text === "" ? 1 : fileText.text.split("\n").length
                            var result = ""
                            for (var i = 1; i <= count; i++)
                                result += i + "\n"
                            return result
                        }

                        font.pixelSize: fileText.font.pixelSize
                        font.family: fileText.font.family
                        lineHeight: 1.2
                        color: "#999999"
                        horizontalAlignment: Text.AlignRight
                        rightPadding: 6
                    }

                    Rectangle {
                        width: 1
                        color: "#dddddd"
                    }

                    TextArea {
                        id: fileText
                        width: fileScroll.width - lineNumbers.width - 1
                        text: ""
                        color: "#333333"
                        font.pixelSize: 12
                        font.family: "Courier New"
                        wrapMode: TextArea.NoWrap
                        background: null
                        readOnly: false
                        leftPadding: 8
                        selectByMouse: true

                        cursorVisible: true
                        focus: true
                        tabStopDistance: 24

                        palette {
                            highlight: "#3399ff"
                            highlightedText: "white"
                        }



                        //  Highlight current line
                        Rectangle {
                            width: parent.width
                            height: fileText.cursorRectangle.height
                            y: fileText.cursorRectangle.y
                            color: "#d0e7ff"
                            z: -1
                        }

                        //  Auto-indent
                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Return) {
                                var cursor = fileText.cursorPosition
                                var before = fileText.text.substring(0, cursor)
                                var lastLine = before.split("\n").pop()

                                var indent = lastLine.match(/^\s*/)[0]
                                fileText.insert(cursor, "\n" + indent)

                                event.accepted = true
                            }
                        }
                    }

                }
            }
            Text {
                id: statusText
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#666666"
                font.pixelSize: 11
                font.italic: true

                text: {
                    var cursor = fileText.cursorPosition
                    var before = fileText.text.substring(0, cursor)
                    var line = before.split("\n").length
                    var col = cursor - before.lastIndexOf("\n")

                    return "Ln " + line + ", Col " + col
                }
            }




            Text {
                id: lineCount
                anchors.bottom: statusText.top
                anchors.horizontalCenter: parent.horizontalCenter
                font.pixelSize: 11
                color: "#888"

                text: "Lines: " + fileText.text.split("\n").length
            }

        }
    }
}
