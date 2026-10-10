# NexRonda 🏍️

> Hybrid Cellular Mesh Intercom & Real-Time Convoy Tracking for Riders.

Built under the **NexKod** ecosystem, **NexRonda** provides ultra-reliable, hands-free group voice communication and convoy telemetry over 4G/5G mobile networks.

---

## ⚡ Key Highlights

- **Virtual Mesh via WebRTC (LiveKit)**: Zero peer-to-peer distance collapse at highway speeds or mountain curves.
- **Graceful Reconnection**: Uninterrupted convoy state—auto-mutes in dead zones (tunnels) and silently re-links in $<500\text{ ms}$ upon getting signal back.
- **Hybrid Voice Transmission**: Voice Activity Detection (VAD) with aggressive wind & exhaust noise suppression + Push-To-Talk (PTT) fallback.
- **In-Ride Convoy Map**: Real-time rider coordinates, distance gaps, battery levels, and cellular signal health badges.
- **Zero-Friction Access**: Instant room join with 6-digit PIN code or QR code scan.

---

## 🛠️ Architecture & Tech Stack

- **Mobile Client**: Flutter (`livekit_client`, background audio daemon, Bluetooth SCO/HFP support)
- **Media Engine**: LiveKit SFU (Cloud or Self-Hosted)
- **Signaling & Backend**: Go (Golang) microservice for LiveKit token issuance & ephemeral PIN rooms
- **State & Telemetry**: Redis

---

## 📁 Repository Structure

```text
NexRonda/
├── app/          # Flutter mobile application
├── server/       # Go signaling & room management service
└── deploy/       # Docker / NexAwan deployment configuration
```
