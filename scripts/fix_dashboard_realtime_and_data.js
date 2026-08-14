const fs = require('fs');
const path = require('path');

const rootAppJsPath = path.join(__dirname, '..', 'app.js');
const adminAppJsPath = path.join(__dirname, '..', 'admin-dashboard', 'app.js');

let code = fs.readFileSync(rootAppJsPath, 'utf8');

// Find the entire block from 'function renderDriverProfile()' to '// ---- RATINGS & REVIEWS MODULE ----'
const startToken = 'function renderDriverProfile() {';
const endToken = '// ---- RATINGS & REVIEWS MODULE ----';

const sIdx = code.indexOf(startToken);
const eIdx = code.indexOf(endToken);

if (sIdx === -1 || eIdx === -1) {
  console.error('ERROR: Could not locate profile render block');
  process.exit(1);
}

const newProfilesBlock = `function renderDriverProfile() {
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
      return \`<div style="padding:48px;text-align:center;color:var(--text-light);background:var(--bg-card);border-radius:var(--radius-lg);margin:24px 0;"><i class="ri-error-warning-line" style="font-size:40px;display:block;margin-bottom:12px;color:var(--warning);"></i><h3 style="margin-bottom:8px;color:var(--text-primary);">لم يتم العثور على هذا الكابتن</h3><p style="font-size:13px;color:var(--text-secondary);">قد يكون الحساب غير مسجل أو تم حذفه من قاعدة البيانات.</p><button class="btn btn-primary btn-sm" onclick="navigateTo('drivers')" style="margin-top:16px;"><i class="ri-arrow-right-line"></i> العودة لقائمة السائقين</button></div>\`;
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
                  <span style="font-weight:900;font-size:14px;color:var(--medium-blue);">\${driver.totalTrips} رحلة</span>
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
      return \`<div style="padding:48px;text-align:center;color:var(--text-light);background:var(--bg-card);border-radius:var(--radius-lg);margin:24px 0;"><i class="ri-error-warning-line" style="font-size:40px;display:block;margin-bottom:12px;color:var(--warning);"></i><h3 style="margin-bottom:8px;color:var(--text-primary);">لم يتم العثور على هذا الراكب</h3><p style="font-size:13px;color:var(--text-secondary);">قد يكون الحساب غير مسجل أو تم حذفه من قاعدة البيانات.</p><button class="btn btn-primary btn-sm" onclick="navigateTo('passengers')" style="margin-top:16px;"><i class="ri-arrow-right-line"></i> العودة لقائمة الركاب</button></div>\`;
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

`;

code = code.substring(0, sIdx) + newProfilesBlock + code.substring(eIdx);

fs.writeFileSync(rootAppJsPath, code, 'utf8');
fs.writeFileSync(adminAppJsPath, code, 'utf8');
console.log('Successfully wrote cleanly structured renderDriverProfile and renderPassengerProfile!');
