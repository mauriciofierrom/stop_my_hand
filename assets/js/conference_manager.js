export class ConferenceManager {
  // TODO: REMOVE THE SEMICOLONS TO KEEP CONSISTENCY
  constructor(channel, localUserId, onRemoteTrack, onPeerConnectionChange) {
    this.channel = channel;
    this.localUserId = localUserId;
    this.onRemoteTrack = onRemoteTrack; // Callback: (peerId, track, stream) => {}
    this.onPeerConnectionChange = onPeerConnectionChange; // Callback: (peerId, state) => {}

    this.peerConnections = new Map();
    this.localStream = null;
    this.iceServers = null;
    this.videoEnabled = true;
    this.audioEnabled = true;
  }

  async initialize(voiceOnly = false) {
    // Fetch ICE servers from OpenRelay
    //this.iceServers = [{ urls: 'stun:stun.l.google.com:19302' }];
    await this.fetchIceServers();

    console.log("Ice Servers fetched");
    // Get local media
    await this.getLocalMedia(voiceOnly);
    console.log("Local media fetched. Returning");
    return this.localStream;
  }

  async fetchIceServers() {
    try {
      const response = await fetch('/api/ice-servers')
      console.log(response)
      const iceServers = await response.json()
      const stun = iceServers.filter(s => s.urls.includes('stun')).slice(0, 1)
      const turn = iceServers.filter(s => s.urls.includes('turn')).slice(0, 2)

      this.iceServers = [...stun, ...turn]

      console.log(this.iceServers);
    } catch (error) {
      console.error("Failed to fetch ICE servers:", error);

      // Fallback to public STUN only
      this.iceServers = [{ urls: "stun:stun.l.google.com:19302" }];
    }
  }

  async getLocalMedia(voiceOnly = false) {
    this.localStream = await navigator.mediaDevices.getUserMedia({
      audio: {
        echoCancellation: true,
        noiseSuppression: true,
        autoGainControl: true,
        sampleRate: 48000,
      },
      video: true
    });

    const videoTrack = this.localStream.getVideoTracks()[0];
    const capabilities = videoTrack.getCapabilities();
    await videoTrack.applyConstraints({
      width: { ideal: capabilities.width.min },
      height: { ideal: capabilities.height.min },
      frameRate: { ideal: 15 }
    });

    this.videoEnabled = !voiceOnly;
    return this.localStream;
  }

  createPeerConnection(peerId) {
    if (this.peerConnections.has(peerId)) {
      return this.peerConnections.get(peerId);
    }

    const pc = new RTCPeerConnection({ iceServers: this.iceServers });

    // Add local tracks
    this.localStream.getTracks().forEach((track) => {
      pc.addTrack(track, this.localStream);
    });

    // Set encoding parameters for bandwidth control
    setTimeout(() => {
      const senders = pc.getSenders();
      senders.forEach((sender) => {
        if (sender.track) {
          const params = sender.getParameters();
          if (!params.encodings) params.encodings = [{}];

          if (sender.track.kind === "video") {
            params.encodings[0].maxBitrate = 250000; // 250kbps
          } else if (sender.track.kind === "audio") {
            params.encodings[0].maxBitrate = 128000; // 128kbps
          }

          sender.setParameters(params);
        }
      });
    }, 100);

    // Handle ICE candidates
    pc.onicecandidate = (event) => {
      if (event.candidate) {
        this.channel.push("webrtc_ice_candidate", {
          target: peerId,
          candidate: event.candidate,
        });
      }
    };

    // Handle remote tracks
    pc.ontrack = (event) => {
      if (this.onRemoteTrack) {
        this.onRemoteTrack(peerId, event.track, event.streams[0]);
      }
    };

    // Monitor connection state
    pc.onconnectionstatechange = () => {
      if (this.onPeerConnectionChange) {
        this.onPeerConnectionChange(peerId, pc.connectionState);
      }

      if (pc.connectionState === "failed" || pc.connectionState === "closed") {
        this.removePeer(peerId);
      }
    };

    this.peerConnections.set(peerId, pc);
    return pc;
  }

  async createOffer(peerId) {
    const pc = this.createPeerConnection(peerId);

    const offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    this.channel.push("webrtc_offer", {
      target: peerId,
      offer: pc.localDescription,
    });
  }

  async handleOffer(peerId, offer) {
    const pc = this.createPeerConnection(peerId);

    await pc.setRemoteDescription(new RTCSessionDescription(offer));

    const answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);

    this.channel.push("webrtc_answer", {
      target: peerId,
      answer: pc.localDescription,
    });
  }

  async handleAnswer(peerId, answer) {
    const pc = this.peerConnections.get(peerId);
    if (!pc) {
      console.error("No peer connection found for", peerId);
      return;
    }

    await pc.setRemoteDescription(new RTCSessionDescription(answer));
  }

  async handleIceCandidate(peerId, candidate) {
    const pc = this.peerConnections.get(peerId);
    if (!pc) {
      console.error("No peer connection found for", peerId);
      return;
    }

    await pc.addIceCandidate(new RTCIceCandidate(candidate));
  }

  handlePeerJoined(peerId) {
    // Create offer for new peer
    this.createOffer(peerId);
  }

  toggleCamera() {
    const videoTrack = this.localStream?.getVideoTracks()[0];
    if (videoTrack) {
      videoTrack.enabled = !videoTrack.enabled;
      this.videoEnabled = videoTrack.enabled;
      return this.videoEnabled;
    }
    return false;
  }

  toggleMicrophone() {
    const audioTrack = this.localStream?.getAudioTracks()[0];
    if (audioTrack) {
      audioTrack.enabled = !audioTrack.enabled;
      this.audioEnabled = audioTrack.enabled;
      return this.audioEnabled;
    }
    return false;
  }

  isCameraEnabled() {
    return this.videoEnabled;
  }

  isMicrophoneEnabled() {
    return this.audioEnabled;
  }

  removePeer(peerId) {
    const pc = this.peerConnections.get(peerId);
    if (pc) {
      pc.close();
      this.peerConnections.delete(peerId);
    }
  }

  destroy() {
    // Close all peer connections
    this.peerConnections.forEach((pc) => pc.close());
    this.peerConnections.clear();

    // Stop local media tracks
    if (this.localStream) {
      this.localStream.getTracks().forEach((track) => track.stop());
      this.localStream = null;
    }
  }
}
