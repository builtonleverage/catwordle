/**
 * CATword Sheets backend.
 * Bound to a Google Sheet with a tab named "KV" and columns:
 * key | value | shared | updated_at
 *
 * Deploy via Deploy > New deployment > Web app
 *   Execute as: Me
 *   Who has access: Anyone
 *
 * Before deploying, set the TOKEN script property (do NOT hardcode it in
 * this file — it's committed to git):
 * Project Settings (gear icon) > Script Properties > Add script property
 *   Property: TOKEN   Value: <your shared secret>
 */

var SHEET_NAME = 'KV';
var DEVICE_SHEET_NAME = 'DeviceLog';
var DEVICE_FIELDS = [
  'device_id','first_seen','last_seen','visits','user_agent','platform','language',
  'timezone','screen_w','screen_h','viewport_w','viewport_h','device_pixel_ratio',
  'color_scheme','touch','hw_concurrency','device_memory','connection_type','referrer'
];

function getToken_() {
  var token = PropertiesService.getScriptProperties().getProperty('TOKEN');
  if (!token) throw new Error('TOKEN script property not set — see setup_()');
  return token;
}

function doGet(e) {
  try {
    var p = e.parameter;
    if (p.token !== getToken_()) return jsonOut_({ ok: false, error: 'unauthorized' });

    var shared = p.shared === 'true';

    if (p.action === 'get') {
      if (!p.key) return jsonOut_({ ok: false, error: 'missing key' });
      var row = findRow_(p.key, shared);
      return jsonOut_({ ok: true, value: row ? row.value : null });
    }

    if (p.action === 'list') {
      var keys = listKeys_(p.prefix || '', shared);
      return jsonOut_({ ok: true, keys: keys });
    }

    return jsonOut_({ ok: false, error: 'unknown action' });
  } catch (err) {
    return jsonOut_({ ok: false, error: String(err) });
  }
}

function doPost(e) {
  try {
    var body = JSON.parse(e.postData.contents);
    if (body.token !== getToken_()) return jsonOut_({ ok: false, error: 'unauthorized' });

    if (body.action === 'set') {
      if (!body.key) return jsonOut_({ ok: false, error: 'missing key' });
      setValue_(body.key, body.value, !!body.shared);
      return jsonOut_({ ok: true });
    }

    if (body.action === 'logDevice') {
      if (!body.device || !body.device.device_id) return jsonOut_({ ok: false, error: 'missing device_id' });
      upsertDevice_(body.device);
      return jsonOut_({ ok: true });
    }

    return jsonOut_({ ok: false, error: 'unknown action' });
  } catch (err) {
    return jsonOut_({ ok: false, error: String(err) });
  }
}

function jsonOut_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

function getSheet_() {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_NAME);
  if (!sheet) throw new Error('Sheet tab "' + SHEET_NAME + '" not found');
  return sheet;
}

// Returns the 1-indexed sheet row for a key+shared pair, or -1 if not found.
function findRowIndex_(key, shared) {
  var data = getSheet_().getDataRange().getValues();
  for (var i = 1; i < data.length; i++) {
    if (data[i][0] === key && !!data[i][2] === shared) return i + 1;
  }
  return -1;
}

function findRow_(key, shared) {
  var idx = findRowIndex_(key, shared);
  if (idx === -1) return null;
  var row = getSheet_().getRange(idx, 1, 1, 4).getValues()[0];
  return { key: row[0], value: row[1], shared: row[2], updated_at: row[3] };
}

function setValue_(key, value, shared) {
  var sheet = getSheet_();
  var idx = findRowIndex_(key, shared);
  var now = new Date().toISOString();
  if (idx === -1) {
    sheet.appendRow([key, value, shared, now]);
  } else {
    sheet.getRange(idx, 2, 1, 3).setValues([[value, shared, now]]);
  }
}

function listKeys_(prefix, shared) {
  var data = getSheet_().getDataRange().getValues();
  var keys = [];
  for (var i = 1; i < data.length; i++) {
    var k = String(data[i][0]);
    var s = !!data[i][2];
    if (s === shared && k.indexOf(prefix) === 0) keys.push(k);
  }
  return keys;
}

function getDeviceSheet_() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName(DEVICE_SHEET_NAME);
  if (!sheet) {
    sheet = ss.insertSheet(DEVICE_SHEET_NAME);
    sheet.appendRow(DEVICE_FIELDS);
  }
  return sheet;
}

function deviceRowValues_(device, firstSeen, lastSeen, visits) {
  return [
    device.device_id, firstSeen, lastSeen, visits,
    device.user_agent || '', device.platform || '', device.language || '',
    device.timezone || '', device.screen_w || '', device.screen_h || '',
    device.viewport_w || '', device.viewport_h || '', device.device_pixel_ratio || '',
    device.color_scheme || '', !!device.touch, device.hw_concurrency || '',
    device.device_memory || '', device.connection_type || '', device.referrer || ''
  ];
}

// Upserts by device_id: updates last_seen/visits on repeat visits, appends a
// new row for a first-time device.
function upsertDevice_(device) {
  var sheet = getDeviceSheet_();
  var data = sheet.getDataRange().getValues();
  var now = new Date().toISOString();
  for (var i = 1; i < data.length; i++) {
    if (data[i][0] === device.device_id) {
      var visits = (Number(data[i][3]) || 0) + 1;
      var row = deviceRowValues_(device, data[i][1], now, visits);
      sheet.getRange(i + 1, 1, 1, DEVICE_FIELDS.length).setValues([row]);
      return;
    }
  }
  sheet.appendRow(deviceRowValues_(device, now, now, 1));
}
