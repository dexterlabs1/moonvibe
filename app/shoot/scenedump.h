#pragma once

#include <QJsonObject>

class QQuickItem;
class QImage;

// Walks a rendered Qt Quick scene and writes down what is actually on screen:
// every visible item's scene-space rectangle, its color, its font, its text,
// and -- for text -- the background color sampled out of the rendered frame
// behind it, which is the only honest way to compute contrast when backgrounds
// come from gradients, overlapping panels and translucent scrims.
//
// The output is deliberately dumb and flat-ish (a tree of plain objects) so a
// script can reason about it without knowing anything about Qt.
namespace SceneDump
{
    // root is normally the window's contentItem; frame is the grabbed image.
    QJsonObject dump(QQuickItem* root, const QImage& frame);
}
