const fs = require('fs');
const path = require('path');

const rootAppPath = path.join(__dirname, '..', 'app.js');
const adminAppPath = path.join(__dirname, '..', 'admin-dashboard', 'app.js');

let code = fs.readFileSync(rootAppPath, 'utf8');

// 1. Add getUserUnifiedRating function right before initSupabaseSync
const unifiedRatingCode = `
// ============================================
// UNIFIED RATINGS & REVIEWS ENGINE (SINGLE SOURCE OF TRUTH)
// ============================================
function getUserUnifiedRating(userId, targetRole = 'all') {
  if (!userId) {
    return {
      average: '5.0',
      ratingNum: 5.0,
      count: 0,
      display: 'جديد (بدون تقييم)',
      hasRatings: false,
      starsBreakdown: { 5: 0, 4: 0, 3: 0, 2: 0, 1: 0 },
      ratingsList: []
    };
  }

  const normalizedUid = String(userId).trim().toLowerCase();
  const allRatings = (typeof allSystemRatings !== 'undefined' && Array.isArray(allSystemRatings)) 
    ? allSystemRatings 
    : [];

  // Filter ratings strictly received by this user
  const matching = allRatings.filter(r => {
    const recId = String(r.receiver_id || r.to_user_id || '').trim().toLowerCase();
    if (recId !== normalizedUid) return false;
    if (targetRole && targetRole !== 'all') {
      const recRole = String(r.receiver_role || r.role || '').trim().toLowerCase();
      if (targetRole === 'driver' || targetRole === 'captain') {
        return recRole === 'driver' || recRole === 'captain';
      }
      if (targetRole === 'rider' || targetRole === 'passenger') {
        return recRole === 'rider' || recRole === 'passenger';
      }
    }
    return true;
  });

  const count = matching.length;
  const starCounts = { 5: 0, 4: 0, 3: 0, 2: 0, 1: 0 };
  let sum = 0;

  matching.forEach(r => {
    const s = parseFloat(r.rating) || 5;
    sum += s;
    const rounded = Math.min(5, Math.max(1, Math.round(s)));
    starCounts[rounded] = (starCounts[rounded] || 0) + 1;
  });

  let avg = '5.0';
  let avgNum = 5.0;
  let hasRatings = false;

  if (count > 0) {
    avgNum = parseFloat((sum / count).toFixed(1));
    avg = avgNum.toFixed(1);
    hasRatings = true;
  } else {
    // If no explicit rating rows in ratings table, check base user rating in DB
    let userObj = (typeof globalUsersMap !== 'undefined') ? (globalUsersMap[userId] || Object.values(globalUsersMap).find(u => u.id && u.id.toLowerCase() === normalizedUid)) : null;
    const baseCount = parseInt(userObj?.rating_count || userObj?.total_ratings || 0);
    const baseRating = parseFloat(userObj?.rating || 0);
    if (baseCount > 0 && baseRating > 0) {
      avgNum = parseFloat(baseRating.toFixed(1));
      avg = avgNum.toFixed(1);
      hasRatings = true;
    }
  }

  const display = hasRatings ? avg : 'جديد (بدون تقييم)';

  return {
    average: avg,
    ratingNum: avgNum,
    count: count,
    display: display,
    hasRatings: hasRatings,
    starsBreakdown: starCounts,
    ratingsList: matching
  };
}
`;

// Insert getUserUnifiedRating if not present
if (!code.includes('function getUserUnifiedRating(')) {
  const syncAnchor = 'function initSupabaseSync() {';
  code = code.replace(syncAnchor, unifiedRatingCode + '\n' + syncAnchor);
}

// 2. Replace viewUserProfile and profile rendering functions
const profileBlockStart = 'function viewUserProfile(';
const profileBlockEnd = '// ---- RATINGS & REVIEWS MODULE ----';

const sIdx = code.indexOf(profileBlockStart);
const eIdx = code.indexOf(profileBlockEnd);

if (sIdx === -1 || eIdx === -1) {
  console.error('ERROR: Could not locate profile block in app.js');
  process.exit(1);
}

const newProfileAndRatingsBlock = `function viewUserProfile(uid, role = 'rider') {
  if (!uid || uid === 'null' || uid === 'undefined') {
    showToast('⚠️ معرف المستخدم غير متاح');
    return;
  }

  activeProfileUid = uid;
  activeProfileRole = role;
  sessionStorage.setItem('admin_activeProfileUid', uid);
  sessionStorage.setItem('admin_activeProfileRole', role);

  // Auto-detect best profile page
  const targetUid = String(uid).trim().toLowerCase();
  const isDriverInStore = (mockData.drivers || []).some(d => (d.uid && d.uid.toLowerCase() === targetUid) || (d.id && d.id.toLowerCase() === targetUid));
  const effectivePage = (role === 'driver' || isDriverInStore) ? 'driver-profile' : 'passenger-profile';

  navigateTo(effectivePage);
  setTimeout(() => {
    loadProfileRatings(uid, role);
  }, 100);
}

// Helper to resolve user entity from memory or trigger async loading
function resolveUserEntity(uid) {
  if (!uid) return null;
  const targetUid = String(uid).trim().toLowerCase();

  // 1. Check in mockData.drivers
  let driverObj = (mockData.drivers || []).find(d => 
    (d.uid && d.uid.toLowerCase() === targetUid) ||
    (d.id && d.id.toLowerCase() === targetUid)
  );
  if (driverObj) return { user: driverObj, type: 'driver' };

  // 2. Check in mockData.passengers
  let passengerObj = (mockData.passengers || []).find(p => 
    (p.uid && p.uid.toLowerCase() === targetUid) ||
    (p.id && p.id.toLowerCase() === targetUid)
  );
  if (passengerObj) return { user: passengerObj, type: 'passenger' };

  // 3. Check in globalUsersMap
  if (typeof globalUsersMap !== 'undefined') {
    for (const [k, u] of Object.entries(globalUsersMap)) {
      if (k.toLowerCase() === targetUid || (u.id && u.id.toLowerCase() === targetUid)) {
        const uRole = (u.role || '').toLowerCase();
        const dName = u.name || u.phone_number || ('مستخدم ' + u.id.substring(0, 6));
        const dateObj = new Date(u.created_at || Date.now());
        const uRatingObj = getUserUnifiedRating(u.id, uRole === 'driver' ? 'driver' : 'rider');

        const constructed = {
          id: (uRole === 'driver' ? 'DRV_' : 'PAS_') + u.id.substring(0, 6).toUpperCase(),
          uid: u.id,
          name: dName,
          phone: u.phone_number || u.phone || '—',
          email: u.email || '—',
          address: u.address || '—',
          rating: uRatingObj.display,
          ratingNum: uRatingObj.ratingNum,
          ratingCount: uRatingObj.count,
          totalTrips: u.total_trips || 0,
          totalSpent: 0,
          earnings: parseFloat(u.wallet_balance || 0),
          status: u.status || (uRole === 'driver' ? 'verified' : 'active'),
          statusAr: u.status === 'suspended' ? 'معلق' : (u.status === 'banned' ? 'محظور' : (uRole === 'driver' ? 'معتمد' : 'نشط')),
          joinDate: dateObj.toLocaleDateString('ar-EG'),
          avatar: dName.charAt(0).toUpperCase(),
          vehicleType: 'car',
          vehicleName: 'مركبة',
          vehicleColor: 'فضي',
          licensePlate: '—',
          isOnline: false,
          nationalIdUrl: '',
          nationalIdBackUrl: '',
          licenseUrl: '',
          licenseBackUrl: '',
          vehicleFrontUrl: '',
          vehicleBackUrl: '',
          vehicleLicenseUrl: '',
        };
        return { user: constructed, type: uRole === 'driver' ? 'driver' : 'passenger' };
      }
    }
  }

  // 4. Check in mockData.trips
  const matchingTrip = (mockData.trips || []).find(t => 
    (t.riderUid && t.riderUid.toLowerCase() === targetUid) ||
    (t.driverUid && t.driverUid.toLowerCase() === targetUid)
  );
  if (matchingTrip) {
    const isDriverMatch = matchingTrip.driverUid && matchingTrip.driverUid.toLowerCase() === targetUid;
    const name = isDriverMatch ? matchingTrip.driverName : matchingTrip.riderName;
    const phone = isDriverMatch ? '—' : matchingTrip.riderPhone;
    const uRatingObj = getUserUnifiedRating(targetUid, isDriverMatch ? 'driver' : 'rider');

    const tripConstructed = {
      id: (isDriverMatch ? 'DRV_' : 'PAS_') + targetUid.substring(0, 6).toUpperCase(),
      uid: targetUid,
      name: name || ('مستخدم ' + targetUid.substring(0, 6)),
      phone: phone || '—',
      email: '—',
      address: '—',
      rating: uRatingObj.display,
      ratingNum: uRatingObj.ratingNum,
      ratingCount: uRatingObj.count,
      totalTrips: 1,
      totalSpent: 0,
      earnings: 0,
      status: 'active',
      statusAr: isDriverMatch ? 'معتمد' : 'نشط',
      joinDate: matchingTrip.date || '2026/01/10',
      avatar: (name || 'م').charAt(0).toUpperCase(),
      vehicleType: matchingTrip.vehicle || 'car',
      vehicleName: 'مركبة',
      vehicleColor: 'فضي',
      licensePlate: '—',
      isOnline: false,
      nationalIdUrl: '',
      nationalIdBackUrl: '',
      licenseUrl: '',
      licenseBackUrl: '',
      vehicleFrontUrl: '',
      vehicleBackUrl: '',
      vehicleLicenseUrl: '',
    };
    return { user: tripConstructed, type: isDriverMatch ? 'driver' : 'passenger' };
  }

  return null;
}

// Asynchronous on-demand user loader
let isFetchingAsyncProfile = false;
async function fetchAndDisplayUserProfile(uid, role) {
  if (isFetchingAsyncProfile || !uid) return;
  isFetchingAsyncProfile = true;

  try {
    const [userRes, driverRes, vehicleRes] = await Promise.all([
      supabaseClient.from('users').select('*').eq('id', uid).maybeSingle(),
      supabaseClient.from('drivers').select('*').eq('id', uid).maybeSingle(),
      supabaseClient.from('vehicles').select('*').or(\`driver_id.eq.\${uid},id.eq.\${uid}\`).maybeSingle()
    ]);

    const u = userRes?.data;
    const d = driverRes?.data;
    const v = vehicleRes?.data;

    if (u || d) {
      const uData = u || {};
      const dData = d || {};
      const vData = v || {};
      const isDriver = !!d || (uData.role === 'driver');
      const uName = uData.name || dData.name || uData.phone_number || dData.phone || ('مستخدم ' + uid.substring(0, 6));
      const uRatingObj = getUserUnifiedRating(uid, isDriver ? 'driver' : 'rider');

      const fullObj = {
        id: (isDriver ? 'DRV_' : 'PAS_') + uid.substring(0, 6).toUpperCase(),
        uid: uid,
        name: uName,
        phone: uData.phone_number || dData.phone || '—',
        email: uData.email || dData.email || '—',
        address: dData.address || uData.address || '—',
        rating: uRatingObj.display,
        ratingNum: uRatingObj.ratingNum,
        ratingCount: uRatingObj.count,
        vehicleType: vData.vehicle_category || vData.type || 'car',
        vehicleName: vData.model || dData.vehicle_name || 'مركبة',
        vehicleColor: vData.color || 'فضي',
        licensePlate: vData.number_plate || '—',
        status: dData.verification_status || uData.status || (isDriver ? 'verified' : 'active'),
        statusAr: (dData.verification_status === 'verified' || uData.status === 'active') ? (isDriver ? 'معتمد' : 'نشط') : 'قيد المراجعة',
        totalTrips: parseInt(dData.total_trips || uData.total_trips || 0),
        earnings: parseFloat(dData.total_earnings || uData.wallet_balance || 0),
        isOnline: dData.is_online || false,
        joinDate: new Date(uData.created_at || dData.created_at || Date.now()).toLocaleDateString('ar-EG'),
        avatar: uName.charAt(0).toUpperCase(),
        nationalIdUrl: dData.national_id_url || '',
        nationalIdBackUrl: dData.national_id_back_url || '',
        licenseUrl: dData.license_url || '',
        licenseBackUrl: dData.license_back_url || '',
        vehicleFrontUrl: dData.vehicle_front_url || '',
        vehicleBackUrl: dData.vehicle_back_url || '',
        vehicleLicenseUrl: dData.vehicle_license_url || '',
        idCardFrontUrl: dData.national_id_url || '',
        idCardBackUrl: dData.national_id_back_url || '',
        driverLicenseFrontUrl: dData.license_url || '',
        driverLicenseBackUrl: dData.license_back_url || '',
        vehicleLicenseFrontUrl: dData.vehicle_front_url || '',
        vehicleLicenseBackUrl: dData.vehicle_back_url || '',
      };

      if (isDriver) {
        if (!mockData.drivers) mockData.drivers = [];
        mockData.drivers.push(fullObj);
      } else {
        if (!mockData.passengers) mockData.passengers = [];
        mockData.passengers.push(fullObj);
      }

      if (typeof globalUsersMap !== 'undefined') {
        globalUsersMap[uid] = uData;
      }

      // Re-render current profile page smoothly
      renderPage(currentPage);
      loadProfileRatings(uid, isDriver ? 'driver' : 'rider');
    }
  } catch (err) {
    console.error('Error in fetchAndDisplayUserProfile:', err);
  } finally {
    isFetchingAsyncProfile = false;
  }
}

function renderDriverProfile() {
  if (!activeProfileUid) {
    return \`<div style="padding:40px;text-align:center;color:var(--text-light);"><i class="ri-user-unfollow-line" style="font-size:36px;display:block;margin-bottom:8px;"></i>لم يتم تحديد كابتن لعرضه.</div>\`;
  }

  const resolved = resolveUserEntity(activeProfileUid);
  if (!resolved) {
    fetchAndDisplayUserProfile(activeProfileUid, 'driver');
    return \`
      <div style="padding:60px;text-align:center;background:var(--bg-card);border-radius:var(--radius-lg);margin:24px 0;border:1px solid var(--border-color);">
        <div class="stat-card-icon" style="margin:0 auto 16px;width:56px;height:56px;font-size:28px;background:rgba(59,130,246,0.1);color:var(--primary);border-radius:50%;display:flex;align-items:center;justify-content:center;">
          <i class="ri-loader-4-line ri-spin"></i>
        </div>
        <h3 style="font-weight:800;font-size:18px;margin-bottom:8px;color:var(--text-primary);">جاري تحميل بيانات الكابتن من الخادم...</h3>
        <p style="font-size:13px;color:var(--text-secondary);">يتم الآن جلب السجلات والمستندات الموثقة مباشرة من Supabase</p>
      </div>
    \`;
  }

  const driver = resolved.user;
  const targetUid = String(activeProfileUid).trim().toLowerCase();
  const ratingInfo = getUserUnifiedRating(activeProfileUid, 'driver');

  // Find driver's trips
  const driverTrips = (mockData.trips || []).filter(t => 
    (t.driverUid && t.driverUid.toLowerCase() === targetUid) ||
    t.driverName === driver.name ||
    (t.driverId && t.driverId.toLowerCase() === targetUid)
  );

  return \`
    <div class="page-section">
      <!-- Back button and title -->
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:24px;">
        <button class="btn btn-outline btn-sm" onclick="navigateTo('drivers')" style="display:flex;align-items:center;gap:6px;">
          <i class="ri-arrow-right-line" style="font-size:16px;"></i> العودة لقائمة الكباتن
        </button>
        <span class="text-light" style="font-size:13px;">تاريخ الانضمام: \${driver.joinDate}</span>
      </div>

      <div class="profile-details-grid">
        <!-- Left Side: Support Chat -->
        <div class="card" style="display:flex;flex-direction:column;height:650px;">
          <div class="card-header" style="border-bottom:1px solid var(--border-color);padding-bottom:14px;">
            <h3 style="display:flex;align-items:center;gap:8px;">
              <i class="ri-customer-service-2-fill text-blue"></i>
              محادثة الدعم الفني المباشرة مع الكابتن
            </h3>
            <span class="status-badge \${driver.isOnline ? 'completed' : 'pending'}" style="font-size:11px;">
              <span class="status-dot"></span> \${driver.isOnline ? 'متصل الآن' : 'غير متصل'}
            </span>
          </div>
          
          <!-- Message History -->
          <div id="profileChatMessages" style="flex:1;padding:20px;overflow-y:auto;background:var(--bg-primary);display:flex;flex-direction:column;gap:12px;">
            <div style="text-align:center;padding:24px;color:var(--text-light);font-size:13px;">جاري تحميل المحادثة المباشرة...</div>
          </div>

          <!-- Message Input -->
          <div style="padding:16px;border-top:1px solid var(--border-color);display:flex;gap:12px;align-items:center;">
            <input type="text" id="profileChatInput" placeholder="اكتب رسالتك للكابتن مباشرة..." style="flex:1;padding:12px;border:1px solid var(--border-color);border-radius:var(--radius-md);background:var(--bg-primary);" onkeydown="if(event.key === 'Enter') sendProfileChatMessage()">
            <button class="btn btn-primary" style="padding:12px 20px;" onclick="sendProfileChatMessage()">
              <i class="ri-send-plane-fill"></i> إرسال
            </button>
          </div>
        </div>

        <!-- Right Side: Details & Documents -->
        <div style="display:flex;flex-direction:column;gap:24px;">
          <!-- Personal Details -->
          <div class="card">
            <div class="card-header">
              <h3><i class="ri-user-star-fill text-blue" style="margin-left:8px;"></i> بيانات الكابتن والحساب</h3>
            </div>
            <div class="card-body">
              <div style="display:flex;gap:20px;align-items:center;margin-bottom:20px;">
                <div class="user-avatar-placeholder" style="width:72px;height:72px;font-size:28px;">\${driver.avatar || 'ك'}</div>
                <div>
                  <h3 style="font-weight:800;font-size:18px;margin-bottom:4px;">\${driver.name}</h3>
                  <span style="font-size:12px;color:var(--text-light);font-family:monospace;direction:ltr;display:inline-block;">UID: \${driver.uid}</span>
                </div>
              </div>

              <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-bottom:20px;">
                <div style="background:var(--bg-primary);padding:12px;border-radius:var(--radius-md);">
                  <div style="font-size:11px;color:var(--text-secondary);margin-bottom:4px;">رقم الهاتف</div>
                  <span style="font-weight:700;font-size:13px;direction:ltr;display:inline-block;">\${driver.phone}</span>
                </div>
                <div style="background:var(--bg-primary);padding:12px;border-radius:var(--radius-md);">
                  <div style="font-size:11px;color:var(--text-secondary);margin-bottom:4px;">البريد الإلكتروني</div>
                  <span style="font-weight:700;font-size:13px;direction:ltr;display:inline-block;word-break:break-all;">\${driver.email || '—'}</span>
                </div>
                <div style="background:var(--bg-primary);padding:12px;border-radius:var(--radius-md);">
                  <div style="font-size:11px;color:var(--text-secondary);margin-bottom:4px;">حالة التوثيق</div>
                  <span class="status-badge \${getStatusClass(driver.status)}" style="font-size:12px;">
                    <span class="status-dot"></span> \${driver.statusAr}
                  </span>
                </div>
                <div style="background:var(--bg-primary);padding:12px;border-radius:var(--radius-md);">
                  <div style="font-size:11px;color:var(--text-secondary);margin-bottom:4px;">نوع المركبة</div>
                  <span style="font-weight:700;font-size:13px;"><i class="\${getVehicleIcon(driver.vehicleType)}"></i> \${driver.vehicleName} (\${driver.licensePlate})</span>
                </div>
                <div style="background:var(--bg-primary);padding:12px;border-radius:var(--radius-md);">
                  <div style="font-size:11px;color:var(--text-secondary);margin-bottom:4px;">إجمالي الرحلات المكتملة</div>
                  <span style="font-weight:900;font-size:14px;color:var(--medium-blue);">\${driver.totalTrips || driverTrips.length} رحلة</span>
                </div>
                <div style="background:var(--bg-primary);padding:12px;border-radius:var(--radius-md);">
                  <div style="font-size:11px;color:var(--text-secondary);margin-bottom:4px;">التقييم العام المستلم</div>
                  \${ratingInfo.hasRatings ? \`
                    <div class="rating" style="font-size:14px;font-weight:800;color:var(--warning);display:flex;align-items:center;gap:4px;">
                      <i class="ri-star-fill"></i>
                      <span>\${ratingInfo.average}</span>
                      <span style="font-size:11px;color:var(--text-light);font-weight:normal;">(\${ratingInfo.count} تقييم)</span>
                    </div>
                  \` : \`
                    <div style="font-size:12px;font-weight:700;color:var(--text-light);display:flex;align-items:center;gap:4px;">
                      <i class="ri-star-line" style="color:var(--text-light);"></i>
                      <span>جديد (بدون تقييم)</span>
                    </div>
                  \`}
                </div>
              </div>

              <!-- Quick Verification Actions -->
              <div style="display:flex;gap:10px;flex-wrap:wrap;border-top:1px solid var(--border-light);padding-top:16px;">
                <button class="btn btn-success btn-sm" onclick="approveDriverDocs('\${driver.uid}'); setTimeout(() => viewUserProfile('\${driver.uid}', 'driver'), 500);">
                  <i class="ri-checkbox-circle-line"></i> اعتماد الكابتن
                </button>
                <button class="btn btn-outline btn-sm" style="color:var(--warning);border-color:var(--warning);" onclick="rejectDriverPrompt('\${driver.uid}'); setTimeout(() => viewUserProfile('\${driver.uid}', 'driver'), 500);">
                  <i class="ri-close-circle-line"></i> رفض المستندات
                </button>
                <button class="btn btn-outline btn-sm" onclick="showEditUserModal('\${driver.uid}', 'driver')">
                  <i class="ri-edit-line"></i> تعديل البيانات
                </button>
                <button class="btn btn-outline btn-sm" onclick="adjustWalletPrompt('\${driver.uid}', 'driver')">
                  <i class="ri-wallet-3-line"></i> شحن المحفظة
                </button>
                \${driver.status === 'suspended' ? \`
                  <button class="btn btn-success btn-sm" style="background:var(--success);" onclick="modifyUserStatus('\${driver.uid}', 'activate', 'driver'); setTimeout(() => viewUserProfile('\${driver.uid}', 'driver'), 500);">
                    <i class="ri-lock-unlock-line"></i> تفعيل الحساب
                  </button>
                \` : \`
                  <button class="btn btn-outline btn-sm" style="color:var(--error);border-color:var(--error);" onclick="modifyUserStatus('\${driver.uid}', 'suspend', 'driver'); setTimeout(() => viewUserProfile('\${driver.uid}', 'driver'), 500);">
                    <i class="ri-lock-line"></i> تعليق الحساب
                  </button>
                \`}
                <button class="btn btn-outline btn-sm" style="color:var(--error);border-color:var(--error);" onclick="deleteUserPrompt('\${driver.uid}', 'driver')">
                  <i class="ri-delete-bin-line"></i> حذف الحساب نهائياً
                </button>
              </div>
            </div>
          </div>

          <!-- Documents Card -->
          <div class="card" style="margin-top:0;">
            <div class="card-header">
              <h3><i class="ri-file-shield-2-fill text-blue" style="margin-left:8px;"></i> المستندات المرفوعة للتحقق</h3>
            </div>
            <div class="card-body">
              <div class="doc-viewer-grid">
                \${renderDocItem('بطاقة الرقم القومي (الوجه الأمامي)', driver.idCardFrontUrl || driver.nationalIdUrl)}
                \${renderDocItem('بطاقة الرقم القومي (الوجه الخلفي)', driver.idCardBackUrl || driver.nationalIdBackUrl)}
                \${renderDocItem('رخصة القيادة (الوجه الأمامي)', driver.driverLicenseFrontUrl || driver.licenseUrl)}
                \${renderDocItem('رخصة القيادة (الوجه الخلفي)', driver.driverLicenseBackUrl || driver.licenseBackUrl)}
                \${renderDocItem('رخصة تسيير المركبة (الوجه الأمامي)', driver.vehicleLicenseFrontUrl || driver.vehicleLicenseUrl || driver.vehicleFrontUrl)}
                \${renderDocItem('رخصة تسيير المركبة (الوجه الخلفي)', driver.vehicleLicenseBackUrl || driver.vehicleBackUrl)}
              </div>
            </div>
          </div>

          <!-- Received Ratings & Reviews Card -->
          <div class="card" style="margin-top:0;">
            <div class="card-header">
              <h3><i class="ri-star-smile-fill text-warning" style="margin-left:8px;"></i> سجل التقييمات والمراجعات المستلمة</h3>
            </div>
            <div class="card-body" id="profileRatingsContainer">
              <div style="text-align:center;padding:24px;color:var(--text-light);">جاري تحميل التقييمات...</div>
            </div>
          </div>
        </div>
      </div>

      <!-- Bottom: Trip History -->
      <div class="card" style="margin-top:24px;">
        <div class="card-header">
          <h3><i class="ri-route-fill text-blue" style="margin-left:8px;"></i> سجل رحلات الكابتن (\${driverTrips.length} رحلة)</h3>
        </div>
        <div class="card-body" style="padding:0;">
          <table class="data-table">
            <thead>
              <tr>
                <th>رقم الرحلة</th>
                <th>التاريخ</th>
                <th>الراكب</th>
                <th>المسار</th>
                <th>السعر</th>
                <th>الحالة</th>
              </tr>
            </thead>
            <tbody>
              \${driverTrips.length === 0 ? \`<tr><td colspan="6" style="text-align:center;padding:24px;color:var(--text-light);">لا توجد رحلات مسجلة لهذا الكابتن</td></tr>\` : ''}
              \${driverTrips.map(trip => \`
                <tr>
                  <td><span class="font-outfit fw-700" style="color:var(--medium-blue);cursor:pointer;" onclick="showTripDetailsModal('\${trip.requestId}')">\${trip.id}</span></td>
                  <td><span style="font-size:12px;color:var(--text-light);font-weight:600;">\${trip.date}</span></td>
                  <td><span class="user-name" style="cursor:pointer;color:var(--medium-blue);font-weight:700;text-decoration:underline;" onclick="\${trip.riderUid ? \`viewUserProfile('\${trip.riderUid}', 'rider')\` : ''}" title="عرض ملف الراكب">\${trip.riderName}</span></td>
                  <td>
                    <div class="route-cell">
                      <div class="route-addresses">
                        <div class="route-from" style="font-size:11px;">\${trip.from}</div>
                        <div class="route-to" style="font-size:11px;">\${trip.to}</div>
                      </div>
                    </div>
                  </td>
                  <td>
                    <span class="price font-outfit">\${trip.price}</span>
                    <span class="price-currency">ج.م</span>
                  </td>
                  <td>
                    <span class="status-badge \${getStatusClass(trip.status)}">
                      <span class="status-dot"></span>
                      \${trip.status}
                    </span>
                  </td>
                </tr>
              \`).join('')}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  \`;
}

function renderPassengerProfile() {
  if (!activeProfileUid) {
    return \`<div style="padding:40px;text-align:center;color:var(--text-light);"><i class="ri-user-unfollow-line" style="font-size:36px;display:block;margin-bottom:8px;"></i>لم يتم تحديد راكب لعرضه.</div>\`;
  }

  const resolved = resolveUserEntity(activeProfileUid);
  if (!resolved) {
    fetchAndDisplayUserProfile(activeProfileUid, 'rider');
    return \`
      <div style="padding:60px;text-align:center;background:var(--bg-card);border-radius:var(--radius-lg);margin:24px 0;border:1px solid var(--border-color);">
        <div class="stat-card-icon" style="margin:0 auto 16px;width:56px;height:56px;font-size:28px;background:rgba(59,130,246,0.1);color:var(--primary);border-radius:50%;display:flex;align-items:center;justify-content:center;">
          <i class="ri-loader-4-line ri-spin"></i>
        </div>
        <h3 style="font-weight:800;font-size:18px;margin-bottom:8px;color:var(--text-primary);">جاري تحميل بيانات الراكب من الخادم...</h3>
        <p style="font-size:13px;color:var(--text-secondary);">يتم الآن جلب السجلات والرحلات مباشرة من Supabase</p>
      </div>
    \`;
  }

  const passenger = resolved.user;
  const targetUid = String(activeProfileUid).trim().toLowerCase();
  const ratingInfo = getUserUnifiedRating(activeProfileUid, 'rider');

  // Find passenger's trips
  const passengerTrips = (mockData.trips || []).filter(t => 
    (t.riderUid && t.riderUid.toLowerCase() === targetUid) ||
    t.riderName === passenger.name ||
    (passenger.phone && passenger.phone !== '—' && t.riderPhone === passenger.phone)
  );

  return \`
    <div class="page-section">
      <!-- Back button and title -->
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:24px;">
        <button class="btn btn-outline btn-sm" onclick="navigateTo('passengers')" style="display:flex;align-items:center;gap:6px;">
          <i class="ri-arrow-right-line" style="font-size:16px;"></i> العودة لقائمة الركاب
        </button>
        <span class="text-light" style="font-size:13px;">تاريخ الانضمام: \${passenger.joinDate}</span>
      </div>

      <div class="profile-details-grid">
        <!-- Left Side: Support Chat -->
        <div class="card" style="display:flex;flex-direction:column;height:550px;">
          <div class="card-header" style="border-bottom:1px solid var(--border-color);padding-bottom:14px;">
            <h3 style="display:flex;align-items:center;gap:8px;">
              <i class="ri-customer-service-2-fill text-blue"></i>
              محادثة الدعم الفني المباشرة مع الراكب
            </h3>
            <span class="status-badge completed" style="font-size:11px;">
              <span class="status-dot"></span> متصل
            </span>
          </div>
          
          <!-- Message History -->
          <div id="profileChatMessages" style="flex:1;padding:20px;overflow-y:auto;background:var(--bg-primary);display:flex;flex-direction:column;gap:12px;">
            <div style="text-align:center;padding:24px;color:var(--text-light);font-size:13px;">جاري تحميل المحادثة المباشرة...</div>
          </div>

          <!-- Message Input -->
          <div style="padding:16px;border-top:1px solid var(--border-color);display:flex;gap:12px;align-items:center;">
            <input type="text" id="profileChatInput" placeholder="اكتب رسالتك للراكب..." style="flex:1;padding:12px;border:1px solid var(--border-color);border-radius:var(--radius-md);background:var(--bg-primary);" onkeydown="if(event.key === 'Enter') sendProfileChatMessage()">
            <button class="btn btn-primary" style="padding:12px 20px;" onclick="sendProfileChatMessage()">
              <i class="ri-send-plane-fill"></i> إرسال
            </button>
          </div>
        </div>

        <!-- Right Side: Details -->
        <div style="display:flex;flex-direction:column;gap:24px;">
          <!-- Personal Details -->
          <div class="card">
            <div class="card-header">
              <h3><i class="ri-user-3-fill text-blue" style="margin-left:8px;"></i> بيانات الراكب الشخصية</h3>
            </div>
            <div class="card-body">
              <div style="display:flex;gap:20px;align-items:center;margin-bottom:20px;">
                <div class="user-avatar-placeholder" style="width:72px;height:72px;font-size:28px;">\${passenger.avatar || 'ر'}</div>
                <div>
                  <h3 style="font-weight:800;font-size:18px;margin-bottom:4px;">\${passenger.name}</h3>
                  <span style="font-size:12px;color:var(--text-light);font-family:monospace;direction:ltr;display:inline-block;">UID: \${passenger.uid}</span>
                </div>
              </div>

              <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-bottom:20px;">
                <div style="background:var(--bg-primary);padding:12px;border-radius:var(--radius-md);">
                  <div style="font-size:11px;color:var(--text-secondary);margin-bottom:4px;">رقم الهاتف</div>
                  <span style="font-weight:700;font-size:13px;direction:ltr;display:inline-block;">\${passenger.phone}</span>
                </div>
                <div style="background:var(--bg-primary);padding:12px;border-radius:var(--radius-md);">
                  <div style="font-size:11px;color:var(--text-secondary);margin-bottom:4px;">البريد الإلكتروني</div>
                  <span style="font-weight:700;font-size:13px;direction:ltr;display:inline-block;word-break:break-all;">\${passenger.email || '—'}</span>
                </div>
                <div style="background:var(--bg-primary);padding:12px;border-radius:var(--radius-md);">
                  <div style="font-size:11px;color:var(--text-secondary);margin-bottom:4px;">إجمالي الرحلات المكتملة</div>
                  <span style="font-weight:900;font-size:14px;color:var(--medium-blue);">\${passenger.totalTrips || passengerTrips.length} رحلة</span>
                </div>
                <div style="background:var(--bg-primary);padding:12px;border-radius:var(--radius-md);">
                  <div style="font-size:11px;color:var(--text-secondary);margin-bottom:4px;">التقييم العام المستلم</div>
                  \${ratingInfo.hasRatings ? \`
                    <div class="rating" style="font-size:14px;font-weight:800;color:var(--warning);display:flex;align-items:center;gap:4px;">
                      <i class="ri-star-fill"></i>
                      <span>\${ratingInfo.average}</span>
                      <span style="font-size:11px;color:var(--text-light);font-weight:normal;">(\${ratingInfo.count} تقييم)</span>
                    </div>
                  \` : \`
                    <div style="font-size:12px;font-weight:700;color:var(--text-light);display:flex;align-items:center;gap:4px;">
                      <i class="ri-star-line" style="color:var(--text-light);"></i>
                      <span>جديد (بدون تقييم)</span>
                    </div>
                  \`}
                </div>
              </div>

              <!-- Quick Actions -->
              <div style="display:flex;gap:10px;flex-wrap:wrap;border-top:1px solid var(--border-light);padding-top:16px;">
                <button class="btn btn-outline btn-sm" onclick="showEditUserModal('\${passenger.uid}', 'rider')">
                  <i class="ri-edit-line"></i> تعديل البيانات الشخصية
                </button>
                <button class="btn btn-outline btn-sm" onclick="adjustWalletPrompt('\${passenger.uid}', 'rider')">
                  <i class="ri-wallet-3-line"></i> شحن المحفظة
                </button>
                \${passenger.status === 'active' ? \`
                  <button class="btn btn-outline btn-sm" style="color:var(--error);border-color:var(--error);" onclick="modifyUserStatus('\${passenger.uid}', 'suspend', 'rider'); setTimeout(() => viewUserProfile('\${passenger.uid}', 'rider'), 500);">
                    <i class="ri-lock-line"></i> تعليق الحساب
                  </button>
                \` : \`
                  <button class="btn btn-success btn-sm" style="background:var(--success);" onclick="modifyUserStatus('\${passenger.uid}', 'activate', 'rider'); setTimeout(() => viewUserProfile('\${passenger.uid}', 'rider'), 500);">
                    <i class="ri-lock-unlock-line"></i> تفعيل الحساب
                  </button>
                \`}
                <button class="btn btn-outline btn-sm" style="color:var(--error);border-color:var(--error);" onclick="modifyUserStatus('\${passenger.uid}', 'ban', 'rider'); setTimeout(() => viewUserProfile('\${passenger.uid}', 'rider'), 500);">
                  <i class="ri-user-unfollow-line"></i> حظر الراكب
                </button>
                <button class="btn btn-outline btn-sm" style="color:var(--error);border-color:var(--error);" onclick="deleteUserPrompt('\${passenger.uid}', 'rider')">
                  <i class="ri-delete-bin-line"></i> حذف الحساب نهائياً
                </button>
              </div>
            </div>
          </div>

          <!-- Received Ratings & Reviews Card -->
          <div class="card" style="margin-top:0;">
            <div class="card-header">
              <h3><i class="ri-star-smile-fill text-warning" style="margin-left:8px;"></i> سجل التقييمات والمراجعات المستلمة</h3>
            </div>
            <div class="card-body" id="profileRatingsContainer">
              <div style="text-align:center;padding:24px;color:var(--text-light);">جاري تحميل التقييمات...</div>
            </div>
          </div>
        </div>
      </div>

      <!-- Bottom: Trip History -->
      <div class="card" style="margin-top:24px;">
        <div class="card-header">
          <h3><i class="ri-route-fill text-blue" style="margin-left:8px;"></i> سجل رحلات الراكب (\${passengerTrips.length} رحلة)</h3>
        </div>
        <div class="card-body" style="padding:0;">
          <table class="data-table">
            <thead>
              <tr>
                <th>رقم الرحلة</th>
                <th>التاريخ</th>
                <th>الكابتن</th>
                <th>المسار</th>
                <th>السعر</th>
                <th>الحالة</th>
              </tr>
            </thead>
            <tbody>
              \${passengerTrips.length === 0 ? \`<tr><td colspan="6" style="text-align:center;padding:24px;color:var(--text-light);">لا توجد رحلات مسجلة لهذا الراكب</td></tr>\` : ''}
              \${passengerTrips.map(trip => \`
                <tr>
                  <td><span class="font-outfit fw-700" style="color:var(--medium-blue);cursor:pointer;" onclick="showTripDetailsModal('\${trip.requestId}')">\${trip.id}</span></td>
                  <td><span style="font-size:12px;color:var(--text-light);font-weight:600;">\${trip.date}</span></td>
                  <td>
                    \${trip.driverUid ? \`
                      <span class="user-name" style="cursor:pointer;color:var(--medium-blue);font-weight:700;text-decoration:underline;" onclick="viewUserProfile('\${trip.driverUid}', 'driver')" title="عرض ملف الكابتن">\${trip.driverName}</span>
                    \` : '<span style="color:var(--text-light);font-size:12px;">—</span>'}
                  </td>
                  <td>
                    <div class="route-cell">
                      <div class="route-addresses">
                        <div class="route-from" style="font-size:11px;">\${trip.from}</div>
                        <div class="route-to" style="font-size:11px;">\${trip.to}</div>
                      </div>
                    </div>
                  </td>
                  <td>
                    <span class="price font-outfit">\${trip.price}</span>
                    <span class="price-currency">ج.م</span>
                  </td>
                  <td>
                    <span class="status-badge \${getStatusClass(trip.status)}">
                      <span class="status-dot"></span>
                      \${trip.status}
                    </span>
                  </td>
                </tr>
              \`).join('')}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  \`;
}

`;

code = code.substring(0, sIdx) + newProfileAndRatingsBlock + code.substring(eIdx);

// 3. Update loadProfileRatings to use getUserUnifiedRating directly
const oldLoadProfileRatingsStart = 'async function loadProfileRatings(';
const nextFunctionAnchor = 'function renderRatingsPage() {';

const lprStart = code.indexOf(oldLoadProfileRatingsStart);
const lprEnd = code.indexOf(nextFunctionAnchor);

if (lprStart !== -1 && lprEnd !== -1) {
  const newLoadProfileRatings = `async function loadProfileRatings(uid, role = 'rider') {
  const container = document.getElementById('profileRatingsContainer');
  if (!container || !uid) return;

  try {
    const targetRole = (role === 'driver' || role === 'captain') ? 'driver' : 'rider';
    const ratingObj = getUserUnifiedRating(uid, targetRole);
    const list = ratingObj.ratingsList || [];
    const hasRatings = ratingObj.hasRatings;
    const avg = ratingObj.average;
    const starCounts = ratingObj.starsBreakdown;

    // Resolve sender names if available
    const senderIds = list.map(r => r.sender_id || r.from_user_id).filter(Boolean);
    let sendersMap = {};
    if (senderIds.length > 0) {
      senderIds.forEach(sId => {
        if (globalUsersMap && globalUsersMap[sId]) {
          sendersMap[sId] = globalUsersMap[sId].name || globalUsersMap[sId].phone_number;
        }
      });
    }

    let html = \`
      <div style="display:flex;align-items:center;justify-content:space-between;background:var(--bg-primary);padding:16px;border-radius:var(--radius-md);margin-bottom:16px;border:1px solid var(--border-color);">
        <div>
          <span style="font-size:12px;color:var(--text-secondary);font-weight:700;">متوسط التقييم العام المستلم (\${targetRole === 'driver' ? 'كابتن' : 'راكب'})</span>
          <div style="font-size:24px;font-weight:900;color:var(--warning);display:flex;align-items:center;gap:6px;">
            <i class="\${hasRatings ? 'ri-star-fill' : 'ri-star-line'}"></i> \${avg} \${hasRatings ? '<span style="font-size:13px;color:var(--text-light);font-weight:normal;">/ 5.0</span>' : ''}
          </div>
        </div>
        <div style="text-align:left;">
          <span style="font-size:12px;color:var(--text-secondary);font-weight:700;">إجمالي التقييمات</span>
          <div style="font-size:20px;font-weight:800;color:var(--text-primary);">\${list.length} تقييم</div>
        </div>
      </div>
    \`;

    if (hasRatings) {
      html += \`
        <!-- Rating Breakdown Bars -->
        <div style="background:var(--bg-primary);padding:14px;border-radius:var(--radius-md);margin-bottom:16px;border:1px solid var(--border-color);display:flex;flex-direction:column;gap:6px;">
          \${[5, 4, 3, 2, 1].map(stars => {
            const count = starCounts[stars] || 0;
            const pct = list.length > 0 ? Math.round((count / list.length) * 100) : 0;
            return \`
              <div style="display:flex;align-items:center;gap:8px;font-size:12px;">
                <span style="width:50px;font-weight:700;display:flex;align-items:center;gap:2px;">\${stars} <i class="ri-star-fill" style="color:var(--warning);font-size:11px;"></i></span>
                <div style="flex:1;height:8px;background:var(--border-color);border-radius:4px;overflow:hidden;">
                  <div style="width:\${pct}%;height:100%;background:var(--warning);border-radius:4px;transition:width 0.3s ease;"></div>
                </div>
                <span style="width:40px;text-align:left;color:var(--text-secondary);font-size:11px;">\${count} (\${pct}%)</span>
              </div>
            \`;
          }).join('')}
        </div>
      \`;
    }

    html += \`<div style="display:flex;flex-direction:column;gap:12px;max-height:400px;overflow-y:auto;padding-left:4px;">\`;

    if (!hasRatings) {
      html += \`
        <div style="padding:24px;text-align:center;color:var(--text-light);background:var(--bg-primary);border-radius:var(--radius-md);border:1px dashed var(--border-color);">
          <i class="ri-star-line" style="font-size:32px;display:block;margin-bottom:8px;color:var(--text-light);"></i>
          لا توجد تقييمات أو مراجعات مسجلة لهذا الحساب كـ \${targetRole === 'driver' ? 'كابتن' : 'راكب'} حتى الآن
        </div>
      \`;
    } else {
      list.forEach(r => {
        const starVal = parseFloat(r.rating) || 5.0;
        const dateStr = r.created_at ? new Date(r.created_at).toLocaleString('ar-EG') : '—';
        const commentText = (r.comment && r.comment.trim() !== '' && r.comment !== 'بدون تعليق') ? r.comment : (r.review || 'بدون تعليق نصي');
        const sId = r.sender_id || r.from_user_id;
        const senderName = sendersMap[sId] || (typeof globalUsersMap !== 'undefined' && globalUsersMap[sId]?.name) || r.sender_name || 'عميل';
        const sRole = (r.sender_role || r.role || '').toLowerCase();
        const senderRole = sRole === 'driver' ? 'كابتن' : 'راكب';

        let starsHtml = '';
        for (let i = 1; i <= 5; i++) {
          if (i <= Math.round(starVal)) {
            starsHtml += \`<i class="ri-star-fill" style="color:var(--warning);"></i>\`;
          } else {
            starsHtml += \`<i class="ri-star-line" style="color:var(--border-color);"></i>\`;
          }
        }

        html += \`
          <div style="background:var(--bg-primary);border:1px solid var(--border-color);border-radius:var(--radius-md);padding:14px;">
            <div style="display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:8px;">
              <div>
                <span style="font-weight:700;font-size:13px;">\${senderName}</span>
                <span class="status-badge pending" style="font-size:10px;margin-right:6px;">\${senderRole}</span>
              </div>
              <span style="font-size:11px;color:var(--text-light);direction:ltr;">\${dateStr}</span>
            </div>
            <div style="display:flex;align-items:center;gap:4px;margin-bottom:6px;font-size:13px;">
              \${starsHtml}
              <span style="font-weight:800;font-size:12px;margin-right:4px;color:var(--warning);">\${starVal.toFixed(1)}</span>
            </div>
            <div style="font-size:13px;color:var(--text-secondary);line-height:1.5;background:var(--bg-card);padding:8px 12px;border-radius:var(--radius-sm);">
              "\${commentText}"
            </div>
          </div>
        \`;
      });
    }

    html += \`</div>\`;
    container.innerHTML = html;
  } catch (err) {
    console.error('Error loading profile ratings:', err);
    container.innerHTML = \`<div style="text-align:center;padding:16px;color:var(--error);">حدث خطأ أثناء تحميل التقييمات</div>\`;
  }
}

`;
  code = code.substring(0, lprStart) + newLoadProfileRatings + code.substring(lprEnd);
}

// 4. Update runBulkSync to use getUserUnifiedRating for drivers & passengers
// Replace the driver rating calculation
code = code.replace(
  /let avgRating = 0;\s+let ratingCount = driverRatingsCountMap\[drv\.id\] \|\| 0;[\s\S]*?const ratingDisplay = ratingCount > 0 \? avgRating\.toFixed\(1\) : 'جديد \(بدون تقييم\)';/,
  `const dRatingObj = getUserUnifiedRating(drv.id, 'driver');
        const avgRating = dRatingObj.ratingNum;
        const ratingCount = dRatingObj.count;
        const ratingDisplay = dRatingObj.display;`
);

// Replace the passenger rating calculation
code = code.replace(
  /const ratingCount = riderRatingsCountMap\[data\.id\] \|\| parseInt\(data\.rating_count \|\| pRecord\.rating_count \|\| 0\);[\s\S]*?const ratingDisplay = ratingCount > 0 \? avgRating\.toFixed\(1\) : 'جديد \(بدون تقييم\)';/,
  `const pRatingObj = getUserUnifiedRating(data.id, 'rider');
          const avgRating = pRatingObj.ratingNum;
          const ratingCount = pRatingObj.count;
          const ratingDisplay = pRatingObj.display;`
);

fs.writeFileSync(rootAppPath, code, 'utf8');
fs.writeFileSync(adminAppPath, code, 'utf8');
console.log('Successfully updated app.js and admin-dashboard/app.js with Unified Rating Engine and Bulletproof Profile Resolver!');
