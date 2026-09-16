const jpeg = require('jpeg-js');

const WIDTH = 320;
const HEIGHT = 240;

/// Synthetic "kitchen cam" frame: a dark vignette plus a moving highlight,
/// so the MJPEG stream visibly animates without needing a real camera or
/// any bundled image asset. Good enough to prove the transport works end
/// to end; swap for a real ESP32-CAM frame source in firmware.
function renderFrame(tick) {
  const data = Buffer.alloc(WIDTH * HEIGHT * 4);
  const cx = WIDTH / 2 + Math.sin(tick / 12) * WIDTH * 0.28;
  const cy = HEIGHT / 2 + Math.cos(tick / 17) * HEIGHT * 0.22;
  for (let y = 0; y < HEIGHT; y++) {
    for (let x = 0; x < WIDTH; x++) {
      const i = (y * WIDTH + x) * 4;
      const d = Math.hypot(x - cx, y - cy);
      const glow = Math.max(0, 1 - d / 140);
      data[i] = 40 + glow * 90; // R
      data[i + 1] = 34 + glow * 70; // G
      data[i + 2] = 28 + glow * 55; // B
      data[i + 3] = 255;
    }
  }
  const encoded = jpeg.encode({ data, width: WIDTH, height: HEIGHT }, 65);
  return encoded.data;
}

function attachStream(app, path) {
  app.get(path, (req, res) => {
    const boundary = 'frame';
    res.writeHead(200, {
      'Content-Type': `multipart/x-mixed-replace; boundary=${boundary}`,
      'Cache-Control': 'no-cache, private',
      Connection: 'close',
      Pragma: 'no-cache',
    });
    let tick = 0;
    const interval = setInterval(() => {
      if (res.writableEnded) {
        clearInterval(interval);
        return;
      }
      const frame = renderFrame(tick++);
      res.write(`--${boundary}\r\n`);
      res.write('Content-Type: image/jpeg\r\n');
      res.write(`Content-Length: ${frame.length}\r\n\r\n`);
      res.write(frame);
      res.write('\r\n');
    }, 200); // ~5fps — plenty for a bowl-side cam, light on the mock server
    req.on('close', () => clearInterval(interval));
  });
}

function snapshotJpeg() {
  return renderFrame(0);
}

module.exports = { attachStream, snapshotJpeg };
