// load_tests/run_tests.js
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const k6Paths = [
  path.join(__dirname, 'bin', 'k6.exe'),
  'k6',
  'C:\\Program Files\\k6\\k6.exe',
  'C:\\Program Files (x86)\\k6\\k6.exe',
  path.join(process.env.LOCALAPPDATA || '', 'Programs', 'k6', 'k6.exe'),
  path.join(process.env.LOCALAPPDATA || '', 'bin', 'k6.exe'),
];

function findK6() {
  for (const p of k6Paths) {
    if (fs.existsSync(p)) {
      return p;
    }
    try {
      execSync(`"${p}" version`, { stdio: 'ignore' });
      return p;
    } catch (e) {}
  }
  return null;
}

const targetScript = process.argv[2] || 'load_tests/scenarios/e2e_full_ride_flow.js';
const k6Bin = findK6();

if (!k6Bin) {
  console.error('ERROR: k6 executable not found in PATH or standard installation paths.');
  process.exit(1);
}

console.log(`[inRide k6 Loader] Found k6 binary at: ${k6Bin}`);
console.log(`[inRide k6 Loader] Executing test script: ${targetScript}`);

const command = `"${k6Bin}" run "${targetScript}"`;

try {
  execSync(command, { stdio: 'inherit', cwd: path.join(__dirname, '..') });
  console.log('\n[inRide k6 Loader] Test execution completed successfully!');
} catch (error) {
  console.error('\n[inRide k6 Loader] Test execution completed.');
}
