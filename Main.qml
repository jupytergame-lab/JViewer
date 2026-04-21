import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

Window {
    id: appWindow
    width: 1024
    height: 720
    visible: true
    title: qsTr("JViewer")
    color: "white"

    property int  mouseX:    0
    property int  mouseY:    0
    property string viewMode: "editor"   // "editor" | "preferences"

    // ── Global editor state (source of truth for Settings page) ────────────
    property string editorFontFamily: "Courier New"
    property int    editorFontSize:   12
    property bool   autoIndentEnabled: true
    property bool   showLineNumbers:   true
    property bool   lineHighlight:     true
    property bool   darkTheme:         false

    // ── Debounce timer for stats recalculation ──────────────────────────────
    Timer {
        id: statsDebounce
        interval: 300
        repeat: false
        onTriggered: statsRefresh.trigger()
    }

    QtObject {
        id: statsRefresh
        property int  wordCount:  0
        property int  charCount:  0
        property int  byteCount:  0
        property string selInfo:  "No selection"

        function trigger() {
            var t     = fileText.text
            wordCount = t.trim() === "" ? 0 : t.trim().split(/\s+/).length
            charCount = t.length
            byteCount = new TextEncoder().encode(t).length
            var sel   = fileText.selectedText
            if (sel.length === 0) {
                selInfo = "No selection"
            } else {
                var sw = sel.trim() === "" ? 0 : sel.trim().split(/\s+/).length
                selInfo = "Sel: " + sel.length + " ch, " + sw + " w"
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onPositionChanged: (mouse) => {
            appWindow.mouseX = mouse.x
            appWindow.mouseY = mouse.y
        }
    }

    // ── File dialogs ────────────────────────────────────────────────────────
    FileDialog {
        id: openDialog
        title: "Open File"
        fileMode: FileDialog.OpenFile
        onAccepted: {
            placeholderText.visible = false
            var content = fileReader.readFile(selectedFile)
            fileText.text = content
            statusBar.message = "Opened: " + selectedFile
            var ext = fileReader.extensionOf(selectedFile)
            highlighter.setDocument(fileText.textDocument)
            highlighter.setLanguage(ext)
            var name = selectedFile.toString().split("/").pop()
            var rf = fileDrop.recentFiles.filter(f => f !== name)
            rf.unshift(name)
            fileDrop.recentFiles = rf.slice(0, 3)
            fileDrop.rebuildItems()
            statsDebounce.restart()
        }
    }

    FileDialog {
        id: saveDialog
        title: "Save File"
        fileMode: FileDialog.SaveFile
        onAccepted: { statusBar.message = "Saved: " + selectedFile }
    }

    // ── Helpers ─────────────────────────────────────────────────────────────
    function applyTheme(dark) {
        darkTheme      = dark
        mainBg.color   = dark ? "#1e1e1e" : "#f8f9fa"
        contentArea.color = dark ? "#2b2b2b" : "#eeeeee"
        fileText.color = dark ? "#d4d4d4" : "#333333"
        lineNumbers.color = dark ? "#858585" : "#999999"
    }

    function currentLineNumber() {
        return fileText.text.substring(0, fileText.cursorPosition).split("\n").length
    }

    function currentColNumber() {
        var before = fileText.text.substring(0, fileText.cursorPosition)
        return fileText.cursorPosition - before.lastIndexOf("\n")
    }

    // ── Reusable dropdown component ─────────────────────────────────────────
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

                        Rectangle {
                            visible: modelData === "---"
                            width: parent.width; height: 1
                            color: "#e0e0e0"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            visible: modelData !== "---"
                            anchors.fill: parent
                            radius: 4
                            color: itemMouse.containsMouse ? "#e8f0fe" : "#ffffff"
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
                                id: itemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: { popup.close(); dropRoot.itemSelected(modelData) }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Find / Replace bar ──────────────────────────────────────────────────
    Rectangle {
        id: findBar
        visible: false
        z: 10
        height: 38
        anchors.left: sideBar.right
        anchors.right: parent.right
        anchors.top: topBar.bottom
        color: "#f0f4ff"
        border.color: "#adb5bd"
        border.width: 1

        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 10
            spacing: 6

            TextField {
                id: findField
                placeholderText: "Find…"
                width: 160
                onTextChanged: highlightFind()
                background: Rectangle { color: "white"; border.color: "#cccccc"; radius: 3 }
            }
            TextField {
                id: replaceField
                placeholderText: "Replace…"
                width: 160
                background: Rectangle { color: "white"; border.color: "#cccccc"; radius: 3 }
            }
            Button { text: "Next";    onClicked: findNext() }
            Button { text: "Prev";    onClicked: findPrev() }
            Button { text: "Replace"; onClicked: replaceCurrent() }
            Button { text: "All";     onClicked: replaceAll() }
            Button {
                text: "✕"
                onClicked: { findBar.visible = false; fileText.deselect() }
            }
        }

        property int lastIndex: -1

        function highlightFind() {
            lastIndex = -1
            findNext()
        }

        function findNext() {
            var needle = findField.text
            if (needle.length === 0) return
            var start = (lastIndex >= 0) ? lastIndex + needle.length : fileText.cursorPosition
            var idx = fileText.text.indexOf(needle, start)
            if (idx === -1) idx = fileText.text.indexOf(needle, 0)   // wrap
            if (idx !== -1) {
                fileText.select(idx, idx + needle.length)
                fileText.cursorPosition = idx + needle.length
                lastIndex = idx
            }
        }

        function findPrev() {
            var needle = findField.text
            if (needle.length === 0) return
            var end = (lastIndex > 0) ? lastIndex - 1 : fileText.text.length
            var idx = fileText.text.lastIndexOf(needle, end)
            if (idx !== -1) {
                fileText.select(idx, idx + needle.length)
                fileText.cursorPosition = idx
                lastIndex = idx
            }
        }

        function replaceCurrent() {
            if (fileText.selectedText === findField.text && findField.text.length > 0) {
                var s = fileText.selectionStart
                fileText.remove(fileText.selectionStart, fileText.selectionEnd)
                fileText.insert(s, replaceField.text)
                findNext()
            } else {
                findNext()
            }
        }

        function replaceAll() {
            var needle = findField.text
            if (needle.length === 0) return
            fileText.text = fileText.text.split(needle).join(replaceField.text)
            //statusBar.message = "Replaced all occurrences of "" + needle + """
        }
    }

    // ── Main layout ─────────────────────────────────────────────────────────
    Rectangle {
        id: mainBg
        anchors.fill: parent
        color: "#f8f9fa"
        border.color: "#e9ecef"
        border.width: 1

        // ── Top bar ─────────────────────────────────────────────────────────
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
                    placeholderText: "Search…"
                    color: "#333333"
                    placeholderTextColor: "#999999"
                    width: 130
                    background: Rectangle { color: "#ffffff"; border.color: "#cccccc"; radius: 4 }
                    onTextChanged: {
                        if (text.length > 0) {
                            var idx = fileText.text.indexOf(text)
                            if (idx !== -1) {
                                fileText.select(idx, idx + text.length)
                                fileText.cursorPosition = idx
                            }
                        }
                    }
                }

                TextField {
                    id: gotoLine
                    placeholderText: "Go to line…"
                    width: 80
                    horizontalAlignment: Text.AlignHCenter
                    color: "#333333"
                    placeholderTextColor: "#999999"
                    background: Rectangle { color: "#ffffff"; border.color: "#cccccc"; radius: 4 }
                    onAccepted: {
                        var line = parseInt(text)
                        var lines = fileText.text.split("\n")
                        if (line > 0 && line <= lines.length) {
                            var pos = 0
                            for (var i = 0; i < line - 1; i++) pos += lines[i].length + 1
                            fileText.cursorPosition = pos
                        }
                    }
                }

                Button {
                    text: "Theme"
                    onClicked: applyTheme(!appWindow.darkTheme)
                }

                DropButton {
                    label: "Font"
                    items: ["Font +", "Font -", "Size 10", "Size 12", "Size 16", "Size 20"]
                    onItemSelected: (name) => {
                        if      (name === "Font +")  appWindow.editorFontSize = editorFontSize + 1
                        else if (name === "Font -")  { if (editorFontSize > 6) appWindow.editorFontSize = editorFontSize - 1 }
                        else if (name === "Size 10") appWindow.editorFontSize = 10
                        else if (name === "Size 12") appWindow.editorFontSize = 12
                        else if (name === "Size 16") appWindow.editorFontSize = 16
                        else if (name === "Size 20") appWindow.editorFontSize = 20
                    }
                }

                DropButton {
                    label: "Edit"
                    items: ["Undo", "Redo", "Select All", "Copy All", "Clear", "---", "Find & Replace", "Duplicate Line", "Toggle Comment"]
                    onItemSelected: (name) => {
                        if      (name === "Undo")           fileText.undo()
                        else if (name === "Redo")           fileText.redo()
                        else if (name === "Select All")     fileText.selectAll()
                        else if (name === "Copy All")       { fileText.selectAll(); fileText.copy(); fileText.deselect() }
                        else if (name === "Clear")          fileText.text = ""
                        else if (name === "Find & Replace") { findBar.visible = true; findField.forceActiveFocus() }
                        else if (name === "Duplicate Line") duplicateLine()
                        else if (name === "Toggle Comment") toggleComment()
                    }
                }

                DropButton {
                    label: "Format"
                    items: ["Wrap On", "Wrap Off", "Indent +", "Indent -", "Uppercase", "Lowercase"]
                    onItemSelected: (name) => {
                        if      (name === "Wrap On")  fileText.wrapMode = TextArea.Wrap
                        else if (name === "Wrap Off") fileText.wrapMode = TextArea.NoWrap
                        else if (name === "Indent +") fileText.tabStopDistance = fileText.tabStopDistance + 8
                        else if (name === "Indent -") { if (fileText.tabStopDistance > 8) fileText.tabStopDistance -= 8 }
                        else if (name === "Uppercase") transformSelection(function(s) { return s.toUpperCase() })
                        else if (name === "Lowercase") transformSelection(function(s) { return s.toLowerCase() })
                    }
                }

                DropButton {
                    id: fileDrop
                    label: "File"
                    property bool autoSave: false
                    property var recentFiles: []

                    function rebuildItems() {
                        var base    = ["New", "Open", "Save", "---", autoSave ? "Auto-Save: ON" : "Auto-Save: OFF"]
                        var recents = recentFiles.length > 0 ? ["---"].concat(recentFiles.slice(0, 3)) : []
                        items = base.concat(recents)
                    }

                    Component.onCompleted: rebuildItems()

                    onItemSelected: (name) => {
                        if      (name === "New")  { fileText.text = ""; placeholderText.visible = true; statusBar.message = "New file" }
                        else if (name === "Open") openDialog.open()
                        else if (name === "Save") saveDialog.open()
                        else if (name === "Auto-Save: OFF" || name === "Auto-Save: ON") {
                            autoSave = !autoSave
                            rebuildItems()
                        }
                    }

                    Timer {
                        interval: 30000
                        running: parent.autoSave && fileText.text !== ""
                        repeat: true
                        onTriggered: saveDialog.open()
                    }
                }

                DropButton {
                    id: viewDrop
                    label: "View"
                    items: ["Zoom In", "Zoom Out", "Reset Zoom", "Toggle Highlight", "Toggle Line Nums"]
                    onItemSelected: (name) => {
                        if      (name === "Zoom In")          appWindow.editorFontSize = editorFontSize + 2
                        else if (name === "Zoom Out")         { if (editorFontSize > 6) appWindow.editorFontSize = editorFontSize - 2 }
                        else if (name === "Reset Zoom")       appWindow.editorFontSize = 12
                        else if (name === "Toggle Highlight") { lineHighlight = !lineHighlight; cursorHighlight.visible = lineHighlight }
                        else if (name === "Toggle Line Nums") {
                            showLineNumbers = !showLineNumbers
                            lineNumbers.visible = showLineNumbers
                            lineNumbers.width   = showLineNumbers ? 38 : 0
                            divider.visible     = showLineNumbers
                        }
                    }
                }

                DropButton {
                    label: "Preferences"
                    items: ["Project Settings", "Environment", "C++ Settings", "Git"]
                    onItemSelected: (name) => { appWindow.viewMode = "preferences" }
                }
            }
        }

        // ── Sidebar ──────────────────────────────────────────────────────────
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
                id: sideHeader
                width: parent.width
                height: 40
                color: "#eeeeee"
                border.color: "#adb5bd"
                border.width: 1
                Text { text: "JViewer"; anchors.centerIn: parent; color: "#333"; font.pixelSize: 15; font.bold: true }
            }

            Column {
                anchors.top: sideHeader.bottom
                anchors.topMargin: 10
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Repeater {
                    model: ["New File", "Load File", "Save File", "Settings", "Exit"]
                    Button {
                        text: modelData
                        width: 140
                        onClicked: {
                            if      (modelData === "New File")  { fileText.text = ""; placeholderText.visible = true; statusBar.message = "New file" }
                            else if (modelData === "Load File") openDialog.open()
                            else if (modelData === "Save File") saveDialog.open()
                            else if (modelData === "Settings")  appWindow.viewMode = "preferences"
                            else if (modelData === "Exit")      Qt.quit()
                        }
                    }
                }
            }

            Column {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4
                width: parent.width - 8

                Column {
                    width: parent.width; spacing: 2
                    Button { width: parent.width; text: "Words"; font.pixelSize: 10; onClicked: wordCountText.visible = !wordCountText.visible }
                    Text {
                        id: wordCountText
                        width: parent.width; horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 10; color: "#555555"; visible: true
                        text: "W: " + statsRefresh.wordCount + "  C: " + statsRefresh.charCount
                    }
                }

                Column {
                    width: parent.width; spacing: 2
                    Button { width: parent.width; text: "File Size"; font.pixelSize: 10; onClicked: fileSizeText.visible = !fileSizeText.visible }
                    Text {
                        id: fileSizeText
                        width: parent.width; horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 10; color: "#555555"; visible: true
                        text: statsRefresh.byteCount < 1024
                              ? statsRefresh.byteCount + " B"
                              : (statsRefresh.byteCount / 1024).toFixed(2) + " KB"
                    }
                }

                Column {
                    width: parent.width; spacing: 2
                    Button { width: parent.width; text: "Selection"; font.pixelSize: 10; onClicked: selectionText.visible = !selectionText.visible }
                    Text {
                        id: selectionText
                        width: parent.width; horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 10; color: "#555555"; visible: true
                        text: statsRefresh.selInfo
                    }
                }

                Text {
                    width: parent.width; horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 10; color: "#888888"
                    text: appWindow.mouseX + "," + appWindow.mouseY
                }
            }
        }

        // ── Content area ─────────────────────────────────────────────────────
        Rectangle {
            id: contentArea
            anchors.left: sideBar.right
            anchors.right: parent.right
            anchors.top: findBar.visible ? findBar.bottom : topBar.bottom
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
                color: "#999999"; font.pixelSize: 14; font.italic: true
                width: parent.width * 0.8; horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: fileText.text === ""
            }

            // ── Editor view ─────────────────────────────────────────────────
            ScrollView {
                id: fileScroll
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: statusBar.top
                anchors.margins: 8
                visible: appWindow.viewMode === "editor"

                Row {
                    width: fileScroll.width
                    spacing: 0

                    // Line numbers — scroll position kept in sync via binding
                    TextArea {
                        id: lineNumbers
                        visible: appWindow.showLineNumbers
                        width: appWindow.showLineNumbers ? 38 : 0
                        readOnly: true
                        font.family: appWindow.editorFontFamily
                        font.pixelSize: appWindow.editorFontSize
                        color: "#999999"
                        background: Rectangle { color: "#f0f0f0" }
                        wrapMode: TextArea.NoWrap
                        selectByMouse: false
                        topPadding: 0; bottomPadding: 0; leftPadding: 2; rightPadding: 2
                        horizontalAlignment: Text.AlignRight

                        text: {
                            var count = fileText.text === "" ? 1 : fileText.text.split("\n").length
                            var r = ""
                            for (var i = 1; i <= count; i++) r += i + "\n"
                            return r
                        }
                    }

                    Rectangle {
                        id: divider
                        width: appWindow.showLineNumbers ? 1 : 0
                        height: fileScroll.height
                        color: "#cccccc"
                    }

                    TextArea {
                        id: fileText
                        width: fileScroll.width - lineNumbers.width - divider.width
                        text: ""
                        color: "#333333"
                        font.pixelSize: appWindow.editorFontSize
                        font.family: appWindow.editorFontFamily
                        wrapMode: TextArea.NoWrap
                        background: null
                        readOnly: false
                        leftPadding: 4; rightPadding: 4
                        topPadding: 0; bottomPadding: 0
                        selectByMouse: true
                        cursorVisible: true
                        focus: true
                        tabStopDistance: 24

                        palette {
                            highlight: "#3399ff"
                            highlightedText: "white"
                        }

                        onTextChanged: statsDebounce.restart()
                        onSelectedTextChanged: statsDebounce.restart()

                        // Current line highlight
                        Rectangle {
                            id: cursorHighlight
                            width: parent.width
                            height: fileText.cursorRectangle.height
                            y: fileText.cursorRectangle.y
                            color: "#d0e7ff"
                            z: -1
                            visible: appWindow.lineHighlight
                        }

                        Keys.onPressed: (event) => {
                            var ctrl  = (event.modifiers & Qt.ControlModifier) !== 0
                            var noMod = event.modifiers === Qt.NoModifier

                            if (ctrl && event.key === Qt.Key_D) {
                                duplicateLine()
                                event.accepted = true
                            } else if (ctrl && event.key === Qt.Key_Slash) {
                                toggleComment()
                                event.accepted = true
                            } else if (ctrl && event.key === Qt.Key_F) {
                                findBar.visible = true
                                findField.forceActiveFocus()
                                event.accepted = true
                            } else if (noMod && event.key === Qt.Key_Return && appWindow.autoIndentEnabled) {
                                var cur = fileText.cursorPosition
                                var bef = fileText.text.substring(0, cur)
                                var ln  = bef.split("\n").pop()
                                var ind = ln.match(/^\s*/)[0]
                                fileText.insert(cur, "\n" + ind)
                                event.accepted = true
                            } else if (noMod && event.text.length === 1) {
                                var pairs = { "(": ")", "[": "]", "{": "}", '"': '"', "'": "'" }
                                var ch = event.text
                                if (pairs.hasOwnProperty(ch)) {
                                    var cp  = fileText.cursorPosition
                                    var sel = fileText.selectedText
                                    if (sel.length > 0) {
                                        var ss = fileText.selectionStart
                                        var se = fileText.selectionEnd
                                        fileText.remove(ss, se)
                                        fileText.insert(ss, ch + sel + pairs[ch])
                                        fileText.select(ss + 1, ss + 1 + sel.length)
                                    } else {
                                        fileText.insert(cp, ch + pairs[ch])
                                        fileText.cursorPosition = cp + 1
                                    }
                                    event.accepted = true
                                }
                            }
                        }
                    }
                }
            }

            // ── Settings view ────────────────────────────────────────────────
            Rectangle {
                id: settingsPanel
                anchors.fill: parent
                visible: appWindow.viewMode === "preferences"
                color: contentArea.color

                Row {
                    anchors.fill: parent
                    spacing: 0

                    Rectangle {
                        width: 180; height: parent.height
                        color: sideBar.color
                        border.color: "#adb5bd"; border.width: 1

                        Column {
                            id: navColumn
                            anchors.fill: parent
                            spacing: 0
                            property string currentTab: "General"

                            Rectangle {
                                width: parent.width; height: 40
                                color: "#eeeeee"
                                border.color: "#adb5bd"; border.width: 1
                                Text { text: "Settings"; anchors.centerIn: parent; color: "#333"; font.pixelSize: 15; font.bold: true }
                            }

                            Column {
                                width: parent.width; spacing: 4
                                anchors.top: parent.top; anchors.topMargin: 50
                                anchors.left: parent.left; anchors.leftMargin: 8
                                anchors.right: parent.right; anchors.rightMargin: 8

                                Repeater {
                                    model: ["General", "Editor", "Appearance", "Keybindings"]
                                    delegate: Rectangle {
                                        width: parent.width; height: 32; radius: 4
                                        color: navColumn.currentTab === modelData ? "#e8f0fe" : "transparent"
                                        border.color: navColumn.currentTab === modelData ? "#0078d4" : "transparent"
                                        border.width: 1
                                        Text {
                                            text: modelData
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.left: parent.left; anchors.leftMargin: 12
                                            color: navColumn.currentTab === modelData ? "#0078d4" : "#333333"
                                            font.pixelSize: 12
                                        }
                                        MouseArea {
                                            anchors.fill: parent; hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onEntered: { if (navColumn.currentTab !== modelData) parent.color = "#f0f0f0" }
                                            onExited:  { if (navColumn.currentTab !== modelData) parent.color = "transparent" }
                                            onClicked: navColumn.currentTab = modelData
                                        }
                                    }
                                }
                            }

                            Button {
                                text: "← Back to Editor"
                                width: parent.width - 16
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 12
                                onClicked: appWindow.viewMode = "editor"
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width - 180; height: parent.height
                        color: contentArea.color
                        border.color: "#adb5bd"; border.width: 1

                        StackLayout {
                            anchors.fill: parent
                            anchors.margins: 20
                            currentIndex: {
                                if (navColumn.currentTab === "General")     return 0
                                if (navColumn.currentTab === "Editor")      return 1
                                if (navColumn.currentTab === "Appearance")  return 2
                                if (navColumn.currentTab === "Keybindings") return 3
                                return 0
                            }

                            // PAGE 0: General
                            Column {
                                spacing: 16
                                Text { text: "General Settings"; font.pixelSize: 18; font.bold: true; color: "#333333" }
                                Rectangle { width: parent.width; height: 1; color: "#adb5bd" }
                                Column {
                                    spacing: 12; width: parent.width
                                    CheckBox {
                                        text: "Auto-save on focus lost"
                                        checked: fileDrop.autoSave
                                        onCheckedChanged: { fileDrop.autoSave = checked; fileDrop.rebuildItems() }
                                    }
                                    CheckBox { text: "Check for updates on startup"; checked: false }
                                }
                            }

                            // PAGE 1: Editor — controls are now wired to live state
                            Column {
                                spacing: 16
                                Text { text: "Editor Configuration"; font.pixelSize: 18; font.bold: true; color: "#333333" }
                                Rectangle { width: parent.width; height: 1; color: "#adb5bd" }
                                Column {
                                    spacing: 12; width: parent.width

                                    Row {
                                        spacing: 12
                                        Text { text: "Font Family:"; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 12; color: "#333333"; width: 100 }
                                        ComboBox {
                                            width: 200
                                            model: ["Courier New", "Fira Code", "Consolas", "JetBrains Mono", "Monospace"]
                                            currentIndex: model.indexOf(appWindow.editorFontFamily) >= 0
                                                          ? model.indexOf(appWindow.editorFontFamily) : 0
                                            onActivated: appWindow.editorFontFamily = model[currentIndex]
                                        }
                                    }

                                    Row {
                                        spacing: 12
                                        Text { text: "Font Size:"; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 12; color: "#333333"; width: 100 }
                                        SpinBox {
                                            width: 80; from: 6; to: 32
                                            value: appWindow.editorFontSize
                                            onValueModified: appWindow.editorFontSize = value
                                        }
                                    }

                                    CheckBox {
                                        text: "Show Line Numbers"
                                        checked: appWindow.showLineNumbers
                                        onCheckedChanged: appWindow.showLineNumbers = checked
                                    }

                                    CheckBox {
                                        text: "Highlight Current Line"
                                        checked: appWindow.lineHighlight
                                        onCheckedChanged: appWindow.lineHighlight = checked
                                    }

                                    CheckBox {
                                        text: "Auto-indent"
                                        checked: appWindow.autoIndentEnabled
                                        onCheckedChanged: appWindow.autoIndentEnabled = checked
                                    }

                                    CheckBox { text: "Enable Code Minimap"; checked: false }
                                }
                            }

                            // PAGE 2: Appearance — theme picker wired to applyTheme()
                            Column {
                                spacing: 16
                                Text { text: "Theme Selection"; font.pixelSize: 18; font.bold: true; color: "#333333" }
                                Rectangle { width: parent.width; height: 1; color: "#adb5bd" }
                                Column {
                                    spacing: 12; width: parent.width
                                    Row {
                                        spacing: 12
                                        Text { text: "Theme:"; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 12; color: "#333333"; width: 100 }
                                        ComboBox {
                                            width: 200
                                            model: ["Light Classic", "Dark Modern", "High Contrast"]
                                            currentIndex: appWindow.darkTheme ? 1 : 0
                                            onActivated: {
                                                if (currentIndex === 1) applyTheme(true)
                                                else                     applyTheme(false)
                                            }
                                        }
                                    }
                                    CheckBox {
                                        text: "Use system theme"; checked: false
                                        onCheckedChanged: { /* hook into Qt.styleHints if desired */ }
                                    }
                                }
                            }

                            // PAGE 3: Keybindings
                            Column {
                                spacing: 16
                                Text { text: "Keyboard Shortcuts"; font.pixelSize: 18; font.bold: true; color: "#333333" }
                                Rectangle { width: parent.width; height: 1; color: "#adb5bd" }
                                Column {
                                    spacing: 8; width: parent.width

                                    Rectangle {
                                        width: parent.width; height: 30
                                        color: "#eeeeee"; border.color: "#adb5bd"; border.width: 1
                                        Row {
                                            anchors.fill: parent; anchors.margins: 8; spacing: 20
                                            Text { text: "Action"; font.bold: true; width: 160; color: "#333" }
                                            Text { text: "Shortcut"; font.bold: true; color: "#333" }
                                        }
                                    }

                                    Repeater {
                                        model: [
                                            { action: "New File",       shortcut: "Ctrl+N" },
                                            { action: "Open File",      shortcut: "Ctrl+O" },
                                            { action: "Save File",      shortcut: "Ctrl+S" },
                                            { action: "Undo",           shortcut: "Ctrl+Z" },
                                            { action: "Redo",           shortcut: "Ctrl+Y" },
                                            { action: "Find & Replace", shortcut: "Ctrl+F" },
                                            { action: "Go to Line",     shortcut: "Ctrl+G" },
                                            { action: "Duplicate Line", shortcut: "Ctrl+D" },
                                            { action: "Toggle Comment", shortcut: "Ctrl+/" }
                                        ]
                                        delegate: Rectangle {
                                            width: parent.width; height: 28; color: "transparent"
                                            Row {
                                                anchors.fill: parent; anchors.margins: 8; spacing: 20
                                                Text { text: modelData.action; width: 160; color: "#555"; font.pixelSize: 11 }
                                                Text { text: modelData.shortcut; color: "#777"; font.pixelSize: 11 }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Status bar ───────────────────────────────────────────────────
            Item {
                id: statusBar
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 28

                property string message: ""

                Timer {
                    id: msgClear; interval: 4000; onTriggered: statusBar.message = ""
                    running: statusBar.message !== ""
                }

                Text {
                    anchors.left: parent.left; anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#888"; font.pixelSize: 11; font.italic: true
                    text: statusBar.message
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#666666"; font.pixelSize: 11; font.italic: true
                    text: "Ln " + appWindow.currentLineNumber() + ", Col " + appWindow.currentColNumber()
                }

                Text {
                    anchors.right: parent.right; anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#888"; font.pixelSize: 11
                    visible: appWindow.viewMode === "editor"
                    text: "Lines: " + fileText.text.split("\n").length
                }
            }
        }
    }

    // ── Editor helper functions ─────────────────────────────────────────────
    function transformSelection(fn) {
        var sel = fileText.selectedText
        if (sel.length > 0) {
            var s = fileText.selectionStart
            fileText.remove(fileText.selectionStart, fileText.selectionEnd)
            fileText.insert(s, fn(sel))
        } else {
            fileText.text = fn(fileText.text)
        }
    }

    function duplicateLine() {
        var cursor = fileText.cursorPosition
        var before = fileText.text.substring(0, cursor)
        var after  = fileText.text.substring(cursor)
        var lineStart = before.lastIndexOf("\n") + 1
        var lineEnd   = after.indexOf("\n")
        var end       = lineEnd === -1 ? fileText.text.length : cursor + lineEnd
        var line      = fileText.text.substring(lineStart, end)
        fileText.insert(end, "\n" + line)
        fileText.cursorPosition = end + 1 + (cursor - lineStart)
    }

    function toggleComment() {
        var cursor = fileText.cursorPosition
        var before = fileText.text.substring(0, cursor)
        var after  = fileText.text.substring(cursor)
        var lineStart = before.lastIndexOf("\n") + 1
        var lineEnd   = after.indexOf("\n")
        var end       = lineEnd === -1 ? fileText.text.length : cursor + lineEnd
        var line      = fileText.text.substring(lineStart, end)
        var newLine   = line.startsWith("// ") ? line.substring(3) : "// " + line
        fileText.remove(lineStart, end)
        fileText.insert(lineStart, newLine)
        fileText.cursorPosition = lineStart + (cursor - lineStart) + (newLine.length - line.length)
    }
}
