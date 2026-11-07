const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { test } = require('node:test');
const assert = require('node:assert/strict');

const root = join(__dirname, '..');
const read = (file) => readFileSync(join(root, file), 'utf8');

test('reviewed eight-request capacity is aligned across the serving layers', () => {
  const vars = read('gcp/environments/ai-staging/variables.tf');
  for (const key of ['nuextract_request_concurrency', 'nuextract_max_num_seqs']) {
    assert.match(vars, new RegExp('variable "' + key + '" \\{[\\s\\S]*?default\\s*=\\s*8'));
  }
  assert.match(vars, /contains\(\[1, 2, 4, 8\], var\.nuextract_request_concurrency\)/);
  assert.match(vars, /contains\(\[1, 2, 4, 8\], var\.nuextract_max_num_seqs\)/);
  const app = read('azure/environments/staging/app-service.tf');
  assert.match(app, /DOCUMENT_EXTRACTION_WORKER_CONCURRENCY\s*=\s*"8"/);
  assert.match(app, /DOCUMENT_EXTRACTION_NUEXTRACT_CONCURRENCY\s*=\s*"8"/);
  assert.match(read('gcp/services/nuextract/start.sh'), /MAX_NUM_SEQS:-8/);
  assert.match(read('gcp/services/nuextract/Dockerfile'), /MAX_NUM_SEQS=8/);
});

test('raising concurrency does not expand the per-request image limit or Paddle capacity', () => {
  assert.match(read('gcp/services/nuextract/start.sh'), /'\{"image": 6, "video": 0\}'/);
  const google = read('gcp/environments/ai-staging/main.tf');
  const paddle = google.slice(google.indexOf('resource "google_cloud_run_v2_service" "paddleocr"'));
  assert.match(paddle, /max_instance_request_concurrency\s*=\s*1/);
  assert.match(paddle, /max_instance_count\s*=\s*1/);
});
