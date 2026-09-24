from __future__ import annotations

import base64
import json
import os
import threading
from typing import Any

import cv2
import numpy as np
import pypdfium2 as pdfium
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from paddleocr import PaddleOCR


class OcrRequest(BaseModel):
    mimeType: str
    contentBase64: str


app = FastAPI(title="Fiscora PaddleOCR", docs_url=None, redoc_url=None)
_lock = threading.Lock()
_max_document_bytes = int(
    os.getenv("OCR_MAX_DOCUMENT_BYTES", str(20 * 1024 * 1024))
)
_max_pdf_pages = int(os.getenv("OCR_MAX_PDF_PAGES", "100"))
_pdf_render_dpi = int(os.getenv("OCR_PDF_RENDER_DPI", "250"))
_page_batch_size = max(1, int(os.getenv("OCR_PAGE_BATCH_SIZE", "4")))
_ocr = PaddleOCR(
    use_doc_orientation_classify=False,
    use_doc_unwarping=False,
    use_textline_orientation=False,
    engine="paddle",
    enable_mkldnn=False,
    cpu_threads=4,
)


@app.get("/health")
def health() -> dict[str, Any]:
    return {
        "status": "ok",
        "model": "PP-OCRv6-medium",
        "pdf": True,
        "pageBatchSize": _page_batch_size,
    }


@app.post("/ocr")
def ocr(request: OcrRequest) -> dict[str, Any]:
    mime_type = request.mimeType.lower()
    if mime_type not in {"application/pdf", "image/jpeg", "image/png"}:
        raise HTTPException(
            status_code=415,
            detail="Only PDF, JPEG and PNG documents are supported.",
        )
    try:
        content = base64.b64decode(request.contentBase64, validate=True)
    except ValueError as error:
        raise HTTPException(status_code=400, detail="Invalid base64 document.") from error
    if not content or len(content) > _max_document_bytes:
        raise HTTPException(
            status_code=413,
            detail=f"Document must be between 1 byte and {_max_document_bytes} bytes.",
        )

    if mime_type == "application/pdf":
        return _ocr_pdf(content)

    image = _decode_image(content)
    height, width = image.shape[:2]
    tokens = _predict_page(image, 1)
    if not tokens:
        raise HTTPException(
            status_code=422,
            detail="PaddleOCR returned no text tokens.",
        )
    return {
        "width": width,
        "height": height,
        "pages": [{"page": 1, "width": width, "height": height, "source": "ocr"}],
        "tokens": tokens,
    }


def _decode_image(content: bytes) -> np.ndarray:
    image = cv2.imdecode(np.frombuffer(content, dtype=np.uint8), cv2.IMREAD_COLOR)
    if image is None:
        raise HTTPException(status_code=400, detail="The image could not be decoded.")
    return image


def _ocr_pdf(content: bytes) -> dict[str, Any]:
    try:
        document = pdfium.PdfDocument(content)
    except Exception as error:
        raise HTTPException(status_code=400, detail="The PDF could not be opened.") from error
    try:
        page_count = len(document)
        if page_count < 1:
            raise HTTPException(status_code=400, detail="The PDF contains no pages.")
        if page_count > _max_pdf_pages:
            raise HTTPException(
                status_code=413,
                detail=f"PDF exceeds the {_max_pdf_pages}-page extraction limit.",
            )

        pages: list[dict[str, Any]] = []
        all_tokens: list[dict[str, Any]] = []
        for batch_start in range(0, page_count, _page_batch_size):
            batch_end = min(page_count, batch_start + _page_batch_size)
            rendered: list[tuple[int, np.ndarray]] = []
            for page_index in range(batch_start, batch_end):
                page = document[page_index]
                page_number = page_index + 1
                try:
                    image = _render_pdf_page(page)
                finally:
                    page.close()
                height, width = image.shape[:2]
                pages.append(
                    {
                        "page": page_number,
                        "width": width,
                        "height": height,
                        "source": "ocr",
                    }
                )
                rendered.append((page_number, image))

            # Keep only a bounded number of rendered pages in memory. The model
            # remains single-threaded, while independent Cloud Run requests can
            # still be scaled and queued safely.
            for page_number, image in rendered:
                all_tokens.extend(_predict_page(image, page_number))

        if not all_tokens:
            raise HTTPException(
                status_code=422,
                detail="The PDF contains no readable text.",
            )
        pages.sort(key=lambda item: int(item["page"]))
        first = pages[0]
        return {
            "width": first["width"],
            "height": first["height"],
            "pageCount": page_count,
            "pages": pages,
            "tokens": all_tokens,
        }
    finally:
        document.close()


def _render_pdf_page(page: pdfium.PdfPage) -> np.ndarray:
    scale = _pdf_render_dpi / 72
    bitmap = page.render(
        scale=scale,
        rotation=0,
        fill_color=(255, 255, 255, 255),
    )
    try:
        image = bitmap.to_numpy()
        if image.ndim != 3 or image.shape[2] < 3:
            raise HTTPException(
                status_code=422,
                detail="A PDF page could not be rendered as a color image.",
            )
        # to_numpy() shares PDFium's bitmap buffer, so copy before closing it.
        return np.array(image[:, :, :3], dtype=np.uint8, copy=True, order="C")
    finally:
        bitmap.close()


def _predict_page(image: np.ndarray, page_number: int) -> list[dict[str, Any]]:
    with _lock:
        results = list(_ocr.predict(image))
    if not results:
        return []

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
                "id": f"p{page_number}_t{len(tokens) + 1}",
                "page": page_number,
                "text": text,
                "confidence": score,
                "bbox": box,
            }
        )

    return tokens
