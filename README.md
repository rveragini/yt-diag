
# YouTube Network Diagnostic

A small diagnostic script for macOS to capture network traffic while watching YouTube.

The aim is to collect some useful network information if buffering or streaming issues occur, so it can be reviewed afterwards and shared with the ISP if needed.

The script runs a 120-second capture and generates a set of reports covering:

- TCP retransmissions and duplicate ACKs
- TCP resets and retransmission events
- UDP and QUIC traffic
- TCP and UDP connections
- Traffic levels over time
- General protocol statistics

## Requirements

- macOS
- Homebrew
- Wireshark (includes tshark)
- tcpdump

If Wireshark is not already installed:

```bash
brew install wireshark
```

## Running the script

Save the script to your Desktop as:

```bash
~/Desktop/youtube-diag.sh
```

Make it executable:

```bash
chmod +x ~/Desktop/youtube-diag.sh
```

Run it:

```bash
~/Desktop/youtube-diag.sh
```

The script will ask you to start YouTube playback before beginning the capture.

Once started, it will:

1. Capture network traffic for 120 seconds.
2. Analyse the captured traffic.
3. Generate the relevant statistics and reports.
4. Save everything in a new folder on your Desktop.

You may be asked for your Mac administrator password when the packet capture starts.

## Where the results are saved

Each run creates a new folder with a timestamp, for example:

```text
youtube-diagnostic-20261030-221835
```

The main files are:

| File | Description |
|---|---|
| REPORT.txt | Summary of the diagnostic results |
| youtube-capture.pcap | Original packet capture |
| traffic-per-second.txt | Traffic statistics over time |
| protocol-statistics.txt | Protocol breakdown |
| protocol-counts.txt | Protocol counts |
| retransmissions.tsv | TCP retransmission details |
| duplicate-acks.tsv | Duplicate ACK details |
| tcp-resets.tsv | TCP reset events |
| tcp-retransmission-details.tsv | Further TCP analysis |
| tcp-conversations.txt | TCP connections |
| udp-conversations.txt | UDP connections |
| retransmissions-by-stream.txt | Retransmissions grouped by TCP stream |

## Reviewing an existing capture

There is no need to run another capture just to look at previously collected results.

For example, to review the diagnostic run from 30 October:

```bash
cd ~/Desktop/youtube-diagnostic-20261030-221835
```

Display the main report:

```bash
cat REPORT.txt
```

View UDP conversations:

```bash
cat udp-conversations.txt
```

View traffic over time:

```bash
cat traffic-per-second.txt
```

Count QUIC packets:

```bash
tshark -r youtube-capture.pcap -Y quic 2>/dev/null | wc -l
```

View TCP retransmissions:

```bash
cat retransmissions.tsv
```

View duplicate ACKs:

```bash
cat duplicate-acks.tsv
```

View TCP resets:

```bash
cat tcp-resets.tsv
```

## Notes

A few things worth keeping in mind when reviewing the results:

- TCP retransmissions can indicate delivery problems, but do not directly establish packet loss.
- Duplicate ACKs can be caused by missing or out-of-order packets.
- TCP resets are not necessarily a sign of a fault.
- YouTube can use QUIC over UDP, so looking at TCP statistics alone is not sufficient.
- Packet captures can be affected by the capture location and network interface behaviour.

The results should be considered alongside what was actually happening during playback, particularly any buffering or automatic changes in video quality.

## Sharing the results

The generated reports and packet capture can be provided to the ISP for further investigation.
