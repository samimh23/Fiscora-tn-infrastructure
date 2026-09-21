import base64
import json
import threading
from typing import Any

import cv2
import numpy as np
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from paddleocr import PaddleOCR


class OcrRequest(BaseModel):
    mimeType: str
    contentBase64: str


app = FastAPI(title="Fiscora PaddleOCR", docs_url=None, redoc_url=None)
_lock = threading.Lock()
_ocr = PaddleOCR(
    use_doc_orientation_classify=False,
    use_doc_unwarping=False,
    use_textline_orientation=False,
    engine="paddle",
    enable_mkldnn=False,
    cpu_threads=4,
)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "model": "PP-OCRv6-medium"}


@app.post("/ocr")
def ocr(request: OcrRequest) -> dict[str, Any]:
    if not request.mimeType.lower().startswith("image/"):
        raise HTTPException(status_code=415, detail="Only image documents are supported.")
    try:
        content = base64.b64decode(request.contentBase64, validate=True)
    except ValueError as error:
        raise HTTPException(status_code=400, detail="Invalid base64 image.") from error
    if not content or len(content) > 20 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Image must be between 1 byte and 20 MiB.")

    image = cv2.imdecode(np.frombuffer(content, dtype=np.uint8), cv2.IMREAD_COLOR)
    if image is None:
        raise HTTPException(status_code=400, detail="The image could not be decoded.")

    height, width = image.shape[:2]
    with _lock:
        results = list(_ocr.predict(image))
    if not results:
        raise HTTPException(status_code=422, detail="PaddleOCR returned no result.")

    payload = results[0].json
    if isinstance(payload, str):
        payload = json.loads(payload)
    result = payload.get("res", payload)
    texts = result.get("rec_texts", [])
    scores = result.get("rec_scores", [])
    boxes = result.get("rec_boxes", [])

    tokens = []
    for index, text in enumerate(texts):
        if not isinstance(text, str) or not text.strip() or index >= len(boxes):
            continue
        box = [int(value) for value in boxes[index]]
        if len(box) != 4 or box[2] <= box[0] or box[3] <= box[1]:
            continue
        score = float(scores[index]) if index < len(scores) else 0.0
        tokens.append(
            {
                "id": f"p1_t{index + 1}",
                "page": 1,
                "text": text,
                "confidence": score,
                "bbox": box,
            }
        )

    if not tokens:
        raise HTTPException(status_code=422, detail="PaddleOCR returned no text tokens.")
    return {"width": width, "height": height, "tokens": tokens}
