#!/usr/bin/env python3
"""PixLift model acquisition & verification tool.

Downloads the Real-ESRGAN `realesr-general-x4v3` checkpoint (BSD-3-Clause,
(c) 2021 Xintao Wang, https://github.com/xinntao/Real-ESRGAN), exports it to
ONNX (opset 13, dynamic spatial axes), verifies the exported model actually
executes 4x super-resolution, computes a SHA-256 digest, and writes:

  assets/model/realesr-general-x4v3.onnx
  assets/model/realesr-general-x4v3.sha256

Run from the android/ project root:
  python tooling/model/export_model.py

Dependencies: torch (CPU), onnx, onnxruntime, pillow.
"""

import hashlib
import sys
import urllib.request
from pathlib import Path

import numpy as np

MODEL_URL = (
    "https://github.com/xinntao/Real-ESRGAN/releases/download/"
    "v0.2.5.0/realesr-general-x4v3.pth"
)
MODEL_FILENAME = "realesr-general-x4v3.onnx"
OUTPUT_DIR = Path(__file__).resolve().parents[2] / "assets" / "model"

from srvgg_compact import SRVGGNetCompact, load_released_state  # noqa: E402


def download(url: str, dest: Path, chunk=1 << 16):
    print(f"downloading {url}")
    req = urllib.request.Request(url, headers={"User-Agent": "pixlift-model-prep/1.0"})
    with urllib.request.urlopen(req) as r, open(dest, "wb") as f:
        while True:
            b = r.read(chunk)
            if not b:
                break
            f.write(b)
    print(f"saved {dest.name}: {dest.stat().st_size / 1e6:.2f} MB")


def _main():
    import onnxruntime as ort
    import torch
    from PIL import Image, ImageDraw

    tmp_dir = Path(__file__).resolve().parent / "_work"
    tmp_dir.mkdir(parents=True, exist_ok=True)
    pth_path = tmp_dir / "realesr-general-x4v3.pth"

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    if not pth_path.exists():
        download(MODEL_URL, pth_path)
    else:
        print(f"using cached checkpoint {pth_path.name}")

    model = SRVGGNetCompact(num_in_ch=3, num_out_ch=3, num_feat=64, num_conv=32, upscale=4, act_type="prelu")
    state = load_released_state(torch.load(pth_path, map_location="cpu", weights_only=True))
    model.load_state_dict(state, strict=True)
    model.eval()
    print("network + checkpoint loaded ok")

    x = torch.rand(1, 3, 128, 128)
    with torch.no_grad():
        y = model(x)
    assert tuple(y.shape) == (1, 3, 512, 512), f"pytorch output shape {tuple(y.shape)}"
    print("pytorch forward shape ok")

    onnx_path = OUTPUT_DIR / MODEL_FILENAME
    torch.onnx.export(
        model,
        (x,),
        str(onnx_path),
        input_names=["input"],
        output_names=["output"],
        opset_version=13,
        do_constant_folding=True,
        dynamic_axes={"input": {0: "N", 2: "H", 3: "W"}, "output": {0: "N", 2: "H_out", 3: "W_out"}},
    )
    print(f"exported {onnx_path.name}: {onnx_path.stat().st_size / 1e6:.2f} MB")

    # Verify the exact shipped bytes with onnxruntime.
    sess_options = ort.SessionOptions()
    sess = ort.InferenceSession(str(onnx_path), sess_options, providers=["CPUExecutionProvider"])
    inp = np.random.RandomState(42).rand(1, 3, 64, 64).astype(np.float32)
    out = sess.run(["output"], {"input": inp})[0]
    assert out.shape == (1, 3, 256, 256), f"ort shape mismatch {out.shape}"
    assert np.isfinite(out).all(), "model produced NaN/Inf"
    print(f"onnxruntime run ok, sample range [{out.min():.3f}, {out.max():.3f}]")

    # Real photographic verification: build a low-res test chart, upscale the
    # exact shipped ONNX, save the before/after for the demo assets.
    size = 512
    img = Image.new("RGB", (size, size), (150, 205, 240))
    d = ImageDraw.Draw(img)
    d.rectangle([32, 32, 480, 480], fill=(35, 55, 85))
    for i in range(0, 448, 32):
        d.line([(32 + i, 32), (480 - i, 480)], fill=(255 - i, 200, 120 + i // 4), width=2)
    d.ellipse([120, 120, 220, 220], fill=(255, 165, 60))
    d.ellipse([292, 292, 392, 392], fill=(110, 220, 175))
    d.text((215, 240), "PIX8", fill=(255, 255, 255))
    demo_in = Path(__file__).resolve().parents[3] / "website" / "public" / "demo" / "before.jpg"
    demo_in.parent.mkdir(parents=True, exist_ok=True)
    img.save(demo_in, quality=92)
    img.save(tmp_dir / "sample_input.png")

    arr = np.asarray(img).astype(np.float32) / 255.0
    inp_nchw = np.transpose(arr, (2, 0, 1))[None, ...]
    out4 = sess.run(["output"], {"input": inp_nchw})[0][0]
    out4 = np.clip(out4, 0.0, 1.0)
    out_img = Image.fromarray((np.transpose(out4, (1, 2, 0)) * 255.0).astype(np.uint8))
    demo_out = Path(__file__).resolve().parents[3] / "website" / "public" / "demo" / "after.png"
    out_img.save(demo_out)
    print(f"verification upscale {img.width}x{img.height} -> {out_img.width}x{out_img.height}")

    digest = hashlib.sha256(onnx_path.read_bytes()).hexdigest()
    (OUTPUT_DIR / (MODEL_FILENAME + ".sha256")).write_text(digest + "\n")
    print(f"{MODEL_FILENAME}   sha256: {digest}")
    print("done.")


if __name__ == "__main__":
    sys.exit(_main())
