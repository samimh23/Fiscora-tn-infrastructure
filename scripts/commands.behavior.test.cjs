// Run the plan wrapper with a fake Terraform command and throwaway configuration.
// Never authenticates, reads live tfvars, or calls a cloud provider.
const { mkdtempSync, mkdirSync, copyFileSync, writeFileSync, rmSync } = require('node:fs');
const { join, resolve, dirname, basename } = require('node:path');
const { tmpdir } = require('node:os');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');
const assert = require('node:assert/strict');

const shell = spawnSync('pwsh', ['-NoLogo', '-NoProfile', '-Command', '$PSVersionTable.PSVersion.Major'], { encoding: 'utf8' });
const skip = shell.error?.code === 'ENOENT' ? 'PowerShell is not installed' : false;
const quote = (value) => `'${value.replaceAll("'", "''")}'`;

function runPlan({ cloud = 'Azure', code = 0, missing = false, existingPlan = false } = {}) {
  const fixture = mkdtempSync(join(tmpdir(), 'fiscora-command-test-'));
  try {
    const scripts = join(fixture, 'scripts');
    const deployment = join(fixture, cloud === 'Azure' ? 'azure/environments/staging' : 'gcp/environments/ai-staging');
    mkdirSync(scripts, { recursive: true });
    mkdirSync(deployment, { recursive: true });
    const command = join(scripts, 'plan.ps1');
    copyFileSync(join(__dirname, 'plan.ps1'), command);
    if (!missing) {
      writeFileSync(join(deployment, 'backend.hcl'), '# empty test fixture');
      writeFileSync(join(deployment, 'terraform.tfvars'), '# empty test fixture');
    }
    if (existingPlan) writeFileSync(join(deployment, 'reviewed.tfplan'), 'do not overwrite');
    const invocation = `& ${quote(command)} -Cloud ${cloud}${existingPlan ? ' -OutFile reviewed.tfplan' : ''}`;
    const script = `
      $calls = [System.Collections.Generic.List[object]]::new()
      function terraform {
        $calls.Add(@($args))
        $global:LASTEXITCODE = if ($args[0] -eq 'plan') { ${code} } else { 0 }
      }
      $before = (Get-Location).Path
      $message = ''
      $ok = $true
      try { ${invocation} | Out-Null }
      catch { $ok = $false; $message = $_.Exception.Message }
      [pscustomobject]@{ ok=$ok; message=$message; calls=@($calls.ToArray()); restored=((Get-Location).Path -eq $before) } | ConvertTo-Json -Depth 8 -Compress
    `;
    const result = spawnSync('pwsh', ['-NoLogo', '-NoProfile', '-Command', script], { encoding: 'utf8', timeout: 30_000 });
    assert.equal(result.status, 0, result.stderr || result.error?.message);
    return JSON.parse(result.stdout.trim());
  } finally {
    assert.equal(dirname(resolve(fixture)), resolve(tmpdir()));
    assert.match(basename(fixture), /^fiscora-command-test-/);
    rmSync(fixture, { recursive: true, force: true });
  }
}

test('plan wrapper preserves backend argument and uses normal refreshed plans', { skip }, () => {
  for (const cloud of ['Azure', 'Google']) {
    const result = runPlan({ cloud });
    assert.equal(result.ok, true, result.message);
    assert.equal(result.restored, true);
    assert.deepEqual(result.calls[0], ['init', '-backend-config=backend.hcl', '-input=false']);
    assert.deepEqual(result.calls[2], ['plan', '-input=false', '-lock-timeout=60s', '-detailed-exitcode']);
  }
});

test('plan accepts exit 2 but reports exit 1 and restores the working directory', { skip }, () => {
  assert.equal(runPlan({ code: 2 }).ok, true);
  const failed = runPlan({ code: 1 });
  assert.equal(failed.ok, false);
  assert.match(failed.message, /plan failed/);
  assert.equal(failed.restored, true);
});

test('missing live configuration or an existing saved plan prevents all Terraform calls', { skip }, () => {
  for (const options of [{ missing: true }, { existingPlan: true }]) {
    const result = runPlan(options);
    assert.equal(result.ok, false);
    assert.equal(result.calls.length, 0);
    assert.equal(result.restored, true);
  }
});
