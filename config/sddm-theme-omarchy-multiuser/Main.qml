import QtQuick 2.0
import SddmComponents 2.0

// Omarchy SDDM theme, with a user chooser.
//
// The stock Omarchy theme is password-only. It hardcodes
//     property string currentUser: userModel.lastUser
// and calls sddm.login() with that value, so the greeter can only ever log
// in as the last user who logged in -- there is no way to pick anyone else.
// This variant keeps the same look but adds a clickable list of users.
//
// Role ids come from sddm 0.21 src/greeter/UserModel.h:
//     NameRole    = Qt.UserRole + 1
//     RealNameRole = Qt.UserRole + 2
// Note that UserModel::data() does NOT implement Qt::DisplayRole, so the
// role number has to be used explicitly.

Rectangle {
  id: root
  width: 640
  height: 480
  color: "#1a1b26"

  readonly property int nameRole: Qt.UserRole + 1
  readonly property int realNameRole: Qt.UserRole + 2

  property string currentUser: userModel.lastUser
  property bool loginFailed: false

  property int sessionIndex: {
    for (var i = 0; i < sessionModel.rowCount(); i++) {
      var name = (sessionModel.data(sessionModel.index(i, 0), Qt.DisplayRole) || "").toString()
      if (name.indexOf("uwsm") !== -1)
        return i
    }
    return sessionModel.lastIndex
  }

  function userNameAt(row) {
    var v = userModel.data(userModel.index(row, 0), root.nameRole)
    return (v === undefined || v === null) ? "" : v.toString()
  }

  function userRealNameAt(row) {
    var v = userModel.data(userModel.index(row, 0), root.realNameRole)
    return (v === undefined || v === null) ? "" : v.toString()
  }

  function currentUserRow() {
    for (var i = 0; i < userModel.count; i++) {
      if (userNameAt(i) === root.currentUser)
        return i
    }
    return -1
  }

  function selectUserByOffset(offset) {
    if (userModel.count < 2)
      return

    var row = currentUserRow()
    if (row < 0)
      row = offset > 0 ? 0 : userModel.count - 1
    else
      row = (row + offset + userModel.count) % userModel.count

    root.currentUser = userNameAt(row)
  }

  Connections {
    target: sddm
    function onLoginFailed() {
      root.loginFailed = true
      password.text = ""
      password.focus = true
    }
    function onLoginSucceeded() {
      root.loginFailed = false
    }
  }

  Column {
    anchors.centerIn: parent
    spacing: 34

    Image {
      id: logo
      source: "logo.png"
      width: Math.min(sourceSize.width, root.width * 0.8)
      height: sourceSize.width > 0 ? Math.round(width * sourceSize.height / sourceSize.width) : 0
      fillMode: Image.PreserveAspectFit
      anchors.horizontalCenter: parent.horizontalCenter
    }

    // ---- user chooser -------------------------------------------------
    Row {
      id: userRow
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 14
      height: 28
      visible: userModel.count > 1

      Repeater {
        id: userRepeater
        model: userModel.count

        delegate: Text {
            id: chip
            property int row: index
            readonly property string uname: root.userNameAt(row)
            readonly property bool selected: root.currentUser === uname

            text: (selected ? "▸ " : "  ") + uname
            height: 28
            verticalAlignment: Text.AlignVCenter
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 19
            font.bold: selected
            color: selected ? "#f7768e" : "#7a8394"

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.currentUser = chip.uname
                password.text = ""
                password.focus = true
              }
            }
        }
      }
    }

    // ---- password ------------------------------------------------------
    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 15

      Image {
        source: root.loginFailed ? "lock-failed.png" : "lock.png"
        width: 34
        height: 38
        fillMode: Image.PreserveAspectFit
        anchors.verticalCenter: parent.verticalCenter
      }

      Item {
        width: entry.width
        height: entry.height

        Image {
          id: entry
          source: root.loginFailed ? "entry-failed.png" : "entry.png"
          anchors.centerIn: parent
        }

        Row {
          anchors.left: parent.left
          anchors.leftMargin: 20
          anchors.verticalCenter: parent.verticalCenter
          spacing: 5

          Repeater {
            model: Math.min(password.text.length, 21)

            Image {
              source: "bullet.png"
              width: 7
              height: 7
            }
          }
        }

        TextInput {
          id: password
          anchors.fill: parent
          anchors.leftMargin: 20
          anchors.rightMargin: 20
          verticalAlignment: TextInput.AlignVCenter
          echoMode: TextInput.Password
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 24
          font.letterSpacing: 5
          passwordCharacter: "•"
          color: "transparent"
          selectionColor: "transparent"
          selectedTextColor: "transparent"
          cursorDelegate: Item {}
          focus: true

          onTextChanged: root.loginFailed = false

          Keys.onPressed: {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              sddm.login(root.currentUser, password.text, root.sessionIndex)
              event.accepted = true
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
              root.selectUserByOffset(-1)
              event.accepted = true
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
              root.selectUserByOffset(1)
              event.accepted = true
            }
          }
        }
      }
    }
  }

  Component.onCompleted: {
    if (!root.currentUser || root.currentUser.length === 0) {
      if (userModel.count > 0)
        root.currentUser = root.userNameAt(0)
    }
    password.forceActiveFocus()
  }
}
