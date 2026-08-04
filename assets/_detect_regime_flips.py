import cv2, os, numpy as np

path = r"c:\Users\CC\Documents\Bandicam\bandicam 2026-08-04 04-50-46-580.mp4"
out = r"c:\Users\CC\AppData\Roaming\MetaQuotes\Terminal\BB16F565FAAA6B23A20C26C49416FF05\MQL5\Experts\Phase\assets\video_frames_bug"
os.makedirs(out, exist_ok=True)

cap = cv2.VideoCapture(path)
fps = cap.get(cv2.CAP_PROP_FPS) or 15
n = int(cap.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH) or 0)
h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT) or 0)

# Chart area approx (exclude watermark/taskbar): middle-upper
y0, y1 = int(h * 0.08), int(h * 0.52)
x0, x1 = int(w * 0.02), int(w * 0.92)

prev = None
events = []
i = 0
# sample every ~0.5s
step = max(1, int(round(fps * 0.5)))
while True:
    ret, frame = cap.read()
    if not ret:
        break
    if i % step == 0:
        crop = frame[y0:y1, x0:x1]
        # classify pixels as green-ish / red-ish regime bg
        b, g, r = cv2.split(crop)
        green = ((g.astype(np.int16) > r.astype(np.int16) + 15) & (g > 40) & (g < 120) & (b < 80)).sum()
        red = ((r.astype(np.int16) > g.astype(np.int16) + 15) & (r > 40) & (r < 140) & (b < 80)).sum()
        total = crop.shape[0] * crop.shape[1]
        gp, rp = 100.0 * green / total, 100.0 * red / total
        t = i / fps
        if prev is not None:
            dg = gp - prev[1]
            dr = rp - prev[2]
            if abs(dg) > 3 or abs(dr) > 3:
                name = f"FLIP_t{t:07.2f}s_g{gp:.1f}_r{rp:.1f}.jpg"
                scale = 1400 / max(w, 1)
                outf = frame
                if scale < 1:
                    outf = cv2.resize(frame, (int(w * scale), int(h * scale)))
                cv2.imwrite(os.path.join(out, name), outf, [int(cv2.IMWRITE_JPEG_QUALITY), 88])
                events.append((t, gp, rp, dg, dr, name))
        prev = (t, gp, rp)
    i += 1
cap.release()

print(f"duration={n/fps:.2f}s samples~{n//step} flips={len(events)}")
for t, gp, rp, dg, dr, name in events:
    print(f"{t:7.2f}s  green={gp:5.1f}% red={rp:5.1f}%  dG={dg:+5.1f} dR={dr:+5.1f}  {name}")
