pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Config

Singleton {
    id: root

    property alias monitorsModel: _monitorsModel
    ListModel { id: _monitorsModel }
    
    property int activeEditIndex: 0
    property real uiScale: 0.10
    property int originalOriginX: 0
    property int originalOriginY: 0
    
    // UI state that helps trigger updates
    property int changeTrigger: 0
    property color selectedResAccent: Theme.color.mint

    function isOverlapping(ax, ay, aw, ah, bx, by, bw, bh) {
        return ax < bx + bw && ax + aw > bx && ay < by + bh && ay + ah > by;
    }

    function isOverlappingAny(x, y, w, h, skipIdx) {
        for (let i = 0; i < root.monitorsModel.count; i++) {
            if (i === skipIdx) continue;
            let m = root.monitorsModel.get(i);
            let isP = m.transform === 1 || m.transform === 3;
            let mW = ((isP ? m.resH : m.resW) / m.sysScale) * root.uiScale;
            let mH = ((isP ? m.resW : m.resH) / m.sysScale) * root.uiScale;
            if (root.isOverlapping(x, y, w, h, m.uiX, m.uiY, mW, mH)) return true;
        }
        return false;
    }

    function getPerimeterSnap(pX, pY, sX, sY, sW, sH, mW, mH, snapT) {
        let edges = [
            { x1: sX - mW, x2: sX + sW, y1: sY - mH, y2: sY - mH },
            { x1: sX - mW, x2: sX + sW, y1: sY + sH, y2: sY + sH },
            { x1: sX - mW, x2: sX - mW, y1: sY - mH, y2: sY + sH },
            { x1: sX + sW, x2: sX + sW, y1: sY - mH, y2: sY + sH }
        ];
        let bestX = pX, bestY = pY, minDist = 999999;
        for (let i = 0; i < 4; i++) {
            let e = edges[i];
            let cx = Math.max(e.x1, Math.min(pX, e.x2));
            let cy = Math.max(e.y1, Math.min(pY, e.y2));
            if (Math.abs(cx - sX) < snapT) cx = sX;
            if (Math.abs(cx - (sX + sW - mW)) < snapT) cx = sX + sW - mW;
            if (Math.abs(cx - (sX + sW/2 - mW/2)) < snapT) cx = sX + sW/2 - mW/2;
            if (Math.abs(cy - sY) < snapT) cy = sY;
            if (Math.abs(cy - (sY + sH - mH)) < snapT) cy = sY + sH - mH;
            if (Math.abs(cy - (sY + sH/2 - mH/2)) < snapT) cy = sY + sH/2 - mH/2;
            let dist = Math.hypot(pX - cx, pY - cy);
            if (dist < minDist) { minDist = dist; bestX = cx; bestY = cy; }
        }
        return { x: bestX, y: bestY };
    }

    function forceLayoutUpdate() {
        if (root.monitorsModel.count < 2) return;
        let mIdx = root.activeEditIndex;
        let mModel = root.monitorsModel.get(mIdx);
        let isP = mModel.transform === 1 || mModel.transform === 3;
        let mW = ((isP ? mModel.resH : mModel.resW) / mModel.sysScale) * root.uiScale;
        let mH = ((isP ? mModel.resW : mModel.resH) / mModel.sysScale) * root.uiScale;
        let bestX = mModel.uiX, bestY = mModel.uiY, bestDist = 999999;
        for (let i = 0; i < root.monitorsModel.count; i++) {
            if (i === mIdx) continue;
            let sModel = root.monitorsModel.get(i);
            let sIsP = sModel.transform === 1 || sModel.transform === 3;
            let sW = ((sIsP ? sModel.resH : sModel.resW) / sModel.sysScale) * root.uiScale;
            let sH = ((sIsP ? sModel.resW : sModel.resH) / sModel.sysScale) * root.uiScale;
            let snapped = root.getPerimeterSnap(mModel.uiX, mModel.uiY, sModel.uiX, sModel.uiY, sW, sH, mW, mH, 20);
            let dist = Math.hypot(snapped.x - mModel.uiX, snapped.y - mModel.uiY);
            if (dist < bestDist) { bestDist = dist; bestX = snapped.x; bestY = snapped.y; }
        }
        root.monitorsModel.setProperty(mIdx, "uiX", bestX);
        root.monitorsModel.setProperty(mIdx, "uiY", bestY);
    }

    property alias delayedLayoutUpdate: _delayedLayoutUpdate
    Timer {
        id: _delayedLayoutUpdate
        interval: 10; running: false; repeat: false
        onTriggered: root.forceLayoutUpdate()
    }

    // Refresh model from hyprctl
    property alias displayPoller: _displayPoller
    Process {
        id: _displayPoller
        command: ["hyprctl", "monitors", "-j"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(this.text.trim());
                    root.monitorsModel.clear();
                    let minX = 999999, minY = 999999;
                    for (let i = 0; i < data.length; i++) {
                        if (data[i].x < minX) minX = data[i].x;
                        if (data[i].y < minY) minY = data[i].y;
                    }
                    root.originalOriginX = minX !== 999999 ? minX : 0;
                    root.originalOriginY = minY !== 999999 ? minY : 0;
                    for (let i = 0; i < data.length; i++) {
                        let scl = data[i].scale !== undefined ? data[i].scale : 1.0;
                        let tf = data[i].transform !== undefined ? data[i].transform : 0;
                        let normalizedX = (data[i].x - minX) * root.uiScale;
                        let normalizedY = (data[i].y - minY) * root.uiScale;
                        // Determine if primary by checking coordinate 0x0
                        let isPri = (data[i].x === 0 && data[i].y === 0);
                        
                        root.monitorsModel.append({
                            name: data[i].name, resW: data[i].width, resH: data[i].height,
                            sysScale: scl, rate: Math.round(data[i].refreshRate).toString(),
                            uiX: normalizedX, uiY: normalizedY, transform: tf,
                            availableModes: JSON.stringify(data[i].availableModes || []),
                            isPrimary: isPri,
                            workspaces: "" // We keep this simple for now, user fills it in
                        });
                        if (data[i].focused) root.activeEditIndex = i;
                    }
                    root.changeTrigger++;
                } catch (e) {
                    console.log("Failed to parse hyprctl monitors -j output");
                }
            }
        }
    }

    // Call hyprctl to apply layout
    function applyMonitors() {
        try {
            if (root.monitorsModel.count === 0) return;
            
            let summaryString = "";
            let primaryMonitorName = "";
            let luaCode = "";
            
            let rects = [];
            for (let i = 0; i < root.monitorsModel.count; i++) {
                let m = root.monitorsModel.get(i);
                let isP = m.transform === 1 || m.transform === 3;
                let physW = Math.round((isP ? m.resH : m.resW) / m.sysScale);
                let physH = Math.round((isP ? m.resW : m.resH) / m.sysScale);
                rects.push({ 
                    x: m.uiX / root.uiScale, y: m.uiY / root.uiScale, 
                    w: physW, h: physH, resW: m.resW, resH: m.resH, 
                    name: m.name, rate: m.rate, sysScale: m.sysScale, 
                    transform: m.transform, isPrimary: m.isPrimary, workspaces: m.workspaces 
                });
            }
            
            function getTightSnap(pX, pY, sX, sY, sW, sH, mW, mH, t) {
                let cx = pX; let cy = pY;
                if (Math.abs(cx - (sX - mW)) < t) cx = sX - mW;
                else if (Math.abs(cx - (sX + sW)) < t) cx = sX + sW;
                else if (Math.abs(cx - sX) < t) cx = sX;
                else if (Math.abs(cx - (sX + sW - mW)) < t) cx = sX + sW - mW;
                if (Math.abs(cy - (sY - mH)) < t) cy = sY - mH;
                else if (Math.abs(cy - (sY + sH)) < t) cy = sY + sH;
                else if (Math.abs(cy - sY) < t) cy = sY;
                else if (Math.abs(cy - (sY + sH - mH)) < t) cy = sY + sH - mH;
                return {x: cx, y: cy};
            }
            
            for (let i = 1; i < rects.length; i++) {
                let bestX = rects[i].x, bestY = rects[i].y, bestDist = 999999;
                for (let j = 0; j < i; j++) {
                    let r0 = rects[j];
                    let snapped = getTightSnap(rects[i].x, rects[i].y, r0.x, r0.y, r0.w, r0.h, rects[i].w, rects[i].h, 25);
                    let dist = Math.hypot(rects[i].x - snapped.x, rects[i].y - snapped.y);
                    if (dist < bestDist) { bestDist = dist; bestX = Math.round(snapped.x); bestY = Math.round(snapped.y); }
                }
                rects[i].x = bestX; rects[i].y = bestY;
            }
            
            let finalMinX = 999999, finalMinY = 999999;
            luaCode = `
local function bind_ws(w, m)
    hl.workspace_rule({ workspace = tostring(w), monitor = m })
end
`;
            primaryMonitorName = "";
            summaryString = "";
            
            for (let i = 0; i < rects.length; i++) {
                if (rects[i].x < finalMinX) finalMinX = rects[i].x;
                if (rects[i].y < finalMinY) finalMinY = rects[i].y;
            }
            
            for (let i = 0; i < rects.length; i++) {
                let r = rects[i];
                r.x = Math.round(r.x - finalMinX);
                r.y = Math.round(r.y - finalMinY);
                
                luaCode += `hl.monitor({ output = "${r.name}", mode = "${r.resW}x${r.resH}@${r.rate}", position = "${r.x}x${r.y}", scale = ${r.sysScale}`;
                if (r.transform !== 0) {
                    luaCode += `, transform = ${r.transform}`;
                }
                luaCode += ` });\n`;
                
                if (r.workspaces) {
                    let groups = r.workspaces.split(/[, ]+/);
                    for (let g of groups) {
                        if (!g) continue;
                        if (g.indexOf("-") !== -1) {
                            let bounds = g.split("-");
                            let start = parseInt(bounds[0]);
                            let end = parseInt(bounds[1]);
                            if (!isNaN(start) && !isNaN(end) && start <= end) {
                                for (let w = start; w <= end; w++) {
                                    luaCode += `bind_ws("${w}", "${r.name}")\n`;
                                }
                            }
                        } else {
                            luaCode += `bind_ws("${g}", "${r.name}")\n`;
                        }
                    }
                }
                if (r.isPrimary) primaryMonitorName = r.name;
                summaryString += r.name + " ";
            }
            
            let fullCmd = `echo '${luaCode}' > ~/.config/hypr/monitors.lua ; hyprctl eval 'package.loaded["monitors"] = nil' ; hyprctl reload`;
            
            if (primaryMonitorName !== "") {
                fullCmd += " ; xrandr --output " + primaryMonitorName + " --primary";
            }
            
            fullCmd += " ; if pgrep -x awww-daemon >/dev/null; then awww kill; sleep 0.2; awww-daemon & elif pgrep -x swww-daemon >/dev/null; then swww kill; sleep 0.2; swww-daemon & fi";
            
            console.log("EXEC:", fullCmd);
            
            Quickshell.execDetached(["sh", "-c", fullCmd]);
            Quickshell.execDetached(["notify-send", "Display Update", "Applied layout for: " + summaryString.trim()]);
        } catch(e) {
            Quickshell.execDetached(["notify-send", "QML Error", e.toString()]);
        }
    }
}
