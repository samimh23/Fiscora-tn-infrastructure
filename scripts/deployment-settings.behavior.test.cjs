// Fake Terraform outputs only. No real state, credentials or cloud calls.
const { mkdtempSync, mkdirSync, copyFileSync, rmSync } = require('node:fs');
const { join, resolve, dirname, basename } = require('node:path');
const { tmpdir } = require('node:os');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');
const assert = require('node:assert/strict');
const shell = spawnSync('pwsh', ['-NoLogo', '-NoProfile', '-Command', '$PSVersionTable.PSVersion.Major'], { encoding: 'utf8' });
const skip = shell.error?.code === 'ENOENT' ? 'PowerShell is not installed' : false;
const quote = value => `'${value.replaceAll("'", "''")}'`;

function runSettings(mode) {
  const fixture = mkdtempSync(join(tmpdir(), 'fiscora-settings-test-'));
  try {
    mkdirSync(join(fixture, 'scripts'));
    mkdirSync(join(fixture, 'azure/environments/staging'), { recursive: true });
    const command = join(fixture, 'scripts/show-deployment-settings.ps1');
    copyFileSync(join(__dirname, 'show-deployment-settings.ps1'), command);
    const script = `
      $calls = [System.Collections.Generic.List[object]]::new()
      function terraform {
        $calls.Add(@($args))
        $name = $args[2]
        $global:LASTEXITCODE = 0
        if ('${mode}' -eq 'failure') { $global:LASTEXITCODE = 1; return }
        if ('${mode}' -eq 'foundation' -and $name -in @('app_service_name', 'app_service_url')) { ConvertTo-Json -InputObject $null -Compress; return }
        if ($name -eq 'backend_hosting') { ConvertTo-Json -InputObject 'app-service' -Compress }
        elseif ($name -eq 'app_service_name') { ConvertTo-Json -InputObject 'app-test-staging' -Compress }
        elseif ($name -eq 'app_service_url') { ConvertTo-Json -InputObject 'https://app-test-staging.azurewebsites.net' -Compress }
        else { ConvertTo-Json -InputObject $name -Compress }
      }
      $before = (Get-Location).Path
      $ok = $true
      $output = @()
      $message = ''
      try { $output = @(& ${quote(command)}) }
      catch { $ok = $false; $message = $_.Exception.Message }
      [pscustomobject]@{ok=$ok; message=$message; output=$output; calls=@($calls.ToArray()); restored=((Get-Location).Path -eq $before)} | ConvertTo-Json -Depth 8 -Compress
    `;
    const result = spawnSync('pwsh', ['-NoLogo', '-NoProfile', '-Command', script], { encoding: 'utf8', timeout: 30_000 });
    assert.equal(result.status, 0, result.stderr || result.error?.message);
    return JSON.parse(result.stdout.trim());
  } finally {
    assert.equal(dirname(resolve(fixture)), resolve(tmpdir()));
    assert.match(basename(fixture), /^fiscora-settings-test-/);
    rmSync(fixture, { recursive: true, force: true });
  }
}

test('settings show existing deployment IDs and API URL without requesting all outputs', { skip }, () => {
  const result = runSettings('app-service');
  assert.equal(result.ok, true, result.message);
  assert.equal(result.restored, true);
  assert.ok(result.output.includes('AZURE_WEB_APP_NAME=app-test-staging'));
  assert.ok(result.output.includes('AZURE_API_URL=https://app-test-staging.azurewebsites.net'));
  assert.ok(result.calls.every(args => args.length === 3 && args[0] === 'output' && args[1] === '-json'));
  assert.ok(!result.calls.some(args => args[2].startsWith('container_app')));
});

test('foundation settings do not invent an API name or URL', { skip }, () => {
  const result = runSettings('foundation');
  assert.equal(result.ok, true, result.message);
  assert.equal(result.restored, true);
  assert.ok(!result.output.some(line => line.startsWith('AZURE_WEB_APP_NAME=')));
  assert.ok(!result.output.some(line => line.startsWith('AZURE_API_URL=')));
  assert.ok(result.output.some(line => line.includes('do not deploy the frontend yet')));
});

test('active App Service settings never direct deployments back to retired hosting', { skip }, () => {
  const result = runSettings('app-service');
  assert.equal(result.ok, true, result.message);
  assert.equal(result.restored, true);
  assert.ok(result.output.includes('AZURE_BACKEND_HOSTING=app-service'));
  assert.ok(result.output.includes('AZURE_WEB_APP_NAME=app-test-staging'));
  assert.ok(result.output.includes('AZURE_API_URL=https://app-test-staging.azurewebsites.net'));
  assert.ok(!result.output.some(line => line.startsWith('AZURE_CONTAINER_APP_NAME=')));
});

test('unavailable state fails before printing deployment settings and restores location', { skip }, () => {
  const result = runSettings('failure');
  assert.equal(result.ok, false);
  assert.equal(result.restored, true);
  assert.deepEqual(result.output, []);
  assert.match(result.message, /Cannot read output azure_tenant_id/);
});
