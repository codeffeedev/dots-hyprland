import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    forceWidth: true
    interactive: false

    property alias confirmPending: monitorHelper.hasPending
    property alias confirmRemaining: confirmTimer.remaining

    function acceptChanges() { monitorHelper.confirmSnapshot(); }
    function rejectChanges() { monitorHelper.revertSnapshot(); }

    Component.onDestruction: {
        if (monitorHelper.hasPending)
            monitorHelper.revertSnapshot();
    }

    ListModel {
        id: monitorModel
    }

        QtObject {
            id: monitorHelper
            property int selectedIndex: -1
            property var pendingSnapshot: null
            property bool hasPending: false
            property string displayMode: "extend"
            property var savedPresets: ({})

        function takeSnapshot(idx) {
            if (pendingSnapshot) return;
            pendingSnapshot = null;
            var monitors = [];
            for (var i = 0; i < monitorModel.count; i++) {
                var mon = monitorModel.get(i);
                monitors.push({
                    x: mon.x,
                    y: mon.y,
                    width: mon.width,
                    height: mon.height,
                    scale: mon.scale,
                    transform: mon.transform,
                    refreshRate: mon.refreshRate,
                    displayName: mon.displayName,
                    disabled: mon.disabled
                });
            }
            pendingSnapshot = {
                index: idx,
                displayMode: displayMode,
                monitors: monitors
            };
            hasPending = true;
            confirmTimer.remaining = 10;
            confirmTimer.start();
        }

        function confirmSnapshot() {
            pendingSnapshot = null;
            hasPending = false;
            confirmTimer.stop();
        }

        function revertSnapshot() {
            if (!pendingSnapshot) return;
            var s = pendingSnapshot;
            displayMode = s.displayMode || "extend";
            for (var i = 0; i < s.monitors.length && i < monitorModel.count; i++) {
                var m = s.monitors[i];
                monitorModel.setProperty(i, "x", m.x);
                monitorModel.setProperty(i, "y", m.y);
                monitorModel.setProperty(i, "width", m.width);
                monitorModel.setProperty(i, "height", m.height);
                monitorModel.setProperty(i, "scale", m.scale);
                monitorModel.setProperty(i, "transform", m.transform);
                monitorModel.setProperty(i, "refreshRate", m.refreshRate);
                monitorModel.setProperty(i, "displayName", m.displayName);
                monitorModel.setProperty(i, "disabled", m.disabled === true);
            }
            pendingSnapshot = null;
            hasPending = false;
            confirmTimer.stop();
            saveDisplayNames();
            applyArrangement();
        }

        function rowHeight() {
            var maxH = 0;
            for (var i = 0; i < monitorModel.count; i++) {
                if (monitorModel.get(i).disabled === true) continue;
                maxH = Math.max(maxH, monitorHelper.logicalHeight(monitorModel.get(i)));
            }
            return maxH + 20;
        }

        function primaryIndex() {
            for (var i = 0; i < monitorModel.count; i++) {
                if (monitorModel.get(i).name.indexOf("eDP-") === 0) return i;
            }
            return monitorModel.count > 0 ? 0 : -1;
        }

        function computeCombinationFingerprint() {
            var names = [];
            for (var i = 0; i < monitorModel.count; i++) {
                names.push(monitorModel.get(i).name);
            }
            names.sort();
            return names.join(",");
        }

        function logicalWidth(m) {
            var transformedWidth = (m.transform === 1 || m.transform === 3) ? m.height : m.width;
            return Math.round(transformedWidth / Math.max(0.01, m.scale || 1));
        }

        function logicalHeight(m) {
            var transformedHeight = (m.transform === 1 || m.transform === 3) ? m.width : m.height;
            return Math.round(transformedHeight / Math.max(0.01, m.scale || 1));
        }

        function rowIndices(y) {
            var indices = [];
            for (var i = 0; i < monitorModel.count; i++) {
                if (monitorModel.get(i).disabled === true) continue;
                if (monitorModel.get(i).y === y) indices.push(i);
            }
            indices.sort(function(a, b) {
                var ma = monitorModel.get(a);
                var mb = monitorModel.get(b);
                return ma.x - mb.x || a - b;
            });
            return indices;
        }

        function layoutRow(indices, startX) {
            var x = Math.max(0, startX);
            for (var i = 0; i < indices.length; i++) {
                var idx = indices[i];
                monitorModel.setProperty(idx, "x", x);
                x += monitorHelper.logicalWidth(monitorModel.get(idx));
            }
        }

        function overlapsAny(idx, x, y) {
            var m = monitorModel.get(idx);
            var w = monitorHelper.logicalWidth(m);
            var h = monitorHelper.logicalHeight(m);
            for (var i = 0; i < monitorModel.count; i++) {
                if (i === idx) continue;
                var o = monitorModel.get(i);
                if (o.disabled === true) continue;
                var ow = monitorHelper.logicalWidth(o);
                var oh = monitorHelper.logicalHeight(o);
                if (x < o.x + ow && x + w > o.x && y < o.y + oh && y + h > o.y)
                    return true;
            }
            return false;
        }

        function nearestFreePosition(idx, desiredX, desiredY) {
            var m = monitorModel.get(idx);
            var w = monitorHelper.logicalWidth(m);
            var h = monitorHelper.logicalHeight(m);
            var snap = 20;
            var dx = Math.max(0, Math.round(desiredX / snap) * snap);
            var dy = Math.round(desiredY / snap) * snap;
            var candidates = [{x: dx, y: dy}];

            for (var i = 0; i < monitorModel.count; i++) {
                if (i === idx) continue;
                var o = monitorModel.get(i);
                if (o.disabled === true) continue;
                var ow = monitorHelper.logicalWidth(o);
                var oh = monitorHelper.logicalHeight(o);
                var xs = [o.x - w, o.x, o.x + ow, dx];
                var ys = [o.y - h, o.y, o.y + oh, dy];
                for (var xi = 0; xi < xs.length; xi++) {
                    for (var yi = 0; yi < ys.length; yi++) {
                        candidates.push({x: Math.max(0, Math.round(xs[xi] / snap) * snap), y: Math.round(ys[yi] / snap) * snap});
                    }
                }
            }

            candidates.sort(function(a, b) {
                var da = Math.abs(a.x - desiredX) + Math.abs(a.y - desiredY);
                var db = Math.abs(b.x - desiredX) + Math.abs(b.y - desiredY);
                return da - db;
            });

            var seen = {};
            for (var c = 0; c < candidates.length; c++) {
                var key = candidates[c].x + "," + candidates[c].y;
                if (seen[key]) continue;
                seen[key] = true;
                if (!monitorHelper.overlapsAny(idx, candidates[c].x, candidates[c].y))
                    return candidates[c];
            }

            var box = monitorHelper.bbox();
            return {x: Math.max(0, box.x + box.w), y: dy};
        }

        function moveToPosition(idx, desiredX, desiredY) {
            if (idx < 0 || idx >= monitorModel.count) return;
            var pos = monitorHelper.nearestFreePosition(idx, desiredX, desiredY);
            var m = monitorModel.get(idx);
            if (m.x === pos.x && m.y === pos.y) return;
            monitorHelper.takeSnapshot(idx);
            monitorModel.setProperty(idx, "x", pos.x);
            monitorModel.setProperty(idx, "y", pos.y);
            monitorHelper.applyArrangement();
        }

        function setDisplayMode(mode) {
            if (displayMode === mode) return;
            monitorHelper.takeSnapshot(monitorHelper.selectedIndex);
            displayMode = mode;
            applyDisplayMode();
            saveDisplayNames();
            applyArrangement();
        }

        function applyDisplayMode() {
            var primary = monitorHelper.primaryIndex();
            for (var i = 0; i < monitorModel.count; i++) {
                var disabled = false;
                if (displayMode === "only-first") disabled = i !== primary;
                else if (displayMode === "only-second") disabled = i === primary;
                monitorModel.setProperty(i, "disabled", disabled);
            }
            if (monitorHelper.selectedIndex >= 0 && monitorModel.get(monitorHelper.selectedIndex).disabled === true) {
                monitorHelper.selectedIndex = primary >= 0 && monitorModel.get(primary).disabled !== true ? primary : 0;
            }
        }

        function applyArrangement() {
            if (monitorModel.count === 0) return;
            monitorHelper.applyDisplayMode();
            var luaLines = [];
            var evalCmds = [];
            var primary = monitorHelper.primaryIndex();
            var primaryName = primary >= 0 ? monitorModel.get(primary).name : "";
            for (var i = 0; i < monitorModel.count; i++) {
                var m = monitorModel.get(i);
                var pos = `${m.x}x${m.y}`;
                var mode = `${m.width}x${m.height}@${m.refreshRate}`;
                if (m.disabled === true) {
                    luaLines.push(`hl.monitor({output = "${m.name}", disabled = true})`);
                    evalCmds.push(`hl.monitor({output = "${m.name}", disabled = true})`);
                } else if (displayMode === "mirror" && i !== primary && primaryName !== "") {
                    luaLines.push(`hl.monitor({output = "${m.name}", mode = "${mode}", mirror = "${primaryName}", scale = ${m.scale}, transform = ${m.transform}})`);
                    evalCmds.push(`hl.monitor({output = "${m.name}", mode = "${mode}", mirror = "${primaryName}", scale = ${m.scale}, transform = ${m.transform}})`);
                } else {
                    var applyPos = displayMode === "mirror" ? "0x0" : pos;
                    luaLines.push(`hl.monitor({output = "${m.name}", mode = "${mode}", position = "${applyPos}", scale = ${m.scale}, transform = ${m.transform}})`);
                    evalCmds.push(`hl.monitor({output = "${m.name}", mode = "${mode}", position = "${applyPos}", scale = ${m.scale}, transform = ${m.transform}})`);
                }
            }
            var script = `#!/bin/bash
MONITORS_LUA="\${HOME}/.config/hypr/monitors.lua"
cat > "\${MONITORS_LUA}" << 'LUAEOF'
-- Auto-generated by QuickConfig
${luaLines.join("\n")}
LUAEOF
${evalCmds.map(function(c) { return "hyprctl eval '" + c + "' 2>/dev/null"; }).join("\n")}
`;
            monitorHelper.saveDisplayNames();
            Quickshell.execDetached(["/usr/bin/bash", "-c", script]);
        }

        function moveSelected(direction) {
            var idx = monitorHelper.selectedIndex;
            if (idx < 0 || monitorModel.count < 2) return;
            var myY = monitorModel.get(idx).y;
            var sameLevel = monitorHelper.rowIndices(myY);
            if (sameLevel.length > 1) {
                var myPos = sameLevel.indexOf(idx);
                var newPos = myPos + direction;
                if (newPos < 0 || newPos >= sameLevel.length) return;
                monitorHelper.takeSnapshot(idx);
                var startX = monitorModel.get(sameLevel[0]).x;
                sameLevel.splice(myPos, 1);
                sameLevel.splice(newPos, 0, idx);
                monitorHelper.layoutRow(sameLevel, startX);
            } else {
                monitorHelper.takeSnapshot(idx);
                var m = monitorModel.get(idx);
                var step = direction < 0 ? -monitorHelper.logicalWidth(m) : monitorHelper.logicalWidth(m);
                monitorModel.setProperty(idx, "x", Math.max(0, m.x + step));
            }
            monitorHelper.applyArrangement();
        }

        function moveVertical(direction) {
            var idx = monitorHelper.selectedIndex;
            if (idx < 0) return;
            monitorHelper.takeSnapshot(idx);
            var rh = monitorHelper.rowHeight();
            var m = monitorModel.get(idx);
            var newY = direction < 0 ? m.y - rh : m.y + rh;
            var anchor = null, bestOverlap = -1, bestDist = Infinity;
            for (var i = 0; i < monitorModel.count; i++) {
                var o = monitorModel.get(i);
                if (i === idx || o.y !== m.y) continue;
                var overlap = Math.min(m.x + monitorHelper.logicalWidth(m), o.x + monitorHelper.logicalWidth(o)) - Math.max(m.x, o.x);
                if (overlap > bestOverlap) {
                    bestOverlap = overlap;
                    bestDist = Infinity;
                    anchor = o;
                } else if (overlap <= 0 && bestOverlap <= 0) {
                    var dist = Math.abs((m.x + monitorHelper.logicalWidth(m) / 2) - (o.x + monitorHelper.logicalWidth(o) / 2));
                    if (dist < bestDist) { bestDist = dist; anchor = o; }
                }
            }
            if (anchor) {
                var newX = anchor.x + Math.round((monitorHelper.logicalWidth(anchor) - monitorHelper.logicalWidth(m)) / 2);
                monitorModel.setProperty(idx, "x", Math.max(0, newX));
            }
            monitorModel.setProperty(idx, "y", newY);
            var row = monitorHelper.rowIndices(newY);
            monitorHelper.layoutRow(row, monitorModel.get(row[0]).x);
            monitorHelper.applyArrangement();
        }

        function resetY() {
            for (var i = 0; i < monitorModel.count; i++)
                monitorModel.setProperty(i, "y", 0);
            monitorHelper.applyArrangement();
        }

        function bbox() {
            if (monitorModel.count === 0) return { x: 0, y: 0, w: 100, h: 100 };
            var found = false, minX = 0, minY = 0, maxX = 0, maxY = 0;
            for (var i = 0; i < monitorModel.count; i++) {
                var m = monitorModel.get(i);
                if (m.disabled === true) continue;
                if (!found) { minX = m.x; minY = m.y; maxX = m.x + monitorHelper.logicalWidth(m); maxY = m.y + monitorHelper.logicalHeight(m); found = true; continue; }
                if (m.x < minX) minX = m.x;
                if (m.y < minY) minY = m.y;
                var rx = m.x + monitorHelper.logicalWidth(m);
                var by = m.y + monitorHelper.logicalHeight(m);
                if (rx > maxX) maxX = rx;
                if (by > maxY) maxY = by;
            }
            if (!found) return { x: 0, y: 0, w: 100, h: 100 };
            return { x: minX, y: minY, w: maxX - minX, h: maxY - minY };
        }

        function friendlyName(m) {
            return m.description || m.make + " " + m.model || m.name;
        }

        function maxHzForModes(modes, w, h) {
            var prefix = w + "x" + h + "@";
            var maxH = 60;
            for (var mode of (modes || [])) {
                if (mode.startsWith(prefix)) {
                    var match = mode.match(/@(\d+(?:\.\d+)?)Hz/);
                    if (match) {
                        var hz = Math.round(parseFloat(match[1]));
                        if (hz > maxH) maxH = hz;
                    }
                }
            }
            return maxH;
        }

        function resolutionOptions(modes) {
            var seen = {};
            var opts = [];
            for (var mode of (modes || [])) {
                var parts = mode.split("@");
                if (parts.length > 0) {
                    var res = parts[0];
                    if (!seen[res]) {
                        seen[res] = true;
                        var dims = res.split("x");
                        if (dims.length === 2) {
                            var w = parseInt(dims[0]);
                            var h = parseInt(dims[1]);
                            opts.push({text: res, value: res, w: w, h: h});
                        }
                    }
                }
            }
            opts.sort(function(a, b) { return b.w - a.w || b.h - a.h; });
            return opts;
        }

        // Hyprland rejects scales that don't divide the resolution into whole
        // logical pixels (e.g. 2880x1800 / 1.75 = 1645.71x1028.57). Only offer
        // scales that are actually valid for this monitor's mode.
        function scaleOptions(w, h) {
            // Below 1.0 the compositor renders larger than the panel and downscales,
            // which buys screen real estate on low-resolution displays at the cost of
            // sharpness and some GPU work.
            var candidates = [0.8, 1.0, 1.125, 1.2, 1.25, 4 / 3, 1.5, 1.6, 5 / 3, 1.75, 1.8, 2.0, 2.25, 2.5, 8 / 3, 3.0];
            var opts = [];
            for (var i = 0; i < candidates.length; i++) {
                var s = candidates[i];
                var lw = w / s;
                var lh = h / s;
                if (Math.abs(lw - Math.round(lw)) > 1e-6) continue;
                if (Math.abs(lh - Math.round(lh)) > 1e-6) continue;
                opts.push({text: Math.round(s * 100) + " %", value: s});
            }
            if (opts.length === 0) opts.push({text: "100 %", value: 1.0});
            return opts;
        }

        function hzOptions(modes, w, h) {
            var maxH = monitorHelper.maxHzForModes(modes, w, h);
            var common = [50, 60, 75, 90, 100, 120, 144, 165, 180, 200, 240, 360];
            var opts = [];
            for (var i = 0; i < common.length; i++) {
                if (common[i] <= maxH) opts.push({text: common[i] + " Hz", value: common[i]});
            }
            return opts;
        }

        function saveDisplayNames() {
            var obj = {};
            for (var i = 0; i < monitorModel.count; i++) {
                var m = monitorModel.get(i);
                obj[m.name] = {
                    n: m.displayName, r: m.refreshRate,
                    w: m.width, h: m.height,
                    s: m.scale, t: m.transform,
                    x: m.x, y: m.y, d: m.disabled
                };
            }
            obj.__displayMode = monitorHelper.displayMode;

            var fingerprint = monitorHelper.computeCombinationFingerprint();
            var preset = { displayMode: monitorHelper.displayMode, monitors: {} };
            for (var i = 0; i < monitorModel.count; i++) {
                var m = monitorModel.get(i);
                preset.monitors[m.name] = {
                    x: m.x, y: m.y, w: m.width, h: m.height,
                    s: m.scale, t: m.transform, r: m.refreshRate, d: m.disabled
                };
            }
            monitorHelper.savedPresets[fingerprint] = preset;
            obj.__presets = monitorHelper.savedPresets;

            var json = JSON.stringify(obj);
            var hex = "";
            for (var j = 0; j < json.length; j++) hex += json.charCodeAt(j).toString(16).padStart(2, "0");
            Quickshell.execDetached(["/usr/bin/bash", "-c",
                "mkdir -p $HOME/.config/hypr && echo " + hex + " | xxd -r -p > $HOME/.config/hypr/monitor-names.json"
            ]);
        }

        function populateModel(parsed) {
            monitorModel.clear();
            for (var m of parsed) {
                var fn = monitorHelper.friendlyName(m);
                var modes = m.availableModes || [];
                var rr = Math.round(m.refreshRate ?? 60);
                monitorModel.append({
                    modesJson: JSON.stringify(modes),
                    name: m.name,
                    description: m.description || "",
                    displayName: fn,
                    width: m.width,
                    height: m.height,
                    x: m.x,
                    y: m.y,
                    scale: m.scale,
                    transform: m.transform ?? 0,
                    refreshRate: rr
                    , disabled: m.disabled === true
                });
            }
            monitorHelper.applyDisplayMode();
        }
    }

    Process {
        id: loadNamesProc
        command: ["/usr/bin/bash", "-c", "cat $HOME/.config/hypr/monitor-names.json 2>/dev/null || echo '{}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text);
                    if (data.__displayMode) {
                        monitorHelper.displayMode = data.__displayMode;
                        monitorHelper.applyDisplayMode();
                    }
                    for (var n in data) {
                        if (n === "__displayMode" || n === "__presets") continue;
                        var val = data[n];
                        var dn = typeof val === "string" ? val : (val.n || val);
                        var hz = typeof val === "object" && val.r ? val.r : null;
                        var w = typeof val === "object" && val.w ? val.w : null;
                        var h = typeof val === "object" && val.h ? val.h : null;
                        var sc = typeof val === "object" && val.s ? val.s : null;
                        var tf = typeof val === "object" && val.t !== undefined ? val.t : null;
                        for (var i = 0; i < monitorModel.count; i++) {
                            if (monitorModel.get(i).name === n) {
                                monitorModel.setProperty(i, "displayName", dn);
                                if (hz) monitorModel.setProperty(i, "refreshRate", hz);
                                if (sc) monitorModel.setProperty(i, "scale", sc);
                                if (tf !== null) monitorModel.setProperty(i, "transform", tf);
                                if (w && h) {
                                    monitorModel.setProperty(i, "width", w);
                                    monitorModel.setProperty(i, "height", h);
                                    var capModes = JSON.parse(monitorModel.get(i).modesJson || "[]");
                                    var cap = monitorHelper.maxHzForModes(capModes, w, h);
                                    var cur = monitorModel.get(i).refreshRate;
                                    if (cur > cap) monitorModel.setProperty(i, "refreshRate", cap);
                                }
                                break;
                            }
                        }
                    }
                    monitorHelper.savedPresets = data.__presets || {};

                    // Apply preset for current monitor combination
                    var fingerprint = monitorHelper.computeCombinationFingerprint();
                    if (data.__presets && data.__presets[fingerprint]) {
                        var preset = data.__presets[fingerprint];
                        if (preset.displayMode) {
                            monitorHelper.displayMode = preset.displayMode;
                            monitorHelper.applyDisplayMode();
                        }
                        for (var monName in preset.monitors) {
                            var p = preset.monitors[monName];
                            for (var i = 0; i < monitorModel.count; i++) {
                                if (monitorModel.get(i).name === monName) {
                                    if (p.x !== undefined) monitorModel.setProperty(i, "x", p.x);
                                    if (p.y !== undefined) monitorModel.setProperty(i, "y", p.y);
                                    if (p.w) monitorModel.setProperty(i, "width", p.w);
                                    if (p.h) monitorModel.setProperty(i, "height", p.h);
                                    if (p.s) monitorModel.setProperty(i, "scale", p.s);
                                    if (p.t !== undefined) monitorModel.setProperty(i, "transform", p.t);
                                    if (p.r) monitorModel.setProperty(i, "refreshRate", p.r);
                                    if (p.d !== undefined) monitorModel.setProperty(i, "disabled", p.d);
                                    break;
                                }
                            }
                        }
                    }
                    } catch (e) {}
                    monitorHelper.applyDisplayMode();
                    monitorNameInput.updateText();
                }
        }
    }

    Process {
        id: fetchMonitorsProc
        command: ["hyprctl", "monitors", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let parsed = JSON.parse(text);
                    parsed.sort((a, b) => a.x - b.x || a.id - b.id);
                    let prevName = monitorHelper.selectedIndex >= 0 && monitorHelper.selectedIndex < monitorModel.count
                        ? monitorModel.get(monitorHelper.selectedIndex).name : null;
                    monitorHelper.populateModel(parsed);
                    if (prevName) {
                        let found = parsed.findIndex(m => m.name === prevName);
                        monitorHelper.selectedIndex = found >= 0 ? found : 0;
                    } else {
                        monitorHelper.selectedIndex = parsed.findIndex(m => m.focused);
                        if (monitorHelper.selectedIndex < 0) monitorHelper.selectedIndex = 0;
                    }
                    loadNamesProc.running = true;
                } catch (e) {
                    console.error("Monitor parse error:", e, text);
                }
            }
        }
    }

    Timer {
        id: confirmTimer
        interval: 1000
        repeat: true
        property int remaining: 10
        onTriggered: {
            remaining -= 1;
            if (remaining <= 0) {
                stop();
                monitorHelper.revertSnapshot();
            }
        }
    }

    ContentSection {
        icon: "screenshot_monitor"
        title: Translation.tr("Monitor Arrangement")
        Layout.fillWidth: true

        Rectangle {
            id: monitorBgRect
            Layout.fillWidth: true
            implicitHeight: 220
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer2

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - 32, parent.height * 2.5)
                height: Math.min(parent.height - 32, parent.width / 2.5)
                radius: 8
                color: "transparent"
                border.width: 1
                border.color: Appearance.colors.colOutline

                Item {
                    id: previewArea
                    anchors.centerIn: parent
                    property var box: monitorHelper.bbox()
                    property real pad: 8
                    property real availW: parent.width - pad * 2
                    property real availH: parent.height - pad * 2
                    property real sc: box.w > 0 && box.h > 0
                        ? Math.min(availW / box.w, availH / box.h, 1.0) : 0.1

                    width: box.w * sc + pad * 2
                    height: box.h * sc + pad * 2

                    Repeater {
                        id: monitorRepeater
                        model: monitorModel

                        delegate: Item {
                            id: monitorCard
                            required property var modelData
                            required property int index
                            property bool dragging: false
                            property real dragX: 0
                            property real dragY: 0

                            x: dragging ? dragX : (modelData.x - previewArea.box.x) * previewArea.sc + previewArea.pad
                            y: dragging ? dragY : (modelData.y - previewArea.box.y) * previewArea.sc + previewArea.pad
                            z: dragging ? 2 : (index === monitorHelper.selectedIndex ? 1 : 0)
                            width: monitorHelper.logicalWidth(modelData) * previewArea.sc
                            height: monitorHelper.logicalHeight(modelData) * previewArea.sc
                            visible: modelData.disabled !== true

                            Rectangle {
                                anchors.fill: parent
                                radius: 6
                                color: index === monitorHelper.selectedIndex
                                    ? Appearance.colors.colPrimaryContainer
                                    : Appearance.colors.colSurfaceContainerHigh
                                border.width: index === monitorHelper.selectedIndex ? 3 : 1
                                border.color: index === monitorHelper.selectedIndex
                                    ? Appearance.colors.colPrimary
                                    : Appearance.colors.colOutline

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 2
                                    width: parent.width - 8

                                    StyledText {
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.maximumWidth: parent.width
                                        text: modelData.displayName
                                        font.pixelSize: Math.max(8, Math.min(12, parent.width * 0.13))
                                        color: index === monitorHelper.selectedIndex
                                            ? Appearance.colors.colOnPrimaryContainer
                                            : Appearance.colors.colOnSurface
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }
                                    StyledText {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: `${modelData.width}x${modelData.height}`
                                        font.pixelSize: Math.max(7, Math.min(11, parent.width * 0.1))
                                        color: index === monitorHelper.selectedIndex
                                            ? Appearance.colors.colOnPrimaryContainer
                                            : Appearance.colors.colOnSurfaceVariant
                                    }
                                }

                                MouseArea {
                                    id: dragArea
                                    anchors.fill: parent
                                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                    property real pressOffsetX: 0
                                    property real pressOffsetY: 0

                                    onPressed: function(mouse) {
                                        monitorHelper.selectedIndex = index;
                                        pressOffsetX = mouse.x;
                                        pressOffsetY = mouse.y;
                                        monitorCard.dragX = monitorCard.x;
                                        monitorCard.dragY = monitorCard.y;
                                        monitorCard.dragging = true;
                                    }

                                    onPositionChanged: function(mouse) {
                                        if (!pressed) return;
                                        var p = mapToItem(previewArea, mouse.x, mouse.y);
                                        monitorCard.dragX = p.x - pressOffsetX;
                                        monitorCard.dragY = p.y - pressOffsetY;
                                    }

                                    onReleased: {
                                        var desiredX = previewArea.box.x + Math.round((monitorCard.dragX - previewArea.pad) / previewArea.sc);
                                        var desiredY = previewArea.box.y + Math.round((monitorCard.dragY - previewArea.pad) / previewArea.sc);
                                        monitorCard.dragging = false;
                                        monitorHelper.moveToPosition(index, desiredX, desiredY);
                                    }

                                    onCanceled: monitorCard.dragging = false
                                    onClicked: monitorHelper.selectedIndex = index
                                }
                            }
                        }
                    }
                }
            }
        }


        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            StyledComboBox {
                Layout.fillWidth: true
                textRole: "text"
                valueRole: "value"
                model: [
                    {text: Translation.tr("Only primary screen"), value: "only-first"},
                    {text: Translation.tr("Extend these displays"), value: "extend"},
                    {text: Translation.tr("Mirror screens"), value: "mirror"},
                    {text: Translation.tr("Only external screens"), value: "only-second"}
                ]
                currentValue: monitorHelper.displayMode
                onActivated: function(index) {
                    monitorHelper.setDisplayMode(model[index].value);
                }
            }

            RippleButtonWithIcon {
                materialIcon: "refresh"
                mainText: ""
                implicitWidth: 35
                implicitHeight: 35
                buttonRadius: Appearance.rounding.small
                colBackground: Appearance.colors.colLayer2
                onClicked: fetchMonitorsProc.running = true

                StyledToolTip {
                    text: Translation.tr("Refresh monitor list")
                }
            }
        }


        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: monitorHelper.selectedIndex >= 0
                    ? `Monitor ${monitorHelper.selectedIndex + 1} of ${monitorModel.count}`
                    : "No monitors"
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnSurfaceVariant
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                spacing: 4
                visible: monitorHelper.selectedIndex >= 0

                StyledText {
                    text: Translation.tr("Monitor name")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnSurfaceVariant
                }

                MaterialTextArea {
                    id: monitorNameInput
                    Layout.fillWidth: true
                    Layout.minimumHeight: 56
                    wrapMode: TextEdit.NoWrap
                    placeholderText: Translation.tr("Monitor name")

                    property bool settingText: false

                    function updateText() {
                        settingText = true;
                        text = monitorHelper.selectedIndex >= 0 && monitorHelper.selectedIndex < monitorModel.count
                            ? monitorModel.get(monitorHelper.selectedIndex).displayName : "";
                        settingText = false;
                    }

                    onTextChanged: {
                        if (settingText) return;
                        if (monitorHelper.selectedIndex >= 0 && monitorHelper.selectedIndex < monitorModel.count) {
                            monitorModel.setProperty(monitorHelper.selectedIndex, "displayName", text);
                            monitorHelper.saveDisplayNames();
                        }
                    }
                }

                StyledText {
                    Layout.topMargin: 8
                    text: Translation.tr("Screen resolution")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnSurfaceVariant
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        StyledComboBox {
                            id: resCombo
                            Layout.fillWidth: true
                            textRole: "text"
                            valueRole: "value"
                            model: monitorHelper.selectedIndex >= 0 && monitorHelper.selectedIndex < monitorModel.count
                                ? monitorHelper.resolutionOptions(JSON.parse(monitorModel.get(monitorHelper.selectedIndex).modesJson || "[]")) : []

                            currentValue: monitorHelper.selectedIndex >= 0 && monitorHelper.selectedIndex < monitorModel.count
                                ? monitorModel.get(monitorHelper.selectedIndex).width + "x" + monitorModel.get(monitorHelper.selectedIndex).height : ""

                            onActivated: function(index) {
                                if (monitorHelper.selectedIndex >= 0 && monitorHelper.selectedIndex < monitorModel.count) {
                                    monitorHelper.takeSnapshot(monitorHelper.selectedIndex);
                                    var opt = model[index];
                                    monitorModel.setProperty(monitorHelper.selectedIndex, "width", opt.w);
                                    monitorModel.setProperty(monitorHelper.selectedIndex, "height", opt.h);
                                    var m = monitorModel.get(monitorHelper.selectedIndex);
                                    var modes = JSON.parse(m.modesJson || "[]");
                                    var mh = monitorHelper.maxHzForModes(modes, opt.w, opt.h);
                                    var rr = m.refreshRate;
                                    if (rr > mh) monitorModel.setProperty(monitorHelper.selectedIndex, "refreshRate", mh);
                                    monitorHelper.saveDisplayNames();
                                    monitorHelper.applyArrangement();
                                }
                            }
                        }

                        StyledText {
                            text: Translation.tr("Refresh rate")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnSurfaceVariant
                        }

                        StyledComboBox {
                            id: hzCombo
                            Layout.fillWidth: true
                            textRole: "text"
                            valueRole: "value"
                            model: monitorHelper.selectedIndex >= 0 && monitorHelper.selectedIndex < monitorModel.count
                                ? monitorHelper.hzOptions(JSON.parse(monitorModel.get(monitorHelper.selectedIndex).modesJson || "[]"), monitorModel.get(monitorHelper.selectedIndex).width, monitorModel.get(monitorHelper.selectedIndex).height) : []

                            currentValue: monitorHelper.selectedIndex >= 0 && monitorHelper.selectedIndex < monitorModel.count
                                ? monitorModel.get(monitorHelper.selectedIndex).refreshRate : 60

                            onActivated: function(index) {
                                if (monitorHelper.selectedIndex >= 0 && monitorHelper.selectedIndex < monitorModel.count) {
                                    monitorHelper.takeSnapshot(monitorHelper.selectedIndex);
                                    var val = model[index].value;
                                    monitorModel.setProperty(monitorHelper.selectedIndex, "refreshRate", val);
                                    monitorHelper.saveDisplayNames();
                                    monitorHelper.applyArrangement();
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        StyledComboBox {
                            id: scaleCombo
                            Layout.fillWidth: true
                            textRole: "text"
                            valueRole: "value"
                            model: monitorHelper.selectedIndex >= 0 && monitorHelper.selectedIndex < monitorModel.count
                                ? monitorHelper.scaleOptions(monitorModel.get(monitorHelper.selectedIndex).width, monitorModel.get(monitorHelper.selectedIndex).height)
                                : [{text: "100 %", value: 1.0}]

                            // Match by nearest value: hyprctl reports truncated floats
                            // (1.6666666) that never compare equal to 5/3.
                            currentIndex: {
                                if (monitorHelper.selectedIndex < 0 || monitorHelper.selectedIndex >= monitorModel.count)
                                    return -1;
                                var cur = monitorModel.get(monitorHelper.selectedIndex).scale || 1.0;
                                var best = -1;
                                var bestDiff = Infinity;
                                for (var i = 0; i < model.length; i++) {
                                    var d = Math.abs(model[i].value - cur);
                                    if (d < bestDiff) {
                                        bestDiff = d;
                                        best = i;
                                    }
                                }
                                return bestDiff <= 0.005 ? best : -1;
                            }

                            onActivated: function(index) {
                                if (monitorHelper.selectedIndex >= 0 && monitorHelper.selectedIndex < monitorModel.count) {
                                    monitorHelper.takeSnapshot(monitorHelper.selectedIndex);
                                    var val = model[index].value;
                                    monitorModel.setProperty(monitorHelper.selectedIndex, "scale", val);
                                    monitorHelper.saveDisplayNames();
                                    monitorHelper.applyArrangement();
                                }
                            }
                        }

                        StyledText {
                            text: Translation.tr("Orientation")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnSurfaceVariant
                        }

                        StyledComboBox {
                            id: orientCombo
                            Layout.fillWidth: true
                            textRole: "text"
                            valueRole: "value"
                            model: [
                                {text: Translation.tr("Horizontal"), value: 0},
                                {text: Translation.tr("Vertical"), value: 1},
                                {text: Translation.tr("Horizontal (flipped)"), value: 2},
                                {text: Translation.tr("Vertical (flipped)"), value: 3}
                            ]

                            currentValue: monitorHelper.selectedIndex >= 0 && monitorHelper.selectedIndex < monitorModel.count
                                ? monitorModel.get(monitorHelper.selectedIndex).transform : 0

                            onActivated: function(index) {
                                if (monitorHelper.selectedIndex >= 0 && monitorHelper.selectedIndex < monitorModel.count) {
                                    monitorHelper.takeSnapshot(monitorHelper.selectedIndex);
                                    var val = model[index].value;
                                    monitorModel.setProperty(monitorHelper.selectedIndex, "transform", val);
                                    monitorHelper.saveDisplayNames();
                                    monitorHelper.applyArrangement();
                                }
                            }
                        }
                    }
                }
            }

            Connections {
                target: monitorHelper
                function onSelectedIndexChanged() {
                    monitorNameInput.updateText();
                }
            }

            Component.onCompleted: monitorNameInput.updateText()
        }

    }

}
