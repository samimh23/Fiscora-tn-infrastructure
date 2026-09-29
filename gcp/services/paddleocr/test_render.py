"""PDF rendering tests: no Paddle model download or inference is required.

Run in the service environment: python -m unittest test_render.py
"""
import base64
import io
import sys
import unittest
from unittest.mock import MagicMock, patch

import pypdfium2 as pdfium
from PIL import Image


# Only the OCR model is mocked. Do not restore the entire sys.modules mapping:
# that would unload NumPy's native modules after importing the app.
original_paddleocr = sys.modules.get("paddleocr")
sys.modules["paddleocr"] = MagicMock()
try:
    import app
finally:
    if original_paddleocr is None:
        sys.modules.pop("paddleocr", None)
    else:
        sys.modules["paddleocr"] = original_paddleocr


class PdfRenderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        document = pdfium.PdfDocument.new()
        try:
            for _ in range(3):
                page = document.new_page(200, 300)
                page.close()
            buffer = io.BytesIO()
            document.save(buffer)
            cls.content = base64.b64encode(buffer.getvalue()).decode("ascii")
        finally:
            document.close()

    def request(self, **changes):
        payload = {"mimeType": "application/pdf", "contentBase64": self.content, "startPage": 1, "pageCount": 2}
        payload.update(changes)
        return app.RenderRequest(**payload)

    def test_returns_real_page_images_without_using_ocr(self):
        with patch.object(app, "_predict_page", side_effect=AssertionError("OCR must not run")):
            result = app.render_pdf(self.request())
        self.assertEqual(result["pageCount"], 3)
        self.assertEqual([page["page"] for page in result["pages"]], [1, 2])
        for page in result["pages"]:
            self.assertEqual(page["mimeType"], "image/jpeg")
            image = Image.open(io.BytesIO(base64.b64decode(page["contentBase64"])))
            self.assertEqual(image.format, "JPEG")
            self.assertLessEqual(max(image.size), 4096)

    def test_last_batch_only_returns_remaining_pages(self):
        result = app.render_pdf(self.request(startPage=3))
        self.assertEqual([page["page"] for page in result["pages"]], [3])

    def test_rejects_invalid_requests(self):
        for changes, status in [
            ({"mimeType": "image/png"}, 415),
            ({"startPage": 0}, 400),
            ({"startPage": 4}, 400),
            ({"pageCount": 7}, 400),
            ({"contentBase64": "not base64"}, 400),
            ({"contentBase64": base64.b64encode(b"not a PDF").decode("ascii")}, 400),
        ]:
            with self.subTest(changes=changes):
                with self.assertRaises(app.HTTPException) as raised:
                    app.render_pdf(self.request(**changes))
                self.assertEqual(raised.exception.status_code, status)

    def test_rejects_documents_above_the_page_limit(self):
        with patch.object(app, "_max_pdf_pages", 2):
            with self.assertRaises(app.HTTPException) as raised:
                app.render_pdf(self.request())
        self.assertEqual(raised.exception.status_code, 413)

    def test_caps_large_page_dimensions(self):
        document = pdfium.PdfDocument.new()
        try:
            page = document.new_page(10000, 100)
            try:
                image = app._render_pdf_page(page)
                self.assertLessEqual(max(image.shape[:2]), 4096)
            finally:
                page.close()
        finally:
            document.close()


if __name__ == "__main__":
    unittest.main()
