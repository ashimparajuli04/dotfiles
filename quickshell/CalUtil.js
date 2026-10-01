.pragma library

// ---------- color helpers ----------
var NAMED_COLORS = {
    "black": "#000000",
    "white": "#FFFFFF",
    "brown": "#A52A2A",
    "yellow": "#FFD60A",
    "dark gray": "#808080",
    "dark green": "#2E8B57",
    "dark blue": "#0A84FF",
    "light gray": "#D3D3D3",
    "light green": "#90EE90",
    "light blue": "#ADD8E6",
    "dark magenta": "#8B008B",
    "dark cyan": "#008B8B",
    "dark red": "#B22222",
    "light magenta": "#FF7AD9",
    "light cyan": "#E0FFFF",
    "light red": "#FF6B6B"
}

var PALETTE = ["#0A84FF", "#30D158", "#FF9F0A", "#BF5AF2", "#64D2FF", "#FFD60A", "#FF375F", "#5E5CE6"]

var DAYS = ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"]
var DAYS_SHORT = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
var MONTHS = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
var MONTHS_LONG = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

// khal reports all-day end dates inclusively (single-day event: start==end),
// so no adjustment is needed.
var ALLDAY_END_EXCLUSIVE = false

function pad2(n) {
    return (n < 10 ? "0" : "") + n
}

function fmtDate(d) {
    return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate())
}

function addDays(d, n) {
    return new Date(d.getFullYear(), d.getMonth(), d.getDate() + n)
}

function parseDate(s) {
    var p = ("" + s).split("-")
    if (p.length !== 3)
        return new Date()
    return new Date(parseInt(p[0], 10), parseInt(p[1], 10) - 1, parseInt(p[2], 10))
}

function now12() {
    var d = new Date()
    var h = d.getHours()
    var ap = h >= 12 ? "PM" : "AM"
    h = h % 12
    if (h === 0)
        h = 12
    return h + ":" + pad2(d.getMinutes()) + " " + ap
}

function nowStamp() {
    var d = new Date()
    var h = d.getHours()
    var ap = h >= 12 ? "PM" : "AM"
    h = h % 12
    if (h === 0)
        h = 12
    return DAYS_SHORT[d.getDay()] + " " + d.getDate() + " · "
         + h + ":" + pad2(d.getMinutes()) + " " + ap
}

function fmt12(t) {
    if (!t || t === "")
        return ""
    var p = ("" + t).split(":")
    if (p.length < 2)
        return t
    var h = parseInt(p[0], 10)
    var ap = h >= 12 ? "PM" : "AM"
    h = h % 12
    if (h === 0)
        h = 12
    return h + ":" + p[1] + " " + ap
}

function rgbParts(hex) {
    var h = ("" + hex).replace("#", "")
    if (h.length === 3)
        h = h.charAt(0) + h.charAt(0) + h.charAt(1) + h.charAt(1) + h.charAt(2) + h.charAt(2)
    if (h.length < 6)
        return [10, 132, 255]
    return [parseInt(h.substring(0, 2), 16), parseInt(h.substring(2, 4), 16), parseInt(h.substring(4, 6), 16)]
}

function hex2(n) {
    var s = Math.round(n).toString(16)
    return s.length < 2 ? "0" + s : s
}

function tint(hex, alpha) {
    var p = rgbParts(hex)
    var a = Math.round(Math.max(0, Math.min(1, alpha)) * 255)
    return "#" + hex2(a) + hex2(p[0]) + hex2(p[1]) + hex2(p[2])
}

function lighten(hex, factor) {
    var p = rgbParts(hex)
    var out = []
    for (var i = 0; i < 3; i++) {
        var v = Math.round(p[i] * factor)
        if (v > 255)
            v = 255
        out.push(hex2(v))
    }
    return "#" + out[0] + out[1] + out[2]
}

function colorOf(raw, calendar) {
    var c = raw && ("" + raw).length ? "" + raw : ""
    if (c.charAt(0) === "#")
        return c
    var n = NAMED_COLORS[c.toLowerCase()]
    if (n)
        return n
    return fallbackColor(calendar || "")
}

function fallbackColor(name) {
    var h = 0
    for (var i = 0; i < name.length; i++)
        h = (h * 31 + name.charCodeAt(i)) % 100003
    return PALETTE[h % PALETTE.length]
}

// ---------- khal JSON ----------
function normalize(e) {
    var sd = e["start-date"] || ""
    if (!sd)
        return null
    var allDay = e["all-day"] === true || e["all-day"] === "True"
    var ed = e["end-date"] || sd
    var cal = e["calendar"] || ""
    return {
        "title": e["title"] || "(untitled)",
        "startDate": sd,
        "endDate": ed,
        "startTime": allDay ? "" : (e["start-time-full"] || "00:00"),
        "endTime": allDay ? "" : (e["end-time-full"] || ""),
        "allDay": allDay,
        "location": e["location"] || "",
        "calendar": cal,
        "color": colorOf(e["calendar-color"], cal),
        "description": e["description"] || "",
        "uid": e["uid"] || ""
    }
}

function parseKhal(text) {
    var out = []
    if (!text)
        return out
    // khal list --json prints one compact JSON array per day; merge them all.
    var lines = ("" + text).split("\n")
    for (var li = 0; li < lines.length; li++) {
        var line = lines[li].trim()
        if (line === "")
            continue
        var arr
        try {
            arr = JSON.parse(line)
        } catch (err) {
            continue
        }
        if (!arr || arr.length === undefined)
            continue
        for (var i = 0; i < arr.length; i++) {
            var ev = normalize(arr[i])
            if (ev)
                out.push(ev)
        }
    }
    return out
}

// ---------- event math ----------
function endVisibleDate(ev) {
    if (!ev.allDay)
        return ev.endDate
    if (ALLDAY_END_EXCLUSIVE && ev.endDate > ev.startDate)
        return fmtDate(addDays(parseDate(ev.endDate), -1))
    return ev.endDate
}

function startStamp(ev) {
    return ev.startDate + " " + (ev.allDay ? "00:00" : ev.startTime)
}

function endStamp(ev) {
    return endVisibleDate(ev) + " " + (ev.allDay ? "23:59" : (ev.endTime || "23:59"))
}

function cmpEvents(a, b) {
    if (a.allDay !== b.allDay)
        return a.allDay ? -1 : 1
    var sa = startStamp(a)
    var sb = startStamp(b)
    if (sa !== sb)
        return sa < sb ? -1 : 1
    if (a.title !== b.title)
        return a.title < b.title ? -1 : 1
    return 0
}

function eventsOn(events, dayStr) {
    var out = []
    for (var i = 0; i < events.length; i++) {
        var ev = events[i]
        if (ev.startDate <= dayStr && dayStr <= endVisibleDate(ev))
            out.push(ev)
    }
    out.sort(cmpEvents)
    return out
}

function dedupe(events) {
    var seen = {}
    var out = []
    for (var i = 0; i < events.length; i++) {
        var ev = events[i]
        var k = ev.uid + "|" + ev.startDate + "|" + ev.startTime + "|" + ev.title + "|" + ev.calendar
        if (seen[k])
            continue
        seen[k] = true
        out.push(ev)
    }
    return out
}

function dayHeader(dayStr) {
    var d = parseDate(dayStr)
    return DAYS[d.getDay()] + ", " + d.getDate() + " " + MONTHS[d.getMonth()]
}

function monthName(m) {
    return MONTHS_LONG[m]
}
