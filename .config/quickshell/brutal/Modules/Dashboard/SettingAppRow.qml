import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Components
import qs.Services

/**
 * A setting that names an application: a label and a dropdown of the
 * installed apps that fit it, storing the chosen entry's command line.
 *
 * The stored value is a command, not a desktop id, because that is what the
 * dashboard rail and the launch binds run — and what a hand-edited
 * settings.json already holds. A value that matches no entry (the shipped
 * `spotify` on a flatpak-only system, `kitty -1`) is kept as its own row
 * rather than shown blank, so opening the list never loses it.
 */
RowLayout {
    id: root

    property string label: ""
    property string description: ""
    /// Freedesktop main category. Matched exactly: as a substring, `Audio`
    /// also matches `AudioVideo` and lists every video player.
    property string category: ""
    /// A second category listed alongside the first, not instead of it.
    property string extraCategory: ""
    /// Optional predicate on the lowercased name, for apps that ship without
    /// the category they belong in.
    property var extraMatch: null
    property string value: ""

    signal changed(string command)

    /// [{ name, command }], sorted by name, one row per distinct command.
    readonly property var choices: {
        const wanted = [root.category, root.extraCategory].filter(c => c !== "");
        const seen = new Set();
        const found = [];
        Apps.all.forEach(entry => {
            const fits = (entry.categories ?? []).some(c => wanted.includes(c))
                || (root.extraMatch && root.extraMatch(entry.name.toLowerCase()));
            const command = Apps.commandFor(entry);
            if (!fits || command === "" || seen.has(command)) return;
            seen.add(command);
            found.push({ name: entry.name, command: command });
        });
        found.sort((a, b) => a.name.localeCompare(b.name));

        if (root.value !== "" && root.matchIn(found) === -1)
            found.unshift({ name: root.value, command: root.value });
        return found;
    }

    readonly property int currentIndex: root.matchIn(root.choices)

    /// The program a command line runs: `/usr/lib/firefox/firefox %u` and
    /// `firefox` are both "firefox".
    function program(command: string): string {
        return (command.trim().split(/\s+/)[0] ?? "").replace(/^["']|["']$/g, "").split("/").pop();
    }

    /// Where `value` sits in a list of choices: its exact command, or failing
    /// that the same program — the shipped defaults are bare names
    /// (`firefox`), not the Exec lines a pick stores. Display only; the value
    /// is not rewritten until something is picked. Bare names only: by
    /// program, `flatpak run A` would match every other flatpak.
    function matchIn(list: var): int {
        const exact = list.findIndex(choice => choice.command === root.value);
        if (exact !== -1 || !/^\S+$/.test(root.value)) return exact;
        const wanted = root.program(root.value);
        return list.findIndex(choice => root.program(choice.command) === wanted);
    }

    spacing: Theme.space.md

    ColumnLayout {
        Layout.fillWidth: true
        spacing: -1

        // fillWidth here too: a layout's maximum width comes from its
        // children, and with no description shown the label is the only one
        // left — without it the column cannot stretch and the dropdown sits
        // against the label instead of in the column of controls.
        BrutalText {
            Layout.fillWidth: true
            text: root.label
            font.pixelSize: Theme.font.size.lg
            font.weight: Theme.font.weight.bold
        }

        BrutalText {
            visible: root.description !== ""
            text: root.description
            dim: true
            font.pixelSize: Theme.font.size.sm
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    BrutalDropdown {
        Layout.preferredWidth: 200
        Layout.alignment: Qt.AlignVCenter

        model: root.choices.map(choice => choice.name)
        currentIndex: root.currentIndex
        onActivated: index => root.changed(root.choices[index].command)
    }
}
