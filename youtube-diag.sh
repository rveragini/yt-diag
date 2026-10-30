
#!/bin/bash

# ==========================================================
# YOUTUBE NETWORK DIAGNOSTIC
# 120-second capture and analysis
# ==========================================================

set -u

DURATION=120
INTERFACE="en0"
DESKTOP="$HOME/Desktop"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")

OUTPUT="$DESKTOP/youtube-diagnostic-$TIMESTAMP"
PCAP="$OUTPUT/youtube-capture.pcap"

mkdir -p "$OUTPUT"

# Locate tshark
TSHARK=$(command -v tshark)

if [ -z "$TSHARK" ]; then
    echo "ERROR: tshark not found."
    echo "Install with: brew install wireshark"
    exit 1
fi

echo "=================================================="
echo " YOUTUBE NETWORK DIAGNOSTIC"
echo "=================================================="
echo "Interface: $INTERFACE"
echo "Duration:  $DURATION seconds"
echo "Output:    $OUTPUT"
echo ""
echo "IMPORTANT:"
echo "Start YouTube playback before beginning the capture."
echo "Use your normal preferred video quality."
echo "If buffering occurs, allow it to continue during capture."
echo "Do not run other bandwidth-heavy activities."
echo ""
read -r -p "Press ENTER to begin capture..."

echo ""
echo "[1/10] Capturing network traffic for 120 seconds..."
echo "Capture started: $(date)"

# Capture all traffic, not just TCP.
sudo -v

sudo tcpdump -i "$INTERFACE" \
    -s 0 \
    -U \
    -w "$PCAP" \
    -G "$DURATION" \
    -W 1 \
    2>"$OUTPUT/capture-log.txt" &

CAPTURE_PID=$!

sleep "$DURATION"

sudo kill -INT "$CAPTURE_PID" 2>/dev/null || true

wait "$CAPTURE_PID" 2>/dev/null || true

echo "[2/10] General capture statistics..."

"$TSHARK" -r "$PCAP" -q -z io,stat,1 \
    > "$OUTPUT/traffic-per-second.txt" 2>&1

echo "[3/10] Protocol distribution..."

"$TSHARK" -r "$PCAP" -q -z io,phs \
    > "$OUTPUT/protocol-statistics.txt" 2>&1

"$TSHARK" -r "$PCAP" \
    -T fields -e frame.protocols \
    | sort | uniq -c | sort -nr \
    > "$OUTPUT/protocol-counts.txt"

echo "[4/10] TCP retransmissions..."

"$TSHARK" -r "$PCAP" \
    -Y 'tcp.analysis.retransmission || tcp.analysis.fast_retransmission' \
    -T fields \
    -E header=y -E separator=/t \
    -e frame.time_relative \
    -e ip.src -e ipv6.src \
    -e ip.dst -e ipv6.dst \
    -e tcp.stream \
    -e tcp.seq \
    -e tcp.analysis.retransmission \
    > "$OUTPUT/retransmissions.tsv"

echo "[5/10] Duplicate ACKs..."

"$TSHARK" -r "$PCAP" \
    -Y 'tcp.analysis.duplicate_ack' \
    -T fields \
    -E header=y -E separator=/t \
    -e frame.time_relative \
    -e ip.src -e ipv6.src \
    -e ip.dst -e ipv6.dst \
    -e tcp.stream \
    -e tcp.ack \
    > "$OUTPUT/duplicate-acks.tsv"

echo "[6/10] TCP resets and timeout indications..."

"$TSHARK" -r "$PCAP" \
    -Y 'tcp.flags.reset == 1' \
    -T fields \
    -E header=y -E separator=/t \
    -e frame.time_relative \
    -e ip.src -e ipv6.src \
    -e ip.dst -e ipv6.dst \
    -e tcp.stream \
    > "$OUTPUT/tcp-resets.tsv"

"$TSHARK" -r "$PCAP" \
    -Y 'tcp.analysis.retransmission || tcp.analysis.fast_retransmission || tcp.analysis.spurious_retransmission' \
    -T fields \
    -e frame.time_relative \
    -e tcp.stream \
    -e tcp.analysis.retransmission \
    -e tcp.analysis.fast_retransmission \
    -e tcp.analysis.spurious_retransmission \
    > "$OUTPUT/tcp-retransmission-details.tsv"

echo "[7/10] TCP and UDP conversations..."

"$TSHARK" -r "$PCAP" -q -z conv,tcp \
    > "$OUTPUT/tcp-conversations.txt" 2>&1

"$TSHARK" -r "$PCAP" -q -z conv,udp \
    > "$OUTPUT/udp-conversations.txt" 2>&1

echo "[8/10] Retransmissions by TCP stream..."

"$TSHARK" -r "$PCAP" \
    -Y 'tcp.analysis.retransmission || tcp.analysis.fast_retransmission' \
    -T fields \
    -e tcp.stream \
    | sort | uniq -c | sort -nr \
    > "$OUTPUT/retransmissions-by-stream.txt"

echo "[9/10] Calculating metrics..."

TCP_COUNT=$("$TSHARK" -r "$PCAP" -Y tcp 2>/dev/null | wc -l | tr -d ' ')

UDP_COUNT=$("$TSHARK" -r "$PCAP" -Y udp 2>/dev/null | wc -l | tr -d ' ')

RETRANS=$("$TSHARK" -r "$PCAP" \
    -Y 'tcp.analysis.retransmission || tcp.analysis.fast_retransmission' \
    2>/dev/null | wc -l | tr -d ' ')

DUPACK=$("$TSHARK" -r "$PCAP" \
    -Y tcp.analysis.duplicate_ack \
    2>/dev/null | wc -l | tr -d ' ')

RESETS=$("$TSHARK" -r "$PCAP" \
    -Y 'tcp.flags.reset == 1' \
    2>/dev/null | wc -l | tr -d ' ')

SPURIOUS=$("$TSHARK" -r "$PCAP" \
    -Y tcp.analysis.spurious_retransmission \
    2>/dev/null | wc -l | tr -d ' ')

TIMEOUTS=$("$TSHARK" -r "$PCAP" \
    -Y tcp.analysis.retransmission \
    2>/dev/null | wc -l | tr -d ' ')

if [ "$TCP_COUNT" -gt 0 ]; then
    RATIO=$(awk -v r="$RETRANS" -v t="$TCP_COUNT" \
        'BEGIN {printf "%.3f", (r/t)*100}')
else
    RATIO="0.000"
fi

echo "[10/10] Generating report..."

cat > "$OUTPUT/REPORT.txt" <<EOF
==================================================
YOUTUBE NETWORK DIAGNOSTIC REPORT
==================================================

Capture date: $(date)
Duration: $DURATION seconds
Interface: $INTERFACE

Playback test: YouTube streaming at user's normal
preferred video quality.

IMPORTANT:
This diagnostic is intended to capture network
behaviour during actual YouTube playback, including
periods of buffering and automatic quality reduction.

The capture does not assume a particular video
resolution or quality setting.

PCAP:
$PCAP

--------------------------------------------------
PACKET COUNTS
--------------------------------------------------

TCP frames: $TCP_COUNT
UDP frames: $UDP_COUNT

--------------------------------------------------
TCP ANALYSIS
--------------------------------------------------

Retransmissions (including fast): $RETRANS
Duplicate ACKs: $DUPACK
TCP resets: $RESETS
Spurious retransmissions: $SPURIOUS
Retransmission indications: $TIMEOUTS

Retransmission / TCP frame ratio: $RATIO%

NOTE:
These are packet-analysis indicators, not direct
measurements of application-level packet loss.

TCP retransmissions and timeout indications can
overlap. They must not be added together.

QUIC uses UDP and requires separate analysis.

--------------------------------------------------
FILES GENERATED
--------------------------------------------------

youtube-capture.pcap
traffic-per-second.txt
protocol-statistics.txt
protocol-counts.txt
retransmissions.tsv
duplicate-acks.tsv
tcp-resets.tsv
tcp-retransmission-details.tsv
tcp-conversations.txt
udp-conversations.txt
retransmissions-by-stream.txt

--------------------------------------------------
INTERPRETATION
--------------------------------------------------

A high retransmission count can indicate network
delivery problems.

Duplicate ACKs can indicate missing or reordered
segments.

TCP resets may be normal connection closures or
application/network events.

UDP traffic may include QUIC video delivery.

Successful playback at one video quality does not
establish that streaming is reliable under all conditions.

Correlate packet behaviour with actual buffering
events and automatic video quality changes.

==================================================
END OF REPORT
==================================================
EOF

echo ""
echo "=================================================="
echo "DIAGNOSTIC COMPLETE"
echo "=================================================="
echo ""
cat "$OUTPUT/REPORT.txt"

echo ""
echo "Results saved to:"
echo "$OUTPUT"