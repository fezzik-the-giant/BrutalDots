pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import qs.Config

/**
 * Application index behind the launcher.
 *
 * Ranking is deliberately boring: exact name, then prefix, then word
 * boundary, then substring, then fuzzy subsequence. Ties break on launch
 * count, so the list settles into habit without reordering on a good match.
 */
Singleton {
    id: root

    /// DesktopEntries scans asynchronously, and only starts once something
    /// has touched it — the first read always comes back empty and fills in a
    /// second or two later. Reading `.values` directly (rather than through
    /// optional chaining) keeps the binding subscribed to that update.
    readonly property var all: {
        const model = DesktopEntries.applications;
        if (!model) return [];
        return model.values.filter(entry => !entry.noDisplay);
    }

    /// Best icon for a window class. A class is not an icon name — see
    /// AGENTS.md "Quickshell". Reading `all` is also what subscribes a
    /// binding to the asynchronous scan; see the note on that property.
    function iconForClass(cls: string): string {
        const name = (cls ?? "").toString().trim();
        if (name === "") return "";

        const direct = Quickshell.iconPath(name, true);
        if (direct !== "") return direct;

        const needle = name.toLowerCase();
        const lower = value => (value ?? "").toString().toLowerCase().trim();
        const execName = entry => lower(entry.execString).split(/\s+/)[0].split("/").pop();

        // Only entries that carry an icon are candidates. Matching the right
        // application and finding it has no Icon= line is the same dead end as
        // not matching at all, and it would shadow a later entry that does.
        const usable = root.all.filter(entry => lower(entry.icon) !== "");

        // id first: `thunar` names itself, while its bulk-rename entry shares
        // that exec basename and would otherwise get there first. Exec
        // basename then catches the opposite shape, which is what the shipped
        // file manager needs: `nautilus` is neither an icon name nor an id
        // (the entry is `org.gnome.Nautilus`), but its Exec begins with it.
        const match = usable.find(entry => lower(entry.id) === needle)
            ?? usable.find(entry => execName(entry) === needle)
            ?? usable.find(entry => lower(entry.name) === needle);

        return match ? Quickshell.iconPath(match.icon, true) : "";
    }

    /// Desktop id -> launch count. Persisted so ranking survives a restart.
    property var launchCounts: ({})

    /// A cap on *fuzzy* matches only. The results list is a virtualised
    /// ListView, so a long list costs nothing to show and truncating one only
    /// hides applications: browsing with an empty query used to stop at 40 of
    /// 117 entries, somewhere in the F's. An empty query is therefore never
    /// capped — see `search`.
    readonly property int maxResults: 200

    function normalise(text: string): string {
        return (text ?? "").toLowerCase().trim();
    }

    /// Subsequence match, measured rather than just tested.
    ///
    /// Returns `{ span, acronym }`, or null for no match. `span` is the
    /// distance from the first matched character to the last, so a tight match
    /// and a coincidence spread across a whole title are distinguishable —
    /// "fire" is 4 characters wide in "Firefox" and 16 in "Ghost of Tsushima
    /// DIRECTOR'S CUT". `acronym` is true when every matched character starts a
    /// word, which is the one case where a wide span is still a good match:
    /// "gimp" against "GNU Image Manipulation Program".
    function subsequence(haystack: string, needle: string): var {
        let at = 0, first = -1, last = -1, acronym = true;
        for (let i = 0; i < haystack.length && at < needle.length; i++) {
            if (haystack[i] !== needle[at]) continue;
            if (first === -1) first = i;
            last = i;
            if (i > 0 && !/[\s\-_.:/]/.test(haystack[i - 1])) acronym = false;
            at++;
        }
        if (at !== needle.length) return null;
        return { span: last - first + 1, acronym: acronym };
    }

    function scoreEntry(entry: var, needle: string): int {
        if (needle === "") return 1;

        const name = root.normalise(entry.name);
        if (name === needle) return 1000;
        if (name.startsWith(needle)) return 900 - Math.min(name.length, 99);

        const words = name.split(/[\s\-_.:]+/);
        if (words.some(word => word.startsWith(needle))) return 800 - Math.min(name.length, 99);

        const inName = name.indexOf(needle);
        if (inName !== -1) return 700 - Math.min(inName, 99);

        const generic = root.normalise(entry.genericName);
        const keywords = (entry.keywords ?? []).map(root.normalise).join(" ");
        if (generic.includes(needle) || keywords.includes(needle)) return 500;

        if (root.normalise(entry.comment).includes(needle)) return 400;
        if (root.normalise(entry.execString).includes(needle)) return 350;

        // Last resort, and the tier that used to make a search for "fire"
        // return Ghost of Tsushima. An acronym scores on its own merits; any
        // other match has to be reasonably tight or it is a coincidence.
        const fuzzy = root.subsequence(name, needle);
        if (!fuzzy) return 0;
        if (fuzzy.acronym) return 300;
        if (fuzzy.span > needle.length * 2 + 2) return 0;
        return 220 - (fuzzy.span - needle.length);
    }

    function count(entry: var): int {
        return root.launchCounts[entry.id] ?? 0;
    }

    /// How many entries at the front of `list` have ever been launched.
    /// The browse list is ordered used-first, so this is where that run ends
    /// and the alphabetical remainder begins.
    function frequentCount(list: var): int {
        let n = 0;
        while (n < list.length && root.count(list[n]) > 0) n++;
        return n;
    }

    /// Ranked entries for a query. An empty query lists everything, most-used
    /// first, so the launcher opens onto something useful.
    function search(text: string): var {
        const needle = root.normalise(text);

        const scored = [];
        for (const entry of root.all) {
            const score = root.scoreEntry(entry, needle);
            if (score > 0) scored.push({ entry: entry, score: score });
        }

        scored.sort((a, b) => {
            if (b.score !== a.score) return b.score - a.score;
            const used = root.count(b.entry) - root.count(a.entry);
            if (used !== 0) return used;
            return a.entry.name.localeCompare(b.entry.name);
        });

        // Browsing is not searching: with no query there is nothing to rank
        // away, so everything is shown.
        const capped = needle === "" ? scored : scored.slice(0, root.maxResults);
        return capped.map(hit => hit.entry);
    }

    function launch(entry: var): void {
        if (!entry) return;

        const counts = Object.assign({}, root.launchCounts);
        counts[entry.id] = (counts[entry.id] ?? 0) + 1;
        root.launchCounts = counts;
        usage.setText(JSON.stringify(counts));

        // execute() does not honour Terminal=true, so a TUI would start with
        // no window to draw in.
        if (entry.runInTerminal) root.run(root.inTerminal(root.commandFor(entry), entry.workingDirectory));
        else entry.execute();
    }

    /// How each terminal takes a command to run. Most take `-e` and the rest
    /// of the line as argv; these are the ones that do not.
    readonly property var execFlags: ({
        "foot": "",
        "footclient": "",
        "wezterm": "start --",
        "gnome-terminal": "--",
        "kgx": "--",
        "ptyxis": "--"
    })

    /// A command line wrapped to open in the terminal chosen in Settings, so
    /// terminal apps follow that choice rather than one fixed here.
    function inTerminal(command: string, dir: string): string {
        const terminal = (Settings.data.apps.terminal ?? "").trim() || "kitty";
        const program = terminal.split(/\s+/)[0].split("/").pop();
        const flag = root.execFlags[program] ?? "-e";
        const line = [terminal, flag, command].filter(part => part !== "").join(" ");
        // Path= in the entry; execute() would have honoured it.
        return dir ? `cd ${JSON.stringify(dir)} && ${line}` : line;
    }

    /// Run a command picked from the desktop entries — the dashboard rail and
    /// the launch binds. Inside a terminal when its entry asks for one.
    function runApp(command: string): void {
        const entry = root.entryForCommand(command);
        root.run(entry?.runInTerminal ? root.inTerminal(command.trim(), entry.workingDirectory) : command);
    }

    /// An entry's Exec line as something `run()` can take: the whole line,
    /// because the first word alone is `flatpak` or `env` for a good share of
    /// entries, minus the field codes (%U, %f…) that only a launcher fills in.
    /// Exec quoting is shell-compatible, so the result goes to `sh -c` as is.
    function commandFor(entry: var): string {
        return (entry?.execString ?? "")
            .replace(/(^|\s)%[a-zA-Z](?=\s|$)/g, "")
            .replace(/%%/g, "%")
            .trim()
            .replace(/\s+/g, " ");
    }

    /// The visible entry whose Exec line is this command, if there is one.
    function entryForCommand(command: string): var {
        const needle = (command ?? "").trim();
        if (needle === "") return null;
        return root.all.find(entry => root.commandFor(entry) === needle) ?? null;
    }

    /// Run a bare command line, as typed. Quoting is not interpreted: the
    /// string is handed to a shell so `foo && bar` and `~` behave as expected.
    function run(command: string): void {
        const trimmed = command.trim();
        if (trimmed === "") return;
        Quickshell.execDetached(["sh", "-c", trimmed]);
    }

    FileView {
        id: usage

        path: `${Quickshell.env("HOME")}/.local/state/brutaldots/launcher.json`
        preload: true
        printErrors: false

        onLoaded: {
            try {
                root.launchCounts = JSON.parse(this.text()) ?? ({});
            } catch (e) {
                root.launchCounts = ({});
            }
        }

        // A missing file is the first-run state; seed it so later writes have
        // a directory to land in.
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) this.setText("{}");
        }
    }
}
