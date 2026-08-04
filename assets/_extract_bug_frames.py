import cv2, os

path = r"c:\Users\CC\Documents\Bandicam\bandicam 2026-08-04 04-50-46-580.mp4"
out = r"c:\Users\CC\AppData\Roaming\MetaQuotes\Terminal\BB16F565FAAA6B23A20C26C49416FF05\MQL5\Experts\Phase\assets\video_frames_bug"
os.makedirs(out, exist_ok=True)

cap = cv2.VideoCapture(path)
if not cap.isOpened():
    print("FAIL open")
    raise SystemExit(1)

fps = cap.get(cv2.CAP_PROP_FPS) or 30
n = int(cap.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH) or 0)
h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT) or 0)
dur = n / fps if fps else 0
print(f"fps={fps:.3f} frames={n} size={w}x{h} duration_sec={dur:.2f}")

# ~1 frame / 1.5s across full video
interval = max(1, int(round(fps * 1.5)))
saved = []
i = 0
while True:
    ret, frame = cap.read()
    if not ret:
        break
    if i % interval == 0 or i == max(0, n - 1):
        t = i / fps
        name = f"t{t:07.2f}s_f{i:06d}.jpg"
        scale = 1400 / max(w, 1)
        if scale < 1:
            frame = cv2.resize(frame, (int(w * scale), int(h * scale)))
        cv2.imwrite(os.path.join(out, name), frame, [int(cv2.IMWRITE_JPEG_QUALITY), 85])
        saved.append((t, name))
    i += 1
cap.release()
print(f"saved={len(saved)}")
for t, name in saved:
    print(f"{t:7.2f}s  {name}")
