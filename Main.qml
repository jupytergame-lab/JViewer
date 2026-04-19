import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Dialogs



Window {
    id: appWindow
    width: 840
    height: 640
    visible: true
    title: qsTr("JViewer")
    color: "white"

    property int mouseX: 0
    property int mouseY: 0

    property string viewMode: "editor" // or settings, preferences etc

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


        onAccepted: {
            var fileUrl = selectedFile
            placeholderText.visible = false
            var content = fileReader.readFile(fileUrl)
            fileText.text = content
            statusText.text = "Opened: " + fileUrl

            var ext = fileReader.extensionOf(fileUrl)
            highlighter.setDocument(fileText.textDocument)
            highlighter.setLanguage(ext)

            // track recent files
            var name = fileUrl.toString().split("/").pop()
            var rf = fileDrop.recentFiles.filter(f => f !== name)
            rf.unshift(name)
            fileDrop.recentFiles = rf.slice(0, 3)
            var base = ["New", "Open", "Save", "──────────", fileDrop.autoSave ? "Auto-Save: ON" : "Auto-Save: OFF"]
            fileDrop.items = base.concat(["──────────"]).concat(fileDrop.recentFiles)
        }
    }

    FileDialog {
        id: saveDialog
        title: "Save File"
        fileMode: FileDialog.SaveFile

        onAccepted: {
            statusText.text = "Saved: " + selectedFile
        }
    }

    // ── Reusable dropdown button ─────────────────────────────────────────────
    component DropButton: Item {
        id: dropRoot
        width: btn.width
        height: btn.height

        property string label: "Menu"
        property var items: []
        signal itemSelected(string name)

        Button {
            id: btn
            text: dropRoot.label + " ▾"
            onClicked: popup.open()
        }

        Popup {
            id: popup
            y: btn.height + 4
            padding: 0
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

            background: Rectangle {
                color: "#ffffff"
                border.color: "#9aa0a6"
                border.width: 1
                radius: 6
            }

            Column {
                width: 200
                spacing: 2
                padding: 4

                Repeater {
                    model: dropRoot.items

                    delegate: Item {
                        width: parent.width
                        height: modelData === "---" ? 8 : 30

                        // ── separator line ─────────────────────
                        Rectangle {
                            visible: modelData === "---"
                            width: parent.width
                            height: 1
                            color: "#e0e0e0"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // ── real item ──────────────────────────
                        Rectangle {
                            visible: modelData !== "---"
                            anchors.fill: parent
                            radius: 4
                            color: mouse.containsMouse ? "#e8f0fe" : "#ffffff"
                            border.color: "#d0d0d0"
                            border.width: 1

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                text: modelData
                                color: "#333333"
                                font.pixelSize: 12
                            }

                            MouseArea {
                                id: mouse
                                anchors.fill: parent
                                hoverEnabled: true

                                onClicked: {
                                    popup.close()
                                    dropRoot.itemSelected(modelData)
                                }
                            }
                        }
                    }
                }
            }
        }

    }
    // ────────────────────────────────────────────────────────────────────────

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
                anchors.verticalCenter: parent.verticalCenter
                x: contentArea.x + (contentArea.width - width) / 2
                spacing: 6

                TextField {
                    id: searchField
                    placeholderText: "Search..."
                    color: "#333333"
                    placeholderTextColor: "#999999"
                    width: 130

                    background: Rectangle {
                        color: "#ffffff"
                        border.color: "#cccccc"
                        radius: 4
                    }

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
                    width: 80
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: "#333333"
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

                // ── Theme toggle ─────────────────────────────────────────
                Button {
                    text: "Theme"
                    onClicked: {
                        var dark = mainBg.color === "#f8f9fa"
                        mainBg.color      = dark ? "#1e1e1e" : "#f8f9fa"
                        contentArea.color = dark ? "#2b2b2b" : "#eeeeee"
                        fileText.color    = dark ? "#ffffff" : "#333333"
                        lineNumbers.color = dark ? "#aaaaaa" : "#999999"
                    }
                }

                // ── Font dropdown ────────────────────────────────────────
                DropButton {
                    label: "Font"
                    items: ["Font +", "Font -", "Size 10", "Size 12", "Size 16", "Size 20"]
                    onItemSelected: (name) => {
                        if      (name === "Font +")  fileText.font.pixelSize = fileText.font.pixelSize + 1
                        else if (name === "Font -")  { if (fileText.font.pixelSize > 6) fileText.font.pixelSize = fileText.font.pixelSize - 1 }
                        else if (name === "Size 10") fileText.font.pixelSize = 10
                        else if (name === "Size 12") fileText.font.pixelSize = 12
                        else if (name === "Size 16") fileText.font.pixelSize = 16
                        else if (name === "Size 20") fileText.font.pixelSize = 20
                    }
                }

                // ── Edit dropdown ────────────────────────────────────────
                DropButton {
                    label: "Edit"
                    items: ["Undo", "Redo", "Select All", "Copy All", "Clear"]
                    onItemSelected: (name) => {
                        if      (name === "Undo")       fileText.undo()
                        else if (name === "Redo")       fileText.redo()
                        else if (name === "Select All") fileText.selectAll()
                        else if (name === "Copy All")   { fileText.selectAll(); fileText.copy(); fileText.deselect() }
                        else if (name === "Clear")      fileText.text = ""
                    }
                }

                // ── Format dropdown ──────────────────────────────────────
                DropButton {
                    label: "Format"
                    items: ["Wrap On", "Wrap Off", "Indent +", "Indent -", "UPPERCASE", "lowercase"]
                    onItemSelected: (name) => {
                        if      (name === "Wrap On")  fileText.wrapMode = TextArea.Wrap
                        else if (name === "Wrap Off") fileText.wrapMode = TextArea.NoWrap
                        else if (name === "Indent +") fileText.tabStopDistance = fileText.tabStopDistance + 8
                        else if (name === "Indent -") { if (fileText.tabStopDistance > 8) fileText.tabStopDistance = fileText.tabStopDistance - 8 }
                        else if (name === "UPPERCASE") {
                            var sel = fileText.selectedText
                            if (sel.length > 0) {
                                var s = fileText.selectionStart
                                fileText.remove(fileText.selectionStart, fileText.selectionEnd)
                                fileText.insert(s, sel.toUpperCase())
                            } else {
                                fileText.text = fileText.text.toUpperCase()
                            }
                        }
                        else if (name === "lowercase") {
                            var sel2 = fileText.selectedText
                            if (sel2.length > 0) {
                                var s2 = fileText.selectionStart
                                fileText.remove(fileText.selectionStart, fileText.selectionEnd)
                                fileText.insert(s2, sel2.toLowerCase())
                            } else {
                                fileText.text = fileText.text.toLowerCase()
                            }
                        }
                    }
                }

                // ── File dropdown ────────────────────────────────────────
                DropButton {
                    id: fileDrop
                    label: "File"
                    property bool autoSave: false
                    property var recentFiles: []
                    items: {
                        var base = ["New", "Open", "Save", "---", "Auto-Save: OFF"]
                        var recents = recentFiles.length > 0
                            ? ["---"].concat(recentFiles.slice(0, 3))
                            : []
                        return base.concat(recents)
                    }
                    onItemSelected: (name) => {
                        if      (name === "New")   { fileText.text = ""; placeholderText.visible = true; placeholderText.text = "New file created"; placeholderText.color = "#333333"; placeholderText.font.italic = false }
                        else if (name === "Open")  openDialog.open()
                        else if (name === "Save")  saveDialog.open()
                        else if (name === "Auto-Save: OFF" || name === "Auto-Save: ON") {
                            autoSave = !autoSave
                            var newItems = ["New", "Open", "Save", "---", autoSave ? "Auto-Save: ON" : "Auto-Save: OFF"]
                            var recents = recentFiles.length > 0 ? ["---"].concat(recentFiles.slice(0, 3)) : []
                            fileDrop.items = newItems.concat(recents)
                        }
                    }

                    Timer {
                        interval: 30000
                        running: parent.autoSave && fileText.text !== ""
                        repeat: true
                        onTriggered: saveDialog.open()
                    }
                }

                // ── View dropdown ────────────────────────────────────────
                DropButton {
                    id: viewDrop
                    label: "View"
                    items: ["Zoom In", "Zoom Out", "Reset Zoom", "Toggle Highlight", "Toggle Line Nums"]
                    property bool lineHighlight: true
                    property bool showLineNums: true
                    onItemSelected: (name) => {
                        if      (name === "Zoom In")         fileText.font.pixelSize = fileText.font.pixelSize + 2
                        else if (name === "Zoom Out")        { if (fileText.font.pixelSize > 6) fileText.font.pixelSize = fileText.font.pixelSize - 2 }
                        else if (name === "Reset Zoom")      fileText.font.pixelSize = 12
                        else if (name === "Toggle Highlight") {
                            lineHighlight = !lineHighlight
                            cursorHighlight.visible = lineHighlight
                        }
                        else if (name === "Toggle Line Nums") {
                            showLineNums = !showLineNums
                            lineNumbers.visible = showLineNums
                            lineNumbers.width = showLineNums ? 38 : 0
                            divider.visible = showLineNums
                        }
                    }
                }

                // ── Stats dropdown ───────────────────────────────────────
                DropButton {
                    id: preferencesDrop
                    label: "Preferences"
                    items: ["Project Settings", "Environment", "C++ Settings", "Git"]
                    property bool lineHighlight: true
                    property bool showLineNums: true
                    onItemSelected: (name) => {
                        appWindow.viewMode = "preferences"
                    }
                }
            }
        }

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
                id: sideMenu
                anchors.top: header.bottom
                anchors.bottom: sideInfoPanel.top
                width: parent.width

                property var menuItems: ["New File", "Load File", "Save File", "Settings", "Exit"]

                Column {
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10

                    Repeater {
                        model: sideMenu.menuItems

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

            // ── Info panels + mouse pos pinned to sidebar bottom ─────────
            Column {
                id: sideInfoPanel
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4
                width: parent.width - 8

                // ── Word Count panel ─────────────────────────────────────
                Column {
                    id: wordCountPanel
                    width: parent.width
                    spacing: 2
                    visible: true

                    Button {
                        width: parent.width
                        text: "Words"
                        font.pixelSize: 10
                        onClicked: wordCountText.visible = !wordCountText.visible
                    }

                    Text {
                        id: wordCountText
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 10
                        color: "#555555"
                        visible: true
                        text: {
                            var t = fileText.text
                            var words = t.trim() === "" ? 0 : t.trim().split(/\s+/).length
                            var chars = t.length
                            return "W: " + words + "  C: " + chars
                        }
                    }
                }

                // ── File Size panel ──────────────────────────────────────
                Column {
                    id: fileSizePanel
                    width: parent.width
                    spacing: 2
                    visible: true

                    Button {
                        width: parent.width
                        text: "File Size"
                        font.pixelSize: 10
                        onClicked: fileSizeText.visible = !fileSizeText.visible
                    }

                    Text {
                        id: fileSizeText
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 10
                        color: "#555555"
                        visible: true
                        text: {
                            var bytes = new TextEncoder().encode(fileText.text).length
                            return bytes < 1024
                                ? bytes + " B"
                                : (bytes / 1024).toFixed(2) + " KB"
                        }
                    }
                }

                // ── Selection Info panel ─────────────────────────────────
                Column {
                    id: selectionPanel
                    width: parent.width
                    spacing: 2
                    visible: true

                    Button {
                        width: parent.width
                        text: "Selection"
                        font.pixelSize: 10
                        onClicked: selectionText.visible = !selectionText.visible
                    }

                    Text {
                        id: selectionText
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 10
                        color: "#555555"
                        visible: true
                        text: {
                            var sel = fileText.selectedText
                            if (sel.length === 0) return "No selection"
                            var selWords = sel.trim() === "" ? 0 : sel.trim().split(/\s+/).length
                            return "Sel: " + sel.length + " ch, " + selWords + " w"
                        }
                    }
                }

                // ── Mouse pos (unchanged) ────────────────────────────────
                Text {
                    id: mousePos
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 10
                    color: "#888888"
                    text: appWindow.mouseX + "," + appWindow.mouseY
                }
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
                visible: fileText.text !== "" && appWindow.viewMode == "editor"


                Row {
                    width: fileScroll.width
                    spacing: 0

                    TextArea {
                        id: lineNumbers
                        visible: appWindow.viewMode == "editor"
                        width: 38
                        readOnly: true

                        text: {
                            var count = fileText.text === "" ? 1 : fileText.text.split("\n").length
                            var result = ""
                            for (var i = 1; i <= count; i++)
                                result += i + "\n"
                            return result
                        }

                        font.family: fileText.font.family
                        font.pixelSize: fileText.font.pixelSize

                        color: "#999999"
                        background: Rectangle { color: "#f0f0f0" }

                        wrapMode: TextArea.NoWrap
                        selectByMouse: false

                        topPadding: 0
                        bottomPadding: 0
                        leftPadding: 2
                        rightPadding: 2

                        horizontalAlignment: Text.AlignRight

                        property int currentLine: fileText.text.substring(0, fileText.cursorPosition).split("\n").length

                        Component.onCompleted: updateLine()

                        function updateLine() {
                            currentLine = fileText.text.substring(0, fileText.cursorPosition).split("\n").length
                        }
                    }

                    Rectangle {
                        id: divider
                        width: 1
                        height: fileScroll.height
                        color: "#cccccc"
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
                        leftPadding: 4
                        rightPadding: 4
                        selectByMouse: true

                        topPadding: 0
                        bottomPadding: 0

                        cursorVisible: true
                        focus: true
                        tabStopDistance: 24

                        palette {
                            highlight: "#3399ff"
                            highlightedText: "white"
                        }

                        // Highlight current line
                        Rectangle {
                            id: cursorHighlight
                            width: parent.width
                            height: fileText.cursorRectangle.height
                            y: fileText.cursorRectangle.y
                            color: "#d0e7ff"
                            z: -1
                        }

                        // Auto-indent
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
                visible: appWindow.viewMode == "editor"
                color: "#888"
                text: "Lines: " + fileText.text.split("\n").length
            }
        }
    }
}
