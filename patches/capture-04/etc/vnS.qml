import QtQuick 2.12
import QtQuick.Window 2.12

// Screen grid for a photo of the cluster. Global loads this page over the whole window while Factory > Screen grid is on.
// The page draws physical screen pixels with no dashboard components:
// - lines every 20 px, brighter every 100 px, with x,y labels every 200 x 100 px away from the edges;
// - colored frames 10 px apart from each screen edge, so a photo shows how many pixels the bezel or the column hides;
// - the center cross, the screen size, and the dashboard transform for the current vehicle model.
Rectangle {
    id: mGrid
    // On the cluster, main.qml sizes the window to the available screen area.
    width: Window.width
    height: Window.height
    color: "#000000"
    readonly property string family: "BMW Type Global"
    // Frame colors from the screen edge inward: 0, 10, 20, ... 70 px.
    readonly property var frames: ["#ffffff", "#ff3b30", "#ff9500", "#ffcc00", "#34c759", "#00c7be", "#0a84ff", "#bf5af2"]
    readonly property var frameNames: ["white", "red", "orange", "yellow", "green", "teal", "blue", "purple"]
    readonly property int model: Number(mTrucksModel)
    // main.qml places the dashboard with these per-model values (scale, rotation, top margin).
    readonly property string transformText: typeof window==="undefined"?"":
        "Dashboard: scale "+window.mSacel[model]+", rotation "+window.mRotation[model]+"°, top "+window.mTopMargin[model]+" px"

    Repeater {
        model: Math.floor(mGrid.width/20)+1
        Rectangle {
            x: index*20
            width: 1
            height: mGrid.height
            color: index%5===0?"#4a6a85":"#18242f"
        }
    }
    Repeater {
        model: Math.floor(mGrid.height/20)+1
        Rectangle {
            y: index*20
            width: mGrid.width
            height: 1
            color: index%5===0?"#4a6a85":"#18242f"
        }
    }
    Repeater {
        model: mGrid.frames.length
        Rectangle {
            x: index*10
            y: index*10
            width: mGrid.width-2*x
            height: mGrid.height-2*y
            color: "transparent"
            border.width: 2
            border.color: mGrid.frames[index]
        }
    }
    // x,y labels at every 200 x 100 px point inside the frames.
    Repeater {
        model: Math.floor(mGrid.width/200)*Math.floor(mGrid.height/100)
        Text {
            readonly property int column: index%Math.floor(mGrid.width/200)+1
            readonly property int row: Math.floor(index/Math.floor(mGrid.width/200))+1
            x: column*200+4
            y: row*100-22
            // Labels stay clear of the edge frames.
            visible: x<mGrid.width-170 && y<mGrid.height-90
            text: column*200+","+row*100
            font.family: mGrid.family
            font.pixelSize: 16
            color: "#8fb3d1"
        }
    }
    Rectangle {
        x: mGrid.width/2
        width: 1
        height: mGrid.height
        color: "#8fd3ff"
    }
    Rectangle {
        y: mGrid.height/2
        width: mGrid.width
        height: 1
        color: "#8fd3ff"
    }
    // The panel is see-through, so the center cross stays visible.
    Rectangle {
        anchors.centerIn: parent
        width: mInfo.width+40
        height: mInfo.height+24
        radius: 10
        color: "#b3000000"
        Column {
            id: mInfo
            anchors.centerIn: parent
            spacing: 6
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Screen "+mGrid.width+" × "+mGrid.height+" px · center "+mGrid.width/2+","+mGrid.height/2
                font.family: mGrid.family
                font.pixelSize: 28
                color: "#ffffff"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: text!==""
                text: mGrid.transformText
                font.family: mGrid.family
                font.pixelSize: 20
                color: "#9aa4af"
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 14
                Text {
                    text: "Frames from the edge:"
                    font.family: mGrid.family
                    font.pixelSize: 20
                    color: "#9aa4af"
                }
                Repeater {
                    model: mGrid.frames.length
                    Text {
                        text: mGrid.frameNames[index]+" "+index*10
                        font.family: mGrid.family
                        font.pixelSize: 20
                        color: mGrid.frames[index]
                    }
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Press any wheel key to hide the grid"
                font.family: mGrid.family
                font.pixelSize: 20
                color: "#7d8792"
            }
        }
    }
}
