#include "starfield.h"

#include <QQuickWindow>
#include <QSGGeometryNode>
#include <QSGVertexColorMaterial>

#include <cmath>
#include <random>

namespace {
constexpr float kTwoPi = 6.28318530718f;
constexpr float kCorePulsePeriod = 9.0f;  // s, slow breathing of the core
}

StarField::StarField(QQuickItem *parent)
    : QQuickItem(parent)
{
    setFlag(ItemHasContents, true);
}

#define DG_SETTER(name, member, signal)          \
    void StarField::name(decltype(member) v)     \
    {                                            \
        if (member == v)                         \
            return;                              \
        member = v;                              \
        m_starsDirty = true;                     \
        Q_EMIT signal();                         \
        update();                                \
    }

DG_SETTER(setScaleFactor, m_scale, layoutChanged)
DG_SETTER(setCenter, m_center, layoutChanged)
DG_SETTER(setFlatten, m_flatten, layoutChanged)
DG_SETTER(setTilt, m_tilt, layoutChanged)
DG_SETTER(setTwinkle, m_twinkle, layoutChanged)
DG_SETTER(setPulse, m_pulse, layoutChanged)
#undef DG_SETTER

void StarField::setTime(qreal t)
{
    if (qFuzzyCompare(m_time, t))
        return;
    m_time = t;
    Q_EMIT timeChanged();
    update();
}

void StarField::setRadius(qreal r)
{
    if (qFuzzyCompare(m_radius, r))
        return;
    m_radius = r;
    m_stars.clear();
    Q_EMIT layoutChanged();
    update();
}

void StarField::setOuterPeriod(qreal p)
{
    if (qFuzzyCompare(m_outerPeriod, p))
        return;
    m_outerPeriod = p;
    m_stars.clear();
    Q_EMIT layoutChanged();
    update();
}

void StarField::setCount(int n)
{
    if (m_count == n)
        return;
    m_count = n;
    m_stars.clear();
    Q_EMIT layoutChanged();
    update();
}

// Same distribution as tools/make_desktop.py: uniform angle, |gauss| radius,
// big squares in the core, brightness falling off with the radius.
void StarField::generate()
{
    std::mt19937 rng(11);
    std::uniform_real_distribution<float> uni(0.f, 1.f);
    std::normal_distribution<float> gauss(0.f, 1.f);
    const float big[] = {5, 7, 9, 11}, small[] = {3, 4, 5};
    // flat rotation curve: angular speed ~ 1/r, clamped in the core
    const float rOuter = 2.f * float(m_radius), rCore = 60.f;
    const float wOuter = kTwoPi / float(m_outerPeriod);

    m_stars.resize(m_count);
    for (Star &s : m_stars) {
        s.theta = uni(rng) * kTwoPi;
        s.r = std::fabs(gauss(rng)) * float(m_radius);
        s.size = s.r < 140.f ? big[int(uni(rng) * 4) & 3] : small[std::min(2, int(uni(rng) * 3))];
        s.grey = std::max(40.f, 245.f - s.r * 0.55f);
        s.omega = wOuter * rOuter / std::max(s.r, rCore);
        // one star in eight twinkles
        if (uni(rng) < 0.125f) {
            s.twinkleW = 0.6f + 1.8f * uni(rng);
            s.twinklePhase = uni(rng) * kTwoPi;
        } else {
            s.twinkleW = 0.f;
            s.twinklePhase = 0.f;
        }
    }
    m_indicesDirty = true;
}

QSGNode *StarField::updatePaintNode(QSGNode *old, UpdatePaintNodeData *)
{
    if (m_stars.isEmpty())
        generate();

    auto *node = static_cast<QSGGeometryNode *>(old);
    const int n = int(m_stars.size());
    if (!node) {
        node = new QSGGeometryNode;
        node->setMaterial(new QSGVertexColorMaterial);
        node->setFlag(QSGNode::OwnsMaterial);
        node->setFlag(QSGNode::OwnsGeometry);
    }
    QSGGeometry *geo = node->geometry();
    if (!geo || geo->vertexCount() != n * 4) {
        geo = new QSGGeometry(QSGGeometry::defaultAttributes_ColoredPoint2D(), n * 4, n * 6,
                              QSGGeometry::UnsignedIntType);
        geo->setDrawingMode(QSGGeometry::DrawTriangles);
        node->setGeometry(geo);
        m_indicesDirty = true;
    }

    if (m_indicesDirty) {
        quint32 *idx = geo->indexDataAsUInt();
        for (int i = 0; i < n; ++i) {
            const quint32 b = quint32(i) * 4;
            const quint32 quad[6] = {b, b + 1, b + 2, b + 2, b + 1, b + 3};
            std::copy(quad, quad + 6, idx + i * 6);
        }
        geo->markIndexDataDirty();
        m_indicesDirty = false;
    }

    // snap to device pixels so the squares stay crisp while they move
    const qreal dpr = window() ? window()->effectiveDevicePixelRatio() : 1.0;
    auto snap = [dpr](float v) { return float(std::round(v * dpr) / dpr); };
    const float k = float(m_scale), t = float(m_time);
    const float cx = float(m_center.x()), cy = float(m_center.y());
    const float fl = float(m_flatten), ti = float(m_tilt);
    const float pulse = m_pulse ? 1.f + 0.06f * std::sin(t * kTwoPi / kCorePulsePeriod) : 1.f;
    const float w = float(width());

    QSGGeometry::ColoredPoint2D *v = geo->vertexDataAsColoredPoint2D();
    for (int i = 0; i < n; ++i, v += 4) {
        const Star &s = m_stars[i];
        const float a = s.theta + s.omega * t;
        const float dx = s.r * std::cos(a);
        const float px = (cx + dx) * k;
        const float py = (cy + s.r * std::sin(a) * fl + dx * ti) * k;

        float g = s.grey;
        if (s.r < 140.f)
            g *= pulse;
        if (m_twinkle && s.twinkleW > 0.f)
            g *= 0.72f + 0.28f * std::sin(t * s.twinkleW + s.twinklePhase);
        const uchar gr = uchar(std::clamp(g, 0.f, 255.f));
        const uchar gg = uchar(std::clamp(g - 6.f, 0.f, 255.f));
        const uchar gb = uchar(std::clamp(g - 18.f, 0.f, 255.f));

        const float sz = std::max(1.f, snap(s.size * k));
        const float x0 = snap(px), y0 = snap(py);
        if (x0 < 0.f || x0 > w) {
            // left of the frame (over the left column) or past the right
            // edge: collapse the quad
            for (int c = 0; c < 4; ++c)
                v[c].set(0, 0, 0, 0, 0, 0);
            continue;
        }
        v[0].set(x0, y0, gr, gg, gb, 255);
        v[1].set(x0 + sz, y0, gr, gg, gb, 255);
        v[2].set(x0, y0 + sz, gr, gg, gb, 255);
        v[3].set(x0 + sz, y0 + sz, gr, gg, gb, 255);
    }
    geo->markVertexDataDirty();
    node->markDirty(QSGNode::DirtyGeometry);
    return node;
}
