// Red Pill lock screen for the Lock Screen Explorer plugin.
// Copy it to ~/.config/omarchy/lock-designs/ and pick it with
//   omarchy-shell lock rescanDesigns && omarchy-shell lock setDesign my-redpill
// Edit it later with `omarchy-shell lock editDesign my-redpill`.
//
// The Choice, in the Red Pill theme's own terms: the green rain is the fiat
// matrix you were born into, the orange streams carrying a ₿ head are the way
// out. Take the blue pill and the whole screen goes back to the illusion --
// cold blue, no bitcoin, infinite supply. Both pills unlock the same way.
import QtQuick
import qs.Commons
import "../plugins/io.github.sirjul1337.lock-explorer/designs"

DesignBase {
  id: lock
  inputItem: field.input

  // The choice. Red is the default because it is the one already made:
  // the theme is called Red Pill.
  property bool redPill: true

  readonly property int cellSize: 20
  // The illusion: katakana, digits and the currencies that get printed.
  readonly property string fiatGlyphs: "ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ0123456789$€¥£%"
  // The signal: what a block hash is actually made of.
  readonly property string hashGlyphs: "0123456789abcdef"

  readonly property color fiatColor: redPill ? Color.lock.borderActive : blueColor
  readonly property color coinColor: Color.accent
  readonly property color blueColor: "#4a86c8"
  readonly property color tint: errorState ? Color.lock.textError : (redPill ? Color.accent : blueColor)
  readonly property color canvasBg: Qt.darker(Color.background, 1.4)

  // Local estimate, no network: block 840,000 (the 2024 halving) plus one
  // block per 10 minutes. Off by a few hundred blocks, hence the "≈".
  readonly property int blockHeight: 840000 + Math.max(0, Math.floor((now.getTime() - Date.UTC(2024, 3, 20, 0, 9, 27)) / 600000))
  readonly property int blocksToHalving: Math.max(0, 1050000 - blockHeight)

  function grouped(n) {
    return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ",")
  }

  // The card's column width. Field, quote and the pair of pills all line up
  // on it, and the pills grow past their half of it if the longest label
  // needs more room (a bigger [font] base-size, a translated label).
  readonly property int contentWidth: 460
  readonly property int pillGap: 16
  readonly property int pillWidth: Math.max(Math.round((contentWidth - pillGap) / 2),
                                            Math.ceil(pillMetrics.width) + 68)

  TextMetrics {
    id: pillMetrics
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    font.letterSpacing: 2
    text: "BLUE PILL · FIAT"
  }

  property var drops: []

  Wallpaper {
    anchors.fill: parent
    lock: lock
    blur: 1.0
    dim: 0.32
    vignetteTop: 0.5
    vignetteMiddle: 0.32
    vignetteBottom: 0.55
  }

  Canvas {
    id: canvas
    anchors.fill: parent
    renderStrategy: Canvas.Cooperative

    // Repaint from scratch when the pill changes so trails in the old color
    // do not linger over the new palette.
    property bool pillChoice: lock.redPill
    onPillChoiceChanged: if (available) { getContext("2d").reset(); requestPaint() }

    function resetDrops() {
      var cols = Math.ceil(width / lock.cellSize)
      var d = []
      for (var i = 0; i < cols; i++)
        d.push({ y: Math.random() * -50, speed: 0.4 + Math.random() * 0.8, coin: Math.random() < 0.12 })
      lock.drops = d
      if (available) { var ctx = getContext("2d"); ctx.reset() }
    }
    onWidthChanged: resetDrops()
    onHeightChanged: resetDrops()
    onAvailableChanged: if (available) resetDrops()

    function glyph(set) {
      return set.charAt(Math.floor(Math.random() * set.length))
    }

    onPaint: {
      var ctx = getContext("2d")
      // Fade the previous frame by erasing alpha instead of painting over it,
      // so the wallpaper keeps showing through the rain.
      ctx.globalCompositeOperation = "destination-out"
      ctx.fillStyle = Qt.rgba(0, 0, 0, 0.16)
      ctx.fillRect(0, 0, width, height)
      ctx.globalCompositeOperation = "source-over"

      ctx.font = "bold " + (lock.cellSize - 4) + "px " + Style.font.family
      var rows = height / lock.cellSize
      var d = lock.drops
      for (var i = 0; i < d.length; i++) {
        var coin = lock.redPill && d[i].coin
        var body = coin ? lock.coinColor : lock.fiatColor
        var head = coin ? Qt.lighter(lock.coinColor, 1.35) : Color.lock.text
        var set = coin ? lock.hashGlyphs : lock.fiatGlyphs
        var x = i * lock.cellSize
        var y = Math.floor(d[i].y) * lock.cellSize

        ctx.fillStyle = Qt.rgba(body.r, body.g, body.b, 0.85)
        ctx.fillText(canvas.glyph(set), x, y)
        // A bitcoin column drops hash digits with a ₿ surfacing now and then.
        ctx.fillStyle = Qt.rgba(head.r, head.g, head.b, 0.95)
        ctx.fillText(coin && Math.random() < 0.35 ? "₿" : canvas.glyph(set), x, y + lock.cellSize)

        d[i].y += d[i].speed
        if (d[i].y > rows + 10 && Math.random() > 0.97) {
          d[i].y = Math.random() * -20
          d[i].speed = 0.4 + Math.random() * 0.8
          d[i].coin = Math.random() < 0.12
        }
      }
    }
  }

  Timer {
    interval: 66
    running: canvas.visible
    repeat: true
    onTriggered: canvas.requestPaint()
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  // One of the two pills. `red` says which one this is; the chosen one lights
  // up, the other one fades back into the rain.
  component Pill: Rectangle {
    id: pill
    property bool red: false
    property color hue: "#000000"
    property string label: ""
    readonly property bool chosen: lock.redPill === pill.red
    readonly property bool hovered: pillArea.containsMouse

    width: lock.pillWidth
    height: 44
    radius: height / 2
    color: lock.withAlpha(hue, chosen ? 0.20 : (hovered ? 0.12 : 0.05))
    border.width: chosen ? 2 : 1
    border.color: lock.withAlpha(hue, chosen ? 0.95 : (hovered ? 0.6 : 0.3))
    Behavior on color { ColorAnimation { duration: 160 } }
    Behavior on border.color { ColorAnimation { duration: 160 } }

    Row {
      anchors.centerIn: parent
      spacing: 10
      Rectangle {
        width: 14
        height: 14
        radius: 7
        anchors.verticalCenter: parent.verticalCenter
        color: pill.chosen ? pill.hue : lock.withAlpha(pill.hue, 0.35)
        border.width: 1
        border.color: lock.withAlpha(pill.hue, 0.9)
        Behavior on color { ColorAnimation { duration: 160 } }
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: pill.label
        color: pill.chosen ? lock.withAlpha(Color.lock.text, 0.95) : lock.withAlpha(Color.lock.text, 0.5)
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.letterSpacing: 2
      }
    }

    MouseArea {
      id: pillArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        lock.redPill = pill.red
        lock.wakeRequested()
        lock.forcePasswordFocus()
      }
    }
  }

  Rectangle {
    anchors.centerIn: parent
    width: box.implicitWidth + 80
    height: box.implicitHeight + 64
    radius: 6
    color: lock.withAlpha(Color.background, 0.82)
    border.width: 1
    border.color: lock.withAlpha(lock.tint, 0.6)
    Behavior on border.color { ColorAnimation { duration: 160 } }

    Column {
      id: box
      anchors.centerIn: parent
      spacing: 18

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: (lock.redPill ? "₿ " : "$ ") + Qt.formatTime(lock.now, "HH:mm:ss")
        color: lock.tint
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.baseSize * 6)
        font.weight: Font.Bold
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: (lock.redPill ? "wake up, " : "sleep well, ") + lock.userName + "..."
        color: lock.withAlpha(Color.lock.text, 0.8)
        font.family: Style.font.family
        font.pixelSize: Style.font.heading
      }

      PasswordField {
        id: field
        lock: lock
        anchors.horizontalCenter: parent.horizontalCenter
        width: lock.contentWidth
        height: 50
        radius: 4
        outlineThickness: 1
        color: lock.withAlpha(Color.background, 0.6)
        placeholder: lock.redPill ? "follow the white rabbit" : "ignorance is bliss"
        // Red pill keeps the theme's green-to-orange border; blue pill takes
        // the orange out of the picture, like everything else it touches.
        borderSpec: lock.redPill
          ? Border.surfaceSpec("lock", lock.errorState ? "border-error" : "border-active",
                               lock.errorState ? Color.lock.borderError : Color.lock.borderActive, 1, "border-alpha")
          : Border.flat(lock.errorState ? Color.lock.borderError : lock.blueColor, 1)
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: lock.pillGap
        Pill { id: bluePill; red: false; hue: lock.blueColor; label: "BLUE PILL · FIAT" }
        Pill { id: redPillButton; red: true; hue: Color.accent; label: "RED PILL · ₿" }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        width: lock.contentWidth
        // A fixed two-line box: the longer hover quotes fit on one line at
        // this width, and even if a bigger font wraps them the card keeps
        // its size instead of breathing in and out under the cursor.
        height: Math.round(Style.font.caption * 2.9)
        maximumLineCount: 2
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignTop
        wrapMode: Text.WordWrap
        text: bluePill.hovered ? "you wake up in your bed and believe whatever you want to believe"
            : redPillButton.hovered ? "you stay in wonderland and I show you how deep the rabbit hole goes"
            : (lock.redPill ? "all I'm offering is the truth, nothing more" : "the story ends, and nothing changes")
        color: lock.withAlpha(Color.lock.text, 0.45)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.italic: true
      }
    }
  }

  Text {
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 36
    anchors.horizontalCenter: parent.horizontalCenter
    text: lock.redPill
      ? "≈ BLOCK " + lock.grouped(lock.blockHeight) + "   ·   HALVING IN ≈ " + lock.grouped(lock.blocksToHalving) + " BLOCKS   ·   21,000,000   ·   PROOF OF WORK"
      : "SUPPLY ∞   ·   ISSUANCE AT WILL   ·   YOUR KEYS ARE THEIRS   ·   PROOF OF TRUST"
    color: lock.withAlpha(lock.tint, 0.55)
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    font.letterSpacing: 3
  }
}
