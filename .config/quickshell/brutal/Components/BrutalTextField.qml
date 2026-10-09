import QtQuick
import qs.Config

/// Bordered single-line input with a themed placeholder.
BrutalBox {
    id: root

    property alias text: input.text
    /// TextInput.Normal by default; TextInput.Password for the lock screen.
    property alias echoMode: input.echoMode
    property alias horizontalAlignment: input.horizontalAlignment
    property string placeholder: ""
    property int hPadding: Theme.space.md

    /// Whether Return fires `accepted` on an empty field. The launcher wants
    /// the guard — an empty prompt should run nothing — but a field used as a
    /// filter over an already-selected list does not: there, Return means
    /// "take the highlighted one", and starting from an empty box is normal.
    property bool acceptEmpty: false

    signal accepted(string text)
    /// Return *or* focus leaving the field, trimmed and empty included: for a
    /// form that saves as you go, where Return-only loses whatever was typed
    /// before clicking on into the next field.
    signal edited(string text)
    /// Raised before the input handles a key, so a consumer (the launcher)
    /// can steal arrows and Escape without owning the field.
    signal keyPressed(var event)

    color: Theme.color.base
    radius: Theme.radius.md
    shadowOffset: Theme.shadow.sm
    implicitHeight: 38

    function clear(): void { input.clear(); }
    function forceFocus(): void { input.forceActiveFocus(); }

    TextInput {
        id: input
        anchors {
            fill: parent
            leftMargin: root.hPadding
            rightMargin: root.hPadding
        }
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.color.ink
        font.family: Theme.font.mono
        font.pixelSize: Theme.font.size.md
        selectionColor: Theme.color.lavender
        selectedTextColor: Theme.color.ink
        clip: true

        Keys.onPressed: event => root.keyPressed(event)

        onEditingFinished: root.edited(text.trim())

        onAccepted: {
            const value = text.trim();
            if (value !== "" || root.acceptEmpty) root.accepted(value);
        }

        BrutalText {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: input.horizontalAlignment
            text: root.placeholder
            dim: true
            font.pixelSize: Theme.font.size.md
            // Shown while the field is focused but still empty: a launcher
            // that blanks its own prompt the moment it opens is unhelpful.
            visible: input.text === ""
        }
    }
}
