pragma Singleton

// Always-on Discord voice bridge client for the New Wave bar.
//
// A single long-lived `discord_bridge.py` process (which speaks Discord's
// local RPC) is supervised here, and a `Quickshell.Io.Socket` client reads its
// JSON-lines protocol. This singleton holds the voice state and is consumed
// by DiscordVoicePill.qml (the bar avatars) and DiscordVoicePanel.qml (the
// popover). Mirrors MusicState.qml: a singleton that supervises a long-lived
// child process. See changes.md (Discord voice).

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    // ---------- state ----------
    property bool bridgeReady: false
    property bool authenticated: false
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

    // ---------- bridge process ----------
    // Spawn once; exit 0 means another bridge already owns the socket (so we
    // just keep using it as a client), anything else means restart.
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
            // Normal exit 0 => another bridge already owns the socket; keep
            // using it as a client. Anything else (crash/kill/non-zero) =>
            // respawn, backing off so a crash-loop can't spin.
            if (exitStatus === 0 && exitCode === 0) {
                root.bridgeReady = false
                return
            }
            console.warn("[discord] bridge exited: code=" + exitCode + " status=" + exitStatus)
            root.bridgeReady = false
            bridgeRestart.interval = root.restartDelay
            bridgeRestart.start()
            root.restartDelay = Math.min(root.restartDelay * 2, 30000)
        }
    }

    // Give the shell a moment before spawning so the path is ready, then let it
    // run for the life of the shell.
    Timer {
        id: bridgeStart
        interval: 100
        running: true
        onTriggered: bridgeProcess.running = true
    }

    Timer {
        id: bridgeRestart
        interval: 3000
        onTriggered: bridgeProcess.running = true
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
        running: true
        onTriggered: bridgeSocket.connected = true
    }

    // Watchdog: reattach after a Quickshell reload or a Discord/socket drop.
    Timer {
        interval: 3000
        repeat: true
        running: true
        onTriggered: if (!bridgeSocket.connected)
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
