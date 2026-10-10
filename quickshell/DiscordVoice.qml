pragma Singleton

// Discord voice bridge client for the New Wave bar — started lazily.
//
// `discord_bridge.py` (which speaks Discord's local RPC) is only spawned while
// Discord is actually running, and stopped when Discord closes (see the
// presence gate below), so the bar carries no python process at all while
// Discord is shut. A `Quickshell.Io.Socket` client reads its JSON-lines
// protocol. This singleton holds the voice state and is consumed by
// DiscordVoicePill.qml (the bar avatars) and DiscordVoicePanel.qml (the
// popover). Mirrors MusicState.qml: a singleton that supervises a long-lived
// child process.

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    // ---------- state ----------
    property bool bridgeReady: false
    property bool authenticated: false
    // Whether Discord itself is running (its local IPC is reachable). The pill
    // stays hidden while Discord is closed, so a not-yet-started Discord can't
    // leave a placeholder stuck in the bar.
    property bool discordRunning: false
    property string authError: ""
    property var currentChannel: null
    property var voiceUsers: []
    property var speakingUsers: ({})
    property var voiceSettings: ({mute: false, deaf: false})

    // Restart backoff for the bridge process: doubles on each crash up to 30s,
    // so a persistently failing bridge can't hot-loop the 3s respawn. Reset to
    // the base value whenever the bridge reports ready.
    property int restartDelay: 3000

    readonly property bool inVoice: currentChannel !== null && currentChannel !== undefined
    readonly property bool isMuted: voiceSettings.mute || false
    readonly property bool isDeafened: voiceSettings.deaf || false

    // Discord's public StreamKit client ID (no secret). Matches the bridge.
    readonly property string clientId: "207646673902501888"
    readonly property string bridgeSocketPath: {
        const runtime = Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
        return runtime + "/newwave-discord-voice.sock"
    }

    // ---------- helpers ----------
    // Discord's CDN serves avatars at this URL; `avatarHash` may be empty for
    // users on the legacy default avatar.
    function avatarUrl(userId, avatarHash) {
        if (!avatarHash) return ""
        return "https://cdn.discordapp.com/avatars/" + userId + "/" + avatarHash + ".png?size=64"
    }

    function sendBridgeCommand(cmd) {
        if (bridgeSocket.connected) {
            bridgeSocket.write(JSON.stringify(cmd) + "\n")
            bridgeSocket.flush()
        }
    }

    // ---------- controls ----------
    function authorize() { sendBridgeCommand({cmd: "authorize"}) }

    function toggleMute() {
        sendBridgeCommand({cmd: "set_voice_settings", mute: !root.isMuted})
    }

    function toggleDeafen() {
        sendBridgeCommand({cmd: "set_voice_settings", deaf: !root.isDeafened})
    }

    function hangup() { sendBridgeCommand({cmd: "hangup"}) }

    function status() {
        if (!authenticated) return "NOT_AUTHENTICATED"
        if (!inVoice) return "NOT_IN_VOICE"
        return JSON.stringify({
            channel: currentChannel ? currentChannel.name : "",
            users: voiceUsers.length,
            muted: isMuted,
            deafened: isDeafened
        })
    }

    // ---------- Discord presence gate ----------
    // The bridge is a whole python process, so it is only spawned while Discord
    // itself is running. Discord creates its local IPC socket
    // ($XDG_RUNTIME_DIR/discord-ipc-N) when it starts and removes it when it
    // closes; this watches that socket with an all-builtin bash loop and emits
    // "up"/"down" only when the state changes. Discord closed => the bridge is
    // stopped outright (no lingering python); Discord open => it starts and
    // reconnects.
    //
    // There is no cheap way to detect "joined a voice call" *without* the
    // bridge — the bridge is the thing that reports voice state — so the gate is
    // Discord-open. The bits that only matter in a call (avatar image downloads,
    // the avatar strip) still activate only on a real voice_channel event.
    Process {
        id: discordGate
        running: true
        command: ["bash", "-c",
            'd="${XDG_RUNTIME_DIR:-/tmp}"; last=""; '
            + 'while :; do cur=down; '
            + 'for i in 0 1 2 3 4 5 6 7 8 9; do [ -S "$d/discord-ipc-$i" ] && { cur=up; break; }; done; '
            + 'if [ "$cur" != "$last" ]; then echo "$cur"; last="$cur"; fi; '
            + 'sleep 2; done']
        stdout: SplitParser {
            onRead: function (line) { root.onDiscordPresence(line === "up") }
        }
    }

    function onDiscordPresence(up) {
        discordRunning = up
        if (up) {
            if (!bridgeProcess.running) {
                restartDelay = 3000
                bridgeProcess.running = true
            }
            socketConnect.restart()
        } else {
            if (bridgeProcess.running)
                bridgeProcess.running = false
            // Drop all state so a closed Discord leaves nothing stale in the bar.
            authenticated = false
            bridgeReady = false
            currentChannel = null
            voiceUsers = []
            speakingUsers = ({})
            if (bridgeSocket.connected)
                bridgeSocket.connected = false
        }
    }

    // ---------- bridge process ----------
    // Started/stopped by the presence gate above — never spawned while Discord
    // is closed. Exit 0 means another bridge already owns the socket (so we just
    // keep using it as a client); anything else means restart, but only while
    // Discord is still running and with exponential backoff so a crash-loop
    // can't spin.
    Process {
        id: bridgeProcess
        command: ["python3", Qt.resolvedUrl("discord_bridge.py").toString().replace("file://", ""),
                   root.bridgeSocketPath, root.clientId]

        // Stream the bridge's stderr live, but only surface warnings/errors
        // (the bridge logs routine INFO lines that would otherwise spam the
        // Quickshell log on every reload).
        stderr: SplitParser {
            onRead: function (line) {
                if (line.indexOf("WARNING") >= 0 || line.indexOf("ERROR") >= 0)
                    console.warn("[discord] " + line)
            }
        }

        // Drain stdout as well: the child must never block writing to a pipe
        // nobody reads. (The bridge currently logs to stderr only.)
        stdout: StdioCollector {}

        onExited: function (exitCode, exitStatus) {
            root.bridgeReady = false
            // Normal exit 0 => another bridge already owns the socket; keep
            // using it as a client.
            if (exitStatus === 0 && exitCode === 0)
                return
            // Stopped because the gate saw Discord close (running=false set by
            // onDiscordPresence): do not respawn.
            if (!root.discordRunning)
                return
            console.warn("[discord] bridge exited: code=" + exitCode + " status=" + exitStatus)
            bridgeRestart.interval = root.restartDelay
            bridgeRestart.start()
            root.restartDelay = Math.min(root.restartDelay * 2, 30000)
        }
    }

    Timer {
        id: bridgeRestart
        interval: 3000
        onTriggered: if (root.discordRunning) bridgeProcess.running = true
    }

    // ---------- socket client ----------
    Socket {
        id: bridgeSocket
        path: root.bridgeSocketPath
        connected: false

        parser: SplitParser {
            onRead: function (line) {
                if (!line)
                    return
                try {
                    root.handleBridgeMessage(JSON.parse(line))
                } catch (e) {
                    console.warn("[discord] parse error: " + e)
                }
            }
        }
    }

    // Connect the client after the (re)started bridge has had a moment to
    // create its socket file.
    Timer {
        id: socketConnect
        interval: 800
        onTriggered: if (root.discordRunning) bridgeSocket.connected = true
    }

    // Watchdog: reattach after a Quickshell reload or a Discord/socket drop.
    Timer {
        interval: 3000
        repeat: true
        running: true
        onTriggered: if (root.discordRunning && !bridgeSocket.connected)
            bridgeSocket.connected = true
    }

    // ---------- protocol ----------
    function handleBridgeMessage(msg) {
        switch (msg.type) {
        case "ready":
            bridgeReady = true
            restartDelay = 3000
            sendBridgeCommand({cmd: "connect"})
            break

        case "auth_required":
            authenticated = false
            authError = ""
            break

        case "auth_complete":
            authenticated = true
            authError = ""
            break

        case "auth_error":
            authError = msg.error || "Authentication failed"
            authenticated = false
            break

        case "discord_status":
            discordRunning = msg.running === true
            break

        case "voice_channel":
            currentChannel = msg.channel || null
            if (!msg.channel) {
                voiceUsers = []
                speakingUsers = ({})
            }
            break

        case "voice_state":
            voiceUsers = msg.users || []
            break

        case "speaking":
            var updated = Object.assign({}, speakingUsers)
            updated[msg.user_id] = msg.speaking
            speakingUsers = updated
            break

        case "voice_settings":
            voiceSettings = {mute: msg.mute || false, deaf: msg.deaf || false}
            break

        case "disconnected":
            authenticated = false
            currentChannel = null
            voiceUsers = []
            speakingUsers = ({})
            voiceSettings = {mute: false, deaf: false}
            break

        case "error":
            console.warn("[discord] bridge error: " + msg.error)
            break
        }
    }
}
