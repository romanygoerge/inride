const fs = require('fs');
const path = require('path');

const files = [
  path.join(__dirname, '..', 'app.js'),
  path.join(__dirname, '..', 'admin-dashboard', 'app.js')
];

files.forEach(filePath => {
  let code = fs.readFileSync(filePath, 'utf8');
  let changeCount = 0;

  // ========== FIX 1: Add ratings case in switch ==========
  // Insert case 'ratings' right after case 'passenger-profile' block
  const walletCase = "      case 'wallet':\r\n        container.innerHTML = renderWallet();";
  const ratingsCase = "      case 'ratings':\r\n        container.innerHTML = renderRatingsPage();\r\n        loadRatingsPageData();\r\n        break;\r\n      case 'wallet':\r\n        container.innerHTML = renderWallet();";
  
  if (code.includes(walletCase) && !code.includes("case 'ratings':")) {
    code = code.replace(walletCase, ratingsCase);
    changeCount++;
    console.log(`[${path.basename(filePath)}] FIX 1: Added case 'ratings' in switch`);
  } else {
    // Try without \r\n
    const walletCaseLF = walletCase.replace(/\r\n/g, '\n');
    const ratingsCaseLF = ratingsCase.replace(/\r\n/g, '\n');
    if (code.includes(walletCaseLF) && !code.includes("case 'ratings':")) {
      code = code.replace(walletCaseLF, ratingsCaseLF);
      changeCount++;
      console.log(`[${path.basename(filePath)}] FIX 1: Added case 'ratings' in switch (LF)`);
    } else {
      console.log(`[${path.basename(filePath)}] FIX 1: SKIPPED (already exists or not found)`);
    }
  }

  // ========== FIX 2: Fix .catch() on maybeSingle and select ==========
  const oldCatch1 = "supabaseClient.from('app_settings').select('*').eq('id', 'default').maybeSingle().catch(() => ({ data: null }))";
  const newCatch1 = "(async () => { try { return await supabaseClient.from('app_settings').select('*').eq('id', 'default').maybeSingle(); } catch(_) { return { data: null }; } })()";
  if (code.includes(oldCatch1)) {
    code = code.replace(oldCatch1, newCatch1);
    changeCount++;
    console.log(`[${path.basename(filePath)}] FIX 2a: Fixed .catch() on app_settings maybeSingle`);
  }

  const oldCatch2 = "supabaseClient.from('passengers').select('*').catch(() => ({ data: [] }))";
  const newCatch2 = "(async () => { try { return await supabaseClient.from('passengers').select('*'); } catch(_) { return { data: [] }; } })()";
  if (code.includes(oldCatch2)) {
    code = code.replace(oldCatch2, newCatch2);
    changeCount++;
    console.log(`[${path.basename(filePath)}] FIX 2b: Fixed .catch() on passengers select`);
  }

  // ========== FIX 3: Fix loadProfileRatings - to_user_id doesn't exist ==========
  const oldOrClause = ".or(`receiver_id.eq.${uid},to_user_id.eq.${uid}`)";
  const newOrClause = ".or(`receiver_id.eq.${uid},sender_id.eq.${uid}`)";
  if (code.includes(oldOrClause)) {
    code = code.replace(oldOrClause, newOrClause);
    changeCount++;
    console.log(`[${path.basename(filePath)}] FIX 3a: Fixed to_user_id -> sender_id in loadProfileRatings query`);
  }

  const oldFilter = "list = allSystemRatings.filter(r => (r.receiver_id === uid || r.to_user_id === uid));";
  const newFilter = "list = allSystemRatings.filter(r => (r.receiver_id === uid || r.sender_id === uid));";
  if (code.includes(oldFilter)) {
    code = code.replace(oldFilter, newFilter);
    changeCount++;
    console.log(`[${path.basename(filePath)}] FIX 3b: Fixed to_user_id -> sender_id in allSystemRatings filter`);
  }

  // ========== FIX 4: Fix loadRatingsPageData - resolve names ==========
  const oldRatingsLoad = `    let dbRatings = data || [];
    // Real ratings from Supabase are the sole source of truth (no synthesized records)
    allSystemRatings = dbRatings;`;
  
  const newRatingsLoad = `    let dbRatings = data || [];

    // Resolve sender & receiver names from globalUsersMap
    const allUserIds = new Set();
    dbRatings.forEach(r => { if (r.sender_id) allUserIds.add(r.sender_id); if (r.receiver_id) allUserIds.add(r.receiver_id); });
    const missingIds = [...allUserIds].filter(id => !globalUsersMap[id]);
    if (missingIds.length > 0) {
      try {
        const { data: usrs } = await supabaseClient.from('users').select('id, name, phone_number, role').in('id', missingIds);
        if (usrs) usrs.forEach(u => { globalUsersMap[u.id] = u; });
      } catch(_) {}
    }

    // Enrich ratings with resolved names
    dbRatings = dbRatings.map(r => {
      const senderUser = globalUsersMap[r.sender_id] || {};
      const receiverUser = globalUsersMap[r.receiver_id] || {};
      return {
        ...r,
        sender_name: senderUser.name || senderUser.phone_number || 'مستخدم',
        sender_role: senderUser.role || (r.receiver_role === 'driver' ? 'rider' : 'driver'),
        receiver_name: receiverUser.name || receiverUser.phone_number || 'مستخدم',
      };
    });

    // Real ratings from Supabase are the sole source of truth (no synthesized records)
    allSystemRatings = dbRatings;`;

  if (code.includes(oldRatingsLoad)) {
    code = code.replace(oldRatingsLoad, newRatingsLoad);
    changeCount++;
    console.log(`[${path.basename(filePath)}] FIX 4: Added name resolution in loadRatingsPageData`);
  }

  // ========== FIX 5: Fix receiver name resolution in filterRatingsPage ==========
  const oldReceiverName = `    // Find receiver name if possible
    let receiverName = 'مستخدم (' + (r.receiver_id ? r.receiver_id.substring(0, 6) : '') + ')';
    if (typeof mockData !== 'undefined') {
      const drv = mockData.drivers ? mockData.drivers.find(d => d.uid === r.receiver_id) : null;
      const psg = mockData.passengers ? mockData.passengers.find(p => p.uid === r.receiver_id) : null;
      if (drv) receiverName = drv.name;
      else if (psg) receiverName = psg.name;
    }`;

  const newReceiverName = `    // Resolve receiver name from enriched data or globalUsersMap
    let receiverName = r.receiver_name || 'مستخدم';
    if (receiverName === 'مستخدم') {
      const recUser = globalUsersMap[r.receiver_id];
      if (recUser) receiverName = recUser.name || recUser.phone_number || 'مستخدم';
      else {
        const drv = (mockData.drivers || []).find(d => d.uid === r.receiver_id);
        const psg = (mockData.passengers || []).find(p => p.uid === r.receiver_id);
        if (drv) receiverName = drv.name;
        else if (psg) receiverName = psg.name;
        else receiverName = 'مستخدم (' + (r.receiver_id ? r.receiver_id.substring(0, 6) : '') + ')';
      }
    }`;

  if (code.includes(oldReceiverName)) {
    code = code.replace(oldReceiverName, newReceiverName);
    changeCount++;
    console.log(`[${path.basename(filePath)}] FIX 5: Improved receiver name resolution`);
  }

  fs.writeFileSync(filePath, code, 'utf8');
  console.log(`[${path.basename(filePath)}] Total changes applied: ${changeCount}\n`);
});

console.log('All fixes applied successfully!');
