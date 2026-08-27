#pragma once

#include <QByteArray>
#include <QString>

#include "SDL_compat.h"
#include <SDL_ttf.h>

// The in-stream drawer.
//
// This cannot be QML: the stream runs in a plain SDL window, and the only way
// anything reaches the screen over live video is OverlayManager's surface slot,
// which every renderer backend already takes and blits. So the drawer draws
// itself into an SDL_Surface with a small software rasteriser and hands it over
// the same way the stats text does.
//
// Rendering is deliberately separable from the session: render() needs nothing
// but the state set on it, so the surface can be produced and inspected without
// a stream running.
class StreamDrawer
{
public:
    StreamDrawer();
    ~StreamDrawer();

    // What the drawer reports about the running session.
    struct Status
    {
        QString appName;
        QString hostName;
        int minutes = 0;
        int width = 0;
        int height = 0;
        int fps = 0;
        QString codec;
        bool hdr = false;
        int bitrateKbps = 0;
        int bitrateMaxKbps = 150000;
        int latencyMs = -1;
        // Plain-language verdict rather than a wall of numbers.
        enum Health { HealthGood, HealthStrained, HealthBad } health = HealthGood;
        QString healthDetail;
        bool gyroEnabled = false;
        bool micMuted = true;
    };

    void setStatus(const Status& status);
    const Status& status() const { return m_Status; }

    bool isOpen() const { return m_Open; }
    void setOpen(bool open) { m_Open = open; }
    void toggle() { m_Open = !m_Open; }

    // Row navigation while the drawer has input focus.
    void moveUp();
    void moveDown();
    void adjustLeft();
    void adjustRight();
    int selectedRow() const { return m_Selected; }

    // Renders the drawer for a window of the given size. Returns a new surface
    // the caller owns, or nullptr if the drawer is closed or has no font.
    SDL_Surface* render(int windowWidth, int windowHeight);

    // Width the panel occupies, so renderers can position it against the right
    // edge without guessing.
    static int panelWidth() { return 430; }

private:
    enum Row
    {
        RowBitrate,
        RowRefresh,
        RowHdr,
        RowGyro,
        RowMic,
        RowCount
    };

    bool loadFonts();

    // Minimal software drawing. SDL gives us rectangles; rounded corners,
    // blending and text layout are ours.
    static void fillRect(SDL_Surface* s, int x, int y, int w, int h, SDL_Color c);
    static void fillRoundedRect(SDL_Surface* s, int x, int y, int w, int h, int radius, SDL_Color c);
    static void strokeRoundedRect(SDL_Surface* s, int x, int y, int w, int h, int radius, int thickness, SDL_Color c);
    static void blendPixel(SDL_Surface* s, int x, int y, SDL_Color c, float coverage);

    int drawText(SDL_Surface* s, TTF_Font* font, const QString& text, int x, int y, SDL_Color c);
    int textWidth(TTF_Font* font, const QString& text);

    void drawSectionLabel(SDL_Surface* s, const QString& text, int x, int y);
    void drawPill(SDL_Surface* s, int x, int y, int h, const QString& text, SDL_Color fg, SDL_Color bg, SDL_Color border);
    void drawRowHighlight(SDL_Surface* s, int x, int y, int w, int h, bool selected);
    void drawRowCard(SDL_Surface* s, int x, int y, int w, int h, bool selected);

    QByteArray m_BodyFontData;
    QByteArray m_DisplayFontData;
    TTF_Font* m_FontMicro = nullptr;
    TTF_Font* m_FontLabel = nullptr;
    TTF_Font* m_FontBody = nullptr;
    TTF_Font* m_FontTitle = nullptr;

    Status m_Status;
    bool m_Open = false;
    int m_Selected = RowBitrate;
};
