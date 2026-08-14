const fs = require('fs');
const path = require('path');

const appJsPath = path.join(__dirname, '..', 'app.js');
let code = fs.readFileSync(appJsPath, 'utf8');

console.log('Original lines:', code.split('\n').length);

// 1. In verifyAndApplyAdminSession: only call initSupabaseSync
code = code.replace(
  `    if (!isSyncStarted) {
      isSyncStarted = true;
      try { initSupabaseSync(); } catch (_) {}
      try { initDriversRealtimeSync(); } catch (_) {}
    }`,
  `    if (!isSyncStarted) {
      isSyncStarted = true;
      try { initSupabaseSync(); } catch (_) {}
    }`
);

// 2. In navigateTo: Add ratings to validPages
code = code.replace(
  `const validPages = ['dashboard', 'trips', 'drivers', 'passengers', 'driver-profile', 'passenger-profile', 'wallet', 'pricing', 'communication', 'messages', 'support', 'content', 'monitoring', 'logs', 'settings'];`,
  `const validPages = ['dashboard', 'trips', 'drivers', 'passengers', 'ratings', 'driver-profile', 'passenger-profile', 'wallet', 'pricing', 'communication', 'messages', 'support', 'content', 'monitoring', 'logs', 'settings'];`
);

// 3. In updateHeaderTitle: Add ratings
code = code.replace(
  `passengers: { title: 'إدارة الركاب والمستخدمين', sub: 'التحكم بالركاب والمستخدمين وتعديل بياناتهم وحظرهم' },`,
  `passengers: { title: 'إدارة الركاب والمستخدمين', sub: 'التحكم بالركاب والمستخدمين وتعديل بياناتهم وحظرهم' },
    ratings: { title: 'إدارة التقييمات والمراجعات', sub: 'عرض وتحليل كافة تقييمات العملاء والكباتن ومراقبة جودة الخدمة' },`
);

// 4. In renderPage: Add ratings switch case
code = code.replace(
  `      case 'passengers':
        container.innerHTML = renderPassengers();
        break;
      case 'driver-profile':
        container.innerHTML = renderDriverProfile();
        initProfileChatSync(activeProfileUid, 'driver');
        loadProfileRatings(activeProfileUid, 'driver');
        break;
      case 'passenger-profile':
        container.innerHTML = renderPassengerProfile();
        initProfileChatSync(activeProfileUid, 'rider');
        loadProfileRatings(activeProfileUid, 'rider');
        break;`,
  `      case 'passengers':
        container.innerHTML = renderPassengers();
        break;
      case 'ratings':
        container.innerHTML = renderRatingsPage();
        loadRatingsPageData();
        break;
      case 'driver-profile':
        container.innerHTML = renderDriverProfile();
        initProfileChatSync(activeProfileUid, 'driver');
        loadProfileRatings(activeProfileUid, 'driver');
        break;
      case 'passenger-profile':
        container.innerHTML = renderPassengerProfile();
        initProfileChatSync(activeProfileUid, 'rider');
        loadProfileRatings(activeProfileUid, 'rider');
        break;`
);

let lines = code.split('\n');

function replaceBlock(startPrefix, endPrefix, newCode) {
  let s = -1, e = -1;
  for (let i = 0; i < lines.length; i++) {
    if (s === -1 && lines[i].trim().startsWith(startPrefix)) {
      s = i;
    } else if (s !== -1 && e === -1 && lines[i].trim().startsWith(endPrefix)) {
      e = i;
      break;
    }
  }
  if (s !== -1 && e !== -1) {
    console.log(`Replacing block: ${startPrefix} (line ${s+1}) -> ${endPrefix} (line ${e+1})`);
    lines.splice(s, e - s, newCode);
    return true;
  } else {
    console.error(`ERROR: Could not find block from '${startPrefix}' to '${endPrefix}'`);
    process.exit(1);
  }
}

// 5. Replace initDriversRealtimeSync
replaceBlock(
  'async function initDriversRealtimeSync()',
  'async function handleLogin(event)',
  `async function initDriversRealtimeSync() {
  if (typeof initSupabaseSync === 'function') {
    return initSupabaseSync();
  }
}
`
);

// 6. Replace renderDrivers
const renderDriversNewCode = `let driverStatusFilter = 'all';

function setDriverStatusFilter(status) {
  driverStatusFilter = status;
  if (currentPages['drivers']) {
    currentPages['drivers'] = 1;
  }
  renderPage('drivers');
}

// ---- DRIVERS ----
function renderDrivers() {
  const q = (searchQuery || '').toLowerCase().trim();
  
  // Filter by status tab & ghost records
  const filteredDrivers = (mockData.drivers || []).filter(d => {
    // Tab filter
    if (driverStatusFilter === 'verified' && d.status !== 'verified') return false;
    if (driverStatusFilter === 'submitted' && d.status !== 'submitted') return false;
    if (driverStatusFilter === 'rejected' && d.status !== 'rejected') return false;
    if (driverStatusFilter === 'unregistered') {
      return d.status === 'unregistered' || !d.status || d.status === 'draft';
    }
    if (driverStatusFilter === 'all') {
      // In "all" tab, exclude completely blank ghost records with 0 trips, no vehicle, no phone, no docs
      if (d.status === 'unregistered' && (!d.phone || d.phone === '—') && (!d.vehicleName || d.vehicleName === 'مركبة') && !d.idCardFrontUrl && !d.nationalIdUrl && d.totalTrips === 0) {
        return false;
      }
    }

    // Search query
    if (q) {
      const matchId = (d.id || '').toString().toLowerCase().includes(q) || (d.uid || '').toString().toLowerCase().includes(q);
      const matchName = (d.name || '').toString().toLowerCase().includes(q);
      const matchPhone = (d.phone || '').toString().includes(q);
      const matchVehicle = (d.vehicleName || '').toString().toLowerCase().includes(q);
      const matchPlate = (d.licensePlate || '').toString().toLowerCase().includes(q);
      return matchId || matchName || matchPhone || matchVehicle || matchPlate;
    }
    return true;
  });

  const page = currentPages['drivers'] || 1;
  const totalItems = filteredDrivers.length;
  const totalPages = Math.max(1, Math.ceil(totalItems / itemsPerPage));
  const safePage = Math.min(page, totalPages);
  const startIndex = (safePage - 1) * itemsPerPage;
  const endIndex = Math.min(startIndex + itemsPerPage, totalItems);
  const paginatedDrivers = filteredDrivers.slice(startIndex, endIndex);

  const verifiedCount = (mockData.drivers || []).filter(d => d.status === 'verified').length;
  const submittedCount = (mockData.drivers || []).filter(d => d.status === 'submitted').length;
  const rejectedCount = (mockData.drivers || []).filter(d => d.status === 'rejected').length;
  const unregisteredCount = (mockData.drivers || []).filter(d => d.status === 'unregistered' || !d.status).length;

  return \`
    <div class="page-section">
      <!-- Stats Overview -->
      <div class="stats-grid" style="grid-template-columns: repeat(4, 1fr); margin-bottom: 24px;">
        <div class="stat-card blue" style="cursor:pointer;" onclick="setDriverStatusFilter('all')">
          <div class="stat-card-header">
            <div class="stat-card-icon"><i class="ri-steering-2-fill"></i></div>
          </div>
          <div class="stat-card-value">\${(mockData.drivers || []).length}</div>
          <div class="stat-card-label">إجمالي الكباتن المسجلين</div>
        </div>
        <div class="stat-card green" style="cursor:pointer;" onclick="setDriverStatusFilter('verified')">
          <div class="stat-card-header">
            <div class="stat-card-icon"><i class="ri-check-double-fill"></i></div>
          </div>
          <div class="stat-card-value">\${verifiedCount}</div>
          <div class="stat-card-label">سائقين معتمدين</div>
        </div>
        <div class="stat-card orange" style="cursor:pointer;" onclick="setDriverStatusFilter('submitted')">
          <div class="stat-card-header">
            <div class="stat-card-icon"><i class="ri-time-fill"></i></div>
          </div>
          <div class="stat-card-value">\${submittedCount}</div>
          <div class="stat-card-label">بانتظار الاعتماد والتوثيق</div>
        </div>
        <div class="stat-card red" style="cursor:pointer;" onclick="setDriverStatusFilter('rejected')">
          <div class="stat-card-header">
            <div class="stat-card-icon"><i class="ri-close-circle-fill"></i></div>
          </div>
          <div class="stat-card-value">\${rejectedCount}</div>
          <div class="stat-card-label">سائقين مرفوضين</div>
        </div>
      </div>

      <!-- Filter Tabs -->
      <div style="display:flex;gap:8px;margin-bottom:16px;flex-wrap:wrap;">
        <button class="btn \${driverStatusFilter === 'all' ? 'btn-primary' : 'btn-outline'} btn-sm" onclick="setDriverStatusFilter('all')">
          <i class="ri-list-check"></i> الكل (\${(mockData.drivers || []).length})
        </button>
        <button class="btn \${driverStatusFilter === 'verified' ? 'btn-success' : 'btn-outline'} btn-sm" style="\${driverStatusFilter === 'verified' ? 'background:var(--success);' : ''}" onclick="setDriverStatusFilter('verified')">
          <i class="ri-checkbox-circle-line"></i> معتمدين (\${verifiedCount})
        </button>
        <button class="btn \${driverStatusFilter === 'submitted' ? 'btn-primary' : 'btn-outline'} btn-sm" style="\${driverStatusFilter === 'submitted' ? 'background:var(--warning);border-color:var(--warning);' : ''}" onclick="setDriverStatusFilter('submitted')">
          <i class="ri-time-line"></i> بانتظار الاعتماد (\${submittedCount})
        </button>
        <button class="btn \${driverStatusFilter === 'rejected' ? 'btn-outline' : 'btn-outline'} btn-sm" style="\${driverStatusFilter === 'rejected' ? 'color:var(--error);border-color:var(--error);background:#fee2e2;' : ''}" onclick="setDriverStatusFilter('rejected')">
          <i class="ri-close-circle-line"></i> مرفوضين (\${rejectedCount})
        </button>
        <button class="btn \${driverStatusFilter === 'unregistered' ? 'btn-outline' : 'btn-outline'} btn-sm" style="\${driverStatusFilter === 'unregistered' ? 'background:var(--bg-secondary);font-weight:700;' : ''}" onclick="setDriverStatusFilter('unregistered')">
          <i class="ri-draft-line"></i> غير مسجلين / مسودة (\${unregisteredCount})
        </button>
      </div>

      <!-- Drivers Table -->
      <div class="card">
        <div class="card-header" style="display:flex;justify-content:space-between;align-items:center;">
          <h3><i class="ri-steering-2-fill text-blue" style="margin-left:8px;"></i> قائمة الكباتن والسائقين</h3>
          <div style="display:flex;gap:10px;align-items:center;">
            <span class="text-light" style="font-size:13px;">\${filteredDrivers.length} كابتن</span>
            <button class="btn btn-primary btn-sm" onclick="showAddUserModal('driver')"><i class="ri-user-add-line"></i> إضافة سائق جديد</button>
            <button class="btn btn-outline btn-sm" onclick="exportDriversCSV()"><i class="ri-download-2-line"></i> تصدير تقرير</button>
          </div>
        </div>
        <div class="card-body" style="padding:0;">
          <table class="data-table">
            <thead>
              <tr>
                <th>الكود</th>
                <th>الكابتن</th>
                <th>الهاتف</th>
                <th>المركبة</th>
                <th>اللوحة</th>
                <th>التقييم</th>
                <th>الرحلات</th>
                <th>الحالة</th>
                <th>متصل</th>
                <th>إجراء</th>
              </tr>
            </thead>
            <tbody>
              \${paginatedDrivers.length === 0 ? \`<tr><td colspan="10" style="text-align:center;padding:32px;color:var(--text-light);">لا يوجد كباتن مسجلون يطابقون خيارات الفرز المحددة</td></tr>\` : ''}
              \${paginatedDrivers.map(driver => \`
                <tr>
                  <td><span class="font-outfit fw-700" style="color:var(--medium-blue);cursor:pointer;" onclick="viewUserProfile('\${driver.uid}', 'driver')" title="عرض الملف الشخصي">\${driver.id}</span></td>
                  <td>
                    <div class="user-cell" style="cursor:pointer;" onclick="viewUserProfile('\${driver.uid}', 'driver')" title="عرض ملف الكابتن \${driver.name}">
                      <div class="user-avatar-placeholder">\${driver.avatar || 'ك'}</div>
                      <div>
                        <div class="user-name" style="color:var(--medium-blue);font-weight:700;text-decoration:underline;">\${driver.name}</div>
                        <div class="user-sub">انضم \${driver.joinDate}</div>
                      </div>
                    </div>
                  </td>
                  <td><span style="font-size:12px;font-weight:600;direction:ltr;display:inline-block;">\${driver.phone}</span></td>
                  <td>
                    \${driver.vehicleName ? \`
                      <div class="vehicle-badge">
                        <i class="\${getVehicleIcon(driver.vehicleType)}"></i>
                        \${driver.vehicleName}
                      </div>
                    \` : '<span style="color:var(--text-light);font-size:12px;">—</span>'}
                  </td>
                  <td>
                    \${driver.licensePlate ? \`<span class="font-outfit fw-700" style="font-size:12px;">\${driver.licensePlate}</span>\` : '—'}
                  </td>
                  <td>
                    \${(driver.ratingCount && driver.ratingCount > 0) ? \`
                      <div class="rating" title="متوسط التقييمات: \${driver.rating} من \${driver.ratingCount} تقييم" style="white-space:nowrap; display:inline-flex; align-items:center; gap:4px; direction:rtl; cursor:pointer;" onclick="viewUserProfile('\${driver.uid}', 'driver')">
                        <i class="ri-star-fill" style="color:var(--warning);"></i>
                        <span style="font-weight:700;">\${driver.rating}</span>
                        <span style="font-size:11px; color:var(--text-light); white-space:nowrap;">(\${driver.ratingCount} تقييم)</span>
                      </div>
                    \` : \`
                      <div class="rating-empty" title="لم يتلق هذا الكابتن أي تقييمات حتى الآن" style="white-space:nowrap; display:inline-flex; align-items:center; gap:4px; color:var(--text-light);">
                        <i class="ri-star-line" style="color:var(--text-light); font-size:14px;"></i>
                        <span style="font-size:11px; font-weight:600; color:var(--text-light);">جديد (بدون تقييم)</span>
                      </div>
                    \`}
                  </td>
                  <td><span class="font-outfit fw-700" style="white-space:nowrap;">\${driver.totalTrips} رحلة</span></td>
                  <td>
                    <span class="status-badge \${driver.status}">
                      <span class="status-dot"></span>
                      \${driver.statusAr}
                    </span>
                  </td>
                  <td>
                    \${driver.isOnline 
                      ? '<span class="status-badge completed"><span class="status-dot"></span> متصل</span>'
                      : '<span style="color:var(--text-light);font-size:12px;">غير متصل</span>'
                    }
                  </td>
                  <td>
                    <div style="display:flex;gap:4px;align-items:center;">
                      <button class="btn btn-primary btn-sm" onclick="viewUserProfile('\${driver.uid}', 'driver')" title="فتح الملف الشخصي الكامل">
                        <i class="ri-user-search-line"></i> الملف
                      </button>
                      <button class="btn btn-outline btn-sm" onclick="reviewDriverDocs('\${driver.uid}')" title="مراجعة المستندات والوثائق">
                        <i class="ri-file-search-line"></i> وثائق
                      </button>
                      <button class="btn btn-outline btn-sm" onclick="showEditUserModal('\${driver.uid}', 'driver')">
                        <i class="ri-edit-line"></i> تعديل
                      </button>
                      <button class="btn btn-outline btn-sm" onclick="adjustWalletPrompt('\${driver.uid}', 'driver')">
                        <i class="ri-wallet-3-line"></i> شحن
                      </button>
                      \${driver.status === 'verified' ? \`
                        <button class="btn btn-outline btn-sm" style="color:var(--error);border-color:var(--error);" onclick="modifyUserStatus('\${driver.uid}', 'suspend', 'driver')">
                          <i class="ri-lock-line"></i> تعليق
                        </button>
                      \` : \`
                        <button class="btn btn-success btn-sm" style="background:var(--success);" onclick="modifyUserStatus('\${driver.uid}', 'verify', 'driver')">
                          <i class="ri-lock-unlock-line"></i> تفعيل
                        </button>
                      \`}
                      <button class="btn btn-outline btn-sm" style="color:var(--error);border-color:var(--error);" onclick="modifyUserStatus('\${driver.uid}', 'ban', 'driver')">
                        <i class="ri-user-unfollow-line"></i> حظر
                      </button>
                      <button class="btn btn-outline btn-sm" style="color:var(--error);border-color:var(--error);" onclick="deleteUserPrompt('\${driver.uid}', 'driver')">
                        <i class="ri-delete-bin-line"></i> حذف
                      </button>
                    </div>
                  </td>
                </tr>
              \`).join('')}
            </tbody>
          </table>
          <div style="display:flex;justify-content:space-between;align-items:center;padding:16px;border-top:1px solid var(--border-color);font-size:13px;">
            <div style="color:var(--text-secondary);">عرض \${totalItems > 0 ? startIndex + 1 : 0} - \${endIndex} من أصل \${totalItems} كابتن</div>
            <div style="display:flex;gap:6px;align-items:center;">
              <button class="btn btn-outline btn-sm" style="padding:4px 10px;" \${safePage === 1 ? 'disabled style="opacity:0.5;pointer-events:none;"' : ''} onclick="changePage('drivers', \${safePage - 1})">السابق</button>
              <span style="font-weight:700;">صفحة \${safePage} من \${totalPages}</span>
              <button class="btn btn-outline btn-sm" style="padding:4px 10px;" \${safePage === totalPages ? 'disabled style="opacity:0.5;pointer-events:none;"' : ''} onclick="changePage('drivers', \${safePage + 1})">التالي</button>
            </div>
          </div>
        </div>
      </div>
    </div>
  \`;
}
`;

replaceBlock('function renderDrivers()', 'async function sendPushNotificationBackend', renderDriversNewCode);

// 7. Replace renderPassengers
const renderPassengersNewCode = `// ---- PASSENGERS ----
function renderPassengers() {
  const q = (searchQuery || '').toLowerCase().trim();
  const filteredPassengers = (mockData.passengers || []).filter(p => {
    if (!q) return true;
    return (p.id || '').toString().toLowerCase().includes(q) ||
           (p.uid || '').toString().toLowerCase().includes(q) ||
           (p.name || '').toString().toLowerCase().includes(q) ||
           (p.phone || '').toString().includes(q) ||
           (p.email || '').toString().toLowerCase().includes(q);
  });

  const page = currentPages['passengers'] || 1;
  const totalItems = filteredPassengers.length;
  const totalPages = Math.max(1, Math.ceil(totalItems / itemsPerPage));
  const safePage = Math.min(page, totalPages);
  const startIndex = (safePage - 1) * itemsPerPage;
  const endIndex = Math.min(startIndex + itemsPerPage, totalItems);
  const paginatedPassengers = filteredPassengers.slice(startIndex, endIndex);

  return \`
    <div class="page-section">
      <!-- Stats Overview -->
      <div class="stats-grid" style="grid-template-columns: repeat(3, 1fr); margin-bottom: 24px;">
        <div class="stat-card blue">
          <div class="stat-card-header">
            <div class="stat-card-icon"><i class="ri-group-fill"></i></div>
          </div>
          <div class="stat-card-value">\${(mockData.passengers || []).length}</div>
          <div class="stat-card-label">إجمالي الركاب المسجلين</div>
        </div>
        <div class="stat-card green">
          <div class="stat-card-header">
            <div class="stat-card-icon"><i class="ri-user-follow-fill"></i></div>
          </div>
          <div class="stat-card-value">\${(mockData.passengers || []).filter(p => p.status === 'active').length}</div>
          <div class="stat-card-label">ركاب نشطين</div>
        </div>
        <div class="stat-card orange">
          <div class="stat-card-header">
            <div class="stat-card-icon"><i class="ri-money-pound-circle-fill"></i></div>
          </div>
          <div class="stat-card-value">\${((mockData.passengers || []).reduce((sum, p) => sum + (p.totalSpent || 0), 0)).toLocaleString()} ج.م</div>
          <div class="stat-card-label">إجمالي الإنفاق للرحلات</div>
        </div>
      </div>

      <!-- Passengers Table -->
      <div class="card">
        <div class="card-header" style="display:flex;justify-content:space-between;align-items:center;">
          <h3><i class="ri-group-fill text-blue" style="margin-left:8px;"></i> جميع الركاب والعملاء</h3>
          <div style="display:flex;gap:10px;align-items:center;">
            <span class="text-light" style="font-size:13px;">\${filteredPassengers.length} راكب</span>
            <button class="btn btn-primary btn-sm" onclick="showAddUserModal('rider')"><i class="ri-user-add-line"></i> إضافة راكب جديد</button>
            <button class="btn btn-outline btn-sm" onclick="exportPassengersCSV()"><i class="ri-download-2-line"></i> تصدير تقرير</button>
          </div>
        </div>
        <div class="card-body" style="padding:0;">
          <table class="data-table">
            <thead>
              <tr>
                <th>الكود</th>
                <th>الراكب</th>
                <th>الهاتف</th>
                <th>التقييم</th>
                <th>الرحلات</th>
                <th>تاريخ الانضمام</th>
                <th>الحالة</th>
                <th>إجراء</th>
              </tr>
            </thead>
            <tbody>
              \${paginatedPassengers.length === 0 ? \`<tr><td colspan="8" style="text-align:center;padding:32px;color:var(--text-light);">لا يوجد ركاب مسجلون حالياً</td></tr>\` : ''}
              \${paginatedPassengers.map(p => \`
                <tr>
                  <td><span class="font-outfit fw-700" style="color:var(--medium-blue);cursor:pointer;" onclick="viewUserProfile('\${p.uid}', 'rider')" title="عرض الملف الشخصي">\${p.id}</span></td>
                  <td>
                    <div class="user-cell" style="cursor:pointer;" onclick="viewUserProfile('\${p.uid}', 'rider')" title="عرض ملف الراكب \${p.name}">
                      <div class="user-avatar-placeholder">\${p.avatar || 'ر'}</div>
                      <div>
                        <div class="user-name" style="color:var(--medium-blue);font-weight:700;text-decoration:underline;">\${p.name}</div>
                        <div class="user-sub">\${p.email || '—'}</div>
                      </div>
                    </div>
                  </td>
                  <td><span style="font-size:12px;font-weight:600;direction:ltr;display:inline-block;">\${p.phone}</span></td>
                  <td>
                    \${(p.ratingCount && p.ratingCount > 0) ? \`
                      <div class="rating" title="متوسط التقييمات: \${p.rating} من \${p.ratingCount} تقييم" style="white-space:nowrap; display:inline-flex; align-items:center; gap:4px; direction:rtl; cursor:pointer;" onclick="viewUserProfile('\${p.uid}', 'rider')">
                        <i class="ri-star-fill" style="color:var(--warning);"></i>
                        <span style="font-weight:700;">\${p.rating}</span>
                        <span style="font-size:11px; color:var(--text-light); white-space:nowrap;">(\${p.ratingCount} تقييم)</span>
                      </div>
                    \` : \`
                      <div class="rating-empty" title="لم يتلق هذا الراكب أي تقييمات حتى الآن" style="white-space:nowrap; display:inline-flex; align-items:center; gap:4px; color:var(--text-light);">
                        <i class="ri-star-line" style="color:var(--text-light); font-size:14px;"></i>
                        <span style="font-size:11px; font-weight:600; color:var(--text-light);">جديد (بدون تقييم)</span>
                      </div>
                    \`}
                  </td>
                  <td><span class="font-outfit fw-700" style="white-space:nowrap;">\${p.totalTrips} رحلة</span></td>
                  <td><span style="font-size:12px;color:var(--text-light);font-weight:600;">\${p.joinDate}</span></td>
                  <td>
                    <span class="status-badge \${getStatusClass(p.status)}">
                      <span class="status-dot"></span>
                      \${p.statusAr}
                    </span>
                  </td>
                  <td>
                    <div style="display:flex;gap:4px;align-items:center;">
                      <button class="btn btn-primary btn-sm" onclick="viewUserProfile('\${p.uid}', 'rider')" title="فتح الملف الشخصي الكامل">
                        <i class="ri-user-search-line"></i> الملف
                      </button>
                      <button class="btn btn-outline btn-sm" onclick="showEditUserModal('\${p.uid}', 'rider')">
                        <i class="ri-edit-line"></i> تعديل
                      </button>
                      <button class="btn btn-outline btn-sm" onclick="adjustWalletPrompt('\${p.uid}', 'rider')">
                        <i class="ri-wallet-3-line"></i> شحن
                      </button>
                      \${p.status === 'active' ? \`
                        <button class="btn btn-outline btn-sm" style="color:var(--error);border-color:var(--error);" onclick="modifyUserStatus('\${p.uid}', 'suspend', 'rider')">
                          <i class="ri-lock-line"></i> تعليق
                        </button>
                      \` : \`
                        <button class="btn btn-success btn-sm" style="background:var(--success);" onclick="modifyUserStatus('\${p.uid}', 'activate', 'rider')">
                          <i class="ri-lock-unlock-line"></i> تفعيل
                        </button>
                      \`}
                      <button class="btn btn-outline btn-sm" style="color:var(--error);border-color:var(--error);" onclick="modifyUserStatus('\${p.uid}', 'ban', 'rider')">
                        <i class="ri-user-unfollow-line"></i> حظر
                      </button>
                      <button class="btn btn-outline btn-sm" style="color:var(--error);border-color:var(--error);" onclick="deleteUserPrompt('\${p.uid}', 'rider')">
                        <i class="ri-delete-bin-line"></i> حذف
                      </button>
                    </div>
                  </td>
                </tr>
              \`).join('')}
            </tbody>
          </table>
          <div style="display:flex;justify-content:space-between;align-items:center;padding:16px;border-top:1px solid var(--border-color);font-size:13px;">
            <div style="color:var(--text-secondary);">عرض \${totalItems > 0 ? startIndex + 1 : 0} - \${endIndex} من أصل \${totalItems} راكب</div>
            <div style="display:flex;gap:6px;align-items:center;">
              <button class="btn btn-outline btn-sm" style="padding:4px 10px;" \${safePage === 1 ? 'disabled style="opacity:0.5;pointer-events:none;"' : ''} onclick="changePage('passengers', \${safePage - 1})">السابق</button>
              <span style="font-weight:700;">صفحة \${safePage} من \${totalPages}</span>
              <button class="btn btn-outline btn-sm" style="padding:4px 10px;" \${safePage === totalPages ? 'disabled style="opacity:0.5;pointer-events:none;"' : ''} onclick="changePage('passengers', \${safePage + 1})">التالي</button>
            </div>
          </div>
        </div>
      </div>
    </div>
  \`;
}
`;

replaceBlock('function renderPassengers()', 'function showAddUserModal', renderPassengersNewCode);

// 8. Replace initSupabaseSync
const newInitSupabaseSyncCode = `let syncDebounceTimer = null;
let globalUsersMap = {};

function initSupabaseSync() {
  if (!supabaseClient) {
    console.warn("Supabase SDK is not loaded. Operating in local mode.");
    return;
  }

  const runBulkSync = async () => {
    try {
      console.log('[SupabaseSync] Running ultra-fast parallel data synchronization...');
      const [usersRes, driversRes, vehiclesRes, ridesRes, ratingsRes, settingsRes, passengersRes] = await Promise.all([
        supabaseClient.from('users').select('*'),
        supabaseClient.from('drivers').select('*'),
        supabaseClient.from('vehicles').select('*'),
        supabaseClient.from('ride_requests').select('*').order('created_at', { ascending: false }),
        supabaseClient.from('ratings').select('*').order('created_at', { ascending: false }),
        supabaseClient.from('app_settings').select('*').eq('id', 'default').maybeSingle().catch(() => ({ data: null })),
        supabaseClient.from('passengers').select('*').catch(() => ({ data: [] }))
      ]);

      const usersList = usersRes.data || [];
      const driversList = driversRes.data || [];
      const vehiclesList = vehiclesRes.data || [];
      const ridesList = ridesRes.data || [];
      const ratingsList = ratingsRes.data || [];
      const settingsData = settingsRes?.data;
      const passengersList = passengersRes?.data || [];

      // 1. Index users
      const usersMap = {};
      usersList.forEach(u => { usersMap[u.id] = u; });
      globalUsersMap = usersMap;

      // 2. Index passengers table
      const passengersDbMap = {};
      passengersList.forEach(p => { passengersDbMap[p.id] = p; });

      // 3. Index vehicles by driver_id and by vehicle id
      const vehiclesByDriver = {};
      const vehiclesById = {};
      vehiclesList.forEach(v => {
        vehiclesById[v.id] = v;
        if (v.driver_id) vehiclesByDriver[v.driver_id] = v;
      });

      // 4. Index ratings
      const riderRatingsMap = {}, riderRatingsCountMap = {};
      const driverRatingsMap = {}, driverRatingsCountMap = {};
      const ratingsByReceiver = {};

      ratingsList.forEach(r => {
        const receiverId = r.receiver_id || r.to_user_id;
        if (receiverId) {
          if (!ratingsByReceiver[receiverId]) ratingsByReceiver[receiverId] = [];
          ratingsByReceiver[receiverId].push(r);

          const starVal = parseFloat(r.rating) || 0;
          const role = ((r.receiver_role || r.role || '').toLowerCase() === 'driver') ? 'driver' : 'rider';
          if (role === 'driver') {
            driverRatingsMap[receiverId] = (driverRatingsMap[receiverId] || 0) + starVal;
            driverRatingsCountMap[receiverId] = (driverRatingsCountMap[receiverId] || 0) + 1;
          } else {
            riderRatingsMap[receiverId] = (riderRatingsMap[receiverId] || 0) + starVal;
            riderRatingsCountMap[receiverId] = (riderRatingsCountMap[receiverId] || 0) + 1;
          }
        }
      });

      allSystemRatings = ratingsList;

      // 5. Index completed trips per driver & passenger
      const driverTripsCountMap = {};
      const passengerTripsCountMap = {};
      const passengerSpentMap = {};

      ridesList.forEach(req => {
        const dId = req.driver_id || req.driverId;
        const pId = req.passenger_id || req.passengerId;
        const st = (req.status || '').toLowerCase();
        const fare = parseFloat(req.offered_fare || req.offeredFare || 0);

        if (dId) {
          if (st === 'completed' || st === 'finished') {
            driverTripsCountMap[dId] = (driverTripsCountMap[dId] || 0) + 1;
          }
        }
        if (pId) {
          if (st === 'completed' || st === 'finished') {
            passengerTripsCountMap[pId] = (passengerTripsCountMap[pId] || 0) + 1;
            passengerSpentMap[pId] = (passengerSpentMap[pId] || 0) + fare;
          }
        }
      });

      // 6. Build Drivers List
      const fullDrivers = [];
      const seenDriverIds = new Set();

      driversList.forEach(drv => {
        seenDriverIds.add(drv.id);
        const userObj = usersMap[drv.id] || {};
        const vehicleObj = (drv.vehicle_id && vehiclesById[drv.vehicle_id]) || vehiclesByDriver[drv.id] || {};

        const realTrips = Math.max(
          driverTripsCountMap[drv.id] || 0,
          parseInt(drv.total_trips || drv.completed_trips || userObj.total_trips || 0)
        );

        let avgRating = 0;
        let ratingCount = driverRatingsCountMap[drv.id] || 0;
        if (ratingCount > 0) {
          avgRating = parseFloat((driverRatingsMap[drv.id] / ratingCount).toFixed(1));
        } else {
          const dbRatingCount = parseInt(drv.rating_count || drv.total_ratings || userObj.rating_count || 0);
          const dbRating = drv.rating || userObj.rating;
          if (dbRatingCount > 0 && dbRating) {
            avgRating = parseFloat(parseFloat(dbRating).toFixed(1));
            ratingCount = dbRatingCount;
          }
        }
        const ratingDisplay = ratingCount > 0 ? avgRating.toFixed(1) : 'جديد (بدون تقييم)';

        let statusAr = 'غير مسجل';
        const stVal = drv.verification_status || 'unregistered';
        if (stVal === 'verified') statusAr = 'معتمد';
        else if (stVal === 'submitted') statusAr = 'قيد المراجعة';
        else if (stVal === 'rejected') statusAr = 'مرفوض';

        let driverName = userObj.name || drv.name;
        if (!driverName || driverName === 'مستخدم جديد' || driverName === 'سائق جديد' || driverName.trim() === '') {
          driverName = userObj.phone_number || drv.phone || ('كابتن ' + drv.id.substring(0, 6));
        }

        const dateObj = new Date(drv.created_at || drv.updated_at || userObj.created_at || Date.now());

        fullDrivers.push({
          id: 'DRV_' + drv.id.substring(0, 6).toUpperCase(),
          uid: drv.id,
          name: driverName,
          phone: userObj.phone_number || drv.phone || '—',
          email: userObj.email || drv.email || '—',
          address: drv.address || userObj.address || '—',
          rating: ratingDisplay,
          ratingNum: avgRating,
          ratingCount: ratingCount,
          vehicleType: vehicleObj.vehicle_category || vehicleObj.type || drv.vehicle_type || 'car',
          vehicleName: vehicleObj.model || drv.vehicle_name || 'مركبة',
          vehicleColor: vehicleObj.color || 'فضي',
          licensePlate: vehicleObj.number_plate || '—',
          status: stVal,
          statusAr: statusAr,
          rejectionReason: drv.rejection_reason || '',
          totalTrips: realTrips,
          earnings: parseFloat(drv.total_earnings || userObj.wallet_balance || 0),
          isOnline: drv.is_online || false,
          joinDate: dateObj.toLocaleDateString('ar-EG'),
          avatar: driverName.charAt(0).toUpperCase(),
          nationalIdUrl: drv.national_id_url || '',
          nationalIdBackUrl: drv.national_id_back_url || '',
          licenseUrl: drv.license_url || '',
          licenseBackUrl: drv.license_back_url || '',
          vehicleFrontUrl: drv.vehicle_front_url || '',
          vehicleBackUrl: drv.vehicle_back_url || '',
          vehicleLicenseUrl: drv.vehicle_license_url || '',
          idCardFrontUrl: drv.national_id_url || '',
          idCardBackUrl: drv.national_id_back_url || '',
          driverLicenseFrontUrl: drv.license_url || '',
          driverLicenseBackUrl: drv.license_back_url || '',
          vehicleLicenseFrontUrl: drv.vehicle_front_url || '',
          vehicleLicenseBackUrl: drv.vehicle_back_url || '',
          vehicleImages: vehicleObj.images || []
        });
      });

      // Also include users who have role = 'driver' but no row in drivers table yet
      usersList.forEach(u => {
        if (u.role === 'driver' && !seenDriverIds.has(u.id)) {
          const realTrips = driverTripsCountMap[u.id] || parseInt(u.total_trips || 0);
          const ratingCount = driverRatingsCountMap[u.id] || parseInt(u.rating_count || 0);
          const avgRating = ratingCount > 0 ? parseFloat((driverRatingsMap[u.id] / ratingCount).toFixed(1)) : (u.rating ? parseFloat(u.rating) : 0);
          const ratingDisplay = ratingCount > 0 ? avgRating.toFixed(1) : 'جديد (بدون تقييم)';
          const vObj = vehiclesByDriver[u.id] || {};
          const dName = u.name || u.phone_number || ('كابتن ' + u.id.substring(0, 6));

          fullDrivers.push({
            id: 'DRV_' + u.id.substring(0, 6).toUpperCase(),
            uid: u.id,
            name: dName,
            phone: u.phone_number || '—',
            email: u.email || '—',
            address: u.address || '—',
            rating: ratingDisplay,
            ratingNum: avgRating,
            ratingCount: ratingCount,
            vehicleType: vObj.vehicle_category || vObj.type || 'car',
            vehicleName: vObj.model || 'مركبة',
            vehicleColor: vObj.color || 'فضي',
            licensePlate: vObj.number_plate || '—',
            status: 'unregistered',
            statusAr: 'غير مسجل',
            rejectionReason: '',
            totalTrips: realTrips,
            earnings: parseFloat(u.wallet_balance || 0),
            isOnline: false,
            joinDate: new Date(u.created_at || Date.now()).toLocaleDateString('ar-EG'),
            avatar: dName.charAt(0).toUpperCase(),
            nationalIdUrl: '',
            nationalIdBackUrl: '',
            licenseUrl: '',
            licenseBackUrl: '',
            vehicleFrontUrl: '',
            vehicleBackUrl: '',
            vehicleLicenseUrl: '',
            idCardFrontUrl: '',
            idCardBackUrl: '',
            driverLicenseFrontUrl: '',
            driverLicenseBackUrl: '',
            vehicleLicenseFrontUrl: '',
            vehicleLicenseBackUrl: '',
            vehicleImages: vObj.images || []
          });
        }
      });

      mockData.drivers = fullDrivers;
      mockData.stats.activeDrivers = fullDrivers.filter(d => d.isOnline).length;

      // 7. Build Passengers List
      const fullPassengers = [];
      const seenPassengerIds = new Set();

      usersList.forEach(data => {
        const pRecord = passengersDbMap[data.id] || {};
        let cleanName = data.name || data.full_name;
        if (!cleanName || cleanName === 'مستخدم هاتف' || cleanName === 'مستخدم جديد' || cleanName.trim() === '') {
          if (pRecord.name && pRecord.name !== 'مستخدم هاتف' && pRecord.name !== 'مستخدم جديد' && pRecord.name.trim() !== '') {
            cleanName = pRecord.name;
          } else {
            cleanName = data.phone_number || data.phone || pRecord.phone || ('عميل ' + data.id.substring(0, 6));
          }
        }
        data.cleanName = cleanName;

        if (data.role === 'rider' || data.role === 'passenger' || !data.role) {
          seenPassengerIds.add(data.id);
          const dateObj = new Date(data.created_at || Date.now());
          const ratingCount = riderRatingsCountMap[data.id] || parseInt(data.rating_count || pRecord.rating_count || 0);
          const avgRating = ratingCount > 0 
            ? parseFloat((riderRatingsMap[data.id] / ratingCount).toFixed(1))
            : (data.rating ? parseFloat(parseFloat(data.rating).toFixed(1)) : 0);

          const ratingDisplay = ratingCount > 0 ? avgRating.toFixed(1) : 'جديد (بدون تقييم)';
          const totalTrips = Math.max(passengerTripsCountMap[data.id] || 0, parseInt(data.total_trips || pRecord.total_trips || 0));
          const totalSpent = passengerSpentMap[data.id] || 0;

          fullPassengers.push({
            id: 'PAS_' + data.id.substring(0, 6).toUpperCase(),
            uid: data.id,
            name: cleanName,
            phone: data.phone_number || data.phone || pRecord.phone || '—',
            email: data.email || pRecord.email || '—',
            address: data.address || pRecord.address || '—',
            rating: ratingDisplay,
            ratingNum: avgRating,
            ratingCount: ratingCount,
            totalTrips: totalTrips,
            totalSpent: totalSpent,
            joinDate: dateObj.toLocaleDateString('ar-EG'),
            status: data.status || 'active',
            statusAr: data.status === 'suspended' ? 'معلق' : (data.status === 'banned' ? 'محظور' : 'نشط'),
            lastTrip: '—',
            avatar: cleanName.charAt(0).toUpperCase(),
          });
        }
      });

      mockData.passengers = fullPassengers;
      mockData.stats.totalPassengers = fullPassengers.length;

      // 8. Build Trips List
      mockData.tripsDataMap = {};
      const fullTrips = [];
      let totalRevenue = 0;

      ridesList.forEach(data => {
        mockData.tripsDataMap[data.id] = data;
        const tripPrice = parseFloat(data.offered_fare || data.offeredFare || 0);
        const st = data.status || 'Pending';
        if (st.toLowerCase() === 'completed') totalRevenue += tripPrice;

        const dateObj = new Date(data.created_at || Date.now());
        const dateStr = \`\${dateObj.getHours()}:\${dateObj.getMinutes().toString().padStart(2, '0')}\`;
        const localeDate = dateObj.toLocaleDateString('ar-EG');

        const pId = data.passenger_id || data.passengerId;
        const dId = data.driver_id || data.driverId;
        const passengerObj = usersMap[pId] || passengersDbMap[pId] || {};
        const driverObj = usersMap[dId] || {};

        let rName = passengerObj.cleanName || passengerObj.name || passengerObj.full_name;
        if (!rName || rName === 'مستخدم هاتف' || rName === 'مستخدم جديد' || rName.trim() === '') {
          rName = passengerObj.phone_number || passengerObj.phone || (pId ? 'راكب (' + pId.substring(0, 6) + ')' : 'عميل');
        }

        let dName = '—';
        if (dId) {
          dName = driverObj.name || driverObj.full_name;
          if (!dName || dName === 'مستخدم جديد' || dName === 'سائق جديد' || dName.trim() === '') {
            dName = driverObj.phone_number || ('كابتن (' + dId.substring(0, 6) + ')');
          }
        }

        let statusArabic = 'جارية';
        if (st.toLowerCase() === 'completed') statusArabic = 'مكتملة';
        else if (st.toLowerCase() === 'cancelled') statusArabic = 'ملغاة';
        else if (st.toLowerCase() === 'pending') statusArabic = 'بانتظار سائق';
        else if (st.toLowerCase() === 'accepted') statusArabic = 'تم القبول';

        fullTrips.push({
          id: (data.id || '').substring(0, 8).toUpperCase(),
          requestId: data.id,
          date: \`\${localeDate}، \${dateStr}\`,
          createdAt: data.created_at,
          riderUid: pId,
          riderName: rName,
          riderPhone: passengerObj.phone_number || passengerObj.phone || '—',
          driverUid: dId,
          driverName: dName,
          from: data.pickup_address || data.pickupAddress || '—',
          to: data.destination_address || data.destinationAddress || '—',
          price: tripPrice,
          status: statusArabic,
          rawStatus: st,
          vehicle: data.vehicle_type === 'scooter' ? 'اسكوتر' : (data.vehicle_type === 'motorcycle' ? 'موتوسيكل' : 'عربية'),
          isDeliveryLocationConfirmed: data.is_delivery_location_confirmed || false,
        });
      });

      mockData.trips = fullTrips;
      mockData.stats.totalTrips = fullTrips.length;
      mockData.stats.totalRevenue = totalRevenue;

      // 9. Update Settings if returned
      if (settingsData) {
        mockData.settings = {
          defaultFareCar: parseFloat(settingsData.default_fare_car || 45),
          defaultFareScooter: parseFloat(settingsData.default_fare_scooter || 20),
          defaultFareMotorcycle: parseFloat(settingsData.default_fare_motorcycle || 15),
          commissionRate: parseFloat(settingsData.commission_rate || 10),
          minFare: parseFloat(settingsData.min_fare || 10),
          maxFare: parseFloat(settingsData.max_fare || 500),
          first_km_fare: parseFloat(settingsData.first_km_fare || 20),
          extra_km_fare: parseFloat(settingsData.extra_km_fare || 5),
          ac_km_fare: parseFloat(settingsData.ac_km_fare || 1),
          heat_hour_km_fare: parseFloat(settingsData.heat_hour_km_fare || 1),
          heat_start_hour: parseInt(settingsData.heat_start_hour || 11),
          heat_end_hour: parseInt(settingsData.heat_end_hour || 15),
          surge_enabled: settingsData.surge_enabled !== false,
          region_fares: Array.isArray(settingsData.region_fares) ? settingsData.region_fares : [
            { id: '1', name: 'القاهرة الكبرى', surcharge: 0, is_default: true },
            { id: '2', name: 'الإسكندرية (الساحل)', surcharge: 5, is_default: false }
          ]
        };
      }

      updatePendingBadge();

      // Render current page safely without disturbing active inputs
      if (document.activeElement && (document.activeElement.tagName === 'INPUT' || document.activeElement.tagName === 'TEXTAREA')) {
        // User is typing, skip intrusive DOM replace
      } else {
        renderPage(currentPage);
      }
      console.log('[SupabaseSync] Parallel sync complete! Drivers:', fullDrivers.length, '| Passengers:', fullPassengers.length, '| Trips:', fullTrips.length);
    } catch (err) {
      console.error('[SupabaseSync] Error during parallel sync:', err);
    }
  };

  // Debounced trigger for realtime updates
  const debouncedSync = () => {
    if (syncDebounceTimer) clearTimeout(syncDebounceTimer);
    syncDebounceTimer = setTimeout(runBulkSync, 300);
  };

  // Initial immediate sync
  runBulkSync();

  // Single consolidated realtime subscription
  try {
    supabaseClient.channel('admin_global_sync_channel')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'users' }, debouncedSync)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'drivers' }, debouncedSync)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'vehicles' }, debouncedSync)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'ride_requests' }, debouncedSync)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'ratings' }, debouncedSync)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'app_settings' }, debouncedSync)
      .subscribe();
  } catch (chanErr) {
    console.warn('[SupabaseSync] Realtime channel subscription warning:', chanErr);
  }
}
`;

replaceBlock('function initSupabaseSync()', '// ============================================', newInitSupabaseSyncCode);

// 9. Replace from changePage down to renderRatingsPage
const newProfilesSectionCode = `// ---- PAGINATION AND EXPORT HELPERS ----
function changePage(pageName, newPage) {
  if (newPage < 1) newPage = 1;
  currentPages[pageName] = newPage;
  renderPage(currentPage);
}

function downloadCSV(filename, data, headers) {
  let csv = '\\ufeff' + headers.join(',') + '\\n';
  data.forEach(row => {
    csv += row.map(val => \`"\${String(val).replace(/"/g, '""')}"\`).join(',') + '\\n';
  });
  
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
  const link = document.createElement('a');
  if (link.download !== undefined) {
    const url = URL.createObjectURL(blob);
    link.setAttribute('href', url);
    link.setAttribute('download', filename);
    link.style.visibility = 'hidden';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  }
}

function exportTripsCSV() {
  const headers = ['رقم الرحلة', 'التاريخ', 'الراكب', 'السائق', 'نقطة الانطلاق', 'الوجهة', 'السعر (ج.م)', 'المركبة', 'الحالة'];
  const data = mockData.trips.map(t => [t.id, t.date, t.riderName, t.driverName, t.from, t.to, t.price, t.vehicle, t.status]);
  downloadCSV('inRide_Trips_' + new Date().toISOString().slice(0,10) + '.csv', data, headers);
}

function exportDriversCSV() {
  const headers = ['الكود', 'الاسم', 'الهاتف', 'البريد', 'المركبة', 'اللوحة', 'التقييم', 'الرحلات', 'الأرباح', 'الحالة'];
  const data = mockData.drivers.map(d => [d.id, d.name, d.phone, d.email, d.vehicleName, d.licensePlate, d.rating, d.totalTrips, d.earnings, d.statusAr]);
  downloadCSV('inRide_Drivers_' + new Date().toISOString().slice(0,10) + '.csv', data, headers);
}

function exportPassengersCSV() {
  const headers = ['الكود', 'الاسم', 'الهاتف', 'البريد', 'التقييم', 'إجمالي الرحلات', 'إجمالي الإنفاق', 'تاريخ الانضمام', 'الحالة'];
  const data = mockData.passengers.map(p => [p.id, p.name, p.phone, p.email, p.rating, p.totalTrips, p.totalSpent, p.joinDate, p.statusAr]);
  downloadCSV('inRide_Passengers_' + new Date().toISOString().slice(0,10) + '.csv', data, headers);
}

// ============================================
// PROFILE PAGES AND SUPPORT CHAT FOR INDIVIDUAL USERS
// ============================================

// Initialize mock support message cache if needed
if (!mockData.supportChats) {
  mockData.supportChats = {};
}

function viewUserProfile(uid, role = 'rider') {
  if (!uid) return;
  activeProfileUid = uid;
  activeProfileRole = role;
  sessionStorage.setItem('admin_activeProfileUid', uid);
  sessionStorage.setItem('admin_activeProfileRole', role);
  navigateTo(role === 'driver' ? 'driver-profile' : 'passenger-profile');
  setTimeout(() => {
    loadProfileRatings(uid, role);
  }, 100);
}

function renderDriverProfile() {
  if (!activeProfileUid) {
    return \`<div style="padding:40px;text-align:center;color:var(--text-light);"><i class="ri-user-unfollow-line" style="font-size:36px;display:block;margin-bottom:8px;"></i>لم يتم تحديد كابتن لعرضه.</div>\`;
  }

  const targetUid = (activeProfileUid || '').toLowerCase();
  let driver = (mockData.drivers || []).find(d => 
    (d.uid && d.uid.toLowerCase() === targetUid) ||
    (d.id && d.id.toLowerCase() === targetUid)
  );

  if (!driver) {
    const userObj = (typeof globalUsersMap !== 'undefined' && globalUsersMap[activeProfileUid]) ||
                    (mockData.passengers || []).find(p => (p.uid && p.uid.toLowerCase() === targetUid));
    if (userObj) {
      const dName = userObj.name || userObj.cleanName || ('كابتن ' + activeProfileUid.substring(0, 6));
      driver = {
        id: 'DRV_' + activeProfileUid.substring(0, 6).toUpperCase(),
        uid: activeProfileUid,
        name: dName,
        phone: userObj.phone_number || userObj.phone || '—',
        email: userObj.email || '—',
        address: userObj.address || '—',
        rating: userObj.rating ? parseFloat(userObj.rating).toFixed(1) : '5.0',
        ratingCount: userObj.ratingCount || userObj.rating_count || 0,
        vehicleType: 'car',
        vehicleName: 'مركبة',
        vehicleColor: 'فضي',
        licensePlate: '—',
        status: userObj.status || 'verified',
        statusAr: userObj.status === 'suspended' ? 'معلق' : (userObj.status === 'banned' ? 'محظور' : 'معتمد'),
        totalTrips: userObj.totalTrips || 0,
        earnings: parseFloat(userObj.wallet_balance || userObj.walletBalance || 0),
        isOnline: false,
        joinDate: userObj.joinDate || '2026/01/10',
        avatar: dName.charAt(0).toUpperCase(),
        nationalIdUrl: '',
        nationalIdBackUrl: '',
        licenseUrl: '',
        licenseBackUrl: '',
        vehicleFrontUrl: '',
        vehicleBackUrl: '',
        vehicleLicenseUrl: '',
      };
    } else {
      driver = {
        id: 'DRV_' + activeProfileUid.substring(0, 6).toUpperCase(),
        uid: activeProfileUid,
        name: 'كابتن (' + activeProfileUid.substring(0, 8) + ')',
        phone: '—',
        email: '—',
        address: '—',
        rating: 'جديد (بدون تقييم)',
        ratingCount: 0,
        vehicleType: 'car',
        vehicleName: 'مركبة',
        vehicleColor: 'فضي',
        licensePlate: '—',
        status: 'submitted',
        statusAr: 'قيد المراجعة',
        totalTrips: 0,
        earnings: 0,
        isOnline: false,
        joinDate: '2026/01/10',
        avatar: 'ك',
        nationalIdUrl: '',
        nationalIdBackUrl: '',
        licenseUrl: '',
        licenseBackUrl: '',
        vehicleFrontUrl: '',
        vehicleBackUrl: '',
        vehicleLicenseUrl: '',
      };
    }
  }

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
              <h3><i class="ri-user-3-fill text-blue" style="margin-left:8px;"></i> بيانات الكابتن الشخصية</h3>
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
                  <div style="font-size:11px;color:var(--text-secondary);margin-bottom:4px;">العنوان المسجل</div>
                  <span style="font-weight:700;font-size:13px;">\${driver.address || '—'}</span>
                </div>
                <div style="background:var(--bg-primary);padding:12px;border-radius:var(--radius-md);">
                  <div style="font-size:11px;color:var(--text-secondary);margin-bottom:4px;">نوع وبيانات المركبة</div>
                  <span class="vehicle-badge" style="font-weight:700;font-size:13px;">
                    <i class="\${getVehicleIcon(driver.vehicleType)}"></i>
                    \${driver.vehicleName || 'مركبة'} (\${driver.licensePlate || '—'})
                  </span>
                </div>
                <div style="background:var(--bg-primary);padding:12px;border-radius:var(--radius-md);">
                  <div style="font-size:11px;color:var(--text-secondary);margin-bottom:4px;">التقييم العام المستلم</div>
                  \${(driver.ratingCount && driver.ratingCount > 0) ? \`
                    <div class="rating" style="font-size:14px;font-weight:800;color:var(--warning);display:flex;align-items:center;gap:4px;">
                      <i class="ri-star-fill"></i>
                      <span>\${driver.rating}</span>
                      <span style="font-size:11px;color:var(--text-light);font-weight:normal;">(\${driver.ratingCount} تقييم)</span>
                    </div>
                  \` : \`
                    <div style="font-size:12px;font-weight:700;color:var(--text-light);display:flex;align-items:center;gap:4px;">
                      <i class="ri-star-line" style="color:var(--text-light);"></i>
                      <span>جديد (بدون تقييم)</span>
                    </div>
                  \`}
                </div>
                <div style="background:var(--bg-primary);padding:12px;border-radius:var(--radius-md);">
                  <div style="font-size:11px;color:var(--text-secondary);margin-bottom:4px;">رصيد الأرباح والمحفظة</div>
                  <span style="font-weight:900;font-size:14px;color:var(--success);">\${(driver.earnings || 0).toLocaleString()} ج.م</span>
                </div>
              </div>

              <!-- Quick Actions -->
              <div style="display:flex;gap:10px;flex-wrap:wrap;border-top:1px solid var(--border-light);padding-top:16px;">
                <button class="btn btn-outline btn-sm" onclick="showEditUserModal('\${driver.uid}', 'driver')">
                  <i class="ri-edit-line"></i> تعديل البيانات الشخصية
                </button>
                <button class="btn btn-outline btn-sm" onclick="adjustWalletPrompt('\${driver.uid}', 'driver')">
                  <i class="ri-wallet-3-line"></i> شحن المحفظة
                </button>
                \${driver.status === 'verified' ? \`
                  <button class="btn btn-outline btn-sm" style="color:var(--error);border-color:var(--error);" onclick="modifyUserStatus('\${driver.uid}', 'suspend', 'driver'); setTimeout(() => viewUserProfile('\${driver.uid}', 'driver'), 500);">
                    <i class="ri-lock-line"></i> تعليق الحساب
                  </button>
                \` : \`
                  <button class="btn btn-success btn-sm" style="background:var(--success);" onclick="modifyUserStatus('\${driver.uid}', 'verify', 'driver'); setTimeout(() => viewUserProfile('\${driver.uid}', 'driver'), 500);">
                    <i class="ri-lock-unlock-line"></i> تفعيل واعتماد الحساب
                  </button>
                \`}
                <button class="btn btn-outline btn-sm" style="color:var(--error);border-color:var(--error);" onclick="modifyUserStatus('\${driver.uid}', 'ban', 'driver'); setTimeout(() => viewUserProfile('\${driver.uid}', 'driver'), 500);">
                  <i class="ri-user-unfollow-line"></i> حظر الكابتن
                </button>
                <button class="btn btn-outline btn-sm" style="color:var(--error);border-color:var(--error);" onclick="deleteUserPrompt('\${driver.uid}', 'driver')">
                  <i class="ri-delete-bin-line"></i> حذف الحساب نهائياً
                </button>
              </div>
            </div>
          </div>

          <!-- Documents -->
          <div class="card">
            <div class="card-header" style="display:flex;justify-content:space-between;align-items:center;">
              <h3><i class="ri-file-text-fill text-blue" style="margin-left:8px;"></i> المستندات والأوراق الثبوتية</h3>
              <span class="status-badge \${driver.status}">
                <span class="status-dot"></span> \${driver.statusAr}
              </span>
            </div>
            <div class="card-body">
              <div style="display:flex;flex-direction:column;gap:12px;">
                <div style="display:flex;justify-content:space-between;align-items:center;background:var(--bg-primary);padding:12px;border-radius:var(--radius-md);">
                  <span style="font-size:13px;font-weight:700;">الأوراق الرسمية المرفوعة (البطاقة، الرخص، صور المركبة)</span>
                  <button class="btn btn-primary btn-sm" onclick="reviewDriverDocs('\${driver.uid}')">
                    <i class="ri-file-search-line"></i> عرض ومراجعة المستندات
                  </button>
                </div>
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
                  <td><span class="font-outfit fw-700" style="color:var(--medium-blue);">\${trip.id}</span></td>
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

  const targetUid = (activeProfileUid || '').toLowerCase();
  let passenger = (mockData.passengers || []).find(p => 
    (p.uid && p.uid.toLowerCase() === targetUid) ||
    (p.id && p.id.toLowerCase() === targetUid)
  );

  if (!passenger) {
    const userObj = (typeof globalUsersMap !== 'undefined' && globalUsersMap[activeProfileUid]) ||
                    (mockData.drivers || []).find(d => (d.uid && d.uid.toLowerCase() === targetUid));
    if (userObj) {
      const pName = userObj.name || userObj.cleanName || ('راكب ' + activeProfileUid.substring(0, 6));
      passenger = {
        id: 'PAS_' + activeProfileUid.substring(0, 6).toUpperCase(),
        uid: activeProfileUid,
        name: pName,
        phone: userObj.phone_number || userObj.phone || '—',
        email: userObj.email || '—',
        address: userObj.address || '—',
        rating: userObj.rating ? parseFloat(userObj.rating).toFixed(1) : '5.0',
        ratingCount: userObj.ratingCount || userObj.rating_count || 0,
        totalTrips: userObj.totalTrips || 0,
        totalSpent: 0,
        joinDate: userObj.joinDate || '2026/01/10',
        status: userObj.status || 'active',
        statusAr: userObj.status === 'suspended' ? 'معلق' : (userObj.status === 'banned' ? 'محظور' : 'نشط'),
        lastTrip: '—',
        avatar: pName.charAt(0).toUpperCase(),
      };
    } else {
      passenger = {
        id: 'PAS_' + activeProfileUid.substring(0, 6).toUpperCase(),
        uid: activeProfileUid,
        name: 'راكب (' + activeProfileUid.substring(0, 8) + ')',
        phone: '—',
        email: '—',
        address: '—',
        rating: 'جديد (بدون تقييم)',
        ratingCount: 0,
        totalTrips: 0,
        totalSpent: 0,
        joinDate: '2026/01/10',
        status: 'active',
        statusAr: 'نشط',
        lastTrip: '—',
        avatar: 'ر',
      };
    }
  }

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
                  <span style="font-weight:900;font-size:14px;color:var(--medium-blue);">\${passenger.totalTrips} رحلة</span>
                </div>
                <div style="background:var(--bg-primary);padding:12px;border-radius:var(--radius-md);">
                  <div style="font-size:11px;color:var(--text-secondary);margin-bottom:4px;">التقييم العام المستلم</div>
                  \${(passenger.ratingCount && passenger.ratingCount > 0) ? \`
                    <div class="rating" style="font-size:14px;font-weight:800;color:var(--warning);display:flex;align-items:center;gap:4px;">
                      <i class="ri-star-fill"></i>
                      <span>\${passenger.rating}</span>
                      <span style="font-size:11px;color:var(--text-light);font-weight:normal;">(\${passenger.ratingCount} تقييم)</span>
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
                  <td><span class="font-outfit fw-700" style="color:var(--medium-blue);">\${trip.id}</span></td>
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

// ---- RATINGS & REVIEWS MODULE ----
async function loadProfileRatings(uid, role = 'rider') {
  const container = document.getElementById('profileRatingsContainer');
  if (!container || !uid) return;
  
  try {
    const { data: ratingsData, error } = await supabaseClient
      .from('ratings')
      .select('*')
      .or(\`receiver_id.eq.\${uid},to_user_id.eq.\${uid}\`)
      .order('created_at', { ascending: false });

    let list = (ratingsData && Array.isArray(ratingsData) && ratingsData.length > 0) ? ratingsData : [];
    
    // If not found in direct query, check allSystemRatings
    if (list.length === 0 && typeof allSystemRatings !== 'undefined' && Array.isArray(allSystemRatings)) {
      list = allSystemRatings.filter(r => (r.receiver_id === uid || r.to_user_id === uid));
    }

    // Resolve sender names if available
    const senderIds = list.map(r => r.sender_id || r.from_user_id).filter(Boolean);
    let sendersMap = {};
    if (senderIds.length > 0) {
      try {
        const { data: senders } = await supabaseClient
          .from('users')
          .select('id, name, phone_number')
          .in('id', senderIds);
        if (senders) {
          senders.forEach(s => { sendersMap[s.id] = s.name || s.phone_number; });
        }
      } catch (_) {}
    }

    const hasRatings = list.length > 0;
    const total = list.reduce((acc, r) => acc + (parseFloat(r.rating) || 0), 0);
    const avg = hasRatings ? (total / list.length).toFixed(1) : 'جديد (بدون تقييم)';

    // Count stars breakdown (5, 4, 3, 2, 1)
    const starCounts = { 5: 0, 4: 0, 3: 0, 2: 0, 1: 0 };
    list.forEach(r => {
      const s = Math.round(parseFloat(r.rating) || 5);
      if (starCounts[s] !== undefined) starCounts[s]++;
    });

    let html = \`
      <div style="display:flex;align-items:center;justify-content:space-between;background:var(--bg-primary);padding:16px;border-radius:var(--radius-md);margin-bottom:16px;border:1px solid var(--border-color);">
        <div>
          <span style="font-size:12px;color:var(--text-secondary);font-weight:700;">متوسط التقييم العام المستلم (\${role === 'driver' ? 'كابتن' : 'راكب'})</span>
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
          لا توجد تقييمات أو مراجعات مسجلة لهذا الحساب كـ \${role === 'driver' ? 'كابتن' : 'راكب'} حتى الآن
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
          <div style="padding:14px;background:var(--bg-primary);border:1px solid var(--border-color);border-radius:var(--radius-md);">
            <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px;">
              <div style="display:flex;align-items:center;gap:8px;">
                <span style="font-weight:700;font-size:13px;color:var(--text-primary);">\${senderName}</span>
                <span class="vehicle-badge" style="font-size:10px;padding:2px 8px;font-weight:700;">\${senderRole}</span>
              </div>
              <span style="font-size:11px;color:var(--text-light);direction:ltr;">\${dateStr}</span>
            </div>
            <div style="display:flex;align-items:center;gap:4px;margin-bottom:6px;">
              \${starsHtml}
              <span style="font-weight:700;font-size:12px;margin-right:6px;color:var(--warning);">\${starVal.toFixed(1)}</span>
            </div>
            <p style="font-size:12px;color:var(--text-secondary);margin:0;line-height:1.4;">\${commentText}</p>
          </div>
        \`;
      });
    }

    html += \`</div>\`;
    container.innerHTML = html;
  } catch (err) {
    console.error('Error loading ratings:', err);
    container.innerHTML = \`<div style="color:var(--error);padding:16px;text-align:center;">حدث خطأ أثناء تحميل التقييمات: \${err.message || err}</div>\`;
  }
}
`;

replaceBlock('// ---- PAGINATION AND EXPORT HELPERS ----', 'function renderRatingsPage()', newProfilesSectionCode);

const outputCode = lines.join('\n');
fs.writeFileSync(appJsPath, outputCode, 'utf8');

console.log('Successfully updated app.js! New lines:', outputCode.split('\n').length);
