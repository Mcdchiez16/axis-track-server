# ──────────────────────────────────────────────────────────────
# Axis Solutions — Custom Traccar image
#
# Build:  docker build -t axis-traccar:latest .
# ──────────────────────────────────────────────────────────────
FROM traccar/traccar:6.14.5

COPY traccar.xml /opt/traccar/conf/traccar.xml

# Built from frontend/ with `npm run build:release`.
COPY web/ /opt/traccar/web/
