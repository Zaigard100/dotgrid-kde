#pragma once

#include <QQuickItem>
#include <QVector>

// The galaxy: axis-aligned squares on a flattened, tilted disc with
// differential rotation. Rendered as one geometry node with the stock
// vertex-colour material (no custom shaders). Setting `time` moves the stars;
// nothing is recomputed or redrawn while `time` stays the same.
class StarField : public QQuickItem
{
    Q_OBJECT
    QML_ELEMENT

    // seconds of animation; drives rotation, twinkle and the core pulse
    Q_PROPERTY(qreal time READ time WRITE setTime NOTIFY timeChanged)
    // reference px -> item px
    Q_PROPERTY(qreal scaleFactor READ scaleFactor WRITE setScaleFactor NOTIFY layoutChanged)
    // disc centre in reference px, relative to the item's top-left corner
    Q_PROPERTY(QPointF center READ center WRITE setCenter NOTIFY layoutChanged)
    Q_PROPERTY(qreal radius READ radius WRITE setRadius NOTIFY layoutChanged)
    Q_PROPERTY(qreal flatten READ flatten WRITE setFlatten NOTIFY layoutChanged)
    Q_PROPERTY(qreal tilt READ tilt WRITE setTilt NOTIFY layoutChanged)
    // seconds per turn at twice the radius; the core turns faster
    Q_PROPERTY(qreal outerPeriod READ outerPeriod WRITE setOuterPeriod NOTIFY layoutChanged)
    Q_PROPERTY(int count READ count WRITE setCount NOTIFY layoutChanged)
    // one star in eight twinkles; the core brightness slowly breathes
    Q_PROPERTY(bool twinkle READ twinkle WRITE setTwinkle NOTIFY layoutChanged)
    Q_PROPERTY(bool pulse READ pulse WRITE setPulse NOTIFY layoutChanged)

public:
    explicit StarField(QQuickItem *parent = nullptr);

    qreal time() const { return m_time; }
    void setTime(qreal t);
    qreal scaleFactor() const { return m_scale; }
    void setScaleFactor(qreal s);
    QPointF center() const { return m_center; }
    void setCenter(QPointF c);
    qreal radius() const { return m_radius; }
    void setRadius(qreal r);
    qreal flatten() const { return m_flatten; }
    void setFlatten(qreal f);
    qreal tilt() const { return m_tilt; }
    void setTilt(qreal t);
    qreal outerPeriod() const { return m_outerPeriod; }
    void setOuterPeriod(qreal p);
    int count() const { return m_count; }
    void setCount(int n);
    bool twinkle() const { return m_twinkle; }
    void setTwinkle(bool on);
    bool pulse() const { return m_pulse; }
    void setPulse(bool on);

Q_SIGNALS:
    void timeChanged();
    void layoutChanged();

protected:
    QSGNode *updatePaintNode(QSGNode *old, UpdatePaintNodeData *) override;

private:
    struct Star {
        float r, theta, omega;   // ref px, rad, rad/s
        float size;              // ref px
        float grey;              // 0..255
        float twinkleW, twinklePhase; // twinkleW == 0: steady
    };

    void generate();

    QVector<Star> m_stars;
    qreal m_time = 0;
    qreal m_scale = 1;
    QPointF m_center{640, 680};
    qreal m_radius = 330;
    qreal m_flatten = 0.33;
    qreal m_tilt = -0.38;
    qreal m_outerPeriod = 240;
    int m_count = 2600;
    bool m_twinkle = true;
    bool m_pulse = true;
    bool m_starsDirty = true;
    bool m_indicesDirty = true;
};
