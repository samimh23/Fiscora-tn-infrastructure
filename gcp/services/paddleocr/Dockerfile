FROM python:3.11-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PADDLE_PDX_MODEL_SOURCE=BOS \
    PADDLE_HOME=/opt/paddle \
    HOME=/opt/paddle \
    OMP_NUM_THREADS=4

WORKDIR /app

RUN apt-get update \
    && apt-get install --no-install-recommends --yes libgl1 libglib2.0-0 libgomp1 \
    && rm -rf /var/lib/apt/lists/*

RUN python -m pip install --no-cache-dir --upgrade pip \
    && python -m pip install --no-cache-dir paddlepaddle==3.2.2 \
       --index-url https://www.paddlepaddle.org.cn/packages/stable/cpu/ \
    && mkdir -p "$PADDLE_HOME"

COPY requirements.txt .
RUN python -m pip install --no-cache-dir -r requirements.txt

COPY app.py .

# Bake PP-OCRv6-medium weights into the image instead of downloading them on
# every scale-from-zero cold start.
RUN python -c "from paddleocr import PaddleOCR; PaddleOCR(use_doc_orientation_classify=False, use_doc_unwarping=False, use_textline_orientation=False, engine='paddle')"
RUN test -d "$HOME/.paddlex/official_models/PP-OCRv6_medium_det" \
    && test -d "$HOME/.paddlex/official_models/PP-OCRv6_medium_rec"

RUN useradd --home-dir "$PADDLE_HOME" --no-create-home --uid 10001 appuser \
    && chown -R appuser:appuser /app "$PADDLE_HOME"
USER appuser

# Fail the build if the Cloud Run user cannot load or run the baked models.
RUN python -c "import cv2, numpy as np; from app import _ocr; image = np.full((160, 480, 3), 255, dtype=np.uint8); cv2.putText(image, 'INVOICE 123', (20, 90), cv2.FONT_HERSHEY_SIMPLEX, 1.4, (0, 0, 0), 2); assert list(_ocr.predict(image))"

EXPOSE 8080
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8080", "--workers", "1"]
