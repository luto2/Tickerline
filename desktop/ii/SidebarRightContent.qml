// SPDX-License-Identifier: GPL-3.0-only (builds on end-4/dots-hyprland, see LICENSE in this folder)
// Tickerline right sidebar (sidebar/sidebar_original_2x.png). Replaces ii's
// SidebarRightContent.qml; ii's toggle models, dialogs, notifications, To Do and Timer
// are reused. Double-brace token placeholders become TickerTokens lookups at install, so
// the Matte switch recolors this live. Edit this copy, not the installed one.
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.models.quickToggles
import qs.modules.ii.bar
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

import qs.modules.ii.sidebarRight.bluetoothDevices
import qs.modules.ii.sidebarRight.nightLight
import qs.modules.ii.sidebarRight.volumeMixer
import qs.modules.ii.sidebarRight.wifiNetworks

Item {
    id: root
    property int sidebarWidth: Appearance.sizes.sidebarWidth
    property string settingsQmlPath: Quickshell.shellPath("settings.qml")
    property bool showAudioOutputDialog: false
    property bool showAudioInputDialog: false
    property bool showBluetoothDialog: false
    property bool showNightLightDialog: false
    property bool showWifiDialog: false

    readonly property string sans: Appearance.font.family.main
    readonly property string mono: Appearance.font.family.monospace
    readonly property string display: Appearance.font.family.expressive

    Connections {
        target: GlobalStates
        function onSidebarRightOpenChanged() {
            if (!GlobalStates.sidebarRightOpen) {
                root.showWifiDialog = false;
                root.showBluetoothDialog = false;
                root.showAudioOutputDialog = false;
                root.showAudioInputDialog = false;
            }
        }
    }

    FileView {
        id: hostnameFile
        path: "/etc/hostname"
    }

    implicitHeight: background.implicitHeight
    implicitWidth: background.implicitWidth

    // ---------- building blocks ----------
    component TickerSectionLabel: Text {
        font { family: root.display; pointSize: 9; weight: Font.DemiBold; letterSpacing: 1 }
        color: "{{text-muted}}"
    }
    component TickerHLine: Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: "{{divider}}"
    }
    component TickerSquareButton: MouseArea {
        id: sb
        property string icon
        property string tip
        property bool isOn: false
        implicitWidth: 32
        implicitHeight: 32
        hoverEnabled: true
        Rectangle {
            anchors.fill: parent
            color: sb.isOn ? "{{accent-container}}" : sb.pressed ? "{{surface-pressed}}" : sb.containsMouse ? "{{surface-hover}}" : "transparent"
            border { width: 1; color: sb.isOn ? "{{accent}}" : "{{divider}}" }
        }
        MaterialSymbol {
            anchors.centerIn: parent
            text: sb.icon
            iconSize: 18
            fill: 1
            color: sb.isOn ? "{{accent}}" : "{{text-secondary}}"
        }
        StyledToolTip { text: sb.tip; extraVisibleCondition: false; alternativeVisibleCondition: sb.containsMouse && sb.tip !== "" }
    }
    component TickerTile: MouseArea {
        id: tile
        required property QtObject model
        property string menu: "" // which dialog right-click opens
        property string label: "" // overrides the toggle's own name
        readonly property bool on: tile.model.toggled
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 56
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.RightButton && tile.menu !== "") root[tile.menu] = true;
            else tile.model.mainAction();
        }
        Rectangle {
            anchors.fill: parent
            color: tile.on ? "{{accent-container}}" : tile.containsMouse ? "{{surface-hover}}" : "{{surface-raised}}"
            border { width: tile.on ? 0 : 1; color: "{{divider}}" }
        }
        Rectangle { // GRUB-style accent bar
            visible: tile.on
            width: 3
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            color: "{{accent}}"
        }
        RowLayout {
            anchors { fill: parent; leftMargin: 18; rightMargin: 12 }
            spacing: 14
            MaterialSymbol {
                text: tile.model.icon
                iconSize: 18
                fill: tile.on ? 1 : 0
                color: tile.on ? "{{accent}}" : "{{text-muted}}"
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: tile.label || tile.model.name
                    font { family: root.sans; pointSize: 10; weight: tile.on ? Font.DemiBold : Font.Normal }
                    color: tile.on ? "{{text-primary}}" : "{{text-secondary}}"
                }
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: tile.model.statusText
                    font { family: root.mono; pointSize: 8 }
                    color: tile.on ? "{{accent}}" : "{{text-muted}}"
                }
            }
        }
        StyledToolTip { text: tile.model.tooltipText; extraVisibleCondition: false; alternativeVisibleCondition: tile.containsMouse && tile.model.tooltipText !== "" }
    }

    component TickerCalendarPane: ColumnLayout {
        id: cal
        required property var group // the BottomGroup: month offset and shown month
        readonly property date todayDate: DateTime.clock.date
        readonly property date monthStart: group.shown
        readonly property int leadDays: (monthStart.getDay() + 6) % 7 // Monday first
        readonly property int dayCount: new Date(monthStart.getFullYear(), monthStart.getMonth() + 1, 0).getDate()
        readonly property int rowCount: Math.ceil((leadDays + dayCount) / 7)
        spacing: 8

        function isoWeek(d) {
            const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
            t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7));
            return Math.ceil(((t - new Date(Date.UTC(t.getUTCFullYear(), 0, 1))) / 86400000 + 1) / 7);
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Text {
                text: Qt.locale("en_US").toString(cal.monthStart, "MMMM yyyy").toUpperCase()
                font { family: root.display; pointSize: 15; weight: Font.DemiBold }
                color: "{{text-primary}}"
            }
            Item { Layout.fillWidth: true }
            MouseArea {
                implicitWidth: todayText.implicitWidth
                implicitHeight: todayText.implicitHeight
                cursorShape: Qt.PointingHandCursor
                onClicked: cal.group.monthOffset = 0
                Text {
                    id: todayText
                    text: "TODAY   " + Qt.locale("en_US").toString(cal.todayDate, "ddd d").toUpperCase()
                    font { family: root.mono; pointSize: 8 }
                    color: cal.group.monthOffset === 0 ? "{{text-muted}}" : "{{accent}}"
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            columns: 8
            rowSpacing: 0
            columnSpacing: 0

            Repeater {
                model: ["WK", "MO", "TU", "WE", "TH", "FR", "SA", "SU"]
                Text {
                    required property string modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 28
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: modelData
                    font { family: root.mono; pointSize: 8 }
                    color: index === 0 ? "{{text-disabled}}" : "{{text-muted}}"
                }
            }
            Rectangle { Layout.columnSpan: 8; Layout.fillWidth: true; implicitHeight: 1; color: "{{divider}}" }

            Repeater {
                model: cal.rowCount * 8
                Item {
                    id: cell
                    required property int index
                    readonly property int col: index % 8
                    readonly property date day: new Date(cal.monthStart.getFullYear(), cal.monthStart.getMonth(), Math.floor(index / 8) * 7 + Math.max(col, 1) - cal.leadDays)
                    readonly property bool inMonth: day.getMonth() === cal.monthStart.getMonth()
                    readonly property bool isToday: day.toDateString() === cal.todayDate.toDateString()
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 28

                    Rectangle {
                        visible: cell.isToday && cell.col > 0
                        anchors { fill: parent; leftMargin: 4; rightMargin: 4; topMargin: 1; bottomMargin: 1 }
                        color: "{{accent-container}}"
                        Rectangle { width: 3; height: parent.height; color: "{{accent}}" }
                        // right-corner brackets, as on the GRUB highlight
                        Rectangle { anchors { right: parent.right; top: parent.top } width: 6; height: 1; color: "{{accent}}" }
                        Rectangle { anchors { right: parent.right; top: parent.top } width: 1; height: 6; color: "{{accent}}" }
                        Rectangle { anchors { right: parent.right; bottom: parent.bottom } width: 6; height: 1; color: "{{accent}}" }
                        Rectangle { anchors { right: parent.right; bottom: parent.bottom } width: 1; height: 6; color: "{{accent}}" }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: cell.col === 0 ? cal.isoWeek(cell.day) : cell.day.getDate()
                        font { family: root.mono; pointSize: 9; weight: cell.isToday && cell.col > 0 ? Font.DemiBold : Font.Normal }
                        color: cell.col === 0 ? "{{text-disabled}}" : cell.isToday ? "{{text-primary}}" : cell.inMonth ? "{{text-secondary}}" : "{{text-disabled}}"
                    }
                }
            }
        }

        RowLayout { // next open to-do item stands in for "next event"
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.bottomMargin: 16
            spacing: 16
            Text {
                text: "NEXT"
                font { family: root.display; pointSize: 9; weight: Font.DemiBold }
                color: "{{text-muted}}"
            }
            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: Todo.list.find(i => !i.done)?.content ?? "No upcoming events"
                font { family: root.sans; pointSize: 10 }
                color: "{{text-secondary}}"
            }
        }
    }

    // ---------- panel ----------
    Rectangle {
        id: background
        anchors.fill: parent
        implicitHeight: parent.height - Appearance.sizes.hyprlandGapsOut * 2
        implicitWidth: root.sidebarWidth - Appearance.sizes.hyprlandGapsOut * 2
        color: Qt.alpha("{{surface-low}}", 0.92)
        border { width: 1; color: "{{divider}}" }

        ColumnLayout {
            anchors { fill: parent; margins: 1 }
            spacing: 0

            // Header: logo, host, uptime, system buttons
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 16
                spacing: 12
                CustomIcon {
                    width: 28
                    height: 28
                    source: SystemInfo.distroIcon
                    colorize: true
                    color: "{{accent}}"
                }
                ColumnLayout {
                    spacing: 0
                    Text {
                        text: hostnameFile.text().trim() || SystemInfo.distroId
                        font { family: root.mono; pointSize: 11; weight: Font.DemiBold }
                        color: "{{text-primary}}"
                    }
                    Text {
                        text: `UP ${DateTime.uptime}`
                        font { family: root.mono; pointSize: 8 }
                        color: "{{text-muted}}"
                    }
                }
                Item { Layout.fillWidth: true }
                TickerSquareButton {
                    icon: "edit"
                    tip: "Edit shell config"
                    onClicked: {
                        GlobalStates.sidebarRightOpen = false;
                        Qt.openUrlExternally(`file://${Directories.shellConfigPath}`);
                    }
                }
                TickerSquareButton {
                    icon: "restart_alt"
                    tip: "Reload Hyprland & Quickshell"
                    onClicked: {
                        Quickshell.execDetached(["hyprctl", "reload"]);
                        Quickshell.reload(true);
                    }
                }
                TickerSquareButton {
                    icon: "settings"
                    tip: "Settings"
                    onClicked: {
                        GlobalStates.sidebarRightOpen = false;
                        Quickshell.execDetached(["qs", "-p", root.settingsQmlPath]);
                    }
                }
                TickerSquareButton {
                    icon: "power_settings_new"
                    tip: "Session"
                    onClicked: GlobalStates.sessionOpen = true
                }
            }
            TickerHLine {}

            // Controls
            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: 16
                spacing: 12
                TickerSectionLabel { text: "CONTROLS" }
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: 8
                    columnSpacing: 8
                    TickerTile { model: NetworkToggle {} menu: "showWifiDialog" }
                    TickerTile { model: BluetoothToggle {} menu: "showBluetoothDialog" }
                    TickerTile { model: AudioToggle {} menu: "showAudioOutputDialog"; label: "Audio" }
                    TickerTile { model: MicToggle {} menu: "showAudioInputDialog"; label: "Microphone" }
                    TickerTile { model: IdleInhibitorToggle {} }
                    TickerTile { model: NightLightToggle {} menu: "showNightLightDialog" }
                    TickerTile { model: DarkModeToggle {} } // the Matte toggle
                }
            }
            TickerHLine {}

            // Notifications
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 16
                Layout.bottomMargin: 8
                spacing: 8
                TickerSectionLabel { text: "NOTIFICATIONS" }
                Text {
                    text: Notifications.list.length
                    font { family: root.mono; pointSize: 9 }
                    color: "{{text-muted}}"
                }
                Item { Layout.fillWidth: true }
                TickerSquareButton {
                    icon: "notifications_off"
                    tip: "Do not disturb"
                    isOn: Notifications.silent
                    onClicked: Notifications.silent = !Notifications.silent
                }
                TickerSquareButton {
                    icon: "delete"
                    tip: "Clear all"
                    onClicked: Notifications.discardAllNotifications()
                }
            }
            ListView {
                id: notifList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: Notifications.appNameList
                boundsBehavior: Flickable.StopAtBounds
                delegate: MouseArea { // one notification group per app
                id: group
                required property string modelData
                required property int index
                readonly property var groupData: Notifications.groupsByAppName[modelData]
                readonly property var notifs: (groupData?.notifications ?? []).slice().reverse() // newest first
                property bool isExpanded: false
                width: ListView.view.width
                implicitHeight: groupCol.implicitHeight + 24
                acceptedButtons: Qt.RightButton | Qt.MiddleButton
                onClicked: group.notifs.forEach(n => Notifications.discardNotification(n.notificationId))

                function formatLine(n) {
                    const esc = s => (s ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/\n/g, " ");
                    return `<b>${esc(n.summary)}</b>&nbsp;&nbsp;<font color="${TickerTokens.t["text-secondary"]}">${esc(n.body)}</font>`;
                }

                Rectangle { // newest group gets the accent bar
                    visible: group.index === 0
                    width: 3
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    color: "{{accent}}"
                }
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 16; rightMargin: 16 }
                    height: 1
                    color: "{{divider}}"
                }

                RowLayout {
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16; topMargin: 12 }
                    spacing: 12

                    Rectangle { // letter avatar
                        Layout.alignment: Qt.AlignTop
                        implicitWidth: 32
                        implicitHeight: 32
                        color: "{{surface-highest}}"
                        Text {
                            anchors.centerIn: parent
                            text: (group.modelData[0] ?? "?").toUpperCase()
                            font { family: root.mono; pointSize: 10; weight: Font.DemiBold }
                            color: "{{text-secondary}}"
                        }
                    }

                    ColumnLayout {
                        id: groupCol
                        Layout.fillWidth: true
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                text: group.modelData.toUpperCase()
                                font { family: root.mono; pointSize: 8; letterSpacing: 0.5 }
                                color: "{{text-muted}}"
                            }
                            Rectangle {
                                visible: group.notifs.length > 1
                                implicitWidth: countText.implicitWidth + 10
                                implicitHeight: 18
                                color: "transparent"
                                border { width: 1; color: "{{outline}}" }
                                Text {
                                    id: countText
                                    anchors.centerIn: parent
                                    text: group.notifs.length
                                    font { family: root.mono; pointSize: 8 }
                                    color: "{{text-secondary}}"
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: NotificationUtils.getFriendlyNotifTimeString(group.groupData?.time)
                                font { family: root.mono; pointSize: 8 }
                                color: "{{text-muted}}"
                            }
                            MouseArea {
                                implicitWidth: 20
                                implicitHeight: 20
                                cursorShape: Qt.PointingHandCursor
                                onClicked: group.isExpanded = !group.isExpanded
                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: group.isExpanded ? "keyboard_arrow_up" : "keyboard_arrow_down"
                                    iconSize: 18
                                    color: "{{text-secondary}}"
                                }
                            }
                        }

                        Repeater {
                            model: group.isExpanded ? group.notifs : group.notifs.slice(0, 2)
                            ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 6
                                Text {
                                    Layout.fillWidth: true
                                    text: group.formatLine(modelData)
                                    textFormat: Text.StyledText
                                    elide: group.isExpanded ? Text.ElideNone : Text.ElideRight
                                    wrapMode: group.isExpanded ? Text.Wrap : Text.NoWrap
                                    maximumLineCount: group.isExpanded ? 6 : 1
                                    font { family: root.sans; pointSize: 10 }
                                    color: "{{text-primary}}"
                                }
                                Flow {
                                    visible: group.isExpanded && modelData.actions.length > 0
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Repeater {
                                        model: modelData.actions
                                        MouseArea {
                                            required property var modelData
                                            property var notif: parent.parent.modelData
                                            implicitWidth: actionText.implicitWidth + 24
                                            implicitHeight: 28
                                            hoverEnabled: true
                                            onClicked: Notifications.attemptInvokeAction(notif.notificationId, modelData.identifier)
                                            Rectangle {
                                                anchors.fill: parent
                                                color: parent.containsMouse ? "{{surface-hover}}" : "transparent"
                                                border { width: 1; color: "{{accent}}" }
                                            }
                                            Text {
                                                id: actionText
                                                anchors.centerIn: parent
                                                text: modelData.text
                                                font { family: root.sans; pointSize: 9 }
                                                color: "{{accent}}"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
    
                }

                Text {
                    anchors.centerIn: parent
                    visible: notifList.count === 0
                    text: "No notifications"
                    font { family: root.mono; pointSize: 9 }
                    color: "{{text-muted}}"
                }
            }
            TickerHLine {}

            // Calendar / To Do / Timer
            ColumnLayout { // Calendar / To Do / Timer
                Layout.fillWidth: true
                // all tabs share the height of a 6-week calendar, so switching tabs or months doesn't jump.
                // 5-week months leave one empty row (28 px) below NEXT
                Layout.preferredHeight: tickerTabs.implicitHeight + 24 + tickerCalendar.implicitHeight + (6 - tickerCalendar.rowCount) * 28
                Layout.fillHeight: false
            id: tickerBottom
            property int tab: Persistent.states.sidebar.bottomGroup.tab
            onTabChanged: Persistent.states.sidebar.bottomGroup.tab = tab
            property int monthOffset: 0
            readonly property date shown: {
                const d = new Date(DateTime.clock.date);
                return new Date(d.getFullYear(), d.getMonth() + monthOffset, 1);
            }
            spacing: 0

            RowLayout {
                id: tickerTabs
                Layout.fillWidth: true
                Layout.margins: 16
                Layout.bottomMargin: 8
                spacing: 24
                Repeater {
                    model: ["CALENDAR", "TO DO", "TIMER"]
                    MouseArea {
                        required property string modelData
                        required property int index
                        implicitWidth: tabText.implicitWidth
                        implicitHeight: 28
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tickerBottom.tab = index
                        Text {
                            id: tabText
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData
                            font { family: root.display; pointSize: 9; weight: Font.DemiBold; letterSpacing: 0.5 }
                            color: tickerBottom.tab === index ? "{{accent}}" : "{{text-muted}}"
                        }
                        Rectangle {
                            visible: tickerBottom.tab === index
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: 2
                            color: "{{accent}}"
                        }
                    }
                }
                Item { Layout.fillWidth: true }
                TickerSquareButton { visible: tickerBottom.tab === 0; icon: "chevron_left"; onClicked: tickerBottom.monthOffset-- }
                TickerSquareButton { visible: tickerBottom.tab === 0; icon: "chevron_right"; onClicked: tickerBottom.monthOffset++ }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: tickerBottom.tab

                TickerCalendarPane { id: tickerCalendar; group: tickerBottom }
                ColumnLayout { // To Do: open items first, done ones struck through below
                    id: todoPane
                    spacing: 8
                    function add() {
                        const text = todoInput.text.trim();
                        if (text === "") return;
                        Todo.addTask(text);
                        todoInput.text = "";
                    }

                    ListView {
                        id: todoList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        clip: true
                        model: Todo.list.map((item, i) => ({ item: item, i: i })).sort((a, b) => a.item.done - b.item.done)
                        delegate: MouseArea {
                            id: todoRow
                            required property var modelData
                            width: ListView.view.width
                            height: 36
                            hoverEnabled: true
                            Rectangle { anchors.fill: parent; color: todoRow.containsMouse ? "{{surface-hover}}" : "transparent" }
                            Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: "{{divider}}" }
                            RowLayout {
                                anchors { fill: parent; leftMargin: 8; rightMargin: 4 }
                                spacing: 12
                                MouseArea { // checkbox
                                    implicitWidth: 16
                                    implicitHeight: 16
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: todoRow.modelData.item.done ? Todo.markUnfinished(todoRow.modelData.i) : Todo.markDone(todoRow.modelData.i)
                                    Rectangle {
                                        anchors.fill: parent
                                        color: todoRow.modelData.item.done ? "{{accent-container}}" : "transparent"
                                        border { width: 1; color: todoRow.modelData.item.done ? "{{accent}}" : "{{text-muted}}" }
                                    }
                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        visible: todoRow.modelData.item.done
                                        text: "check"
                                        iconSize: 14
                                        color: "{{accent}}"
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: todoRow.modelData.item.content
                                    font { family: root.sans; pointSize: 10; strikeout: todoRow.modelData.item.done }
                                    color: todoRow.modelData.item.done ? "{{text-disabled}}" : "{{text-secondary}}"
                                }
                                MouseArea { // delete
                                    visible: todoRow.containsMouse
                                    implicitWidth: 24
                                    implicitHeight: 24
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Todo.deleteItem(todoRow.modelData.i)
                                    MaterialSymbol { anchors.centerIn: parent; text: "close"; iconSize: 16; color: "{{text-muted}}" }
                                }
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: todoList.count === 0
                            text: "Nothing to do"
                            font { family: root.mono; pointSize: 9 }
                            color: "{{text-muted}}"
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        Layout.bottomMargin: 16
                        spacing: 8
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 32
                            color: "{{surface-base}}"
                            border { width: 1; color: todoInput.activeFocus ? "{{accent}}" : "{{divider}}" }
                            TextInput {
                                id: todoInput
                                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true
                                font { family: root.mono; pointSize: 9 }
                                color: "{{text-primary}}"
                                selectionColor: "{{accent-container}}"
                                onAccepted: todoPane.add()
                            }
                            Text {
                                anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                                visible: todoInput.text === ""
                                text: "NEW TASK"
                                font { family: root.mono; pointSize: 9 }
                                color: "{{text-disabled}}"
                            }
                        }
                        TickerSquareButton { icon: "add"; tip: "Add task"; onClicked: todoPane.add() }
                    }
                }
                ColumnLayout { // Timer: pomodoro or stopwatch, both from ii's TimerService
                    id: timerPane
                    property bool stopwatch: false
                    function pad(n) { return String(n).padStart(2, "0"); }
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        spacing: 16
                        Repeater {
                            model: ["POMODORO", "STOPWATCH"]
                            MouseArea {
                                required property string modelData
                                required property int index
                                implicitWidth: modeText.implicitWidth
                                implicitHeight: 24
                                cursorShape: Qt.PointingHandCursor
                                onClicked: timerPane.stopwatch = index === 1
                                Text {
                                    id: modeText
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData
                                    font { family: root.mono; pointSize: 8 }
                                    color: timerPane.stopwatch === (index === 1) ? "{{accent}}" : "{{text-muted}}"
                                }
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            visible: !timerPane.stopwatch
                            text: `CYCLE ${TimerService.pomodoroCycle + 1} / ${TimerService.cyclesBeforeLongBreak}`
                            font { family: root.mono; pointSize: 8 }
                            color: "{{text-disabled}}"
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: {
                            if (!timerPane.stopwatch) {
                                const s = TimerService.pomodoroSecondsLeft;
                                return `${timerPane.pad(Math.floor(s / 60))}:${timerPane.pad(s % 60)}`;
                            }
                            const t = TimerService.stopwatchTime; // 10 ms steps
                            return `${timerPane.pad(Math.floor(t / 6000))}:${timerPane.pad(Math.floor(t / 100) % 60)}.${timerPane.pad(t % 100)}`;
                        }
                        font { family: root.display; pointSize: 36; weight: Font.Medium }
                        color: "{{text-primary}}"
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: timerPane.stopwatch
                            ? (TimerService.stopwatchLaps.length > 0 ? `LAP ${TimerService.stopwatchLaps.length}` : (TimerService.stopwatchRunning ? "RUNNING" : "STOPPED"))
                            : (TimerService.pomodoroLongBreak ? "LONG BREAK" : TimerService.pomodoroBreak ? "BREAK" : "FOCUS")
                        font { family: root.mono; pointSize: 8; letterSpacing: 1 }
                        color: "{{text-muted}}"
                    }
                    Rectangle { // pomodoro progress
                        visible: !timerPane.stopwatch
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        Layout.topMargin: 16
                        implicitHeight: 2
                        color: "{{divider}}"
                        Rectangle {
                            height: parent.height
                            width: parent.width * (1 - TimerService.pomodoroSecondsLeft / Math.max(1, TimerService.pomodoroLapDuration))
                            color: "{{accent}}"
                        }
                    }

                    Item { Layout.fillHeight: true }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        Layout.bottomMargin: 16
                        spacing: 8
                        Repeater {
                            model: timerPane.stopwatch ? [
                                { label: TimerService.stopwatchRunning ? "PAUSE" : "START", primary: true, act: () => TimerService.toggleStopwatch() },
                                // reassign instead of TimerService's push, so bindings see the new lap
                                { label: "LAP", primary: false, act: () => { if (TimerService.stopwatchRunning) Persistent.states.timer.stopwatch.laps = [...TimerService.stopwatchLaps, TimerService.stopwatchTime]; } },
                                { label: "RESET", primary: false, act: () => TimerService.stopwatchReset() }
                            ] : [
                                { label: TimerService.pomodoroRunning ? "PAUSE" : "START", primary: true, act: () => TimerService.togglePomodoro() },
                                { label: "RESET", primary: false, act: () => TimerService.resetPomodoro() }
                            ]
                            MouseArea {
                                id: timerButton
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                implicitHeight: 36
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: modelData.act()
                                Rectangle {
                                    anchors.fill: parent
                                    color: timerButton.modelData.primary ? (timerButton.containsMouse ? "{{accent-hover}}" : "{{accent}}") : timerButton.containsMouse ? "{{surface-hover}}" : "transparent"
                                    border { width: timerButton.modelData.primary ? 0 : 1; color: "{{divider}}" }
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: timerButton.modelData.label
                                    font { family: root.display; pointSize: 9; weight: Font.DemiBold; letterSpacing: 0.5 }
                                    color: timerButton.modelData.primary ? "{{on-accent}}" : "{{text-secondary}}"
                                }
                            }
                        }
                    }
                }
            }
    
            }
        }
    }

    // ---------- ii's dialogs (unchanged) ----------
    ToggleDialog {
        shownPropertyString: "showAudioOutputDialog"
        dialog: VolumeDialog { isSink: true }
    }
    ToggleDialog {
        shownPropertyString: "showAudioInputDialog"
        dialog: VolumeDialog { isSink: false }
    }
    ToggleDialog {
        shownPropertyString: "showBluetoothDialog"
        dialog: BluetoothDialog {}
        onShownChanged: {
            if (!shown) {
                Bluetooth.defaultAdapter.discovering = false;
            } else {
                Bluetooth.defaultAdapter.enabled = true;
                Bluetooth.defaultAdapter.discovering = true;
            }
        }
    }
    ToggleDialog {
        shownPropertyString: "showNightLightDialog"
        dialog: NightLightDialog {}
    }
    ToggleDialog {
        shownPropertyString: "showWifiDialog"
        dialog: WifiDialog {}
        onShownChanged: {
            if (!shown) return;
            Network.enableWifi();
            Network.rescanWifi();
        }
    }

    component ToggleDialog: Loader {
        id: toggleDialogLoader
        required property string shownPropertyString
        property alias dialog: toggleDialogLoader.sourceComponent
        readonly property bool shown: root[shownPropertyString]
        anchors.fill: parent

        onShownChanged: if (shown) toggleDialogLoader.active = true;
        active: shown
        onActiveChanged: {
            if (active) {
                item.show = true;
                item.forceActiveFocus();
            }
        }
        Connections {
            target: toggleDialogLoader.item
            function onDismiss() {
                toggleDialogLoader.item.show = false;
                root[toggleDialogLoader.shownPropertyString] = false;
            }
            function onVisibleChanged() {
                if (!toggleDialogLoader.item.visible && !root[toggleDialogLoader.shownPropertyString]) toggleDialogLoader.active = false;
            }
        }
    }
}
