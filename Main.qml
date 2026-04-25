import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

Window {
    id: appWindow
    width:  1280
    height: 800
    visible: true
    title: qsTr("JViewer")
    color: "white"

    // ── Global state ────────────────────────────────────────────────────────
    property int    mouseX:            0
    property int    mouseY:            0
    property string viewMode:          "editor"   // "editor" | "preferences"
    property string editorFontFamily:  "Courier New"
    property int    editorFontSize:    12
    property bool   autoIndentEnabled: true
    property bool   showLineNumbers:   true
    property bool   lineHighlight:     true
    property bool   darkTheme:         false
    property bool   showMinimap:       false
    property bool   showTerminal:      false
    property bool   showBreadcrumb:    true
    property bool   splitView:         false
    property bool   wordWrap:          false
    property string currentEncoding:   "UTF-8"
    property string currentEOL:        "LF"
    property string currentLanguage:   "Plain Text"
    property bool   macroRecording:    false

    // ── Reactive theme palette ───────────────────────────────────────────────
    readonly property color thBg:         darkTheme ? "#1e1e1e"  : "#f8f9fa"
    readonly property color thContent:    darkTheme ? "#2b2b2b"  : "#eeeeee"
    readonly property color thSide:       darkTheme ? "#252526"  : "#ffffff"
    readonly property color thTopBar:     darkTheme ? "#3c3c3c"  : "#ffffff"
    readonly property color thText:       darkTheme ? "#d4d4d4"  : "#333333"
    readonly property color thSubText:    darkTheme ? "#999999"  : "#555555"
    readonly property color thBorder:     darkTheme ? "#555555"  : "#adb5bd"
    readonly property color thPopupBg:    darkTheme ? "#2d2d2d"  : "#ffffff"
    readonly property color thPopupHover: darkTheme ? "#094771"  : "#e8f0fe"
    readonly property color thPopupItem:  darkTheme ? "#3a3a3a"  : "#ffffff"
    readonly property color thPopupText:  darkTheme ? "#d4d4d4"  : "#333333"
    readonly property color thPopupSep:   darkTheme ? "#555555"  : "#e0e0e0"
    readonly property color thLineNum:    darkTheme ? "#858585"  : "#999999"
    readonly property color thRowAlt:     darkTheme ? "#303030"  : "#f8f8f8"
    readonly property color thInputBg:    darkTheme ? "#3c3c3c"  : "#ffffff"
    readonly property color thInputBorder:darkTheme ? "#666666"  : "#cccccc"
    readonly property color thStatusBg:   darkTheme ? "#007acc"  : "#f0f0f0"
    readonly property color thStatusText: darkTheme ? "#ffffff"  : "#555555"
    property var    macroSteps:        []
    property int    tabSize:           4
    property bool   showWhitespace:    false
    property bool   bracketMatch:      true
    property bool   stickyScroll:      false
    property string gitBranch:         "main"
    property int    terminalHeight:    140

    // ── Debounced stats ─────────────────────────────────────────────────────
    Timer {
        id: statsDebounce
        interval: 250
        repeat: false
        onTriggered: statsRefresh.trigger()
    }

    QtObject {
        id: statsRefresh
        property int    wordCount:  0
        property int    charCount:  0
        property int    byteCount:  0
        property int    lineCount:  1
        property string selInfo:    "No selection"
        property int    selChars:   0
        property int    selWords:   0

        function trigger() {
            var t      = fileText.text
            lineCount  = t === "" ? 1 : t.split("\n").length
            wordCount  = t.trim() === "" ? 0 : t.trim().split(/\s+/).length
            charCount  = t.length
            byteCount  = new TextEncoder().encode(t).length
            var sel    = fileText.selectedText
            if (sel.length === 0) {
                selInfo  = "No selection"
                selChars = 0
                selWords = 0
            } else {
                selWords = sel.trim() === "" ? 0 : sel.trim().split(/\s+/).length
                selChars = sel.length
                selInfo  = sel.length + " ch / " + selWords + " w"
            }
        }
    }

    // ── Macro engine ─────────────────────────────────────────────────────────
    QtObject {
        id: macroEngine
        function record(step) {
            if (appWindow.macroRecording) appWindow.macroSteps.push(step)
        }
        function playback() {
            for (var i = 0; i < appWindow.macroSteps.length; i++) {
                var s = appWindow.macroSteps[i]
                if      (s.type === "insert") fileText.insert(fileText.cursorPosition, s.text)
                else if (s.type === "remove") fileText.remove(fileText.selectionStart, fileText.selectionEnd)
            }
            terminalOutput("Macro played back (" + appWindow.macroSteps.length + " steps)")
        }
    }

    // ── Terminal output helper ───────────────────────────────────────────────
    function terminalOutput(msg) {
        var ts = new Date().toLocaleTimeString()
        terminalText.text += "[" + ts + "] " + msg + "\n"
        appWindow.showTerminal = true
    }

    // ── Mouse tracking ───────────────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onPositionChanged: (mouse) => { appWindow.mouseX = mouse.x; appWindow.mouseY = mouse.y }
    }

    // ── File dialogs ─────────────────────────────────────────────────────────
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
            appWindow.currentLanguage = ext.toUpperCase() || "Plain Text"
            var name = selectedFile.toString().split("/").pop()
            var rf = fileDrop.recentFiles.filter(f => f !== name)
            rf.unshift(name)
            fileDrop.recentFiles = rf.slice(0, 5)
            fileDrop.rebuildItems()
            tabBar.addTab(name)
            statsDebounce.restart()
            terminalOutput("Opened: " + name)
        }
    }

    FileDialog {
        id: saveDialog
        title: "Save File"
        fileMode: FileDialog.SaveFile
        onAccepted: {
            statusBar.message = "Saved: " + selectedFile
            terminalOutput("Saved: " + selectedFile)
        }
    }

    // ── Theme helpers ────────────────────────────────────────────────────────
    function applyTheme(dark) { darkTheme = dark }

    // ── Cursor helpers ───────────────────────────────────────────────────────
    function currentLineNumber() { return fileText.text.substring(0, fileText.cursorPosition).split("\n").length }
    function currentColNumber()  { var b = fileText.text.substring(0, fileText.cursorPosition); return fileText.cursorPosition - b.lastIndexOf("\n") }

    // ── Selection transform ──────────────────────────────────────────────────
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

    // ── Duplicate line ───────────────────────────────────────────────────────
    function duplicateLine() {
        var cursor    = fileText.cursorPosition
        var before    = fileText.text.substring(0, cursor)
        var after     = fileText.text.substring(cursor)
        var lineStart = before.lastIndexOf("\n") + 1
        var lineEnd   = after.indexOf("\n")
        var end       = lineEnd === -1 ? fileText.text.length : cursor + lineEnd
        var line      = fileText.text.substring(lineStart, end)
        fileText.insert(end, "\n" + line)
        fileText.cursorPosition = end + 1 + (cursor - lineStart)
        macroEngine.record({ type: "insert", text: "\n" + line })
    }

    // ── Toggle comment ───────────────────────────────────────────────────────
    function toggleComment() {
        var cursor    = fileText.cursorPosition
        var before    = fileText.text.substring(0, cursor)
        var after     = fileText.text.substring(cursor)
        var lineStart = before.lastIndexOf("\n") + 1
        var lineEnd   = after.indexOf("\n")
        var end       = lineEnd === -1 ? fileText.text.length : cursor + lineEnd
        var line      = fileText.text.substring(lineStart, end)
        var newLine   = line.startsWith("// ") ? line.substring(3) : "// " + line
        fileText.remove(lineStart, end)
        fileText.insert(lineStart, newLine)
        fileText.cursorPosition = lineStart + (cursor - lineStart) + (newLine.length - line.length)
    }

    // ── Sort lines ───────────────────────────────────────────────────────────
    function sortLines(ascending) {
        var lines = fileText.text.split("\n")
        lines.sort()
        if (!ascending) lines.reverse()
        fileText.text = lines.join("\n")
        terminalOutput("Lines sorted " + (ascending ? "A→Z" : "Z→A"))
    }

    // ── Remove duplicate lines ───────────────────────────────────────────────
    function removeDuplicateLines() {
        var lines  = fileText.text.split("\n")
        var seen   = {}
        var result = lines.filter(l => { if (seen[l]) return false; seen[l] = true; return true })
        var removed = lines.length - result.length
        fileText.text = result.join("\n")
        terminalOutput("Removed " + removed + " duplicate line(s)")
    }

    // ── Trim trailing whitespace ─────────────────────────────────────────────
    function trimTrailing() {
        fileText.text = fileText.text.split("\n").map(l => l.replace(/\s+$/, "")).join("\n")
        terminalOutput("Trailing whitespace trimmed")
    }

    // ── Indent selection ─────────────────────────────────────────────────────
    function indentSelection(direction) {
        var sel = fileText.selectedText
        if (sel.length === 0) return
        var tab   = "    ".substring(0, appWindow.tabSize)
        var s     = fileText.selectionStart
        var lines = sel.split("\n").map(l => direction > 0 ? tab + l : l.replace(/^    /, "").replace(/^\t/, ""))
        fileText.remove(s, fileText.selectionEnd)
        fileText.insert(s, lines.join("\n"))
    }

    // ── Reusable DropButton ──────────────────────────────────────────────────
    component DropButton: Item {
        id: dropRoot
        width: btn.width
        height: btn.height
        property string label: "Menu"
        property var    items: []
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
                color: appWindow.thPopupBg; border.color: appWindow.thBorder
                border.width: 1; radius: 6
            }

            Column {
                width: 220; spacing: 2; padding: 4
                Repeater {
                    model: dropRoot.items
                    delegate: Item {
                        width: parent.width
                        height: modelData === "---" ? 8 : 30

                        Rectangle {
                            visible: modelData === "---"
                            width: parent.width; height: 1
                            color: appWindow.thPopupSep
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            visible: modelData !== "---"
                            anchors.fill: parent; radius: 4
                            color: itemMouse.containsMouse ? appWindow.thPopupHover : appWindow.thPopupItem
                            border.color: appWindow.thBorder; border.width: 1

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left; anchors.leftMargin: 10
                                text: modelData; color: appWindow.thPopupText; font.pixelSize: 12
                            }

                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent; hoverEnabled: true
                                onClicked: { popup.close(); dropRoot.itemSelected(modelData) }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Find / Replace bar ───────────────────────────────────────────────────
    Rectangle {
        id: findBar
        visible: false; z: 10; height: 38
        anchors.left: sideBar.right; anchors.right: parent.right
        anchors.top: topBar.bottom
        color: "#f0f4ff"; border.color: "#adb5bd"; border.width: 1

        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left; anchors.leftMargin: 10
            spacing: 6

            TextField { id: findField; placeholderText: "Find…"; width: 160; onTextChanged: findBar.highlightFind(); background: Rectangle { color: "white"; border.color: "#cccccc"; radius: 3 } }
            TextField { id: replaceField; placeholderText: "Replace…"; width: 160; background: Rectangle { color: "white"; border.color: "#cccccc"; radius: 3 } }
            CheckBox  { id: caseSensitive; text: "Aa" }
            CheckBox  { id: regexMode; text: ".*" }
            Button    { text: "Next";    onClicked: findBar.findNext() }
            Button    { text: "Prev";    onClicked: findBar.findPrev() }
            Button    { text: "Replace"; onClicked: findBar.replaceCurrent() }
            Button    { text: "All";     onClicked: findBar.replaceAll() }
            Text      { anchors.verticalCenter: parent.verticalCenter; text: findBar.matchCount > 0 ? findBar.matchCount + " matches" : ""; color: "#555"; font.pixelSize: 11 }
            Button    { text: "✕"; onClicked: { findBar.visible = false; fileText.deselect() } }
        }

        property int lastIndex:  -1
        property int matchCount: 0

        function countMatches(needle) {
            if (needle.length === 0) { matchCount = 0; return }
            var hay = caseSensitive.checked ? fileText.text : fileText.text.toLowerCase()
            var n   = caseSensitive.checked ? needle : needle.toLowerCase()
            var count = 0; var pos = 0
            while ((pos = hay.indexOf(n, pos)) !== -1) { count++; pos += n.length }
            matchCount = count
        }

        function highlightFind() { lastIndex = -1; countMatches(findField.text); findNext() }

        function findNext() {
            var needle = findField.text; if (needle.length === 0) return
            var hay   = caseSensitive.checked ? fileText.text : fileText.text.toLowerCase()
            var n     = caseSensitive.checked ? needle : needle.toLowerCase()
            var start = (lastIndex >= 0) ? lastIndex + needle.length : fileText.cursorPosition
            var idx   = hay.indexOf(n, start)
            if (idx === -1) idx = hay.indexOf(n, 0)
            if (idx !== -1) { fileText.select(idx, idx + needle.length); fileText.cursorPosition = idx + needle.length; lastIndex = idx }
        }

        function findPrev() {
            var needle = findField.text; if (needle.length === 0) return
            var hay   = caseSensitive.checked ? fileText.text : fileText.text.toLowerCase()
            var n     = caseSensitive.checked ? needle : needle.toLowerCase()
            var end   = (lastIndex > 0) ? lastIndex - 1 : fileText.text.length
            var idx   = hay.lastIndexOf(n, end)
            if (idx !== -1) { fileText.select(idx, idx + needle.length); fileText.cursorPosition = idx; lastIndex = idx }
        }

        function replaceCurrent() {
            if (fileText.selectedText.toLowerCase() === findField.text.toLowerCase() && findField.text.length > 0) {
                var s = fileText.selectionStart
                fileText.remove(fileText.selectionStart, fileText.selectionEnd)
                fileText.insert(s, replaceField.text)
                findNext()
            } else { findNext() }
        }

        function replaceAll() {
            var needle = findField.text; if (needle.length === 0) return
            var before = fileText.text.split(needle).length - 1
            fileText.text = fileText.text.split(needle).join(replaceField.text)
            terminalOutput("Replaced " + before + " occurrence(s) of '" + needle + "'")
            matchCount = 0
        }
    }

    // ── Tab bar ──────────────────────────────────────────────────────────────
    Rectangle {
        id: tabBarContainer
        visible: tabBar.model.count > 0
        anchors.left: sideBar.right; anchors.right: parent.right
        anchors.top: findBar.visible ? findBar.bottom : topBar.bottom
        height: visible ? 28 : 0
        color: "#f0f0f0"; border.color: "#adb5bd"; border.width: 1; z: 5

        QtObject {
            id: tabBar
            property var model: ListModel {}
            property int currentIndex: 0

            function addTab(name) {
                for (var i = 0; i < model.count; i++) if (model.get(i).name === name) { currentIndex = i; return }
                model.append({ name: name })
                currentIndex = model.count - 1
            }
            function closeTab(idx) {
                model.remove(idx)
                if (currentIndex >= model.count) currentIndex = model.count - 1
            }
        }

        Row {
            anchors.fill: parent; spacing: 0
            Repeater {
                model: tabBar.model
                delegate: Rectangle {
                    height: parent.height; width: Math.min(160, tabLabel.implicitWidth + 32)
                    color: tabBar.currentIndex === index ? "#ffffff" : "#e0e0e0"
                    border.color: "#adb5bd"; border.width: 1
                    Row {
                        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 4; spacing: 4
                        Text { id: tabLabel; text: name; font.pixelSize: 11; color: "#333"; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight }
                        Text {
                            text: "×"; font.pixelSize: 13; color: "#888"; anchors.verticalCenter: parent.verticalCenter
                            MouseArea { anchors.fill: parent; onClicked: tabBar.closeTab(index) }
                        }
                    }
                    MouseArea { anchors.fill: parent; onClicked: tabBar.currentIndex = index; z: -1 }
                }
            }
        }
    }

    // ── Main background ──────────────────────────────────────────────────────
    Rectangle {
        id: mainBg
        anchors.fill: parent
        color: appWindow.thBg; border.color: appWindow.thBorder; border.width: 1

        // ── Top bar ──────────────────────────────────────────────────────────
        Rectangle {
            id: topBar
            width: parent.width; height: 40
            anchors.top: parent.top
            color: appWindow.thTopBar; border.color: appWindow.thBorder; border.width: 1

            Row {
                anchors.verticalCenter: parent.verticalCenter
                x: contentArea.x + (contentArea.width - width) / 2
                spacing: 6

                // Search
                TextField {
                    id: searchField
                    placeholderText: "Search…"
                    color: "#333333"; placeholderTextColor: "#999999"; width: 120
                    background: Rectangle { color: "#ffffff"; border.color: "#cccccc"; radius: 4 }
                    onTextChanged: {
                        if (text.length > 0) {
                            var idx = fileText.text.indexOf(text)
                            if (idx !== -1) { fileText.select(idx, idx + text.length); fileText.cursorPosition = idx }
                        }
                    }
                }

                // Go to line
                TextField {
                    id: gotoLine
                    placeholderText: "Go to line…"
                    width: 80; horizontalAlignment: Text.AlignHCenter
                    color: "#333333"; placeholderTextColor: "#999999"
                    background: Rectangle { color: "#ffffff"; border.color: "#cccccc"; radius: 4 }
                    onAccepted: {
                        var line  = parseInt(text)
                        var lines = fileText.text.split("\n")
                        if (line > 0 && line <= lines.length) {
                            var pos = 0
                            for (var i = 0; i < line - 1; i++) pos += lines[i].length + 1
                            fileText.cursorPosition = pos
                        }
                        text = ""
                    }
                }

                // Theme toggle
                Button {
                    text: appWindow.darkTheme ? "☀ Light" : "🌙 Dark"
                    onClicked: applyTheme(!appWindow.darkTheme)
                }

                // Font
                DropButton {
                    label: "Font"
                    items: ["Font +", "Font -", "---", "Size 8", "Size 10", "Size 12", "Size 14", "Size 16", "Size 20", "Size 24", "---", "Courier New", "Fira Code", "Consolas", "JetBrains Mono", "Monospace"]
                    onItemSelected: (name) => {
                        if      (name === "Font +")       { if (editorFontSize < 32) appWindow.editorFontSize++ }
                        else if (name === "Font -")       { if (editorFontSize > 6)  appWindow.editorFontSize-- }
                        else if (name.startsWith("Size ")) appWindow.editorFontSize = parseInt(name.split(" ")[1])
                        else                               appWindow.editorFontFamily = name
                    }
                }

                // Edit
                DropButton {
                    label: "Edit"
                    items: ["Undo", "Redo", "---", "Cut", "Copy", "Paste", "---",
                            "Select All", "Copy All", "Clear",
                            "---", "Find & Replace",
                            "---", "Duplicate Line", "Delete Line", "Move Line Up", "Move Line Down",
                            "---", "Toggle Comment", "Block Comment",
                            "---", "Indent →", "Outdent ←"]
                    onItemSelected: (name) => {
                        if      (name === "Undo")           fileText.undo()
                        else if (name === "Redo")           fileText.redo()
                        else if (name === "Cut")            fileText.cut()
                        else if (name === "Copy")           fileText.copy()
                        else if (name === "Paste")          fileText.paste()
                        else if (name === "Select All")     fileText.selectAll()
                        else if (name === "Copy All")       { fileText.selectAll(); fileText.copy(); fileText.deselect() }
                        else if (name === "Clear")          fileText.text = ""
                        else if (name === "Find & Replace") { findBar.visible = true; findField.forceActiveFocus() }
                        else if (name === "Duplicate Line") duplicateLine()
                        else if (name === "Delete Line")    deleteLine()
                        else if (name === "Move Line Up")   moveLine(-1)
                        else if (name === "Move Line Down") moveLine(1)
                        else if (name === "Toggle Comment") toggleComment()
                        else if (name === "Block Comment")  blockComment()
                        else if (name === "Indent →")       indentSelection(1)
                        else if (name === "Outdent ←")      indentSelection(-1)
                    }
                }

                // Format
                DropButton {
                    label: "Format"
                    items: ["Wrap On", "Wrap Off", "---",
                            "Uppercase", "Lowercase", "Title Case",
                            "---", "Sort Lines A→Z", "Sort Lines Z→A",
                            "Remove Duplicate Lines", "Trim Trailing Space",
                            "---", "Tab Size 2", "Tab Size 4", "Tab Size 8",
                            "---", "Encode to Base64", "Decode Base64"]
                    onItemSelected: (name) => {
                        if      (name === "Wrap On")             { fileText.wrapMode = TextArea.Wrap;   appWindow.wordWrap = true }
                        else if (name === "Wrap Off")            { fileText.wrapMode = TextArea.NoWrap;  appWindow.wordWrap = false }
                        else if (name === "Uppercase")           transformSelection(s => s.toUpperCase())
                        else if (name === "Lowercase")           transformSelection(s => s.toLowerCase())
                        else if (name === "Title Case")          transformSelection(s => s.replace(/\b\w/g, c => c.toUpperCase()))
                        else if (name === "Sort Lines A→Z")      sortLines(true)
                        else if (name === "Sort Lines Z→A")      sortLines(false)
                        else if (name === "Remove Duplicate Lines") removeDuplicateLines()
                        else if (name === "Trim Trailing Space")  trimTrailing()
                        else if (name === "Tab Size 2")           { appWindow.tabSize = 2; fileText.tabStopDistance = 16 }
                        else if (name === "Tab Size 4")           { appWindow.tabSize = 4; fileText.tabStopDistance = 24 }
                        else if (name === "Tab Size 8")           { appWindow.tabSize = 8; fileText.tabStopDistance = 48 }
                        else if (name === "Encode to Base64")     encodeBase64()
                        else if (name === "Decode Base64")        decodeBase64()
                    }
                }

                // File
                DropButton {
                    id: fileDrop
                    label: "File"
                    property bool autoSave: false
                    property var  recentFiles: []

                    function rebuildItems() {
                        var base    = ["New", "Open", "Save", "Save As", "---",
                                       "Close Tab", "---",
                                       autoSave ? "Auto-Save: ON" : "Auto-Save: OFF"]
                        var recents = recentFiles.length > 0 ? ["---", "Recent Files:"].concat(recentFiles.slice(0, 5)) : []
                        items = base.concat(recents)
                    }
                    Component.onCompleted: rebuildItems()

                    onItemSelected: (name) => {
                        if      (name === "New")     { fileText.text = ""; placeholderText.visible = true; statusBar.message = "New file" }
                        else if (name === "Open")     openDialog.open()
                        else if (name === "Save" || name === "Save As") saveDialog.open()
                        else if (name === "Close Tab") tabBar.closeTab(tabBar.currentIndex)
                        else if (name === "Auto-Save: OFF" || name === "Auto-Save: ON") {
                            autoSave = !autoSave; rebuildItems()
                            terminalOutput("Auto-save " + (autoSave ? "enabled" : "disabled"))
                        }
                    }

                    Timer {
                        interval: 30000
                        running: parent.autoSave && fileText.text !== ""
                        repeat: true
                        onTriggered: saveDialog.open()
                    }
                }

                // View
                DropButton {
                    label: "View"
                    items: ["Zoom In", "Zoom Out", "Reset Zoom", "---",
                            "Toggle Line Highlight", "Toggle Line Numbers",
                            "Toggle Minimap", "Toggle Terminal",
                            "Toggle Breadcrumb", "Toggle Split View",
                            "Toggle Whitespace",
                            "---", "Preferences"]
                    onItemSelected: (name) => {
                        if      (name === "Zoom In")            { if (editorFontSize < 32) appWindow.editorFontSize += 2 }
                        else if (name === "Zoom Out")           { if (editorFontSize > 6)  appWindow.editorFontSize -= 2 }
                        else if (name === "Reset Zoom")          appWindow.editorFontSize = 12
                        else if (name === "Toggle Line Highlight") { lineHighlight = !lineHighlight; cursorHighlight.visible = lineHighlight }
                        else if (name === "Toggle Line Numbers") {
                            showLineNumbers = !showLineNumbers
                            lineNumbers.visible = showLineNumbers; lineNumbers.width = showLineNumbers ? 38 : 0; divider.visible = showLineNumbers
                        }
                        else if (name === "Toggle Minimap")       appWindow.showMinimap   = !appWindow.showMinimap
                        else if (name === "Toggle Terminal")      appWindow.showTerminal  = !appWindow.showTerminal
                        else if (name === "Toggle Breadcrumb")    appWindow.showBreadcrumb = !appWindow.showBreadcrumb
                        else if (name === "Toggle Split View")    appWindow.splitView     = !appWindow.splitView
                        else if (name === "Toggle Whitespace")    appWindow.showWhitespace = !appWindow.showWhitespace
                        else if (name === "Preferences")          appWindow.viewMode = "preferences"
                    }
                }

                // Tools
                DropButton {
                    label: "Tools"
                    items: ["Run Script", "Build", "Lint File",
                            "---",
                            macroRecording ? "⏹ Stop Macro" : "⏺ Record Macro",
                            "▶ Play Macro", "Clear Macro",
                            "---",
                            "Word Count", "Char Frequency",
                            "Show Hex View",
                            "---",
                            "Git Status", "Git Diff", "Git Commit",
                            "---",
                            "Format JSON", "Format XML",
                            "---",
                            "Hash MD5", "Hash SHA256"]
                    onItemSelected: (name) => {
                        if      (name === "⏺ Record Macro")      { appWindow.macroRecording = true;  appWindow.macroSteps = []; terminalOutput("Macro recording started") }
                        else if (name === "⏹ Stop Macro")        { appWindow.macroRecording = false; terminalOutput("Macro recording stopped (" + appWindow.macroSteps.length + " steps)") }
                        else if (name === "▶ Play Macro")         macroEngine.playback()
                        else if (name === "Clear Macro")          { appWindow.macroSteps = []; terminalOutput("Macro cleared") }
                        else if (name === "Word Count")           terminalOutput("Words: " + statsRefresh.wordCount + "  Chars: " + statsRefresh.charCount + "  Lines: " + statsRefresh.lineCount)
                        else if (name === "Char Frequency")       charFrequency()
                        else if (name === "Git Status")           terminalOutput("git status → branch: " + appWindow.gitBranch + " (simulated)")
                        else if (name === "Git Diff")             terminalOutput("git diff → no staged changes (simulated)")
                        else if (name === "Git Commit")           terminalOutput("git commit → nothing to commit (simulated)")
                        else if (name === "Format JSON")          formatJSON()
                        else if (name === "Format XML")           terminalOutput("XML formatter: plug in your XML library here")
                        else if (name === "Hash MD5")             terminalOutput("MD5: (plug in your hash backend here)")
                        else if (name === "Hash SHA256")          terminalOutput("SHA-256: (plug in your hash backend here)")
                        else if (name === "Run Script")           terminalOutput("Run: (connect your script runner here)")
                        else if (name === "Build")                terminalOutput("Build: (connect your build system here)")
                        else if (name === "Lint File")            terminalOutput("Lint: (connect your linter here)")
                        else if (name === "Show Hex View")        hexDialog.open()
                    }
                }

                // Preferences short
                DropButton {
                    label: "Settings"
                    items: ["Project Settings", "Environment", "C++ Settings", "Git Config", "Keybindings", "---", "Open Preferences"]
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
            color: appWindow.thSide; border.color: appWindow.thBorder; border.width: 1; z: 1

            Rectangle {
                id: sideHeader
                width: parent.width; height: 40
                color: appWindow.darkTheme ? "#333333" : "#eeeeee"; border.color: appWindow.thBorder; border.width: 1
                Text { text: "JViewer"; anchors.centerIn: parent; color: appWindow.thText; font.pixelSize: 15; font.bold: true }
            }

            Column {
                id: sideButtons
                anchors.top: sideHeader.bottom; anchors.topMargin: 8
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6

                Repeater {
                    model: ["New File", "Load File", "Save File", "---",
                            "Find & Replace", "Go to Symbol",
                            "---",
                            "Terminal", "Minimap",
                            "---",
                            "Settings", "Exit"]
                    delegate: Item {
                        width: 144
                        height: modelData === "---" ? 6 : 28

                        Rectangle {
                            visible: modelData === "---"
                            width: parent.width; height: 1; color: "#e0e0e0"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Button {
                            visible: modelData !== "---"
                            text: modelData; width: parent.width; height: 28
                            font.pixelSize: 11
                            onClicked: {
                                if      (modelData === "New File")      { fileText.text = ""; placeholderText.visible = true; statusBar.message = "New file" }
                                else if (modelData === "Load File")      openDialog.open()
                                else if (modelData === "Save File")      saveDialog.open()
                                else if (modelData === "Find & Replace") { findBar.visible = true; findField.forceActiveFocus() }
                                else if (modelData === "Go to Symbol")   terminalOutput("Symbol browser: connect your parser here")
                                else if (modelData === "Terminal")        appWindow.showTerminal  = !appWindow.showTerminal
                                else if (modelData === "Minimap")         appWindow.showMinimap   = !appWindow.showMinimap
                                else if (modelData === "Settings")        appWindow.viewMode = "preferences"
                                else if (modelData === "Exit")            Qt.quit()
                            }
                        }
                    }
                }
            }

            // Commands list
            Rectangle {
                id: commandsBox
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: sideButtons.bottom; anchors.topMargin: 8
                width: 144; height: 130
                radius: 4; color: appWindow.darkTheme ? "#333333" : "#eeeeee"; border.color: appWindow.thBorder; border.width: 1

                Text {
                    id: commandsLabel
                    text: "Commands"
                    font.pixelSize: 10; font.bold: true; color: appWindow.thSubText
                    anchors.top: parent.top; anchors.left: parent.left
                    anchors.leftMargin: 6; anchors.topMargin: 4
                }

                Component {
                    id: commandDelegate
                    Item {
                        required property string commandName
                        required property string isCommandExecutable
                        width: ListView.view.width; height: 26
                        Row {
                            anchors.fill: parent; anchors.margins: 4; spacing: 4
                            Text { text: commandName; font.pixelSize: 10; color: appWindow.thText; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight; width: parent.width - status.width - 4 }
                            Text { id: status; text: isCommandExecutable; font.pixelSize: 10; color: isCommandExecutable === "✔" ? "green" : "red"; verticalAlignment: Text.AlignVCenter }
                        }
                    }
                }

                ListView {
                    anchors.fill: parent; anchors.topMargin: 20
                    model: CommandsList {}
                    delegate: commandDelegate
                    highlight: Rectangle { color: "lightsteelblue"; radius: 3 }
                    focus: true; clip: true
                }
            }

            // Stats panel
            Column {
                anchors.bottom: parent.bottom; anchors.bottomMargin: 6
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 3; width: parent.width - 8

                // Words/chars
                Rectangle {
                    width: parent.width; height: 22; radius: 3
                    color: appWindow.darkTheme ? "#333" : "#f0f0f0"; border.color: appWindow.thBorder; border.width: 1
                    Text { anchors.centerIn: parent; font.pixelSize: 10; color: appWindow.thSubText
                        text: "W:" + statsRefresh.wordCount + " C:" + statsRefresh.charCount + " L:" + statsRefresh.lineCount }
                }

                // Byte count
                Rectangle {
                    width: parent.width; height: 22; radius: 3
                    color: appWindow.darkTheme ? "#333" : "#f0f0f0"; border.color: appWindow.thBorder; border.width: 1
                    Text { anchors.centerIn: parent; font.pixelSize: 10; color: appWindow.thSubText
                        text: statsRefresh.byteCount < 1024 ? statsRefresh.byteCount + " B" : (statsRefresh.byteCount / 1024).toFixed(2) + " KB" }
                }

                // Selection
                Rectangle {
                    width: parent.width; height: 22; radius: 3
                    color: appWindow.darkTheme ? "#333" : "#f0f0f0"; border.color: appWindow.thBorder; border.width: 1
                    Text { anchors.centerIn: parent; font.pixelSize: 10; color: appWindow.thSubText; text: statsRefresh.selInfo }
                }

                // Macro indicator
                Rectangle {
                    width: parent.width; height: 22; radius: 3
                    color: appWindow.macroRecording ? "#ffe0e0" : "#f0f0f0"
                    border.color: appWindow.macroRecording ? "#ff8080" : "#ddd"; border.width: 1
                    Text { anchors.centerIn: parent; font.pixelSize: 10
                        color: appWindow.macroRecording ? "#cc0000" : "#aaa"
                        text: appWindow.macroRecording ? "⏺ REC " + appWindow.macroSteps.length : "No macro" }
                }

                // Mouse position
                Text {
                    width: parent.width; horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 10; color: "#aaa"
                    text: appWindow.mouseX + "," + appWindow.mouseY
                }
            }
        }

        // ── Content area ─────────────────────────────────────────────────────
        Rectangle {
            id: contentArea
            anchors.left: sideBar.right; anchors.right: parent.right
            anchors.top: tabBarContainer.visible ? tabBarContainer.bottom : (findBar.visible ? findBar.bottom : topBar.bottom)
            anchors.bottom: parent.bottom
            anchors.margins: 8
            color: appWindow.thContent; radius: 4; border.color: appWindow.thBorder; border.width: 1

            // Breadcrumb
            Rectangle {
                id: breadcrumb
                visible: appWindow.showBreadcrumb && appWindow.viewMode === "editor"
                anchors.top: parent.top; anchors.left: parent.left; anchors.right: minimap.visible ? minimap.left : parent.right
                height: visible ? 22 : 0
                color: appWindow.darkTheme ? "#2a2a2a" : "#f5f5f5"; border.color: appWindow.thBorder; border.width: 1

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left; anchors.leftMargin: 8
                    spacing: 4
                    Text { text: "File"; font.pixelSize: 10; color: appWindow.thLineNum }
                    Text { text: "›"; font.pixelSize: 10; color: appWindow.thLineNum }
                    Text { text: appWindow.currentLanguage; font.pixelSize: 10; color: appWindow.thSubText }
                    Text { text: "›"; font.pixelSize: 10; color: appWindow.thLineNum }
                    Text { text: "Ln " + appWindow.currentLineNumber(); font.pixelSize: 10; color: appWindow.thSubText }
                }
            }

            Text {
                id: placeholderText
                text: "Choose a file to get started or create something new"
                anchors.centerIn: parent
                color: "#999999"; font.pixelSize: 14; font.italic: true
                width: parent.width * 0.8; horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap; visible: fileText.text === ""
            }

            // ── Editor view ──────────────────────────────────────────────────
            Item {
                id: editorArea
                visible: appWindow.viewMode === "editor"
                anchors.top: breadcrumb.visible ? breadcrumb.bottom : parent.top
                anchors.left: parent.left
                anchors.right: minimap.visible ? minimap.left : parent.right
                anchors.bottom: terminalPanel.visible ? terminalPanel.top : statusBar.top
                anchors.margins: 4

                // Split view — second editor pane
                Row {
                    anchors.fill: parent; spacing: 2

                    ScrollView {
                        id: fileScroll
                        width: appWindow.splitView ? parent.width / 2 - 1 : parent.width
                        height: parent.height

                        Row {
                            width: fileScroll.width; spacing: 0

                            TextArea {
                                id: lineNumbers
                                visible: appWindow.showLineNumbers
                                width: appWindow.showLineNumbers ? 38 : 0
                                readOnly: true
                                font.family: appWindow.editorFontFamily
                                font.pixelSize: appWindow.editorFontSize
                                color: appWindow.thLineNum
                                background: Rectangle { color: appWindow.darkTheme ? "#252525" : "#f0f0f0" }
                                wrapMode: TextArea.NoWrap; selectByMouse: false
                                topPadding: 0; bottomPadding: 0; leftPadding: 2; rightPadding: 2
                                horizontalAlignment: Text.AlignRight

                                text: {
                                    var count = fileText.text === "" ? 1 : fileText.text.split("\n").length
                                    var r = ""
                                    for (var i = 1; i <= count; i++) r += i + "\n"
                                    return r
                                }
                            }

                            Rectangle { id: divider; width: appWindow.showLineNumbers ? 1 : 0; height: fileScroll.height; color: "#cccccc" }

                            TextArea {
                                id: fileText
                                width: fileScroll.width - lineNumbers.width - divider.width
                                text: ""; color: appWindow.thText
                                font.pixelSize: appWindow.editorFontSize
                                font.family: appWindow.editorFontFamily
                                wrapMode: TextArea.NoWrap; background: null
                                readOnly: false
                                leftPadding: 4; rightPadding: 4; topPadding: 0; bottomPadding: 0
                                selectByMouse: true; cursorVisible: true; focus: true
                                tabStopDistance: 24

                                palette { highlight: "#3399ff"; highlightedText: "white" }

                                onTextChanged:         { statsDebounce.restart(); if (macroRecording && event) macroEngine.record({ type: "insert", text: "" }) }
                                onSelectedTextChanged:  statsDebounce.restart()

                                // Current line highlight
                                Rectangle {
                                    id: cursorHighlight
                                    width: parent.width; height: fileText.cursorRectangle.height
                                    y: fileText.cursorRectangle.y
                                    color: "#d0e7ff"; z: -1
                                    visible: appWindow.lineHighlight
                                }

                                Keys.onPressed: (event) => {
                                    var ctrl  = (event.modifiers & Qt.ControlModifier) !== 0
                                    var shift = (event.modifiers & Qt.ShiftModifier)   !== 0
                                    var noMod = event.modifiers === Qt.NoModifier

                                    if (ctrl && event.key === Qt.Key_D)      { duplicateLine();  event.accepted = true }
                                    else if (ctrl && event.key === Qt.Key_Slash) { toggleComment(); event.accepted = true }
                                    else if (ctrl && event.key === Qt.Key_F) { findBar.visible = true; findField.forceActiveFocus(); event.accepted = true }
                                    else if (ctrl && event.key === Qt.Key_G) { gotoLine.forceActiveFocus(); event.accepted = true }
                                    else if (ctrl && event.key === Qt.Key_Z && !shift) { fileText.undo(); event.accepted = true }
                                    else if (ctrl && event.key === Qt.Key_Z &&  shift) { fileText.redo(); event.accepted = true }
                                    else if (ctrl && event.key === Qt.Key_Y) { fileText.redo(); event.accepted = true }
                                    else if (ctrl && event.key === Qt.Key_A) { fileText.selectAll(); event.accepted = true }
                                    else if (ctrl && event.key === Qt.Key_X) { fileText.cut(); event.accepted = true }
                                    else if (ctrl && event.key === Qt.Key_C) { fileText.copy(); event.accepted = true }
                                    else if (ctrl && event.key === Qt.Key_V) { fileText.paste(); event.accepted = true }
                                    else if (ctrl && event.key === Qt.Key_S) { saveDialog.open(); event.accepted = true }
                                    else if (ctrl && event.key === Qt.Key_O) { openDialog.open(); event.accepted = true }
                                    else if (ctrl && event.key === Qt.Key_N) { fileText.text = ""; placeholderText.visible = true; event.accepted = true }
                                    else if (ctrl && event.key === Qt.Key_Plus)  { if (editorFontSize < 32) appWindow.editorFontSize += 1; event.accepted = true }
                                    else if (ctrl && event.key === Qt.Key_Minus) { if (editorFontSize > 6)  appWindow.editorFontSize -= 1; event.accepted = true }
                                    else if (ctrl && event.key === Qt.Key_BracketRight) { indentSelection(1);  event.accepted = true }
                                    else if (ctrl && event.key === Qt.Key_BracketLeft)  { indentSelection(-1); event.accepted = true }
                                    else if (ctrl && event.key === Qt.Key_Backslash) { appWindow.splitView = !appWindow.splitView; event.accepted = true }
                                    else if (ctrl && event.key === Qt.Key_Grave) { appWindow.showTerminal = !appWindow.showTerminal; event.accepted = true }

                                    // Auto-indent on Enter
                                    else if (noMod && event.key === Qt.Key_Return && appWindow.autoIndentEnabled) {
                                        var cur = fileText.cursorPosition
                                        var bef = fileText.text.substring(0, cur)
                                        var ln  = bef.split("\n").pop()
                                        var ind = ln.match(/^\s*/)[0]
                                        // Extra indent after {
                                        if (ln.trimEnd().endsWith("{")) ind += "    "
                                        fileText.insert(cur, "\n" + ind)
                                        event.accepted = true
                                    }

                                    // Bracket / quote auto-close
                                    else if (noMod && event.text.length === 1) {
                                        var pairs = { "(": ")", "[": "]", "{": "}", '"': '"', "'": "'" }
                                        var ch = event.text
                                        if (pairs.hasOwnProperty(ch)) {
                                            var cp  = fileText.cursorPosition
                                            var sel = fileText.selectedText
                                            if (sel.length > 0) {
                                                var ss = fileText.selectionStart; var se = fileText.selectionEnd
                                                fileText.remove(ss, se); fileText.insert(ss, ch + sel + pairs[ch])
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

                    // Split pane
                    ScrollView {
                        id: splitScroll
                        visible: appWindow.splitView
                        width: appWindow.splitView ? parent.width / 2 - 1 : 0
                        height: parent.height

                        TextArea {
                            id: fileText2
                            width: splitScroll.width
                            text: fileText.text
                            color: fileText.color
                            font.pixelSize: appWindow.editorFontSize
                            font.family: appWindow.editorFontFamily
                            wrapMode: TextArea.NoWrap; background: null
                            readOnly: true
                            leftPadding: 4; rightPadding: 4
                            selectByMouse: true
                        }
                    }
                }
            }

            // ── Minimap ──────────────────────────────────────────────────────
            Rectangle {
                id: minimap
                visible: appWindow.showMinimap && appWindow.viewMode === "editor"
                anchors.top: breadcrumb.visible ? breadcrumb.bottom : parent.top
                anchors.right: parent.right
                anchors.bottom: terminalPanel.visible ? terminalPanel.top : statusBar.top
                width: visible ? 80 : 0
                color: appWindow.darkTheme ? "#252525" : "#f9f9f9"; border.color: appWindow.thBorder; border.width: 1

                Text {
                    anchors.top: parent.top; anchors.topMargin: 4
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "MAP"; font.pixelSize: 8; color: appWindow.thLineNum; font.bold: true
                }

                // Simulated minimap content
                TextArea {
                    anchors.fill: parent; anchors.topMargin: 16
                    text: fileText.text
                    font.pixelSize: 2; color: appWindow.thLineNum
                    readOnly: true; background: null
                    wrapMode: TextArea.Wrap
                    leftPadding: 2; rightPadding: 2
                    selectByMouse: false
                }

                // Viewport indicator
                Rectangle {
                    anchors.top: parent.top; anchors.topMargin: 16
                    anchors.left: parent.left; anchors.right: parent.right
                    height: 30; color: "#0078d420"; border.color: "#0078d440"; border.width: 1
                }
            }

            // ── Terminal panel ───────────────────────────────────────────────
            Rectangle {
                id: terminalPanel
                visible: appWindow.showTerminal && appWindow.viewMode === "editor"
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: statusBar.top
                height: visible ? appWindow.terminalHeight : 0
                color: "#1e1e1e"; border.color: "#333"; border.width: 1

                // Resize handle
                Rectangle {
                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                    height: 4; color: "#444"
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.SizeVerCursor
                        property int startY: 0; property int startH: 0
                        onPressed:  (mouse) => { startY = mouse.y; startH = appWindow.terminalHeight }
                        onPositionChanged: (mouse) => {
                            var delta = startY - mouse.y
                            appWindow.terminalHeight = Math.max(60, Math.min(400, startH + delta))
                        }
                    }
                }

                // Terminal header
                Rectangle {
                    id: terminalHeader
                    anchors.top: parent.top; anchors.topMargin: 4
                    anchors.left: parent.left; anchors.right: parent.right
                    height: 22; color: "#2d2d2d"

                    Row {
                        anchors.fill: parent; anchors.leftMargin: 8; spacing: 8
                        Text { text: "TERMINAL"; color: "#aaa"; font.pixelSize: 10; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "OUTPUT"; color: "#666"; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "PROBLEMS"; color: "#666"; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Row {
                        anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                        Button {
                            text: "🗑"; font.pixelSize: 10; height: 18
                            onClicked: terminalText.text = ""
                        }
                        Button {
                            text: "✕"; font.pixelSize: 10; height: 18
                            onClicked: appWindow.showTerminal = false
                        }
                    }
                }

                ScrollView {
                    anchors.top: terminalHeader.bottom; anchors.left: parent.left
                    anchors.right: parent.right; anchors.bottom: terminalInput.top
                    clip: true

                    TextArea {
                        id: terminalText
                        text: "JViewer Terminal ready.\n"
                        color: "#cccccc"; background: null
                        font.family: "Courier New"; font.pixelSize: 11
                        readOnly: true; wrapMode: TextArea.Wrap
                        leftPadding: 8
                    }
                }

                // Terminal input line
                Rectangle {
                    id: terminalInput
                    anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
                    height: 24; color: "#111"

                    Row {
                        anchors.fill: parent; anchors.leftMargin: 6; spacing: 4
                        Text { text: "$ "; color: "#4ec9b0"; font.family: "Courier New"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        TextField {
                            id: termInputField
                            width: parent.width - 20; height: parent.height
                            color: "#cccccc"; placeholderTextColor: "#555"
                            placeholderText: "Enter command…"
                            font.family: "Courier New"; font.pixelSize: 11
                            background: null
                            onAccepted: {
                                if (text.trim().length > 0) {
                                    terminalOutput("> " + text)
                                    terminalOutput("(command execution: connect your shell backend here)")
                                    text = ""
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
                    anchors.fill: parent; spacing: 0

                    // Nav sidebar
                    Rectangle {
                        width: 180; height: parent.height
                        color: appWindow.thSide; border.color: appWindow.thBorder; border.width: 1

                        Column {
                            id: navColumn
                            anchors.fill: parent; spacing: 0
                            property string currentTab: "General"

                            Rectangle {
                                width: parent.width; height: 40; color: appWindow.darkTheme ? "#333" : "#eeeeee"
                                border.color: appWindow.thBorder; border.width: 1
                                Text { text: "Settings"; anchors.centerIn: parent; color: appWindow.thText; font.pixelSize: 15; font.bold: true }
                            }

                            Column {
                                width: parent.width; spacing: 4
                                anchors.top: parent.top; anchors.topMargin: 50
                                anchors.left: parent.left; anchors.leftMargin: 8
                                anchors.right: parent.right; anchors.rightMargin: 8

                                Repeater {
                                    model: ["General", "Editor", "Appearance", "Keybindings", "Extensions", "Git", "Build & Run"]
                                    delegate: Rectangle {
                                        width: parent.width; height: 32; radius: 4
                                        color: navColumn.currentTab === modelData ? "#e8f0fe" : "transparent"
                                        border.color: navColumn.currentTab === modelData ? "#0078d4" : "transparent"; border.width: 1
                                        Text {
                                            text: modelData; anchors.verticalCenter: parent.verticalCenter
                                            anchors.left: parent.left; anchors.leftMargin: 12
                                            color: navColumn.currentTab === modelData ? "#0078d4" : appWindow.thText; font.pixelSize: 12
                                        }
                                        MouseArea {
                                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onEntered: { if (navColumn.currentTab !== modelData) parent.color = appWindow.darkTheme ? "#3a3a3a" : "#f0f0f0" }
                                            onExited:  { if (navColumn.currentTab !== modelData) parent.color = "transparent" }
                                            onClicked: navColumn.currentTab = modelData
                                        }
                                    }
                                }
                            }

                            Button {
                                text: "← Back to Editor"
                                width: parent.width - 16; height: 32
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom; anchors.bottomMargin: 12
                                onClicked: appWindow.viewMode = "editor"
                            }
                        }
                    }

                    // Settings content
                    Rectangle {
                        width: parent.width - 180; height: parent.height
                        color: appWindow.thContent; border.color: appWindow.thBorder; border.width: 1

                        StackLayout {
                            anchors.fill: parent; anchors.margins: 20
                            currentIndex: {
                                var tabs = ["General","Editor","Appearance","Keybindings","Extensions","Git","Build & Run"]
                                return tabs.indexOf(navColumn.currentTab)
                            }

                            // PAGE 0: General
                            Column {
                                spacing: 16
                                Text { text: "General Settings"; font.pixelSize: 18; font.bold: true; color: appWindow.thText }
                                Rectangle { width: parent.width; height: 1; color: appWindow.thBorder }
                                Column {
                                    spacing: 12; width: parent.width
                                    CheckBox { text: "Auto-save on focus lost"; checked: fileDrop.autoSave; onCheckedChanged: { fileDrop.autoSave = checked; fileDrop.rebuildItems() } }
                                    CheckBox { text: "Check for updates on startup"; checked: false }
                                    CheckBox { text: "Restore last session"; checked: true }
                                    CheckBox { text: "Show welcome tab on startup"; checked: false }
                                    Row {
                                        spacing: 12
                                        Text { text: "Language:"; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 12; color: appWindow.thText; width: 120 }
                                        ComboBox { width: 200; model: ["Plain Text", "C++", "Java", "Python", "JavaScript", "TypeScript", "Rust", "Go", "QML"]; onActivated: appWindow.currentLanguage = model[currentIndex] }
                                    }
                                    Row {
                                        spacing: 12
                                        Text { text: "Encoding:"; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 12; color: appWindow.thText; width: 120 }
                                        ComboBox { width: 200; model: ["UTF-8", "UTF-16", "ASCII", "ISO-8859-1"]; onActivated: appWindow.currentEncoding = model[currentIndex] }
                                    }
                                    Row {
                                        spacing: 12
                                        Text { text: "Line Endings:"; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 12; color: appWindow.thText; width: 120 }
                                        ComboBox { width: 200; model: ["LF", "CRLF", "CR"]; onActivated: appWindow.currentEOL = model[currentIndex] }
                                    }
                                }
                            }

                            // PAGE 1: Editor
                            Column {
                                spacing: 16
                                Text { text: "Editor Configuration"; font.pixelSize: 18; font.bold: true; color: appWindow.thText }
                                Rectangle { width: parent.width; height: 1; color: appWindow.thBorder }
                                Column {
                                    spacing: 12; width: parent.width
                                    Row {
                                        spacing: 12
                                        Text { text: "Font Family:"; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 12; color: appWindow.thText; width: 120 }
                                        ComboBox { width: 200; model: ["Courier New", "Fira Code", "Consolas", "JetBrains Mono", "Monospace"]; currentIndex: model.indexOf(appWindow.editorFontFamily) >= 0 ? model.indexOf(appWindow.editorFontFamily) : 0; onActivated: appWindow.editorFontFamily = model[currentIndex] }
                                    }
                                    Row {
                                        spacing: 12
                                        Text { text: "Font Size:"; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 12; color: appWindow.thText; width: 120 }
                                        SpinBox { width: 80; from: 6; to: 32; value: appWindow.editorFontSize; onValueModified: appWindow.editorFontSize = value }
                                    }
                                    Row {
                                        spacing: 12
                                        Text { text: "Tab Size:"; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 12; color: appWindow.thText; width: 120 }
                                        SpinBox { width: 80; from: 1; to: 8; value: appWindow.tabSize; onValueModified: appWindow.tabSize = value }
                                    }
                                    CheckBox { text: "Show Line Numbers";       checked: appWindow.showLineNumbers;    onCheckedChanged: appWindow.showLineNumbers    = checked }
                                    CheckBox { text: "Highlight Current Line";  checked: appWindow.lineHighlight;     onCheckedChanged: appWindow.lineHighlight       = checked }
                                    CheckBox { text: "Auto-indent";             checked: appWindow.autoIndentEnabled; onCheckedChanged: appWindow.autoIndentEnabled   = checked }
                                    CheckBox { text: "Bracket Matching";        checked: appWindow.bracketMatch;      onCheckedChanged: appWindow.bracketMatch        = checked }
                                    CheckBox { text: "Show Minimap";            checked: appWindow.showMinimap;       onCheckedChanged: appWindow.showMinimap         = checked }
                                    CheckBox { text: "Show Whitespace";         checked: appWindow.showWhitespace;    onCheckedChanged: appWindow.showWhitespace      = checked }
                                    CheckBox { text: "Word Wrap";               checked: appWindow.wordWrap;          onCheckedChanged: { appWindow.wordWrap = checked; fileText.wrapMode = checked ? TextArea.Wrap : TextArea.NoWrap } }
                                    CheckBox { text: "Sticky Scroll";           checked: appWindow.stickyScroll;      onCheckedChanged: appWindow.stickyScroll        = checked }
                                }
                            }

                            // PAGE 2: Appearance
                            Column {
                                spacing: 16
                                Text { text: "Theme & Appearance"; font.pixelSize: 18; font.bold: true; color: appWindow.thText }
                                Rectangle { width: parent.width; height: 1; color: appWindow.thBorder }
                                Column {
                                    spacing: 12; width: parent.width
                                    Row {
                                        spacing: 12
                                        Text { text: "Theme:"; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 12; color: appWindow.thText; width: 120 }
                                        ComboBox { width: 200; model: ["Light Classic", "Dark Modern", "High Contrast"]; currentIndex: appWindow.darkTheme ? 1 : 0; onActivated: { if (currentIndex === 1) applyTheme(true); else applyTheme(false) } }
                                    }
                                    CheckBox { text: "Show Breadcrumb"; checked: appWindow.showBreadcrumb; onCheckedChanged: appWindow.showBreadcrumb = checked }
                                    CheckBox { text: "Show Tab Bar";    checked: true }
                                    CheckBox { text: "Compact Mode";    checked: false }
                                }
                            }

                            // PAGE 3: Keybindings
                            Column {
                                spacing: 16
                                Text { text: "Keyboard Shortcuts"; font.pixelSize: 18; font.bold: true; color: appWindow.thText }
                                Rectangle { width: parent.width; height: 1; color: appWindow.thBorder }
                                Column {
                                    spacing: 0; width: parent.width

                                    Rectangle {
                                        width: parent.width; height: 28
                                        color: appWindow.darkTheme ? "#333333" : "#eeeeee"
                                        border.color: appWindow.thBorder; border.width: 1
                                        Row { anchors.fill: parent; anchors.margins: 8; spacing: 20
                                            Text { text: "Action";   font.bold: true; width: 180; color: appWindow.thText; font.pixelSize: 12 }
                                            Text { text: "Shortcut"; font.bold: true;             color: appWindow.thText; font.pixelSize: 12 }
                                        }
                                    }

                                    Repeater {
                                        model: [
                                            { action: "New File",            shortcut: "Ctrl+N" },
                                            { action: "Open File",           shortcut: "Ctrl+O" },
                                            { action: "Save File",           shortcut: "Ctrl+S" },
                                            { action: "Undo",                shortcut: "Ctrl+Z" },
                                            { action: "Redo",                shortcut: "Ctrl+Y / Ctrl+Shift+Z" },
                                            { action: "Cut",                 shortcut: "Ctrl+X" },
                                            { action: "Copy",                shortcut: "Ctrl+C" },
                                            { action: "Paste",               shortcut: "Ctrl+V" },
                                            { action: "Select All",          shortcut: "Ctrl+A" },
                                            { action: "Find & Replace",      shortcut: "Ctrl+F" },
                                            { action: "Go to Line",          shortcut: "Ctrl+G" },
                                            { action: "Duplicate Line",      shortcut: "Ctrl+D" },
                                            { action: "Toggle Comment",      shortcut: "Ctrl+/" },
                                            { action: "Indent",              shortcut: "Ctrl+]" },
                                            { action: "Outdent",             shortcut: "Ctrl+[" },
                                            { action: "Split View",          shortcut: "Ctrl+\\" },
                                            { action: "Toggle Terminal",     shortcut: "Ctrl+`" },
                                            { action: "Zoom In",             shortcut: "Ctrl++" },
                                            { action: "Zoom Out",            shortcut: "Ctrl+-" }
                                        ]
                                        delegate: Rectangle {
                                            width: parent.width; height: 26
                                            color: index % 2 === 0 ? "transparent" : (appWindow.darkTheme ? "#2e2e2e" : "#f8f8f8")
                                            Row {
                                                anchors.fill: parent; anchors.margins: 8; spacing: 20
                                                Text { text: modelData.action;   width: 180; color: appWindow.thText;    font.pixelSize: 11 }
                                                Text { text: modelData.shortcut;             color: appWindow.thSubText; font.pixelSize: 11; font.family: "Courier New" }
                                            }
                                        }
                                    }
                                }
                            }

                            // PAGE 4: Extensions
                            Column {
                                spacing: 16
                                Text { text: "Extensions"; font.pixelSize: 18; font.bold: true; color: "#333333" }
                                Rectangle { width: parent.width; height: 1; color: "#adb5bd" }
                                Column {
                                    spacing: 8; width: parent.width
                                    Repeater {
                                        model: [
                                            { name: "C++ Language Support",   desc: "Syntax, IntelliSense, debugging", enabled: true  },
                                            { name: "Java Pack",              desc: "Java syntax and project tools",   enabled: true  },
                                            { name: "Git Lens",               desc: "Git integration and blame",       enabled: false },
                                            { name: "Hex Editor",             desc: "Binary file viewer",              enabled: false },
                                            { name: "JSON Tools",             desc: "Format, validate, diff JSON",     enabled: true  },
                                            { name: "Spell Checker",          desc: "Check spelling in comments",      enabled: false }
                                        ]
                                        delegate: Rectangle {
                                            width: parent.width; height: 44; radius: 4
                                            color: "#f9f9f9"; border.color: "#ddd"; border.width: 1
                                            Row {
                                                anchors.fill: parent; anchors.margins: 10; spacing: 10
                                                Column {
                                                    anchors.verticalCenter: parent.verticalCenter; spacing: 2; width: parent.width - 70
                                                    Text { text: modelData.name; font.pixelSize: 12; font.bold: true; color: "#333" }
                                                    Text { text: modelData.desc; font.pixelSize: 10; color: "#888" }
                                                }
                                                Switch { checked: modelData.enabled; anchors.verticalCenter: parent.verticalCenter }
                                            }
                                        }
                                    }
                                }
                            }

                            // PAGE 5: Git
                            Column {
                                spacing: 16
                                Text { text: "Git Configuration"; font.pixelSize: 18; font.bold: true; color: "#333333" }
                                Rectangle { width: parent.width; height: 1; color: "#adb5bd" }
                                Column {
                                    spacing: 12; width: parent.width
                                    Row {
                                        spacing: 12
                                        Text { text: "User Name:"; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 12; color: "#333"; width: 120 }
                                        TextField { width: 200; placeholderText: "git config user.name"; background: Rectangle { color: "white"; border.color: "#ccc"; radius: 3 } }
                                    }
                                    Row {
                                        spacing: 12
                                        Text { text: "User Email:"; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 12; color: "#333"; width: 120 }
                                        TextField { width: 200; placeholderText: "git config user.email"; background: Rectangle { color: "white"; border.color: "#ccc"; radius: 3 } }
                                    }
                                    Row {
                                        spacing: 12
                                        Text { text: "Default Branch:"; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 12; color: "#333"; width: 120 }
                                        TextField { width: 200; text: appWindow.gitBranch; background: Rectangle { color: "white"; border.color: "#ccc"; radius: 3 }
                                    }
                                    CheckBox { text: "Auto-fetch on open"; checked: false }
                                    CheckBox { text: "Show gutter diff markers"; checked: true }
                                }
                            }

                            // PAGE 6: Build & Run
                            Column {
                                spacing: 16
                                Text { text: "Build & Run"; font.pixelSize: 18; font.bold: true; color: "#333333" }
                                Rectangle { width: parent.width; height: 1; color: "#adb5bd" }
                                Column {
                                    spacing: 12; width: parent.width
                                    Row {
                                        spacing: 12
                                        Text { text: "Build Command:"; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 12; color: "#333"; width: 120 }
                                        TextField { width: 260; placeholderText: "cmake --build . --config Release"; background: Rectangle { color: "white"; border.color: "#ccc"; radius: 3 } }
                                    }
                                    Row {
                                        spacing: 12
                                        Text { text: "Run Command:"; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 12; color: "#333"; width: 120 }
                                        TextField { width: 260; placeholderText: "./build/MyApp"; background: Rectangle { color: "white"; border.color: "#ccc"; radius: 3 } }
                                    }
                                    Row {
                                        spacing: 12
                                        Text { text: "Working Dir:"; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 12; color: "#333"; width: 120 }
                                        TextField { width: 260; placeholderText: "${workspaceRoot}"; background: Rectangle { color: "white"; border.color: "#ccc"; radius: 3 } }
                                    }
                                    CheckBox { text: "Clear terminal before build"; checked: true }
                                    CheckBox { text: "Auto-run after successful build"; checked: false }
                                    CheckBox { text: "Show errors in gutter"; checked: true }
                                }
                            }
                        }
                    }
                }
            }

            // ── Status bar ───────────────────────────────────────────────────
            Item {
                id: statusBar
                anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
                height: 24

                property string message: ""
                Timer { id: msgClear; interval: 4000; onTriggered: statusBar.message = ""; running: statusBar.message !== "" }

                Rectangle { anchors.fill: parent; color: appWindow.darkTheme ? "#007acc" : "#f0f0f0"; border.color: appWindow.thBorder; border.width: 1 }

                // Left: status message
                Text {
                    anchors.left: parent.left; anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    color: appWindow.darkTheme ? "#ccc" : "#666"; font.pixelSize: 10; font.italic: true; text: statusBar.message
                }

                // Centre: line / col
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: parent.verticalCenter
                    color: appWindow.darkTheme ? "#fff" : "#555"; font.pixelSize: 10
                    text: "Ln " + appWindow.currentLineNumber() + ", Col " + appWindow.currentColNumber()
                }

                // Right status chips
                Row {
                    anchors.right: parent.right; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter; spacing: 8

                    Text { font.pixelSize: 10; color: appWindow.darkTheme ? "#ccc" : "#777"; text: appWindow.currentLanguage }
                    Text { font.pixelSize: 10; color: appWindow.darkTheme ? "#ccc" : "#777"; text: "|" }
                    Text { font.pixelSize: 10; color: appWindow.darkTheme ? "#ccc" : "#777"; text: appWindow.currentEncoding }
                    Text { font.pixelSize: 10; color: appWindow.darkTheme ? "#ccc" : "#777"; text: "|" }
                    Text { font.pixelSize: 10; color: appWindow.darkTheme ? "#ccc" : "#777"; text: appWindow.currentEOL }
                    Text { font.pixelSize: 10; color: appWindow.darkTheme ? "#ccc" : "#777"; text: "|" }
                    Text { font.pixelSize: 10; color: appWindow.darkTheme ? "#ccc" : "#777"; text: "Lines: " + statsRefresh.lineCount }
                    Text { font.pixelSize: 10; color: appWindow.darkTheme ? "#ccc" : "#777"; text: "|" }
                    Text { font.pixelSize: 10; color: appWindow.macroRecording ? "#ff8080" : (appWindow.darkTheme ? "#ccc" : "#777"); text: appWindow.macroRecording ? "⏺ REC" : "Git: " + appWindow.gitBranch }
                }
            }
        }
    }

    // ── Extra editor functions ────────────────────────────────────────────────
    function deleteLine() {
        var cursor    = fileText.cursorPosition
        var before    = fileText.text.substring(0, cursor)
        var after     = fileText.text.substring(cursor)
        var lineStart = before.lastIndexOf("\n") + 1
        var lineEnd   = after.indexOf("\n")
        var end       = lineEnd === -1 ? fileText.text.length : cursor + lineEnd + 1
        if (lineStart === 0 && end >= fileText.text.length) { fileText.text = ""; return }
        fileText.remove(lineStart, Math.min(end, fileText.text.length))
        terminalOutput("Line deleted")
    }

    function moveLine(direction) {
        var cursor    = fileText.cursorPosition
        var lines     = fileText.text.split("\n")
        var lineIdx   = fileText.text.substring(0, cursor).split("\n").length - 1
        if (direction === -1 && lineIdx === 0)                return
        if (direction ===  1 && lineIdx === lines.length - 1) return
        var line      = lines.splice(lineIdx, 1)[0]
        lines.splice(lineIdx + direction, 0, line)
        var pos = cursor
        fileText.text = lines.join("\n")
        fileText.cursorPosition = Math.max(0, Math.min(pos, fileText.text.length))
    }

    function blockComment() {
        var sel = fileText.selectedText
        if (sel.length > 0) {
            var s = fileText.selectionStart
            fileText.remove(s, fileText.selectionEnd)
            fileText.insert(s, "/* " + sel + " */")
        } else {
            var cp = fileText.cursorPosition
            fileText.insert(cp, "/* */")
            fileText.cursorPosition = cp + 3
        }
    }

    function charFrequency() {
        var t = fileText.selectedText.length > 0 ? fileText.selectedText : fileText.text
        var freq = {}
        for (var i = 0; i < t.length; i++) {
            var c = t[i]
            if (c === " " || c === "\n" || c === "\t") continue
            freq[c] = (freq[c] || 0) + 1
        }
        var pairs = Object.entries(freq).sort((a, b) => b[1] - a[1]).slice(0, 10)
        terminalOutput("Top chars: " + pairs.map(p => p[0] + "=" + p[1]).join(", "))
    }

    function formatJSON() {
        try {
            var obj = JSON.parse(fileText.text)
            fileText.text = JSON.stringify(obj, null, appWindow.tabSize)
            terminalOutput("JSON formatted OK")
        } catch (e) {
            terminalOutput("JSON error: " + e.message)
        }
    }

    function encodeBase64() {
        var sel = fileText.selectedText
        var src = sel.length > 0 ? sel : fileText.text
        var b64 = Qt.btoa(src)
        if (sel.length > 0) {
            var s = fileText.selectionStart
            fileText.remove(fileText.selectionStart, fileText.selectionEnd)
            fileText.insert(s, b64)
        } else {
            fileText.text = b64
        }
        terminalOutput("Encoded to Base64 (" + b64.length + " chars)")
    }

    function decodeBase64() {
        try {
            var sel = fileText.selectedText
            var src = sel.length > 0 ? sel : fileText.text
            var dec = Qt.atob(src)
            if (sel.length > 0) {
                var s = fileText.selectionStart
                fileText.remove(fileText.selectionStart, fileText.selectionEnd)
                fileText.insert(s, dec)
            } else {
                fileText.text = dec
            }
            terminalOutput("Decoded from Base64")
        } catch (e) {
            terminalOutput("Base64 decode error: " + e.message)
        }
    }

    // Hex dialog (placeholder)
    Dialog {
        id: hexDialog
        title: "Hex View"
        width: 480; height: 300
        anchors.centerIn: parent

        ScrollView {
            anchors.fill: parent
            TextArea {
                font.family: "Courier New"; font.pixelSize: 11; readOnly: true
                text: {
                    var t   = fileText.text.substring(0, 512)
                    var out = ""
                    for (var i = 0; i < t.length; i += 16) {
                        var chunk = t.substring(i, i + 16)
                        var hex   = ""
                        var asc   = ""
                        for (var j = 0; j < chunk.length; j++) {
                            var code = chunk.charCodeAt(j)
                            hex += ("0" + code.toString(16)).slice(-2) + " "
                            asc += (code >= 32 && code < 127) ? chunk[j] : "."
                        }
                        out += ("0000" + i.toString(16)).slice(-4) + "  " + hex.padEnd(49) + " " + asc + "\n"
                    }
                    return out || "(empty)"
                }
            }
        }

        standardButtons: Dialog.Close
    }
}
