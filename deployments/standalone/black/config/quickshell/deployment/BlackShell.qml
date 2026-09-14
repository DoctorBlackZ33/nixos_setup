import QtQuick

Item {
    id: shell
    required property var config
    default property alias content: content.data

    Item {
        id: content
    }
}
