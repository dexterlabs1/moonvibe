#include "scenedump.h"

#include <QQuickItem>
#include <QJsonArray>
#include <QImage>
#include <QColor>
#include <QFont>
#include <QHash>
#include <QMetaObject>

namespace
{

// QML-defined types arrive as "SettingsView_QMLTYPE_31" and C++ ones as
// "QQuickRectangle". Neither is what anyone reading a report wants to see.
QString typeName(const QObject* object)
{
    QString name = QString::fromUtf8(object->metaObject()->className());

    int qmlType = name.indexOf(QStringLiteral("_QMLTYPE"));
    if (qmlType > 0) {
        name = name.left(qmlType);
    }

    int qmlBase = name.indexOf(QStringLiteral("_QML_"));
    if (qmlBase > 0) {
        name = name.left(qmlBase);
    }

    if (name.startsWith(QStringLiteral("QQuick"))) {
        name = name.mid(6);
    }

    return name;
}

QString colorToString(const QColor& color)
{
    if (!color.isValid()) {
        return QString();
    }

    return color.alpha() == 255 ? color.name(QColor::HexRgb)
                                : color.name(QColor::HexArgb);
}

// A control the user is expected to hit. Used to check Deck-sized touch and
// focus targets, so it deliberately includes plain MouseAreas.
bool isInteractive(const QQuickItem* item)
{
    return item->inherits("QQuickAbstractButton") ||
           item->inherits("QQuickMouseArea") ||
           item->inherits("QQuickTextInput") ||
           item->inherits("QQuickComboBox") ||
           item->inherits("QQuickSlider") ||
           item->metaObject()->indexOfSignal("clicked()") >= 0;
}

// The background behind a piece of text, taken from the frame we just rendered
// rather than inferred from the item tree. Gradients, scrims and overlapping
// panels all mean the nearest ancestor Rectangle is often not what is actually
// behind the glyphs.
//
// Pixels close to the text color are ignored so the glyphs themselves do not
// win the vote; whatever is left and most common is the background.
QString sampleBackground(const QImage& frame, const QRectF& deviceRect, const QColor& textColor)
{
    QRect area = deviceRect.toAlignedRect().adjusted(-2, -2, 2, 2).intersected(frame.rect());
    if (area.width() <= 0 || area.height() <= 0) {
        return QString();
    }

    // Keep the vote cheap on large items.
    int step = 1;
    while ((area.width() / step) * (area.height() / step) > 40000) {
        step++;
    }

    QHash<QRgb, int> votes;
    int fgR = textColor.red(), fgG = textColor.green(), fgB = textColor.blue();
    bool haveText = textColor.isValid();

    for (int y = area.top(); y <= area.bottom(); y += step) {
        for (int x = area.left(); x <= area.right(); x += step) {
            QRgb pixel = frame.pixel(x, y);

            if (haveText) {
                int distance = qAbs(qRed(pixel) - fgR) +
                               qAbs(qGreen(pixel) - fgG) +
                               qAbs(qBlue(pixel) - fgB);
                if (distance < 90) {
                    continue;
                }
            }

            votes[pixel]++;
        }
    }

    QRgb winner = 0;
    int best = 0;
    for (auto it = votes.constBegin(); it != votes.constEnd(); ++it) {
        if (it.value() > best) {
            best = it.value();
            winner = it.key();
        }
    }

    if (best == 0) {
        return QString();
    }

    return colorToString(QColor(qRed(winner), qGreen(winner), qBlue(winner)));
}

QJsonObject dumpItem(QQuickItem* item, const QImage& frame, qreal scale, qreal inheritedOpacity, int depth)
{
    QJsonObject node;

    const qreal opacity = inheritedOpacity * item->opacity();
    const QRectF sceneRect = item->mapRectToScene(QRectF(0, 0, item->width(), item->height()));

    node["type"] = typeName(item);
    if (!item->objectName().isEmpty()) {
        node["name"] = item->objectName();
    }
    node["x"] = qRound(sceneRect.x() * 100) / 100.0;
    node["y"] = qRound(sceneRect.y() * 100) / 100.0;
    node["w"] = qRound(sceneRect.width() * 100) / 100.0;
    node["h"] = qRound(sceneRect.height() * 100) / 100.0;
    node["depth"] = depth;

    if (opacity < 0.999) {
        node["opacity"] = qRound(opacity * 1000) / 1000.0;
    }
    if (item->clip()) {
        node["clip"] = true;
    }
    if (!item->isEnabled()) {
        node["enabled"] = false;
    }
    if (item->hasActiveFocus()) {
        node["focus"] = true;
    }
    if (isInteractive(item)) {
        node["interactive"] = true;
    }

    QVariant color = item->property("color");
    if (color.isValid() && color.canConvert<QColor>()) {
        QString value = colorToString(color.value<QColor>());
        if (!value.isEmpty()) {
            node["color"] = value;
        }
    }

    QVariant radius = item->property("radius");
    if (radius.isValid() && radius.canConvert<qreal>() && radius.toReal() > 0) {
        node["radius"] = qRound(radius.toReal() * 100) / 100.0;
    }

    QVariant border = item->property("border");
    if (border.isValid()) {
        QObject* borderObject = border.value<QObject*>();
        if (borderObject != nullptr && borderObject->property("width").toReal() > 0) {
            node["borderWidth"] = qRound(borderObject->property("width").toReal() * 100) / 100.0;
            QString borderColor = colorToString(borderObject->property("color").value<QColor>());
            if (!borderColor.isEmpty()) {
                node["borderColor"] = borderColor;
            }
        }
    }

    QVariant text = item->property("text");
    bool hasText = text.isValid() && text.canConvert<QString>() && !text.toString().isEmpty();
    if (hasText) {
        node["text"] = text.toString();

        QVariant font = item->property("font");
        if (font.isValid() && font.canConvert<QFont>()) {
            QFont f = font.value<QFont>();
            node["fontFamily"] = f.family();
            node["fontSize"] = f.pixelSize() > 0 ? f.pixelSize() : -f.pointSize();
            node["fontWeight"] = f.weight();
            if (!qFuzzyIsNull(f.letterSpacing())) {
                node["letterSpacing"] = qRound(f.letterSpacing() * 100) / 100.0;
            }
        }

        // Text that does not fit and has no elide is text the user cannot read.
        QVariant elide = item->property("elide");
        if (elide.isValid()) {
            node["elide"] = elide.toInt();
        }
        node["implicitW"] = qRound(item->implicitWidth() * 100) / 100.0;
        node["implicitH"] = qRound(item->implicitHeight() * 100) / 100.0;

        if (!frame.isNull() && opacity > 0.05) {
            QRectF deviceRect(sceneRect.x() * scale, sceneRect.y() * scale,
                              sceneRect.width() * scale, sceneRect.height() * scale);
            QString background = sampleBackground(frame, deviceRect,
                                                  item->property("color").value<QColor>());
            if (!background.isEmpty()) {
                node["bgSampled"] = background;
            }
        }
    }

    QJsonArray children;
    const auto childItems = item->childItems();
    for (QQuickItem* child : childItems) {
        // An invisible or zero-sized item is not part of what the user sees, and
        // its whole subtree is invisible with it.
        if (!child->isVisible() || child->width() <= 0 || child->height() <= 0) {
            continue;
        }

        children.append(dumpItem(child, frame, scale, opacity, depth + 1));
    }

    if (!children.isEmpty()) {
        node["children"] = children;
    }

    return node;
}

} // namespace

QJsonObject SceneDump::dump(QQuickItem* root, const QImage& frame)
{
    QJsonObject result;

    // The grab comes back in device pixels; the item tree is in logical ones.
    qreal scale = 1.0;
    if (!frame.isNull() && root->width() > 0) {
        scale = frame.width() / root->width();
    }

    result["width"] = root->width();
    result["height"] = root->height();
    result["scale"] = scale;
    result["root"] = dumpItem(root, frame, scale, 1.0, 0);

    return result;
}
