#include "streamdrawer.h"

#include <QFile>
#include <cmath>

// The design tokens, mirrored from app/gui/Theme.qml. They are duplicated
// rather than shared because nothing here can reach QML -- if Theme.qml
// changes, these change with it.
namespace {

const SDL_Color kBg          = {0x0d, 0x0e, 0x15, 0xF2};
const SDL_Color kPanel       = {0x16, 0x18, 0x26, 0xFF};
const SDL_Color kPanelHi     = {0x1d, 0x20, 0x32, 0xFF};
const SDL_Color kLine        = {0x23, 0x27, 0x3a, 0xFF};
const SDL_Color kLineHi      = {0x2a, 0x2e, 0x45, 0xFF};
const SDL_Color kText        = {0xec, 0xee, 0xf8, 0xFF};
const SDL_Color kTextMuted   = {0x8b, 0x91, 0xad, 0xFF};
const SDL_Color kTextFaint   = {0x4b, 0x50, 0x69, 0xFF};
const SDL_Color kAccent      = {0x8f, 0xa6, 0xff, 0xFF};
const SDL_Color kOk          = {0x5b, 0xd5, 0x8c, 0xFF};
const SDL_Color kWarn        = {0xf0, 0xb3, 0x5c, 0xFF};
const SDL_Color kDanger      = {0xef, 0x73, 0x73, 0xFF};
const SDL_Color kTransparent = {0, 0, 0, 0};

const int kPad = 26;

SDL_Color withAlpha(SDL_Color c, Uint8 a)
{
    c.a = a;
    return c;
}

}

StreamDrawer::StreamDrawer()
{
    loadFonts();
}

StreamDrawer::~StreamDrawer()
{
    for (TTF_Font* f : {m_FontMicro, m_FontLabel, m_FontBody, m_FontTitle}) {
        if (f != nullptr) {
            TTF_CloseFont(f);
        }
    }
}

bool StreamDrawer::loadFonts()
{
    if (TTF_WasInit() == 0 && TTF_Init() != 0) {
        SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION, "TTF_Init() failed: %s", TTF_GetError());
        return false;
    }

    // The same faces the rest of the UI uses, straight out of the resource
    // bundle. The QByteArrays must outlive the fonts, hence the members.
    QFile body(QStringLiteral(":/fonts/Manrope-Bold.ttf"));
    QFile display(QStringLiteral(":/fonts/SpaceGrotesk-Bold.ttf"));
    if (!body.open(QIODevice::ReadOnly) || !display.open(QIODevice::ReadOnly)) {
        SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION, "Drawer fonts missing from resources");
        return false;
    }

    m_BodyFontData = body.readAll();
    m_DisplayFontData = display.readAll();

    auto open = [](const QByteArray& data, int size) -> TTF_Font* {
        return TTF_OpenFontRW(SDL_RWFromConstMem(data.constData(), data.size()), 1, size);
    };

    m_FontMicro = open(m_BodyFontData, 12);
    m_FontLabel = open(m_BodyFontData, 14);
    m_FontBody  = open(m_BodyFontData, 16);
    m_FontTitle = open(m_DisplayFontData, 26);

    return m_FontBody != nullptr;
}

void StreamDrawer::setStatus(const Status& status)
{
    m_Status = status;
}

void StreamDrawer::moveUp()
{
    m_Selected = (m_Selected + RowCount - 1) % RowCount;
}

void StreamDrawer::moveDown()
{
    m_Selected = (m_Selected + 1) % RowCount;
}

void StreamDrawer::adjustLeft()
{
    if (m_Selected == RowBitrate) {
        m_Status.bitrateKbps = qMax(500, m_Status.bitrateKbps - 5000);
    }
    else if (m_Selected == RowRefresh) {
        m_Status.fps = m_Status.fps > 60 ? 60 : (m_Status.fps > 40 ? 40 : 30);
    }
    else if (m_Selected == RowHdr) {
        m_Status.hdr = false;
    }
    else if (m_Selected == RowGyro) {
        m_Status.gyroEnabled = false;
    }
    else if (m_Selected == RowMic) {
        m_Status.micMuted = true;
    }
}

void StreamDrawer::adjustRight()
{
    if (m_Selected == RowBitrate) {
        m_Status.bitrateKbps = qMin(m_Status.bitrateMaxKbps, m_Status.bitrateKbps + 5000);
    }
    else if (m_Selected == RowRefresh) {
        m_Status.fps = m_Status.fps < 40 ? 40 : (m_Status.fps < 60 ? 60 : 90);
    }
    else if (m_Selected == RowHdr) {
        m_Status.hdr = true;
    }
    else if (m_Selected == RowGyro) {
        m_Status.gyroEnabled = true;
    }
    else if (m_Selected == RowMic) {
        m_Status.micMuted = false;
    }
}

void StreamDrawer::blendPixel(SDL_Surface* s, int x, int y, SDL_Color c, float coverage)
{
    if (x < 0 || y < 0 || x >= s->w || y >= s->h || coverage <= 0.0f) {
        return;
    }

    float a = (c.a / 255.0f) * qMin(1.0f, coverage);
    Uint32* p = (Uint32*)((Uint8*)s->pixels + y * s->pitch) + x;

    Uint8 dr, dg, db, da;
    SDL_GetRGBA(*p, s->format, &dr, &dg, &db, &da);

    auto mix = [a](Uint8 src, Uint8 dst) -> Uint8 {
        return (Uint8)qBound(0.0f, src * a + dst * (1.0f - a), 255.0f);
    };

    *p = SDL_MapRGBA(s->format,
                     mix(c.r, dr), mix(c.g, dg), mix(c.b, db),
                     (Uint8)qBound(0.0f, c.a * a + da * (1.0f - a), 255.0f));
}

void StreamDrawer::fillRect(SDL_Surface* s, int x, int y, int w, int h, SDL_Color c)
{
    for (int yy = y; yy < y + h; yy++) {
        for (int xx = x; xx < x + w; xx++) {
            blendPixel(s, xx, yy, c, 1.0f);
        }
    }
}

namespace {

// Coverage of a rounded rectangle at a point, 0..1, antialiased at the corners.
float roundedCoverage(int w, int h, int radius, int px, int py)
{
    if (px < 0 || py < 0 || px >= w || py >= h) {
        return 0.0f;
    }

    int cx = -1, cy = -1;
    if (px < radius && py < radius)                  { cx = radius;         cy = radius; }
    else if (px >= w - radius && py < radius)        { cx = w - radius - 1; cy = radius; }
    else if (px < radius && py >= h - radius)        { cx = radius;         cy = h - radius - 1; }
    else if (px >= w - radius && py >= h - radius)   { cx = w - radius - 1; cy = h - radius - 1; }

    if (cx < 0) {
        return 1.0f;
    }

    float d = std::sqrt(float((px - cx) * (px - cx) + (py - cy) * (py - cy)));
    return qBound(0.0f, radius - d + 0.5f, 1.0f);
}

}

void StreamDrawer::fillRoundedRect(SDL_Surface* s, int x, int y, int w, int h, int radius, SDL_Color c)
{
    radius = qMin(radius, qMin(w, h) / 2);

    for (int yy = 0; yy < h; yy++) {
        for (int xx = 0; xx < w; xx++) {
            blendPixel(s, x + xx, y + yy, c, roundedCoverage(w, h, radius, xx, yy));
        }
    }
}

void StreamDrawer::strokeRoundedRect(SDL_Surface* s, int x, int y, int w, int h, int radius, int thickness, SDL_Color c)
{
    radius = qMin(radius, qMin(w, h) / 2);

    // The ring is the outer shape minus the shape inset by the stroke width.
    // Subtracting coverages keeps the corners antialiased on both edges, and
    // crucially leaves whatever is underneath untouched -- the previous version
    // filled the interior and so painted solid blocks instead of borders.
    for (int yy = 0; yy < h; yy++) {
        for (int xx = 0; xx < w; xx++) {
            float outer = roundedCoverage(w, h, radius, xx, yy);
            float inner = roundedCoverage(w - thickness * 2, h - thickness * 2,
                                          qMax(0, radius - thickness),
                                          xx - thickness, yy - thickness);
            blendPixel(s, x + xx, y + yy, c, outer - inner);
        }
    }
}

int StreamDrawer::textWidth(TTF_Font* font, const QString& text)
{
    if (font == nullptr) {
        return 0;
    }
    int w = 0, h = 0;
    TTF_SizeUTF8(font, text.toUtf8().constData(), &w, &h);
    return w;
}

int StreamDrawer::drawText(SDL_Surface* s, TTF_Font* font, const QString& text, int x, int y, SDL_Color c)
{
    if (font == nullptr || text.isEmpty()) {
        return 0;
    }

    SDL_Color plain = {c.r, c.g, c.b, 0xFF};
    SDL_Surface* rendered = TTF_RenderUTF8_Blended(font, text.toUtf8().constData(), plain);
    if (rendered == nullptr) {
        return 0;
    }

    SDL_Rect dst = {x, y, rendered->w, rendered->h};
    SDL_SetSurfaceBlendMode(rendered, SDL_BLENDMODE_BLEND);
    SDL_BlitSurface(rendered, nullptr, s, &dst);

    int width = rendered->w;
    SDL_FreeSurface(rendered);
    return width;
}

void StreamDrawer::drawSectionLabel(SDL_Surface* s, const QString& text, int x, int y)
{
    // Tracked-out small caps, the same treatment the QML sections use. TTF has
    // no letter-spacing, so it is applied by drawing character by character.
    int cursor = x;
    const QString upper = text.toUpper();
    for (int i = 0; i < upper.length(); i++) {
        cursor += drawText(s, m_FontMicro, upper.mid(i, 1), cursor, y, kTextMuted);
        cursor += 2;
    }
}

void StreamDrawer::drawPill(SDL_Surface* s, int x, int y, int h, const QString& text,
                            SDL_Color fg, SDL_Color bg, SDL_Color border)
{
    int w = textWidth(m_FontMicro, text) + 22;
    fillRoundedRect(s, x, y, w, h, h / 2, bg);
    if (border.a > 0) {
        strokeRoundedRect(s, x, y, w, h, h / 2, 1, border);
    }
    drawText(s, m_FontMicro, text, x + 11, y + (h - 15) / 2, fg);
}

void StreamDrawer::drawRowHighlight(SDL_Surface* s, int x, int y, int w, int h, bool selected)
{
    if (!selected) {
        return;
    }
    fillRoundedRect(s, x - 10, y - 6, w + 20, h + 12, 10, kPanelHi);
    fillRoundedRect(s, x - 10, y - 6 + (h + 12) / 2 - 9, 3, 18, 2, kAccent);
}

SDL_Surface* StreamDrawer::render(int windowWidth, int windowHeight)
{
    if (!m_Open || m_FontBody == nullptr) {
        return nullptr;
    }

    const int w = panelWidth();
    const int h = windowHeight;
    Q_UNUSED(windowWidth);

    SDL_Surface* s = SDL_CreateRGBSurfaceWithFormat(0, w, h, 32, SDL_PIXELFORMAT_ARGB8888);
    if (s == nullptr) {
        return nullptr;
    }
    SDL_FillRect(s, nullptr, SDL_MapRGBA(s->format, 0, 0, 0, 0));

    fillRect(s, 0, 0, w, h, kBg);
    fillRect(s, 0, 0, 1, h, kLine);

    int y = kPad;

    // ---- Session ----
    drawSectionLabel(s, QStringLiteral("Session"), kPad, y);
    y += 22;

    const QString mode = QStringLiteral("%1p · %2").arg(m_Status.height).arg(m_Status.fps);
    drawText(s, m_FontTitle, mode, kPad, y, kText);
    int modeW = textWidth(m_FontTitle, mode);
    QString codecLine = m_Status.codec;
    if (m_Status.hdr) {
        codecLine += QStringLiteral(" · HDR");
    }
    drawText(s, m_FontLabel, codecLine, kPad + modeW + 12, y + 10, kTextMuted);
    y += 46;

    // One honest verdict, then the evidence.
    SDL_Color healthColor = m_Status.health == Status::HealthGood ? kOk
                          : m_Status.health == Status::HealthStrained ? kWarn
                          : kDanger;
    fillRoundedRect(s, kPad, y, w - kPad * 2, 62, 10, withAlpha(healthColor, 0x14));
    strokeRoundedRect(s, kPad, y, w - kPad * 2, 62, 10, 1, withAlpha(healthColor, 0x55));

    // Signal bars: filled to match the verdict.
    int bars = m_Status.health == Status::HealthGood ? 4
             : m_Status.health == Status::HealthStrained ? 2 : 1;
    for (int i = 0; i < 4; i++) {
        int bh = 6 + i * 3;
        fillRect(s, kPad + 14 + i * 7, y + 34 - bh, 4, bh, i < bars ? healthColor : kLineHi);
    }

    const QString verdict = m_Status.health == Status::HealthGood ? QStringLiteral("Holding steady")
                          : m_Status.health == Status::HealthStrained ? QStringLiteral("Struggling")
                          : QStringLiteral("Not keeping up");
    drawText(s, m_FontBody, verdict, kPad + 52, y + 12, healthColor);
    drawText(s, m_FontMicro, m_Status.healthDetail, kPad + 52, y + 34, kTextMuted);
    y += 84;

    // ---- Bitrate ----
    drawRowHighlight(s, kPad, y, w - kPad * 2, 58, m_Selected == RowBitrate);
    drawSectionLabel(s, QStringLiteral("Bitrate"), kPad, y);
    drawPill(s, kPad + 92, y - 3, 20, QStringLiteral("LIVE"), kAccent,
             withAlpha(kAccent, 0x24), withAlpha(kAccent, 0x66));

    const QString rate = QStringLiteral("%1 Mbps").arg(m_Status.bitrateKbps / 1000);
    drawText(s, m_FontBody, rate, w - kPad - textWidth(m_FontBody, rate), y - 4, kText);
    y += 26;

    // Track and fill
    fillRoundedRect(s, kPad, y, w - kPad * 2, 8, 4, kPanelHi);
    float frac = m_Status.bitrateMaxKbps > 0
            ? qBound(0.0f, float(m_Status.bitrateKbps) / m_Status.bitrateMaxKbps, 1.0f) : 0.0f;
    fillRoundedRect(s, kPad, y, int((w - kPad * 2) * frac), 8, 4, kAccent);
    int knobX = kPad + int((w - kPad * 2) * frac);
    fillRoundedRect(s, knobX - 9, y - 5, 18, 18, 9, kText);
    fillRoundedRect(s, knobX - 6, y - 2, 12, 12, 6, kAccent);
    y += 40;

    // ---- Display ----
    drawRowHighlight(s, kPad, y, w - kPad * 2, 58, m_Selected == RowRefresh);
    drawSectionLabel(s, QStringLiteral("Display"), kPad, y);
    y += 24;

    const int rates[] = {40, 60, 90};
    int px = kPad;
    for (int r : rates) {
        bool active = m_Status.fps == r;
        int pw = (w - kPad * 2 - 16) / 3;
        fillRoundedRect(s, px, y, pw, 38, 9, active ? kPanelHi : kPanel);
        strokeRoundedRect(s, px, y, pw, 38, 9, 1, active ? kAccent : kLine);
        const QString label = QStringLiteral("%1 Hz").arg(r);
        drawText(s, m_FontLabel, label, px + (pw - textWidth(m_FontLabel, label)) / 2, y + 10,
                 active ? kText : kTextMuted);
        px += pw + 8;
    }
    y += 54;

    // HDR row
    drawRowHighlight(s, kPad, y, w - kPad * 2, 40, m_Selected == RowHdr);
    fillRoundedRect(s, kPad, y, w - kPad * 2, 40, 9, kPanel);
    strokeRoundedRect(s, kPad, y, w - kPad * 2, 40, 9, 1, kLine);
    drawText(s, m_FontLabel, QStringLiteral("HDR"), kPad + 14, y + 11, kText);
    drawText(s, m_FontMicro, QStringLiteral("reconnects"),
             w - kPad - 76 - textWidth(m_FontMicro, QStringLiteral("reconnects")), y + 13, kTextFaint);
    // Switch
    fillRoundedRect(s, w - kPad - 58, y + 9, 44, 22, 11, m_Status.hdr ? kAccent : kLineHi);
    fillRoundedRect(s, w - kPad - 58 + (m_Status.hdr ? 24 : 3), y + 12, 16, 16, 8,
                    m_Status.hdr ? kBg : kTextMuted);
    y += 58;

    // ---- Input and audio ----
    drawSectionLabel(s, QStringLiteral("Input & audio"), kPad, y);
    y += 24;

    struct Toggle { const char* label; bool on; const char* onText; const char* offText; int row; };
    const Toggle toggles[] = {
        {"Gyro", m_Status.gyroEnabled, "on", "off", RowGyro},
        {"Mic",  !m_Status.micMuted,   "live", "muted", RowMic},
    };
    for (const Toggle& t : toggles) {
        drawRowHighlight(s, kPad, y, w - kPad * 2, 40, m_Selected == t.row);
        fillRoundedRect(s, kPad, y, w - kPad * 2, 40, 9, kPanel);
        strokeRoundedRect(s, kPad, y, w - kPad * 2, 40, 9, 1, kLine);
        drawText(s, m_FontLabel, QString::fromUtf8(t.label), kPad + 14, y + 11, kText);
        const QString state = QString::fromUtf8(t.on ? t.onText : t.offText);
        drawText(s, m_FontLabel, state, w - kPad - 14 - textWidth(m_FontLabel, state), y + 11,
                 t.on ? kOk : kTextFaint);
        y += 48;
    }

    // ---- Quit, deliberately held ----
    int footerY = h - 92;
    fillRect(s, kPad, footerY - 18, w - kPad * 2, 1, kLine);

    // Progress ring, drawn as an arc of short segments.
    int cx = kPad + 23, cy = footerY + 23, rad = 20;
    for (int deg = 0; deg < 360; deg += 3) {
        float a = float(deg - 90) * float(M_PI) / 180.0f;
        SDL_Color c = deg < 120 ? kDanger : kLine;
        for (int t = 0; t < 3; t++) {
            blendPixel(s, cx + int((rad - t) * std::cos(a)), cy + int((rad - t) * std::sin(a)), c, 1.0f);
        }
    }
    drawText(s, m_FontLabel, QStringLiteral("A"), cx - 5, cy - 10, kText);

    drawText(s, m_FontBody, QStringLiteral("Hold to quit"), kPad + 56, footerY + 8, kDanger);
    drawText(s, m_FontMicro, QStringLiteral("Release to keep playing"), kPad + 56, footerY + 30, kTextMuted);

    return s;
}
