const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { test } = require('node:test');
const assert = require('node:assert/strict');
const root = join(__dirname, '..');
const read = (file) => readFileSync(join(root, file), 'utf8');

test('simple commands never automatically apply or replace live inputs', () => {
  for (const file of ['check.ps1', 'plan.ps1', 'deploy-ai.ps1']) {
    const source = read(`scripts/${file}`);
    assert.doesNotMatch(source, /terraform\s+(apply|destroy)|Copy-Item|Set-Content|Out-File/i);
    assert.match(source, /finally \{ Pop-Location \}|build-\$Service\.ps1/);
  }
});

test('plan requires existing configuration, refreshes normally and accepts a change proposal', () => {
  const source = read('scripts/plan.ps1');
  assert.match(source, /'backend\.hcl', 'terraform\.tfvars'/);
  assert.match(source, /-notin @\(0, 2\)/);
  assert.match(source, /plan file already exists/);
  assert.doesNotMatch(source, /-refresh=false|-lock=false|deploy_application\s*=/);
  assert.match(source, /-lock-timeout=60s/);
});

test('checks use no cloud backend and include mocked ownership tests', () => {
  const source = read('scripts/check.ps1');
  assert.match(source, /init -backend=false -input=false/);
  assert.match(source, /terraform test/);
  assert.doesNotMatch(source, /az login|gcloud|backend-config/);
});

test('AI release preparation selects one build and preserves configuration', () => {
  const source = read('scripts/deploy-ai.ps1');
  assert.match(source, /ValidateSet\('qwen', 'nuextract', 'paddleocr'\)/);
  assert.match(source, /build-\$Service\.ps1/);
  assert.doesNotMatch(source, /run services update|enable_\w+\s*=|terraform @/);
});

test('application wiring uses grouped settings without moving resource addresses', () => {
  const assembly = read('azure/environments/staging/main.tf');
  const application = read('azure/modules/application/main.tf');
  for (const group of ['database', 'storage', 'smtp', 'ai']) {
    assert.match(assembly, new RegExp(`  ${group} = \\{`));
    assert.match(application, new RegExp(`var\\.${group}\\.`));
  }
  assert.match(application, /resource "azurerm_container_app" "api"/);
  assert.match(application, /prevent_destroy = true/);
  assert.match(application, /ignore_changes\s*= \[template\[0\]\.container\[0\]\.image\]/);
  assert.match(assembly, /database_name\s*= "accounting_nest"/);
  assert.match(assembly, /name\s*= module\.database\.database_name/);
});
