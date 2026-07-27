/* ============================================
   inRide Admin Dashboard - Application Logic
   SPA Navigation, Real-Time Supabase Database, Charts, Interactions
   ============================================ */

// ============================================
// STATE AND CONFIGURATION (Real Supabase Database)
// ============================================
const SUPABASE_URL = 'https://fylruevfksmqnkykqkin.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5bHJ1ZXZma3NtcW5reWtxa2luIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ3NTY3NDYsImV4cCI6MjEwMDMzMjc0Nn0.u5NVng7fsptjQOnNlEYP7MzNDp8_ssN94xSxzg8VYi4';
let supabaseClient = null;
if (typeof window.supabase !== 'undefined') {
  supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
}

function showToast(message) {
  let toastContainer = document.getElementById('toastContainer');
  if (!toastContainer) {
    toastContainer = document.createElement('div');
    toastContainer.id = 'toastContainer';
    toastContainer.style.position = 'fixed';
    toastContainer.style.bottom = '20px';
    toastContainer.style.left = '20px'; // LTR, but we are RTL so maybe right=20px? Let's use right
    toastContainer.style.right = '20px';
    toastContainer.style.left = 'auto';
    toastContainer.style.zIndex = '9999';
    toastContainer.style.display = 'flex';
    toastContainer.style.flexDirection = 'column';
    toastContainer.style.gap = '10px';
    document.body.appendChild(toastContainer);
  }

  const toast = document.createElement('div');
  toast.style.background = 'var(--text-primary, #333)';
  toast.style.color = '#fff';
  toast.style.padding = '12px 20px';
  toast.style.borderRadius = '8px';
  toast.style.boxShadow = '0 4px 12px rgba(0,0,0,0.15)';
  toast.style.fontSize = '14px';
  toast.style.opacity = '0';
  toast.style.transform = 'translateY(20px)';
  toast.style.transition = 'all 0.3s ease';
  toast.textContent = message;

  toastContainer.appendChild(toast);

  // Animate in
  setTimeout(() => {
    toast.style.opacity = '1';
    toast.style.transform = 'translateY(0)';
  }, 10);

  // Remove after 3s
  setTimeout(() => {
    toast.style.opacity = '0';
    toast.style.transform = 'translateY(20px)';
    setTimeout(() => toast.remove(), 300);
  }, 3000);
}

const mockData = {
  // Real-time statistics populated from Firestore
  stats: {
    totalTrips: 3,
    activeDrivers: 2,
    totalPassengers: 3,
    totalRevenue: 80,
  },

  // Real-time lists populated from Firestore (with fallbacks)
  trips: [
    {
      id: "TRP01",
      requestId: "req01",
      date: "اليوم، 10:15",
      riderName: "كريم أحمد",
      riderPhone: "01012345678",
      driverName: "محمد علي",
      from: "شارع الجلاء، السادات",
      to: "جامعة السادات",
      price: 45,
      status: "مكتملة",
      vehicle: "عربية",
      rating: 5.0,
      paymentMethod: "كاش"
    },
    {
      id: "TRP02",
      requestId: "req02",
      date: "اليوم، 11:30",
      riderName: "سارة محمود",
      riderPhone: "01198765432",
      driverName: "أحمد حسن",
      from: "المنطقة الأولى",
      to: "المنطقة الرابعة",
      price: 20,
      status: "جارية",
      vehicle: "اسكوتر",
      rating: 0,
      paymentMethod: "كاش"
    }
  ],
  drivers: [
    {
      id: "DRV01",
      uid: "drv_uid_01",
      name: "محمد علي",
      phone: "01511223344",
      email: "mohamed.ali@inride.com",
      address: "المنطقة الخامسة، السادات",
      rating: 4.9,
      vehicleType: "car",
      vehicleName: "هيونداي إلنترا",
      vehicleColor: "فضي",
      licensePlate: "أ ب ج 1 2 3",
      status: "verified",
      statusAr: "معتمد",
      totalTrips: 120,
      earnings: 4500,
      isOnline: true,
      joinDate: "2026/01/10",
      avatar: "م",
      idCardFrontUrl: "https://images.unsplash.com/photo-1554774853-aae0a22c8aa4?q=80&w=300",
      idCardBackUrl: "https://images.unsplash.com/photo-1554774853-aae0a22c8aa4?q=80&w=300",
      driverLicenseFrontUrl: "https://images.unsplash.com/photo-1554774853-aae0a22c8aa4?q=80&w=300",
      driverLicenseBackUrl: "https://images.unsplash.com/photo-1554774853-aae0a22c8aa4?q=80&w=300",
      vehicleLicenseFrontUrl: "https://images.unsplash.com/photo-1554774853-aae0a22c8aa4?q=80&w=300",
      vehicleLicenseBackUrl: "https://images.unsplash.com/photo-1554774853-aae0a22c8aa4?q=80&w=300",
      vehicleImages: ["https://images.unsplash.com/photo-1549317661-bd32c8ce0db2?q=80&w=300"]
    },
    {
      id: "DRV02",
      uid: "drv_uid_02",
      name: "أحمد حسن",
      phone: "01099887766",
      email: "ahmed.hassan@inride.com",
      address: "المنطقة السكنية السابعة، السادات",
      rating: 4.8,
      vehicleType: "scooter",
      vehicleName: "اسكوتر بينيلي",
      vehicleColor: "أسود",
      licensePlate: "د هـ و 4 5 6",
      status: "submitted",
      statusAr: "قيد المراجعة",
      totalTrips: 45,
      earnings: 1200,
      isOnline: true,
      joinDate: "2026/02/15",
      avatar: "أ",
      idCardFrontUrl: "",
      idCardBackUrl: "",
      driverLicenseFrontUrl: "",
      driverLicenseBackUrl: "",
      vehicleLicenseFrontUrl: "",
      vehicleLicenseBackUrl: "",
      vehicleImages: []
    }
  ],
  passengers: [
    {
      id: "PAS01",
      uid: "pas_uid_01",
      name: "كريم أحمد",
      phone: "01012345678",
      email: "karim.ahmed@gmail.com",
      address: "المنطقة الثانية، السادات",
      rating: 5.0,
      totalTrips: 18,
      totalSpent: 950,
      joinDate: "2026/01/01",
      status: "active",
      statusAr: "نشط",
      lastTrip: "TRP01",
      avatar: "ك"
    },
    {
      id: "PAS02",
      uid: "pas_uid_02",
      name: "سارة محمود",
      phone: "01198765432",
      email: "sara.mah@gmail.com",
      address: "المنطقة السادسة، السادات",
      rating: 4.7,
      totalTrips: 8,
      totalSpent: 320,
      joinDate: "2026/03/12",
      status: "active",
      statusAr: "نشط",
      lastTrip: "TRP02",
      avatar: "س"
    },
    {
      id: "PAS03",
      uid: "pas_uid_03",
      name: "هاني سمير",
      phone: "01233445566",
      email: "hani.samir@yahoo.com",
      address: "المنطقة الأولى، السادات",
      rating: 4.5,
      totalTrips: 3,
      totalSpent: 120,
      joinDate: "2026/04/05",
      status: "suspended",
      statusAr: "معلق",
      lastTrip: "—",
      avatar: "ه"
    }
  ],
  transactions: [],
  // Weekly activity dynamically calculated from ride dates
  weeklyActivity: [
    { day: 'السبت', trips: 2 },
    { day: 'الأحد', trips: 5 },
    { day: 'الاثنين', trips: 3 },
    { day: 'الثلاثاء', trips: 7 },
    { day: 'الأربعاء', trips: 4 },
    { day: 'الخميس', trips: 8 },
    { day: 'الجمعة', trips: 2 },
  ],

  // Platform default configurations
  settings: {
    defaultFareCar: 45,
    defaultFareScooter: 20,
    defaultFareMotorcycle: 15,
    commissionRate: 10,
    minFare: 10,
    maxFare: 500,
  },
};

let currentPage = 'dashboard';
let settingsDirty = false;
let currentFilter = 'all';
let searchQuery = '';
let dateFilter = 'all'; // 'all', 'today', 'week', 'month', 'custom'
let customDateStart = '';
let customDateEnd = '';
let currentPages = { trips: 1, drivers: 1, passengers: 1, wallet: 1, support: 1, logs: 1 };
const itemsPerPage = 8;

// ---- Date filtering functions ----
// ---- UUID Generator ----
function generateUUID() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    var r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

function getFilteredTrips() {
  return mockData.trips.filter(trip => {
    // If the trip doesn't have an associated Firestore/Supabase request record with created_at, default to showing it
    const createdStr = mockData.tripsDataMap && mockData.tripsDataMap[trip.requestId] 
      ? mockData.tripsDataMap[trip.requestId].created_at 
      : null;
    if (!createdStr) return true;
    const date = new Date(createdStr);
    
    if (dateFilter === 'today') {
      const today = new Date();
      return date.getDate() === today.getDate() &&
             date.getMonth() === today.getMonth() &&
             date.getFullYear() === today.getFullYear();
    }
    if (dateFilter === 'week') {
      const now = new Date();
      const oneWeekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
      return date >= oneWeekAgo;
    }
    if (dateFilter === 'month') {
      const today = new Date();
      return date.getMonth() === today.getMonth() &&
             date.getFullYear() === today.getFullYear();
    }
    if (dateFilter === 'custom') {
      if (!customDateStart || !customDateEnd) return true;
      const start = new Date(customDateStart);
      start.setHours(0,0,0,0);
      const end = new Date(customDateEnd);
      end.setHours(23,59,59,999);
    }
    return true;
  }).sort((a, b) => {
    const createdStrA = mockData.tripsDataMap && mockData.tripsDataMap[a.requestId] 
      ? mockData.tripsDataMap[a.requestId].created_at 
      : null;
    const createdStrB = mockData.tripsDataMap && mockData.tripsDataMap[b.requestId] 
      ? mockData.tripsDataMap[b.requestId].created_at 
      : null;
    const dateA = createdStrA ? new Date(createdStrA).getTime() : 0;
    const dateB = createdStrB ? new Date(createdStrB).getTime() : 0;
    return dateB - dateA; // Descending
  });
}

function getDashboardStats() {
  const filtered = getFilteredTrips();
  let revenue = 0;
  filtered.forEach(t => {
    if (t.status === 'مكتملة') revenue += t.price;
  });
  return {
    totalTrips: filtered.length,
    activeDrivers: mockData.drivers.filter(d => d.isOnline).length,
    totalPassengers: mockData.passengers.length,
    totalRevenue: revenue
  };
}

function setDateFilter(filter) {
  dateFilter = filter;
  renderPage(currentPage);
}

function setCustomDateRange(start, end) {
  customDateStart = start;
  customDateEnd = end;
  dateFilter = 'custom';
  renderPage(currentPage);
}

function renderDateFilterBar() {
  return `
    <div class="date-filter-bar" style="display:flex;align-items:center;justify-content:space-between;background:white;padding:16px;border-radius:var(--radius-lg);margin-bottom:20px;border:1px solid var(--border-color);gap:16px;flex-wrap:wrap;">
      <div style="display:flex;align-items:center;gap:10px;">
        <i class="ri-calendar-todo-fill text-blue" style="font-size:22px;"></i>
        <span style="font-weight:700;font-size:14px;color:var(--text-primary);">تصفية البيانات حسب التاريخ (يوم بيومه):</span>
      </div>
      <div style="display:flex;align-items:center;gap:8px;flex-wrap:wrap;">
        <button class="btn btn-sm ${dateFilter === 'all' ? 'btn-primary' : 'btn-outline'}" onclick="setDateFilter('all')">كل الأوقات</button>
        <button class="btn btn-sm ${dateFilter === 'today' ? 'btn-primary' : 'btn-outline'}" onclick="setDateFilter('today')">اليوم الجاري</button>
        <button class="btn btn-sm ${dateFilter === 'week' ? 'btn-primary' : 'btn-outline'}" onclick="setDateFilter('week')">هذا الأسبوع</button>
        <button class="btn btn-sm ${dateFilter === 'month' ? 'btn-primary' : 'btn-outline'}" onclick="setDateFilter('month')">هذا الشهر</button>
        <div style="display:flex;align-items:center;gap:4px;">
          <span style="font-size:12px;font-weight:700;color:var(--text-secondary);">مخصص:</span>
          <input type="date" id="dateStart" value="${customDateStart || ''}" class="settings-input" style="padding:6px;font-size:11px;" onchange="setCustomDateRange(this.value, document.getElementById('dateEnd').value)">
          <span style="font-size:11px;">إلى</span>
          <input type="date" id="dateEnd" value="${customDateEnd || ''}" class="settings-input" style="padding:6px;font-size:11px;" onchange="setCustomDateRange(document.getElementById('dateStart').value, this.value)">
        </div>
      </div>
    </div>
  `;
}

// ============================================
// HELPER FUNCTIONS
// ============================================

function getVehicleIcon(type) {
  switch (type) {
    case 'عربية':
    case 'car': 
      return 'ri-car-fill';
    case 'اسكوتر':
    case 'scooter': 
      return 'ri-e-bike-2-fill';
    case 'موتوسيكل':
    case 'motorcycle': 
      return 'ri-motorbike-fill';
    default: 
      return 'ri-car-fill';
  }
}

function getStatusClass(status) {
  switch (status) {
    case 'مكتملة':
    case 'Completed': 
      return 'completed';
    case 'ملغاة':
    case 'Cancelled': 
      return 'cancelled';
    case 'جارية':
    case 'Searching':
    case 'Accepted':
    case 'DriverArriving':
    case 'TripStarted':
      return 'active';
    case 'verified':
    case 'معتمد': 
      return 'verified';
    case 'submitted':
    case 'قيد المراجعة': 
      return 'submitted';
    case 'unregistered':
    case 'غير مسجل': 
      return 'unregistered';
    case 'نشط':
    case 'active': 
      return 'completed';
    case 'غير نشط':
    case 'inactive': 
      return 'cancelled';
    default: 
      return 'pending';
  }
}

function animateCounter(element, target, duration = 1200) {
  let start = 0;
  const startTime = performance.now();

  function update(currentTime) {
    const elapsed = currentTime - startTime;
    const progress = Math.min(elapsed / duration, 1);
    const eased = 1 - Math.pow(1 - progress, 3); // ease-out cubic
    const current = Math.round(start + (target - start) * eased);

    element.textContent = current.toLocaleString('ar-EG');

    if (progress < 1) {
      requestAnimationFrame(update);
    }
  }

  requestAnimationFrame(update);
}

// ============================================
// NAVIGATION
// ============================================

function navigateTo(page) {
  currentPage = page;
  sessionStorage.setItem('admin_currentPage', page);
  if (page === 'driver-profile' || page === 'passenger-profile') {
    sessionStorage.setItem('admin_activeProfileUid', activeProfileUid);
    sessionStorage.setItem('admin_activeProfileRole', activeProfileRole);
  } else {
    sessionStorage.removeItem('admin_activeProfileUid');
    sessionStorage.removeItem('admin_activeProfileRole');
  }

  // Update active nav item
  document.querySelectorAll('.nav-item').forEach(item => {
    item.classList.remove('active');
    if (item.dataset.page === page) {
      item.classList.add('active');
    }
  });

  // Update header title
  updateHeaderTitle(page);

  // Render page content
  renderPage(page);

  // Close mobile sidebar
  closeSidebar();
}

function updateHeaderTitle(page) {
  const titles = {
    dashboard: { title: 'لوحة التحكم', sub: 'مرحباً بك في لوحة إدارة inRide' },
    trips: { title: 'إدارة الرحلات والطلبات', sub: 'عرض وإدارة جميع الرحلات والطلبات والتحكم بحالتها' },
    drivers: { title: 'إدارة السائقين والتوثيق', sub: 'مراجعة المستندات واعتماد الحسابات أو تعليقها' },
    passengers: { title: 'إدارة الركاب والمستخدمين', sub: 'التحكم بالركاب والمستخدمين وتعديل بياناتهم وحظرهم' },
    'driver-profile': { title: 'الملف الشخصي للكابتن', sub: 'عرض بيانات الكابتن ومستنداته ورحلاته والدعم المباشر' },
    'passenger-profile': { title: 'الملف الشخصي للراكب', sub: 'عرض بيانات الراكب ورحلاته والدعم المباشر' },
    wallet: { title: 'المحفظة والمالية', sub: 'مراجعة عمليات الشحن والسحب وإدارة الرصيد المالي' },
    pricing: { title: 'التسعير والمناطق', sub: 'إدارة تسعير الرحلات والعمولات ونسبة الـ Surge' },
    messages: { title: 'الإشعارات والرسائل', sub: 'إرسال الإشعارات الجماعية والمستهدفة وجدولة التنبيهات' },
    support: { title: 'الدعم الفني والشكاوى', sub: 'استقبال شكاوى المستخدمين والرد عليها وإغلاق التذاكر' },
    content: { title: 'إدارة المحتوى', sub: 'التحكم في البانرات، الإعلانات، الكوبونات والأسئلة الشائعة' },
    monitoring: { title: 'مراقبة النظام والأداء', sub: 'متابعة حالة السيرفرات والأخطاء والرحلات النشطة حالياً' },
    logs: { title: 'سجلات التدقيق والصلاحيات', sub: 'متابعة سجلات عمليات الموظفين (Audit Logs) وإدارة الـ RBAC' },
    settings: { title: 'الإعدادات العامة', sub: 'التحكم في أوضاع الصيانة وميزات التطبيق (Feature Flags)' },
  };

  const info = titles[page] || titles.dashboard;
  document.getElementById('headerTitle').textContent = info.title;
  document.getElementById('headerSub').textContent = info.sub;
}

// ============================================
// MOBILE SIDEBAR
// ============================================

function toggleSidebar() {
  const sidebar = document.getElementById('sidebar');
  const overlay = document.getElementById('overlay');
  sidebar.classList.toggle('open');
  overlay.classList.toggle('active');
}

function closeSidebar() {
  const sidebar = document.getElementById('sidebar');
  const overlay = document.getElementById('overlay');
  if (sidebar) sidebar.classList.remove('open');
  if (overlay) overlay.classList.remove('active');
}

// ============================================
// PAGE RENDERERS
// ============================================

function renderPage(page) {
  const container = document.getElementById('pageContent');
  if (!container) return;

  switch (page) {
    case 'dashboard':
      container.innerHTML = renderDashboard();
      initDashboardAnimations();
      break;
    case 'trips':
      container.innerHTML = renderTrips();
      break;
    case 'drivers':
      container.innerHTML = renderDrivers();
      break;
    case 'passengers':
      container.innerHTML = renderPassengers();
      break;
    case 'driver-profile':
      container.innerHTML = renderDriverProfile();
      initProfileChatSync(activeProfileUid, 'driver');
      break;
    case 'passenger-profile':
      container.innerHTML = renderPassengerProfile();
      initProfileChatSync(activeProfileUid, 'rider');
      break;
    case 'wallet':
      container.innerHTML = renderWallet();
      break;
    case 'pricing':
      container.innerHTML = renderPricing();
      break;
    case 'messages':
      container.innerHTML = renderMessages();
      initMessagesPage();
      break;
    case 'support':
      container.innerHTML = renderSupport();
      break;
    case 'content':
      container.innerHTML = renderContent();
      break;
    case 'monitoring':
      container.innerHTML = renderMonitoring();
      break;
    case 'logs':
      container.innerHTML = renderLogs();
      break;
    case 'settings':
      container.innerHTML = renderSettings();
      break;
    default:
      container.innerHTML = renderDashboard();
      initDashboardAnimations();
  }
}

// ---- DASHBOARD ----
function renderDashboard() {
  const maxTrips = mockData.weeklyActivity.length > 0 
    ? Math.max(...mockData.weeklyActivity.map(d => d.trips)) 
    : 0;
  const stats = getDashboardStats();

  return `
    <div class="page-section">
      ${renderDateFilterBar()}
      
      <!-- Stats Cards -->
      <div class="stats-grid">
        <div class="stat-card blue">
          <div class="stat-card-header">
            <div class="stat-card-icon"><i class="ri-route-fill"></i></div>
            <div class="stat-card-trend up"><i class="ri-arrow-up-s-line"></i> مباشر</div>
          </div>
          <div class="stat-card-value" data-target="${stats.totalTrips}">0</div>
          <div class="stat-card-label">إجمالي الرحلات</div>
        </div>
        <div class="stat-card green">
          <div class="stat-card-header">
            <div class="stat-card-icon"><i class="ri-steering-2-fill"></i></div>
            <div class="stat-card-trend up"><i class="ri-arrow-up-s-line"></i> متصل</div>
          </div>
          <div class="stat-card-value" data-target="${stats.activeDrivers}">0</div>
          <div class="stat-card-label">السائقين النشطين</div>
        </div>
        <div class="stat-card orange">
          <div class="stat-card-header">
            <div class="stat-card-icon"><i class="ri-group-fill"></i></div>
            <div class="stat-card-trend up"><i class="ri-arrow-up-s-line"></i> مسجل</div>
          </div>
          <div class="stat-card-value" data-target="${stats.totalPassengers}">0</div>
          <div class="stat-card-label">إجمالي الركاب</div>
        </div>
        <div class="stat-card red">
          <div class="stat-card-header">
            <div class="stat-card-icon"><i class="ri-money-pound-circle-fill"></i></div>
            <div class="stat-card-trend up"><i class="ri-arrow-up-s-line"></i> رحلات مكتملة</div>
          </div>
          <div class="stat-card-value" data-target="${stats.totalRevenue}">0</div>
          <div class="stat-card-label">إجمالي الإيرادات (ج.م)</div>
        </div>
      </div>

      <!-- Chart + Activity -->
      <div class="grid-3">
        <!-- Weekly Activity Chart -->
        <div class="card">
          <div class="card-header">
            <h3><i class="ri-bar-chart-grouped-fill text-blue" style="margin-left:8px;"></i> نشاط الرحلات - هذا الأسبوع</h3>
            <div class="live-indicator">
              <span class="live-dot"></span>
              مباشر
            </div>
          </div>
          <div class="card-body">
            <div class="activity-bars">
              ${mockData.weeklyActivity.map((d) => `
                <div class="activity-bar" style="height: ${maxTrips > 0 ? (d.trips / maxTrips) * 100 : 0}%;" 
                     data-tooltip="${d.trips} رحلة" title="${d.day}: ${d.trips} رحلة"></div>
              `).join('')}
            </div>
            <div class="activity-labels">
              ${mockData.weeklyActivity.map(d => `<span>${d.day}</span>`).join('')}
            </div>
          </div>
        </div>

        <!-- Quick Stats Sidebar -->
        <div class="card">
          <div class="card-header">
            <h3><i class="ri-pie-chart-fill text-blue" style="margin-left:8px;"></i> ملخص سريع</h3>
          </div>
          <div class="card-body">
            <div style="display:flex;flex-direction:column;gap:16px;">
              <div style="display:flex;align-items:center;justify-content:space-between;padding:14px;background:var(--bg-primary);border-radius:var(--radius-md);">
                <div style="display:flex;align-items:center;gap:10px;">
                  <i class="ri-car-fill" style="color:var(--medium-blue);font-size:20px;"></i>
                  <span style="font-weight:600;font-size:13px;">رحلات العربيات</span>
                </div>
                <span class="font-outfit fw-900" style="color:var(--medium-blue);">${mockData.trips.filter(t => t.vehicle === 'عربية').length}</span>
              </div>
              <div style="display:flex;align-items:center;justify-content:space-between;padding:14px;background:var(--bg-primary);border-radius:var(--radius-md);">
                <div style="display:flex;align-items:center;gap:10px;">
                  <i class="ri-e-bike-2-fill" style="color:var(--light-blue);font-size:20px;"></i>
                  <span style="font-weight:600;font-size:13px;">رحلات الاسكوتر</span>
                </div>
                <span class="font-outfit fw-900" style="color:var(--light-blue);">${mockData.trips.filter(t => t.vehicle === 'اسكوتر').length}</span>
              </div>
              <div style="display:flex;align-items:center;justify-content:space-between;padding:14px;background:var(--bg-primary);border-radius:var(--radius-md);">
                <div style="display:flex;align-items:center;gap:10px;">
                  <i class="ri-motorbike-fill" style="color:var(--dark-blue);font-size:20px;"></i>
                  <span style="font-weight:600;font-size:13px;">رحلات الموتوسيكل</span>
                </div>
                <span class="font-outfit fw-900" style="color:var(--dark-blue);">${mockData.trips.filter(t => t.vehicle === 'موتوسيكل').length}</span>
              </div>
              <div style="display:flex;align-items:center;justify-content:space-between;padding:14px;background:var(--success-bg);border-radius:var(--radius-md);">
                <div style="display:flex;align-items:center;gap:10px;">
                  <i class="ri-check-double-fill" style="color:var(--success);font-size:20px;"></i>
                  <span style="font-weight:600;font-size:13px;">نسبة الإكمال</span>
                </div>
                <span class="font-outfit fw-900" style="color:var(--success);">${mockData.trips.length > 0 ? Math.round((mockData.trips.filter(t => t.status === 'مكتملة').length / mockData.trips.length) * 100) : 0}%</span>
              </div>
              <div style="display:flex;align-items:center;justify-content:space-between;padding:14px;background:var(--warning-bg);border-radius:var(--radius-md);">
                <div style="display:flex;align-items:center;gap:10px;">
                  <i class="ri-time-fill" style="color:var(--warning);font-size:20px;"></i>
                  <span style="font-weight:600;font-size:13px;">سائقين بانتظار الاعتماد</span>
                </div>
                <span class="font-outfit fw-900" style="color:var(--warning);">${mockData.drivers.filter(d => d.status === 'submitted').length}</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Recent Trips Table -->
      <div class="card">
        <div class="card-header">
          <h3><i class="ri-history-fill text-blue" style="margin-left:8px;"></i> آخر الرحلات</h3>
          <button class="btn btn-outline btn-sm" onclick="navigateTo('trips')">
            عرض الكل <i class="ri-arrow-left-s-line"></i>
          </button>
        </div>
        <div class="card-body" style="padding:0;">
          <div class="table-responsive">
            <table class="data-table">
              <thead>
                <tr>
                  <th>رقم الرحلة</th>
                  <th>الراكب</th>
                  <th>السائق</th>
                  <th>المسار</th>
                  <th>المركبة</th>
                  <th>السعر</th>
                  <th>الحالة</th>
                </tr>
              </thead>
              <tbody>
                ${mockData.trips.length === 0 ? `<tr><td colspan="7" style="text-align:center;padding:24px;color:var(--text-light);">لا توجد رحلات حالياً في النظام</td></tr>` : ''}
                ${mockData.trips.slice(0, 5).map(trip => `
                  <tr>
                    <td><span class="font-outfit fw-700" style="color:var(--medium-blue);">${trip.id}</span></td>
                    <td>
                      <div class="user-cell">
                        <div class="user-avatar-placeholder">${trip.riderName.charAt(0)}</div>
                        <div>
                          <div class="user-name">${trip.riderName}</div>
                        </div>
                      </div>
                    </td>
                    <td>
                      <div class="user-name">${trip.driverName}</div>
                    </td>
                    <td>
                      <div class="route-cell">
                        <div class="route-dots">
                          <div class="route-dot from"></div>
                          <div class="route-line"></div>
                          <div class="route-dot to"></div>
                        </div>
                        <div class="route-addresses">
                          <div class="route-from">${trip.from}</div>
                          <div class="route-to">${trip.to}</div>
                        </div>
                      </div>
                    </td>
                    <td>
                      <div class="vehicle-badge">
                        <i class="${getVehicleIcon(trip.vehicle)}"></i>
                        ${trip.vehicle}
                      </div>
                    </td>
                    <td>
                      <span class="price font-outfit">${trip.price}</span>
                      <span class="price-currency">ج.م</span>
                    </td>
                    <td>
                      <span class="status-badge ${getStatusClass(trip.status)}">
                        <span class="status-dot"></span>
                        ${trip.status}
                      </span>
                    </td>
                  </tr>
                `).join('')}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  `;
}

function initDashboardAnimations() {
  setTimeout(() => {
    document.querySelectorAll('.stat-card-value[data-target]').forEach(el => {
      const target = parseInt(el.dataset.target);
      animateCounter(el, target);
    });
  }, 300);
}

// ---- TRIPS ----
function formatTime(timestamp) {
  if (!timestamp) return '';
  let dateObj;
  if (timestamp.toDate) {
    dateObj = timestamp.toDate();
  } else if (timestamp instanceof Date) {
    dateObj = timestamp;
  } else {
    dateObj = new Date(timestamp);
  }
  return dateObj.toLocaleTimeString('ar-EG', { hour: '2-digit', minute: '2-digit' });
}

function getReceiverTrackingHtml(trip) {
  if (trip.isDeliveryLocationConfirmed === false || trip.receiverLocationConfirmed || trip.linkOpened) {
    const openedStatus = trip.linkOpened 
      ? `<span style="font-size: 11px; padding: 3px 6px; border-radius: 4px; display: inline-flex; align-items: center; gap: 4px; font-weight: 600; color: #2e7d32; background: #e8f5e9; border: 1px solid #c8e6c9;"><i class="ri-eye-line"></i> فتح الرابط (${trip.linkOpenedTime ? formatTime(trip.linkOpenedTime) : 'مؤخراً'})</span>` 
      : `<span style="font-size: 11px; padding: 3px 6px; border-radius: 4px; display: inline-flex; align-items: center; gap: 4px; font-weight: 600; color: #ef6c00; background: #fff3e0; border: 1px solid #ffe0b2;"><i class="ri-eye-off-line"></i> لم يفتح الرابط</span>`;
    
    let permissionStatus = '';
    if (trip.locationPermissionGranted === true) {
      permissionStatus = `<span style="font-size: 11px; padding: 3px 6px; border-radius: 4px; display: inline-flex; align-items: center; gap: 4px; font-weight: 600; color: #2e7d32; background: #e8f5e9; border: 1px solid #c8e6c9;"><i class="ri-map-pin-user-line"></i> إذن الموقع: مسموح</span>`;
    } else if (trip.locationPermissionGranted === false) {
      permissionStatus = `<span style="font-size: 11px; padding: 3px 6px; border-radius: 4px; display: inline-flex; align-items: center; gap: 4px; font-weight: 600; color: #c62828; background: #ffebee; border: 1px solid #ffcdd2;"><i class="ri-error-warning-line"></i> إذن الموقع: مرفوض</span>`;
    } else {
      permissionStatus = `<span style="font-size: 11px; padding: 3px 6px; border-radius: 4px; display: inline-flex; align-items: center; gap: 4px; font-weight: 600; color: #37474f; background: #eceff1; border: 1px solid #cfd8dc;"><i class="ri-question-line"></i> إذن الموقع: بانتظار الطلب</span>`;
    }

    let sentStatus = '';
    if (trip.locationSent) {
      const sourceStr = trip.receiverLocationSource === 'gps' ? 'GPS' : 'يدوي';
      sentStatus = `<span style="font-size: 11px; padding: 3px 6px; border-radius: 4px; display: inline-flex; align-items: center; gap: 4px; font-weight: 600; color: #ffffff; background: #2e7d32; border: 1px solid #2e7d32;"><i class="ri-check-line"></i> تم الإرسال (${sourceStr} - ${trip.locationSentTime ? formatTime(trip.locationSentTime) : 'مؤخراً'})</span>`;
    } else {
      sentStatus = `<span style="font-size: 11px; padding: 3px 6px; border-radius: 4px; display: inline-flex; align-items: center; gap: 4px; font-weight: 600; color: #ffffff; background: #ef6c00; border: 1px solid #ef6c00;"><i class="ri-time-line"></i> بانتظار إرسال الموقع</span>`;
    }

    return `
      <div class="receiver-tracking-info" style="margin-top:8px; display:flex; flex-wrap:wrap; gap:6px;">
        ${openedStatus}
        ${permissionStatus}
        ${sentStatus}
      </div>
    `;
  }
  return '';
}

function groupTripsByDate(trips) {
  const groups = {};
  trips.forEach(trip => {
    let dayLabel = "تواريخ سابقة";
    const createdStr = mockData.tripsDataMap && mockData.tripsDataMap[trip.requestId]
      ? mockData.tripsDataMap[trip.requestId].created_at
      : null;
    if (createdStr) {
      const d = new Date(createdStr);
      const today = new Date();
      const yesterday = new Date(today.getTime() - 24*60*60*1000);
      if (d.getDate() === today.getDate() && d.getMonth() === today.getMonth() && d.getFullYear() === today.getFullYear()) {
        dayLabel = "اليوم الجاري";
      } else if (d.getDate() === yesterday.getDate() && d.getMonth() === yesterday.getMonth() && d.getFullYear() === yesterday.getFullYear()) {
        dayLabel = "أمس";
      } else {
        dayLabel = d.toLocaleDateString('ar-EG', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' });
      }
    } else {
      if (trip.date.startsWith("اليوم")) dayLabel = "اليوم الجاري";
      else if (trip.date.startsWith("أمس")) dayLabel = "أمس";
    }
    
    if (!groups[dayLabel]) groups[dayLabel] = [];
    groups[dayLabel].push(trip);
  });
  return groups;
}

function renderTrips() {
  const baseTrips = getFilteredTrips();
  const filteredTrips = (currentFilter === 'all'
    ? baseTrips
    : baseTrips.filter(t => {
        if (currentFilter === 'completed') return t.status === 'مكتملة';
        if (currentFilter === 'cancelled') return t.status === 'ملغاة';
        if (currentFilter === 'active') return t.status === 'جارية';
        return true;
      })).filter(t => {
        return t.id.toLowerCase().includes(searchQuery) ||
               t.riderName.toLowerCase().includes(searchQuery) ||
               t.driverName.toLowerCase().includes(searchQuery) ||
               t.from.toLowerCase().includes(searchQuery) ||
               t.to.toLowerCase().includes(searchQuery);
      });

  const completedCount = baseTrips.filter(t => t.status === 'مكتملة').length;
  const cancelledCount = baseTrips.filter(t => t.status === 'ملغاة').length;
  const activeCount = baseTrips.filter(t => t.status === 'جارية').length;

  const page = currentPages['trips'] || 1;
  const totalItems = filteredTrips.length;
  const totalPages = Math.ceil(totalItems / itemsPerPage) || 1;
  const startIndex = (page - 1) * itemsPerPage;
  const endIndex = Math.min(startIndex + itemsPerPage, totalItems);
  const paginatedTrips = filteredTrips.slice(startIndex, endIndex);

  // Group paginated trips by date
  const grouped = groupTripsByDate(paginatedTrips);
  let tableBodyHtml = '';
  if (paginatedTrips.length === 0) {
    tableBodyHtml = `<tr><td colspan="10" style="text-align:center;padding:24px;color:var(--text-light);">لا توجد رحلات لعرضها</td></tr>`;
  } else {
    for (const groupName in grouped) {
      tableBodyHtml += `
        <tr class="date-group-header-row" style="background:var(--border-light);font-weight:bold;color:var(--text-primary);">
          <td colspan="10" style="padding:10px 16px;font-size:12px;text-align:right;">
            <i class="ri-calendar-event-line text-blue" style="margin-left:6px;vertical-align:middle;"></i>${groupName}
          </td>
        </tr>
      `;
      grouped[groupName].forEach(trip => {
        tableBodyHtml += `
          <tr>
            <td><span class="font-outfit fw-700" style="color:var(--medium-blue);">${trip.id}</span></td>
            <td><span style="font-size:12px;color:var(--text-light);font-weight:600;">${trip.date}</span></td>
            <td>
              <div class="user-cell">
                <div class="user-avatar-placeholder">${trip.riderName.charAt(0)}</div>
                <div>
                  <div class="user-name">${trip.riderName}</div>
                  <div class="user-sub">${trip.riderPhone}</div>
                </div>
              </div>
            </td>
            <td><div class="user-name">${trip.driverName}</div></td>
            <td>
              <div class="route-cell">
                <div class="route-dots">
                  <div class="route-dot from"></div>
                  <div class="route-line"></div>
                  <div class="route-dot to"></div>
                </div>
                <div class="route-addresses">
                  <div class="route-from">${trip.from}</div>
                  <div class="route-to">${trip.to}</div>
                  ${getReceiverTrackingHtml(trip)}
                </div>
              </div>
            </td>
            <td>
              <div class="vehicle-badge">
                <i class="${getVehicleIcon(trip.vehicle)}"></i>
                ${trip.vehicle}
              </div>
            </td>
            <td>
              <span class="price font-outfit">${trip.price}</span>
              <span class="price-currency">ج.م</span>
            </td>
            <td>
              ${trip.rating > 0 ? `
                <div class="rating">
                  <i class="ri-star-fill"></i>
                  <span>${trip.rating}</span>
                </div>
              ` : '<span style="color:var(--text-light);font-size:12px;">—</span>'}
            </td>
            <td>
              <span class="status-badge ${getStatusClass(trip.status)}">
                <span class="status-dot"></span>
                ${trip.status}
              </span>
            </td>
            <td>
              <div style="display:flex;gap:4px;align-items:center;">
                <button class="btn btn-outline btn-sm" style="padding:4px 8px;font-size:11px;" onclick="changeTripPricePrompt('${trip.requestId}')"><i class="ri-edit-line"></i> تسعير</button>
                ${trip.status === 'جارية' ? `
                  <button class="btn btn-outline btn-sm" style="color:var(--error);border-color:var(--error);padding:4px 8px;font-size:11px;" onclick="modifyTripStatus('${trip.requestId}', 'Cancelled')"><i class="ri-close-line"></i> إلغاء</button>
                  <button class="btn btn-success btn-sm" style="padding:4px 8px;font-size:11px;background:var(--success);" onclick="modifyTripStatus('${trip.requestId}', 'Completed')"><i class="ri-check-line"></i> إنهاء</button>
                ` : ''}
              </div>
            </td>
          </tr>
        `;
      });
    }
  }

  return `
    <div class="page-section">
      ${renderDateFilterBar()}

      <!-- Filters -->
      <div class="filters-bar">
        <button class="filter-btn ${currentFilter === 'all' ? 'active' : ''}" onclick="filterTrips('all')">
          الكل <span class="filter-count">${baseTrips.length}</span>
        </button>
        <button class="filter-btn ${currentFilter === 'completed' ? 'active' : ''}" onclick="filterTrips('completed')">
          مكتملة <span class="filter-count">${completedCount}</span>
        </button>
        <button class="filter-btn ${currentFilter === 'active' ? 'active' : ''}" onclick="filterTrips('active')">
          جارية <span class="filter-count">${activeCount}</span>
        </button>
        <button class="filter-btn ${currentFilter === 'cancelled' ? 'active' : ''}" onclick="filterTrips('cancelled')">
          ملغاة <span class="filter-count">${cancelledCount}</span>
        </button>
      </div>

      <!-- Trips Table -->
      <div class="card">
        <div class="card-header" style="display:flex;justify-content:space-between;align-items:center;">
          <h3><i class="ri-route-fill text-blue" style="margin-left:8px;"></i> جميع الرحلات والطلبات</h3>
          <div style="display:flex;gap:10px;align-items:center;">
            <span class="text-light" style="font-size:13px;">${filteredTrips.length} رحلة</span>
            <button class="btn btn-outline btn-sm" onclick="exportTripsCSV()"><i class="ri-download-2-line"></i> تصدير تقرير</button>
          </div>
        </div>
        <div class="card-body" style="padding:0;">
          <div class="table-responsive">
            <table class="data-table">
              <thead>
                <tr>
                  <th>رقم الرحلة</th>
                  <th>التاريخ</th>
                  <th>الراكب</th>
                  <th>السائق</th>
                  <th>المسار</th>
                  <th>المركبة</th>
                  <th>السعر</th>
                  <th>التقييم</th>
                  <th>الحالة</th>
                  <th>إجراء</th>
                </tr>
              </thead>
              <tbody>
                ${tableBodyHtml}
              </tbody>
            </table>
          </div>
          <div style="display:flex;justify-content:space-between;align-items:center;padding:16px;border-top:1px solid var(--border-color);font-size:13px;">
            <div style="color:var(--text-secondary);">عرض ${totalItems > 0 ? startIndex + 1 : 0} - ${endIndex} من أصل ${totalItems} رحلة</div>
            <div style="display:flex;gap:6px;align-items:center;">
              <button class="btn btn-outline btn-sm" style="padding:4px 10px;" ${page === 1 ? 'disabled style="opacity:0.5;pointer-events:none;"' : ''} onclick="changePage('trips', ${page - 1})">السابق</button>
              <span style="font-weight:700;">صفحة ${page} من ${totalPages}</span>
              <button class="btn btn-outline btn-sm" style="padding:4px 10px;" ${page === totalPages ? 'disabled style="opacity:0.5;pointer-events:none;"' : ''} onclick="changePage('trips', ${page + 1})">التالي</button>
            </div>
          </div>
        </div>
      </div>
    </div>
  `;
}

function changeTripPricePrompt(requestId) {
  const newPriceStr = prompt('ادخل السعر الجديد للرحلة (ج.م):');
  const newPrice = parseFloat(newPriceStr);
  if (isNaN(newPrice) || newPrice <= 0) {
    showToast('⚠️ سعر غير صالح');
    return;
  }
  
  if (supabaseClient) {
    supabaseClient.from('ride_requests').update({ offered_fare: newPrice }).eq('id', requestId)
      .then(({ error }) => {
        if (!error) {
          logAction(`تعديل سعر الرحلة ${requestId} إلى ${newPrice} ج.م`);
          showToast(`✅ تم تعديل سعر الرحلة بنجاح`);
        } else {
          showToast(`❌ فشل: ${error.message}`);
        }
      }).catch(err => showToast(`❌ فشل: ${err.message}`));
  } else {
    const trip = mockData.trips.find(t => t.requestId === requestId);
    if (trip) {
      trip.price = newPrice;
      logAction(`تعديل سعر الرحلة ${requestId} محلياً إلى ${newPrice} ج.م`);
      renderPage('trips');
      showToast(`✅ تم تعديل السعر محلياً`);
    }
  }
}

function filterTrips(filter) {
  currentFilter = filter;
  renderPage('trips');
}

// ---- DRIVERS ----
function renderDrivers() {
  const filteredDrivers = mockData.drivers.filter(d => {
    return d.id.toLowerCase().includes(searchQuery) ||
           d.name.toLowerCase().includes(searchQuery) ||
           d.phone.includes(searchQuery) ||
           (d.vehicleName && d.vehicleName.toLowerCase().includes(searchQuery)) ||
           (d.licensePlate && d.licensePlate.toLowerCase().includes(searchQuery));
  });

  const page = currentPages['drivers'] || 1;
  const totalItems = filteredDrivers.length;
  const totalPages = Math.ceil(totalItems / itemsPerPage) || 1;
  const startIndex = (page - 1) * itemsPerPage;
  const endIndex = Math.min(startIndex + itemsPerPage, totalItems);
  const paginatedDrivers = filteredDrivers.slice(startIndex, endIndex);

  return `
    <div class="page-section">
      <!-- Stats Overview -->
      <div class="stats-grid" style="grid-template-columns: repeat(3, 1fr); margin-bottom: 24px;">
        <div class="stat-card green">
          <div class="stat-card-header">
            <div class="stat-card-icon"><i class="ri-check-double-fill"></i></div>
          </div>
          <div class="stat-card-value">${mockData.drivers.filter(d => d.status === 'verified').length}</div>
          <div class="stat-card-label">سائقين معتمدين</div>
        </div>
        <div class="stat-card orange">
          <div class="stat-card-header">
            <div class="stat-card-icon"><i class="ri-time-fill"></i></div>
          </div>
          <div class="stat-card-value">${mockData.drivers.filter(d => d.status === 'submitted').length}</div>
          <div class="stat-card-label">بانتظار الاعتماد</div>
        </div>
        <div class="stat-card red">
          <div class="stat-card-header">
            <div class="stat-card-icon"><i class="ri-close-circle-fill"></i></div>
          </div>
          <div class="stat-card-value">${mockData.drivers.filter(d => d.status === 'unregistered').length}</div>
          <div class="stat-card-label">غير مسجلين</div>
        </div>
      </div>

      <!-- Drivers Table -->
      <div class="card">
        <div class="card-header" style="display:flex;justify-content:space-between;align-items:center;">
          <h3><i class="ri-steering-2-fill text-blue" style="margin-left:8px;"></i> جميع السائقين والكباتن</h3>
          <div style="display:flex;gap:10px;align-items:center;">
            <span class="text-light" style="font-size:13px;">${filteredDrivers.length} سائق</span>
            <button class="btn btn-primary btn-sm" onclick="showAddUserModal('driver')"><i class="ri-user-add-line"></i> إضافة سائق جديد</button>
            <button class="btn btn-outline btn-sm" onclick="exportDriversCSV()"><i class="ri-download-2-line"></i> تصدير تقرير</button>
          </div>
        </div>
        <div class="card-body" style="padding:0;">
          <table class="data-table">
            <thead>
              <tr>
                <th>الكود</th>
                <th>السائق</th>
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
              ${paginatedDrivers.length === 0 ? `<tr><td colspan="10" style="text-align:center;padding:24px;color:var(--text-light);">لا يوجد سائقون مسجلون حالياً</td></tr>` : ''}
              ${paginatedDrivers.map(driver => `
                <tr>
                  <td><span class="font-outfit fw-700" style="color:var(--medium-blue);">${driver.id}</span></td>
                  <td>
                    <div class="user-cell">
                      <div class="user-avatar-placeholder">${driver.avatar}</div>
                      <div>
                        <div class="user-name" style="cursor:pointer;color:var(--medium-blue);font-weight:700;" onclick="viewUserProfile('${driver.uid}', 'driver')">${driver.name}</div>
                        <div class="user-sub">انضم ${driver.joinDate}</div>
                      </div>
                    </div>
                  </td>
                  <td><span style="font-size:12px;font-weight:600;direction:ltr;display:inline-block;">${driver.phone}</span></td>
                  <td>
                    ${driver.vehicleName ? `
                      <div class="vehicle-badge">
                        <i class="${getVehicleIcon(driver.vehicleType)}"></i>
                        ${driver.vehicleName}
                      </div>
                    ` : '<span style="color:var(--text-light);font-size:12px;">—</span>'}
                  </td>
                  <td>
                    ${driver.licensePlate ? `<span class="font-outfit fw-700" style="font-size:12px;">${driver.licensePlate}</span>` : '—'}
                  </td>
                  <td>
                    <div class="rating">
                      <i class="ri-star-fill"></i>
                      <span>${driver.rating}</span>
                    </div>
                  </td>
                  <td><span class="font-outfit fw-700">${driver.totalTrips}</span></td>
                  <td>
                    <span class="status-badge ${driver.status}">
                      <span class="status-dot"></span>
                      ${driver.statusAr}
                    </span>
                  </td>
                  <td>
                    ${driver.isOnline 
                      ? '<span class="status-badge completed"><span class="status-dot"></span> متصل</span>'
                      : '<span style="color:var(--text-light);font-size:12px;">غير متصل</span>'
                    }
                  </td>
                  <td>
                    <div style="display:flex;gap:4px;align-items:center;">
                      <button class="btn btn-outline btn-sm" onclick="reviewDriverDocs('${driver.uid}')">
                        <i class="ri-file-search-line"></i> وثائق
                      </button>
                      <button class="btn btn-outline btn-sm" onclick="showEditUserModal('${driver.uid}', 'driver')">
                        <i class="ri-edit-line"></i> تعديل
                      </button>
                      <button class="btn btn-outline btn-sm" onclick="adjustWalletPrompt('${driver.uid}', 'driver')">
                        <i class="ri-wallet-3-line"></i> شحن
                      </button>
                      ${driver.status === 'verified' ? `
                        <button class="btn btn-outline btn-sm" style="color:var(--error);border-color:var(--error);" onclick="modifyUserStatus('${driver.uid}', 'suspend', 'driver')">
                          <i class="ri-lock-line"></i> تعليق
                        </button>
                      ` : `
                        <button class="btn btn-success btn-sm" style="background:var(--success);" onclick="modifyUserStatus('${driver.uid}', 'verify', 'driver')">
                          <i class="ri-lock-unlock-line"></i> تفعيل
                        </button>
                      `}
                      <button class="btn btn-outline btn-sm" style="color:var(--error);border-color:var(--error);" onclick="modifyUserStatus('${driver.uid}', 'ban', 'driver')">
                        <i class="ri-user-unfollow-line"></i> حظر
                      </button>
                      <button class="btn btn-outline btn-sm" style="color:var(--error);border-color:var(--error);" onclick="deleteUserPrompt('${driver.uid}', 'driver')">
                        <i class="ri-delete-bin-line"></i> حذف
                      </button>
                    </div>
                  </td>
                </tr>
              `).join('')}
            </tbody>
          </table>
          <div style="display:flex;justify-content:space-between;align-items:center;padding:16px;border-top:1px solid var(--border-color);font-size:13px;">
            <div style="color:var(--text-secondary);">عرض ${totalItems > 0 ? startIndex + 1 : 0} - ${endIndex} من أصل ${totalItems} كابتن</div>
            <div style="display:flex;gap:6px;align-items:center;">
              <button class="btn btn-outline btn-sm" style="padding:4px 10px;" ${page === 1 ? 'disabled style="opacity:0.5;pointer-events:none;"' : ''} onclick="changePage('drivers', ${page - 1})">السابق</button>
              <span style="font-weight:700;">صفحة ${page} من ${totalPages}</span>
              <button class="btn btn-outline btn-sm" style="padding:4px 10px;" ${page === totalPages ? 'disabled style="opacity:0.5;pointer-events:none;"' : ''} onclick="changePage('drivers', ${page + 1})">التالي</button>
            </div>
          </div>
        </div>
      </div>
    </div>
  `;
}

function approveDriver(driverId) {
  const driver = mockData.drivers.find(d => d.id === driverId);
  if (driver) {
    if (supabaseClient && driver.uid) {
      supabaseClient.from('drivers').update({ verification_status: 'verified' }).eq('id', driver.uid)
        .then(({ error }) => {
          if (!error) {
            showToast(`✅ تم اعتماد السائق ${driver.name} بنجاح`);
          } else {
            showToast(`❌ فشل الاعتماد: ${error.message}`);
          }
        }).catch(err => {
          showToast(`❌ فشل الاعتماد: ${err.message}`);
        });
    } else {
      // Local fallback
      driver.status = 'verified';
      driver.statusAr = 'معتمد';
      updatePendingBadge();
      renderPage('drivers');
      showToast(`✅ تم اعتماد السائق ${driver.name} بنجاح`);
    }
  }
}

function viewDriver(driverId) {
  const driver = mockData.drivers.find(d => d.id === driverId);
  if (driver) {
    showToast(`📋 عرض بيانات: ${driver.name}`);
  }
}

function updatePendingBadge() {
  const pendingCount = mockData.drivers.filter(d => d.status === 'submitted').length;
  const badge = document.getElementById('driversBadge');
  if (badge) {
    if (pendingCount > 0) {
      badge.textContent = pendingCount;
      badge.style.display = 'inline';
    } else {
      badge.style.display = 'none';
    }
  }
}

// ---- PASSENGERS ----
function renderPassengers() {
  const filteredPassengers = mockData.passengers.filter(p => {
    return p.id.toLowerCase().includes(searchQuery) ||
           p.name.toLowerCase().includes(searchQuery) ||
           p.phone.includes(searchQuery);
  });

  const page = currentPages['passengers'] || 1;
  const totalItems = filteredPassengers.length;
  const totalPages = Math.ceil(totalItems / itemsPerPage) || 1;
  const startIndex = (page - 1) * itemsPerPage;
  const endIndex = Math.min(startIndex + itemsPerPage, totalItems);
  const paginatedPassengers = filteredPassengers.slice(startIndex, endIndex);

  return `
    <div class="page-section">
      <!-- Stats Overview -->
      <div class="stats-grid" style="grid-template-columns: repeat(3, 1fr); margin-bottom: 24px;">
        <div class="stat-card blue">
          <div class="stat-card-header">
            <div class="stat-card-icon"><i class="ri-group-fill"></i></div>
          </div>
          <div class="stat-card-value">${mockData.passengers.length}</div>
          <div class="stat-card-label">إجمالي الركاب</div>
        </div>
        <div class="stat-card green">
          <div class="stat-card-header">
            <div class="stat-card-icon"><i class="ri-user-follow-fill"></i></div>
          </div>
          <div class="stat-card-value">${mockData.passengers.filter(p => p.status === 'active').length}</div>
          <div class="stat-card-label">ركاب نشطين</div>
        </div>
        <div class="stat-card orange">
          <div class="stat-card-header">
            <div class="stat-card-icon"><i class="ri-money-pound-circle-fill"></i></div>
          </div>
          <div class="stat-card-value">${(mockData.passengers.reduce((sum, p) => sum + (p.totalSpent || 0), 0)).toLocaleString()}</div>
          <div class="stat-card-label">إجمالي الإنفاق (ج.م)</div>
        </div>
      </div>

      <!-- Passengers Table -->
      <div class="card">
        <div class="card-header" style="display:flex;justify-content:space-between;align-items:center;">
          <h3><i class="ri-group-fill text-blue" style="margin-left:8px;"></i> جميع الركاب والمستخدمين</h3>
          <div style="display:flex;gap:10px;align-items:center;">
            <span class="text-light" style="font-size:13px;">${filteredPassengers.length} راكب</span>
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
              ${paginatedPassengers.length === 0 ? `<tr><td colspan="8" style="text-align:center;padding:24px;color:var(--text-light);">لا يوجد ركاب مسجلون حالياً</td></tr>` : ''}
              ${paginatedPassengers.map(p => `
                <tr>
                  <td><span class="font-outfit fw-700" style="color:var(--medium-blue);">${p.id}</span></td>
                  <td>
                    <div class="user-cell">
                      <div class="user-avatar-placeholder">${p.avatar}</div>
                      <div>
                        <div class="user-name" style="cursor:pointer;color:var(--medium-blue);font-weight:700;" onclick="viewUserProfile('${p.uid}', 'rider')">${p.name}</div>
                      </div>
                    </div>
                  </td>
                  <td><span style="font-size:12px;font-weight:600;direction:ltr;display:inline-block;">${p.phone}</span></td>
                  <td>
                    <div class="rating">
                      <i class="ri-star-fill"></i>
                      <span>${p.rating}</span>
                    </div>
                  </td>
                  <td><span class="font-outfit fw-700">${p.totalTrips}</span></td>
                  <td><span style="font-size:12px;color:var(--text-light);font-weight:600;">${p.joinDate}</span></td>
                  <td>
                    <span class="status-badge ${getStatusClass(p.status)}">
                      <span class="status-dot"></span>
                      ${p.statusAr}
                    </span>
                  </td>
                  <td>
                    <div style="display:flex;gap:4px;align-items:center;">
                      <button class="btn btn-outline btn-sm" onclick="showEditUserModal('${p.uid}', 'rider')">
                        <i class="ri-edit-line"></i> تعديل
                      </button>
                      <button class="btn btn-outline btn-sm" onclick="adjustWalletPrompt('${p.uid}', 'rider')">
                        <i class="ri-wallet-3-line"></i> شحن
                      </button>
                      ${p.status === 'active' ? `
                        <button class="btn btn-outline btn-sm" style="color:var(--error);border-color:var(--error);" onclick="modifyUserStatus('${p.uid}', 'suspend', 'rider')">
                          <i class="ri-lock-line"></i> تعليق
                        </button>
                      ` : `
                        <button class="btn btn-success btn-sm" style="background:var(--success);" onclick="modifyUserStatus('${p.uid}', 'activate', 'rider')">
                          <i class="ri-lock-unlock-line"></i> تفعيل
                        </button>
                      `}
                      <button class="btn btn-outline btn-sm" style="color:var(--error);border-color:var(--error);" onclick="modifyUserStatus('${p.uid}', 'ban', 'rider')">
                        <i class="ri-user-unfollow-line"></i> حظر
                      </button>
                      <button class="btn btn-outline btn-sm" style="color:var(--error);border-color:var(--error);" onclick="deleteUserPrompt('${p.uid}', 'rider')">
                        <i class="ri-delete-bin-line"></i> حذف
                      </button>
                    </div>
                  </td>
                </tr>
              `).join('')}
            </tbody>
          </table>
          <div style="display:flex;justify-content:space-between;align-items:center;padding:16px;border-top:1px solid var(--border-color);font-size:13px;">
            <div style="color:var(--text-secondary);">عرض ${totalItems > 0 ? startIndex + 1 : 0} - ${endIndex} من أصل ${totalItems} راكب</div>
            <div style="display:flex;gap:6px;align-items:center;">
              <button class="btn btn-outline btn-sm" style="padding:4px 10px;" ${page === 1 ? 'disabled style="opacity:0.5;pointer-events:none;"' : ''} onclick="changePage('passengers', ${page - 1})">السابق</button>
              <span style="font-weight:700;">صفحة ${page} من ${totalPages}</span>
              <button class="btn btn-outline btn-sm" style="padding:4px 10px;" ${page === totalPages ? 'disabled style="opacity:0.5;pointer-events:none;"' : ''} onclick="changePage('passengers', ${page + 1})">التالي</button>
            </div>
          </div>
        </div>
      </div>
    </div>
  `;
}

function showAddUserModal(role) {
  const isDriver = role === 'driver';
  const title = isDriver ? 'إضافة سائق (كابتن) جديد' : 'إضافة راكب جديد';
  
  const modal = document.createElement('div');
  modal.className = 'modal-backdrop';
  modal.style.cssText = `
    position: fixed; top:0; left:0; width:100%; height:100%;
    background: rgba(0,0,0,0.5); z-index:10000;
    display:flex; align-items:center; justify-content:center;
    font-family: 'Cairo', sans-serif;
  `;
  
  modal.innerHTML = `
    <div style="background:white; padding:24px; border-radius:var(--radius-lg); width:550px; max-width:95%; max-height:85vh; overflow-y:auto; box-shadow: 0 10px 25px rgba(0,0,0,0.2); direction:rtl; text-align:right;">
      <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:20px; border-bottom:1px solid var(--border-color); padding-bottom:12px;">
        <h3 style="font-weight:800; margin:0; font-size:18px;"><i class="ri-user-add-line text-blue" style="margin-left:8px;"></i> ${title}</h3>
        <button onclick="this.closest('.modal-backdrop').remove()" style="font-size:24px;color:var(--text-light);background:none;border:none;cursor:pointer;"><i class="ri-close-line"></i></button>
      </div>
      
      <form id="addUserForm" onsubmit="event.preventDefault(); submitAddUser('${role}')" style="display:flex; flex-direction:column; gap:16px;">
        <div>
          <label style="display:block; margin-bottom:6px; font-weight:700; font-size:13px; color:var(--text-primary);">الاسم الكامل *</label>
          <input type="text" id="addName" required class="form-control" style="width:100%; padding:10px; border:1px solid var(--border-color); border-radius:var(--radius-md);" placeholder="أدخل اسم المستخدم الثلاثي">
        </div>
        
        <div style="display:grid; grid-template-columns:1fr 1fr; gap:12px;">
          <div>
            <label style="display:block; margin-bottom:6px; font-weight:700; font-size:13px; color:var(--text-primary);">رقم الهاتف *</label>
            <input type="text" id="addPhone" required class="form-control" style="width:100%; padding:10px; border:1px solid var(--border-color); border-radius:var(--radius-md);" placeholder="مثال: 01012345678">
          </div>
          <div>
            <label style="display:block; margin-bottom:6px; font-weight:700; font-size:13px; color:var(--text-primary);">البريد الإلكتروني</label>
            <input type="email" id="addEmail" class="form-control" style="width:100%; padding:10px; border:1px solid var(--border-color); border-radius:var(--radius-md);" placeholder="example@inride.com">
          </div>
        </div>

        <div>
          <label style="display:block; margin-bottom:6px; font-weight:700; font-size:13px; color:var(--text-primary);">العنوان</label>
          <input type="text" id="addAddress" class="form-control" style="width:100%; padding:10px; border:1px solid var(--border-color); border-radius:var(--radius-md);" placeholder="المحافظة، المدينة، المنطقة">
        </div>

        <div>
          <label style="display:block; margin-bottom:6px; font-weight:700; font-size:13px; color:var(--text-primary);">التقييم الافتراضي</label>
          <input type="number" id="addRating" min="1" max="5" step="0.1" value="5.0" class="form-control" style="width:100%; padding:10px; border:1px solid var(--border-color); border-radius:var(--radius-md);">
        </div>

        ${isDriver ? `
        <div style="border-top:1px solid var(--border-light); padding-top:14px; margin-top:6px;">
          <h4 style="font-weight:700; font-size:14px; margin-bottom:12px; color:var(--medium-blue);"><i class="ri-car-fill"></i> بيانات المركبة</h4>
          
          <div style="display:grid; grid-template-columns:1fr 1fr; gap:12px; margin-bottom:12px;">
            <div>
              <label style="display:block; margin-bottom:6px; font-weight:700; font-size:12px;">نوع المركبة *</label>
              <select id="addVehicleType" required class="form-control" style="width:100%; padding:10px; border:1px solid var(--border-color); border-radius:var(--radius-md); background:white;">
                <option value="car">عربية (Car)</option>
                <option value="scooter">اسكوتر (Scooter)</option>
                <option value="motorcycle">موتوسيكل (Motorcycle)</option>
              </select>
            </div>
            <div>
              <label style="display:block; margin-bottom:6px; font-weight:700; font-size:12px;">موديل/اسم المركبة *</label>
              <input type="text" id="addVehicleName" required class="form-control" style="width:100%; padding:10px; border:1px solid var(--border-color); border-radius:var(--radius-md);" placeholder="مثال: هيونداي إلنترا 2024">
            </div>
          </div>
          
          <div>
            <label style="display:block; margin-bottom:6px; font-weight:700; font-size:12px;">رقم لوحة المركبة *</label>
            <input type="text" id="addLicensePlate" required class="form-control" style="width:100%; padding:10px; border:1px solid var(--border-color); border-radius:var(--radius-md);" placeholder="مثال: أ ب ج 1 2 3">
          </div>
        </div>
        ` : ''}

        <div style="display:flex; justify-content:flex-end; gap:10px; border-top:1px solid var(--border-color); padding-top:16px; margin-top:10px;">
          <button type="button" class="btn btn-outline" onclick="this.closest('.modal-backdrop').remove()">إلغاء</button>
          <button type="submit" class="btn btn-primary">حفظ وإضافة</button>
        </div>
      </form>
    </div>
  `;
  document.body.appendChild(modal);
}

function submitAddUser(role) {
  const isDriver = role === 'driver';
  const name = document.getElementById('addName').value.trim();
  const phone = document.getElementById('addPhone').value.trim();
  const email = document.getElementById('addEmail').value.trim();
  const address = document.getElementById('addAddress').value.trim();
  const rating = parseFloat(document.getElementById('addRating').value) || 5.0;
  
  let vehicleType = '';
  let vehicleName = '';
  let licensePlate = '';
  
  if (isDriver) {
    vehicleType = document.getElementById('addVehicleType').value;
    vehicleName = document.getElementById('addVehicleName').value.trim();
    licensePlate = document.getElementById('addLicensePlate').value.trim();
  }

  const modal = document.querySelector('.modal-backdrop');
  if (modal) modal.remove();

  if (supabaseClient) {
    (async () => {
      try {
        const uid = generateUUID();
        const userData = {
          id: uid,
          name: name,
          phone_number: phone,
          email: email,
          address: address,
          role: isDriver ? 'driver' : 'rider',
          rating: rating,
          created_at: new Date().toISOString()
        };

        const { error: userError } = await supabaseClient.from('users').insert(userData);
        if (userError) throw userError;

        if (isDriver) {
          const vehicleId = generateUUID();
          const { error: vError } = await supabaseClient.from('vehicles').insert({
            id: vehicleId,
            type: vehicleType,
            model: vehicleName,
            number_plate: licensePlate,
            color: 'فضي'
          });
          if (vError) throw vError;

          const { error: dError } = await supabaseClient.from('drivers').insert({
            id: uid,
            vehicle_id: vehicleId,
            verification_status: 'verified',
            is_online: false,
            updated_at: new Date().toISOString()
          });
          if (dError) throw dError;

          logAction(`إضافة كابتن جديد (الاسم: ${name}، الهاتف: ${phone})`);
          showToast('✅ تم إضافة الكابتن بنجاح');
        } else {
          const { error: pError } = await supabaseClient.from('passengers').insert({
            id: uid,
            name: name,
            phone: phone,
            created_at: new Date().toISOString()
          });
          if (pError) throw pError;

          logAction(`إضافة راكب جديد (الاسم: ${name}، الهاتف: ${phone})`);
          showToast('✅ تم إضافة الراكب بنجاح');
        }
      } catch (err) {
        showToast(`❌ فشل الإضافة: ${err.message}`);
      }
    })();
  } else {
    // Local fallback
    const uid = 'local_uid_' + Math.random().toString(36).substring(2, 10);
    const dateStr = new Date().toLocaleDateString('ar-EG');
    const avatar = name.charAt(0);
    
    if (isDriver) {
      const newDriver = {
        id: uid.substring(0, 8).toUpperCase(),
        uid: uid,
        name: name,
        phone: phone,
        email: email,
        address: address,
        rating: rating,
        vehicleType: vehicleType,
        vehicleName: vehicleName,
        vehicleColor: 'فضي',
        licensePlate: licensePlate,
        status: 'verified',
        statusAr: 'معتمد',
        totalTrips: 0,
        earnings: 0,
        isOnline: false,
        joinDate: dateStr,
        avatar: avatar,
        idCardFrontUrl: '',
        idCardBackUrl: '',
        driverLicenseFrontUrl: '',
        driverLicenseBackUrl: '',
        vehicleLicenseFrontUrl: '',
        vehicleLicenseBackUrl: '',
        vehicleImages: []
      };
      mockData.drivers.unshift(newDriver);
      mockData.stats.activeDrivers = mockData.drivers.filter(d => d.isOnline).length;
      logAction(`إضافة سائق جديد محلياً (الاسم: ${name})`);
      renderPage('drivers');
    } else {
      const newPassenger = {
        id: uid.substring(0, 8).toUpperCase(),
        uid: uid,
        name: name,
        phone: phone,
        email: email,
        address: address,
        rating: rating,
        totalTrips: 0,
        totalSpent: 0,
        joinDate: dateStr,
        status: 'active',
        statusAr: 'نشط',
        lastTrip: '—',
        avatar: avatar
      };
      mockData.passengers.unshift(newPassenger);
      mockData.stats.totalPassengers = mockData.passengers.length;
      logAction(`إضافة راكب جديد محلياً (الاسم: ${name})`);
      renderPage('passengers');
    }
    showToast('✅ تم الإضافة محليياً (وضع التجربة)');
  }
}

function showEditUserModal(uid, role) {
  const isDriver = role === 'driver';
  let user = null;
  if (isDriver) {
    user = mockData.drivers.find(d => d.uid === uid);
  } else {
    user = mockData.passengers.find(p => p.uid === uid);
  }
  
  if (!user) {
    showToast('⚠️ لم يتم العثور على بيانات المستخدم');
    return;
  }

  const modal = document.createElement('div');
  modal.className = 'modal-backdrop';
  modal.style.cssText = `
    position: fixed; top:0; left:0; width:100%; height:100%;
    background: rgba(0,0,0,0.5); z-index:10000;
    display:flex; align-items:center; justify-content:center;
    font-family: 'Cairo', sans-serif;
  `;
  
  modal.innerHTML = `
    <div style="background:white; padding:24px; border-radius:var(--radius-lg); width:550px; max-width:95%; max-height:85vh; overflow-y:auto; box-shadow: 0 10px 25px rgba(0,0,0,0.2); direction:rtl; text-align:right;">
      <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:20px; border-bottom:1px solid var(--border-color); padding-bottom:12px;">
        <h3 style="font-weight:800; margin:0; font-size:18px;"><i class="ri-edit-line text-blue" style="margin-left:8px;"></i> تعديل بيانات المستخدم</h3>
        <button onclick="this.closest('.modal-backdrop').remove()" style="font-size:24px;color:var(--text-light);background:none;border:none;cursor:pointer;"><i class="ri-close-line"></i></button>
      </div>
      
      <form id="editUserForm" onsubmit="event.preventDefault(); submitEditUser('${uid}', '${role}')" style="display:flex; flex-direction:column; gap:16px;">
        <div>
          <label style="display:block; margin-bottom:6px; font-weight:700; font-size:13px; color:var(--text-primary);">الاسم الكامل *</label>
          <input type="text" id="editName" required class="form-control" style="width:100%; padding:10px; border:1px solid var(--border-color); border-radius:var(--radius-md);" value="${user.name}">
        </div>
        
        <div style="display:grid; grid-template-columns:1fr 1fr; gap:12px;">
          <div>
            <label style="display:block; margin-bottom:6px; font-weight:700; font-size:13px; color:var(--text-primary);">رقم الهاتف *</label>
            <input type="text" id="editPhone" required class="form-control" style="width:100%; padding:10px; border:1px solid var(--border-color); border-radius:var(--radius-md);" value="${user.phone}">
          </div>
          <div>
            <label style="display:block; margin-bottom:6px; font-weight:700; font-size:13px; color:var(--text-primary);">البريد الإلكتروني</label>
            <input type="email" id="editEmail" class="form-control" style="width:100%; padding:10px; border:1px solid var(--border-color); border-radius:var(--radius-md);" value="${user.email || ''}" placeholder="example@inride.com">
          </div>
        </div>

        <div>
          <label style="display:block; margin-bottom:6px; font-weight:700; font-size:13px; color:var(--text-primary);">العنوان</label>
          <input type="text" id="editAddress" class="form-control" style="width:100%; padding:10px; border:1px solid var(--border-color); border-radius:var(--radius-md);" value="${user.address || ''}" placeholder="المحافظة، المدينة، المنطقة">
        </div>

        <div>
          <label style="display:block; margin-bottom:6px; font-weight:700; font-size:13px; color:var(--text-primary);">التقييم</label>
          <input type="number" id="editRating" min="1" max="5" step="0.1" class="form-control" style="width:100%; padding:10px; border:1px solid var(--border-color); border-radius:var(--radius-md);" value="${user.rating}">
        </div>

        ${isDriver ? `
        <div style="border-top:1px solid var(--border-light); padding-top:14px; margin-top:6px;">
          <h4 style="font-weight:700; font-size:14px; margin-bottom:12px; color:var(--medium-blue);"><i class="ri-car-fill"></i> بيانات المركبة</h4>
          
          <div style="display:grid; grid-template-columns:1fr 1fr; gap:12px; margin-bottom:12px;">
            <div>
              <label style="display:block; margin-bottom:6px; font-weight:700; font-size:12px;">نوع المركبة *</label>
              <select id="editVehicleType" required class="form-control" style="width:100%; padding:10px; border:1px solid var(--border-color); border-radius:var(--radius-md); background:white;">
                <option value="car" ${user.vehicleType === 'car' ? 'selected' : ''}>عربية (Car)</option>
                <option value="scooter" ${user.vehicleType === 'scooter' ? 'selected' : ''}>اسكوتر (Scooter)</option>
                <option value="motorcycle" ${user.vehicleType === 'motorcycle' ? 'selected' : ''}>موتوسيكل (Motorcycle)</option>
              </select>
            </div>
            <div>
              <label style="display:block; margin-bottom:6px; font-weight:700; font-size:12px;">موديل/اسم المركبة *</label>
              <input type="text" id="editVehicleName" required class="form-control" style="width:100%; padding:10px; border:1px solid var(--border-color); border-radius:var(--radius-md);" value="${user.vehicleName || ''}">
            </div>
          </div>
          
          <div>
            <label style="display:block; margin-bottom:6px; font-weight:700; font-size:12px;">رقم لوحة المركبة *</label>
            <input type="text" id="editLicensePlate" required class="form-control" style="width:100%; padding:10px; border:1px solid var(--border-color); border-radius:var(--radius-md);" value="${user.licensePlate || ''}">
          </div>
        </div>
        ` : ''}

        <div style="display:flex; justify-content:flex-end; gap:10px; border-top:1px solid var(--border-color); padding-top:16px; margin-top:10px;">
          <button type="button" class="btn btn-outline" onclick="this.closest('.modal-backdrop').remove()">إلغاء</button>
          <button type="submit" class="btn btn-primary">حفظ التغييرات</button>
        </div>
      </form>
    </div>
  `;
  document.body.appendChild(modal);
}

function submitEditUser(uid, role) {
  const isDriver = role === 'driver';
  const name = document.getElementById('editName').value.trim();
  const phone = document.getElementById('editPhone').value.trim();
  const email = document.getElementById('editEmail').value.trim();
  const address = document.getElementById('editAddress').value.trim();
  const rating = parseFloat(document.getElementById('editRating').value) || 5.0;
  
  let vehicleType = '';
  let vehicleName = '';
  let licensePlate = '';
  
  if (isDriver) {
    vehicleType = document.getElementById('editVehicleType').value;
    vehicleName = document.getElementById('editVehicleName').value.trim();
    licensePlate = document.getElementById('editLicensePlate').value.trim();
  }

  const modal = document.querySelector('.modal-backdrop');
  if (modal) modal.remove();

  if (supabaseClient) {
    (async () => {
      try {
        const { error: userError } = await supabaseClient.from('users').update({
          name: name,
          phone_number: phone,
          email: email,
          address: address,
          rating: rating
        }).eq('id', uid);
        if (userError) throw userError;

        if (isDriver) {
          const { data: driverData, error: driverGetError } = await supabaseClient.from('drivers').select('vehicle_id').eq('id', uid).maybeSingle();
          if (!driverGetError && driverData && driverData.vehicle_id) {
            const { error: vehicleError } = await supabaseClient.from('vehicles').update({
              type: vehicleType,
              model: vehicleName,
              number_plate: licensePlate
            }).eq('id', driverData.vehicle_id);
            if (vehicleError) throw vehicleError;
          }
        }

        logAction(`تعديل بيانات المستخدم ${uid} (الاسم: ${name})`);
        showToast('✅ تم تحديث البيانات بنجاح');
        
        // If we are currently viewing this profile, refresh the profile page
        if (currentPage === 'driver-profile' || currentPage === 'passenger-profile') {
          viewUserProfile(uid, role);
        }
      } catch (err) {
        showToast(`❌ فشل التعديل: ${err.message}`);
      }
    })();
  } else {
    // Local fallback
    if (isDriver) {
      const d = mockData.drivers.find(dr => dr.uid === uid);
      if (d) {
        d.name = name;
        d.phone = phone;
        d.email = email;
        d.address = address;
        d.rating = rating;
        d.vehicleType = vehicleType;
        d.vehicleName = vehicleName;
        d.licensePlate = licensePlate;
        d.avatar = name.charAt(0);
        logAction(`تعديل بيانات السائق محلياً: ${uid}`);
        
        if (currentPage === 'driver-profile') {
          renderDriverProfile();
          renderPage('driver-profile');
        } else {
          renderPage('drivers');
        }
      }
    } else {
      const p = mockData.passengers.find(pass => pass.uid === uid);
      if (p) {
        p.name = name;
        p.phone = phone;
        p.email = email;
        p.address = address;
        p.rating = rating;
        p.avatar = name.charAt(0);
        logAction(`تعديل بيانات الراكب محلياً: ${uid}`);
        
        if (currentPage === 'passenger-profile') {
          renderPassengerProfile();
          renderPage('passenger-profile');
        } else {
          renderPage('passengers');
        }
      }
    }
    showToast('✅ تم التعديل محلياً (وضع التجربة)');
  }
}

function deleteUserPrompt(uid, role) {
  const isDriver = role === 'driver';
  const roleName = isDriver ? 'السائق' : 'الراكب';
  
  // Custom styled confirmation modal
  const modal = document.createElement('div');
  modal.className = 'modal-backdrop';
  modal.style.cssText = `
    position: fixed; top:0; left:0; width:100%; height:100%;
    background: rgba(0,0,0,0.5); z-index:10000;
    display:flex; align-items:center; justify-content:center;
    font-family: 'Cairo', sans-serif;
  `;
  
  modal.innerHTML = `
    <div style="background:white; padding:24px; border-radius:var(--radius-lg); width:450px; max-width:95%; box-shadow: 0 10px 25px rgba(0,0,0,0.2); direction:rtl; text-align:right;">
      <div style="display:flex; gap:16px; align-items:flex-start; margin-bottom:20px;">
        <div style="width:48px; height:48px; border-radius:50%; background:var(--error-bg); color:var(--error); display:flex; align-items:center; justify-content:center; font-size:24px; flex-shrink:0;">
          <i class="ri-error-warning-line"></i>
        </div>
        <div>
          <h3 style="font-weight:800; margin:0 0 8px 0; font-size:16px; color:var(--text-primary);">تحذير: حذف الحساب نهائياً</h3>
          <p style="font-size:13px; color:var(--text-secondary); margin:0;">هل أنت متأكد من رغبتك في حذف حساب هذا ${roleName} بالكامل؟ سيتم مسح كافة البيانات وسجلات التوثيق نهائياً من النظام ولا يمكن استرجاعها.</p>
        </div>
      </div>
      
      <div style="display:flex; justify-content:flex-end; gap:10px; border-top:1px solid var(--border-color); padding-top:16px;">
        <button type="button" class="btn btn-outline" onclick="this.closest('.modal-backdrop').remove()">إلغاء</button>
        <button type="button" class="btn btn-danger" onclick="submitDeleteUser('${uid}', '${role}')" style="background:var(--error); color:white;">نعم، احذف الحساب</button>
      </div>
    </div>
  `;
  document.body.appendChild(modal);
}

function submitDeleteUser(uid, role) {
  const isDriver = role === 'driver';
  const modal = document.querySelector('.modal-backdrop');
  if (modal) modal.remove();

  if (supabaseClient) {
    (async () => {
      try {
        if (isDriver) {
          const { data: driverData } = await supabaseClient.from('drivers').select('vehicle_id').eq('id', uid).maybeSingle();
          
          await supabaseClient.from('drivers').delete().eq('id', uid);

          if (driverData && driverData.vehicle_id) {
            await supabaseClient.from('vehicles').delete().eq('id', driverData.vehicle_id);
          }
        } else {
          await supabaseClient.from('passengers').delete().eq('id', uid);
        }

        const { error: userDeleteError } = await supabaseClient.from('users').delete().eq('id', uid);
        if (userDeleteError) throw userDeleteError;

        logAction(`حذف حساب مستخدم نهائياً: ${uid} (دور: ${role})`);
        showToast('❌ تم حذف حساب المستخدم بنجاح');
        
        if (currentPage === 'driver-profile' || currentPage === 'passenger-profile') {
          navigateTo(isDriver ? 'drivers' : 'passengers');
        } else {
          renderPage(currentPage);
        }
      } catch (err) {
        showToast(`❌ فشل الحذف: ${err.message}`);
      }
    })();
  } else {
    // Local fallback
    if (isDriver) {
      mockData.drivers = mockData.drivers.filter(d => d.uid !== uid);
      mockData.stats.activeDrivers = mockData.drivers.filter(d => d.isOnline).length;
      logAction(`حذف كابتن محلياً: ${uid}`);
      
      if (currentPage === 'driver-profile') {
        navigateTo('drivers');
      } else {
        renderPage('drivers');
      }
    } else {
      mockData.passengers = mockData.passengers.filter(p => p.uid !== uid);
      mockData.stats.totalPassengers = mockData.passengers.length;
      logAction(`حذف راكب محلياً: ${uid}`);
      
      if (currentPage === 'passenger-profile') {
        navigateTo('passengers');
      } else {
        renderPage('passengers');
      }
    }
    showToast('❌ تم الحذف محلياً (وضع التجربة)');
  }
}

function adjustWalletPrompt(uid, role) {
  const amountStr = prompt('ادخل القيمة لتعديل الرصيد (مثال: 50 للزيادة، -50 للخصم):');
  if (amountStr) {
    adjustUserWallet(uid, amountStr, role);
  }
}

// ---- WALLET ----
function renderWallet() {
  const totalIncome = mockData.stats.totalRevenue;
  const totalExpense = Math.round(totalIncome * 0.8);
  const netBalance = totalIncome - totalExpense;

  return `
    <div class="page-section">
      <!-- Wallet Cards -->
      <div class="stats-grid" style="grid-template-columns: repeat(3, 1fr); margin-bottom: 24px;">
        <div class="stat-card blue">
          <div class="stat-card-header">
            <div class="stat-card-icon"><i class="ri-wallet-3-fill"></i></div>
          </div>
          <div class="stat-card-value">${netBalance.toLocaleString()}</div>
          <div class="stat-card-label">صافي الرصيد (ج.م)</div>
        </div>
        <div class="stat-card green">
          <div class="stat-card-header">
            <div class="stat-card-icon"><i class="ri-arrow-down-circle-fill"></i></div>
          </div>
          <div class="stat-card-value">${totalIncome.toLocaleString()}</div>
          <div class="stat-card-label">إجمالي الإيرادات (ج.م)</div>
        </div>
        <div class="stat-card red">
          <div class="stat-card-header">
            <div class="stat-card-icon"><i class="ri-arrow-up-circle-fill"></i></div>
          </div>
          <div class="stat-card-value">${totalExpense.toLocaleString()}</div>
          <div class="stat-card-label">إجمالي المصروفات (ج.م)</div>
        </div>
      </div>

      <div class="grid-2">
        <!-- Wallet Balance Card -->
        <div class="wallet-card">
          <div class="wallet-card-content">
            <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:16px;">
              <span class="wallet-label">الرصيد المتاح</span>
              <i class="ri-wallet-3-fill" style="font-size:28px;opacity:0.7;"></i>
            </div>
            <div class="wallet-amount">${netBalance.toLocaleString()}</div>
            <div class="wallet-currency">جنيه مصري</div>
            <div style="margin-top:20px;display:flex;gap:12px;">
              <button class="btn" style="background:rgba(255,255,255,0.2);color:white;flex:1;" onclick="showToast('تم طلب سحب الرصيد')">
                <i class="ri-arrow-up-line"></i> سحب
              </button>
              <button class="btn" style="background:white;color:var(--medium-blue);flex:1;">
                <i class="ri-bar-chart-line"></i> تقرير
              </button>
            </div>
          </div>
        </div>

        <!-- Payment Methods -->
        <div class="card">
          <div class="card-header">
            <h3><i class="ri-bank-card-fill text-blue" style="margin-left:8px;"></i> طرق الدفع المقبولة</h3>
          </div>
          <div class="card-body">
            <div style="display:flex;flex-direction:column;gap:12px;">
              <div style="display:flex;align-items:center;justify-content:space-between;padding:14px;background:var(--bg-primary);border-radius:var(--radius-md);border:1px solid var(--border-color);">
                <div style="display:flex;align-items:center;gap:12px;">
                  <i class="ri-wallet-3-line" style="font-size:20px;color:var(--medium-blue);"></i>
                  <div>
                    <div style="font-weight:700;font-size:13px;">المحفظة</div>
                    <div style="font-size:11px;color:var(--text-light);">رصيد إلكتروني</div>
                  </div>
                </div>
                <i class="ri-check-line" style="color:var(--success);"></i>
              </div>
              <div style="display:flex;align-items:center;justify-content:space-between;padding:14px;background:var(--bg-primary);border-radius:var(--radius-md);border:1px solid var(--border-color);">
                <div style="display:flex;align-items:center;gap:12px;">
                  <i class="ri-visa-fill" style="font-size:20px;color:var(--medium-blue);"></i>
                  <div>
                    <div style="font-weight:700;font-size:13px;">فيزا كارد</div>
                    <div style="font-size:11px;color:var(--text-light);">دفع بالبطاقة</div>
                  </div>
                </div>
                <i class="ri-check-line" style="color:var(--success);"></i>
              </div>
              <div style="display:flex;align-items:center;justify-content:space-between;padding:14px;background:var(--bg-primary);border-radius:var(--radius-md);border:1px solid var(--border-color);">
                <div style="display:flex;align-items:center;gap:12px;">
                  <i class="ri-money-dollar-circle-line" style="font-size:20px;color:var(--medium-blue);"></i>
                  <div>
                    <div style="font-weight:700;font-size:13px;">كاش</div>
                    <div style="font-size:11px;color:var(--text-light);">الدفع نقداً</div>
                  </div>
                </div>
                <i class="ri-check-line" style="color:var(--success);"></i>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Transactions -->
      <div class="card mt-20">
        <div class="card-header">
          <h3><i class="ri-exchange-funds-fill text-blue" style="margin-left:8px;"></i> آخر المعاملات المالية</h3>
          <span class="text-light" style="font-size:13px;">${mockData.trips.filter(t => t.status === 'مكتملة').length} معاملة</span>
        </div>
        <div class="card-body">
          ${mockData.trips.filter(t => t.status === 'مكتملة').length === 0 ? `<div style="text-align:center;padding:16px;color:var(--text-light);">لا توجد معاملات مكتملة بعد</div>` : ''}
          ${mockData.trips.filter(t => t.status === 'مكتملة').map(trip => `
            <div class="transaction-item">
              <div class="transaction-info">
                <div class="transaction-icon income">
                  <i class="ri-arrow-down-line"></i>
                </div>
                <div class="transaction-text">
                  <h5>إيراد رحلة ${trip.id}</h5>
                  <span>${trip.date}</span>
                </div>
              </div>
              <div class="transaction-amount income">
                +${trip.price} ج.م
              </div>
            </div>
            <div class="transaction-item">
              <div class="transaction-info">
                <div class="transaction-icon expense">
                  <i class="ri-arrow-up-line"></i>
                </div>
                <div class="transaction-text">
                  <h5>مستحق سائق (${trip.driverName}) للرحلة ${trip.id}</h5>
                  <span>${trip.date}</span>
                </div>
              </div>
              <div class="transaction-amount expense">
                -${Math.round(trip.price * 0.8)} ج.م
              </div>
            </div>
          `).join('')}
        </div>
      </div>
    </div>
  `;
}

// ---- SETTINGS ----
function renderSettings() {
  return `
    <div class="page-section">
      <div class="grid-2">
        <!-- Vehicle Default Prices -->
        <div class="card">
          <div class="card-header">
            <h3><i class="ri-price-tag-3-fill text-blue" style="margin-left:8px;"></i> أسعار الرحلات الافتراضية</h3>
          </div>
          <div class="card-body">
            <div class="settings-group">
              <div class="settings-item">
                <div class="settings-item-info">
                  <div class="settings-item-icon">
                    <i class="ri-car-fill"></i>
                  </div>
                  <div class="settings-item-text">
                    <h5>عربية</h5>
                    <p>السعر الافتراضي للعربية</p>
                  </div>
                </div>
                <div style="display:flex;align-items:center;gap:8px;">
                  <input type="number" class="settings-input" value="${mockData.settings.defaultFareCar}" id="fareCar" onchange="updateSetting('defaultFareCar', this.value)">
                  <span style="font-size:12px;font-weight:700;color:var(--text-secondary);">ج.م</span>
                </div>
              </div>
              <div class="settings-item">
                <div class="settings-item-info">
                  <div class="settings-item-icon">
                    <i class="ri-e-bike-2-fill"></i>
                  </div>
                  <div class="settings-item-text">
                    <h5>اسكوتر</h5>
                    <p>السعر الافتراضي للاسكوتر</p>
                  </div>
                </div>
                <div style="display:flex;align-items:center;gap:8px;">
                  <input type="number" class="settings-input" value="${mockData.settings.defaultFareScooter}" id="fareScooter" onchange="updateSetting('defaultFareScooter', this.value)">
                  <span style="font-size:12px;font-weight:700;color:var(--text-secondary);">ج.م</span>
                </div>
              </div>
              <div class="settings-item">
                <div class="settings-item-info">
                  <div class="settings-item-icon">
                    <i class="ri-motorbike-fill"></i>
                  </div>
                  <div class="settings-item-text">
                    <h5>موتوسيكل</h5>
                    <p>السعر الافتراضي للموتوسيكل</p>
                  </div>
                </div>
                <div style="display:flex;align-items:center;gap:8px;">
                  <input type="number" class="settings-input" value="${mockData.settings.defaultFareMotorcycle}" id="fareMotorcycle" onchange="updateSetting('defaultFareMotorcycle', this.value)">
                  <span style="font-size:12px;font-weight:700;color:var(--text-secondary);">ج.م</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- App Settings -->
        <div class="card">
          <div class="card-header">
            <h3><i class="ri-settings-5-fill text-blue" style="margin-left:8px;"></i> إعدادات المنصة والعمولات</h3>
          </div>
          <div class="card-body">
            <div class="settings-group">
              <div class="settings-item">
                <div class="settings-item-info">
                  <div class="settings-item-icon">
                    <i class="ri-percent-fill"></i>
                  </div>
                  <div class="settings-item-text">
                    <h5>نسبة عمولة التطبيق</h5>
                    <p>النسبة التي يقتطعها التطبيق من الرحلة</p>
                  </div>
                </div>
                <div style="display:flex;align-items:center;gap:8px;">
                  <input type="number" class="settings-input" value="${mockData.settings.commissionRate}" id="commissionRate" onchange="updateSetting('commissionRate', this.value)">
                  <span style="font-size:12px;font-weight:700;color:var(--text-secondary);">%</span>
                </div>
              </div>
              <div class="settings-item">
                <div class="settings-item-info">
                  <div class="settings-item-icon">
                    <i class="ri-download-2-fill"></i>
                  </div>
                  <div class="settings-item-text">
                    <h5>الحد الأدنى لسعر الرحلة</h5>
                    <p>أقل قيمة مسموح بها للرحلة</p>
                  </div>
                </div>
                <div style="display:flex;align-items:center;gap:8px;">
                  <input type="number" class="settings-input" value="${mockData.settings.minFare}" id="minFare" onchange="updateSetting('minFare', this.value)">
                  <span style="font-size:12px;font-weight:700;color:var(--text-secondary);">ج.م</span>
                </div>
              </div>
              <div class="settings-item">
                <div class="settings-item-info">
                  <div class="settings-item-icon">
                    <i class="ri-upload-2-fill"></i>
                  </div>
                  <div class="settings-item-text">
                    <h5>الحد الأقصى لسعر الرحلة</h5>
                    <p>أعلى قيمة مسموح بها للرحلة</p>
                  </div>
                </div>
                <div style="display:flex;align-items:center;gap:8px;">
                  <input type="number" class="settings-input" value="${mockData.settings.maxFare}" id="maxFare" onchange="updateSetting('maxFare', this.value)">
                  <span style="font-size:12px;font-weight:700;color:var(--text-secondary);">ج.م</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Application Options -->
      <div class="card mt-20">
        <div class="card-header">
          <h3><i class="ri-apps-fill text-blue" style="margin-left:8px;"></i> خيارات التطبيق</h3>
        </div>
        <div class="card-body">
          <div class="settings-group">
            <div class="settings-item">
              <div class="settings-item-info">
                <div class="settings-item-icon">
                  <i class="ri-notification-3-fill"></i>
                </div>
                <div class="settings-item-text">
                  <h5>الإشعارات الفورية</h5>
                  <p>إرسال إشعارات للسائقين والركاب</p>
                </div>
              </div>
              <label class="toggle-switch">
                <input type="checkbox" checked>
                <span class="toggle-slider"></span>
              </label>
            </div>
            <div class="settings-item">
              <div class="settings-item-info">
                <div class="settings-item-icon">
                  <i class="ri-map-pin-fill"></i>
                </div>
                <div class="settings-item-text">
                  <h5>تتبع الموقع المباشر</h5>
                  <p>تتبع مواقع السائقين أثناء الرحلات</p>
                </div>
              </div>
              <label class="toggle-switch">
                <input type="checkbox" checked>
                <span class="toggle-slider"></span>
              </label>
            </div>
            <div class="settings-item">
              <div class="settings-item-info">
                <div class="settings-item-icon">
                  <i class="ri-shield-check-fill"></i>
                </div>
                <div class="settings-item-text">
                  <h5>الاعتماد التلقائي للسائقين</h5>
                  <p>اعتماد السائقين تلقائياً بعد رفع المستندات</p>
                </div>
              </div>
              <label class="toggle-switch">
                <input type="checkbox">
                <span class="toggle-slider"></span>
              </label>
            </div>
            <div class="settings-item">
              <div class="settings-item-info">
                <div class="settings-item-icon">
                  <i class="ri-global-fill"></i>
                </div>
                <div class="settings-item-text">
                  <h5>لغة التطبيق</h5>
                  <p>اللغة الافتراضية للتطبيق</p>
                </div>
              </div>
              <span style="font-size:13px;font-weight:700;color:var(--text-primary);">العربية</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Save Button -->
      <div id="settings-save-container" style="display:${settingsDirty ? 'flex' : 'none'};justify-content:flex-end;margin-top:24px;">
        <button class="btn btn-primary" onclick="saveSettings()">
          <i class="ri-check-line"></i> حفظ الإعدادات
        </button>
      </div>
    </div>
  `;
}

function updateSetting(key, value) {
  const parsedVal = parseFloat(value);
  if (mockData.settings[key] !== parsedVal) {
    mockData.settings[key] = parsedVal;
    settingsDirty = true;
    renderPage(currentPage);
  }
}

async function saveSettings() {
  if (supabaseClient) {
    try {
      const updateObj = {
        default_fare_car: mockData.settings.defaultFareCar,
        default_fare_scooter: mockData.settings.defaultFareScooter,
        default_fare_motorcycle: mockData.settings.defaultFareMotorcycle,
        commission_rate: mockData.settings.commissionRate,
        min_fare: mockData.settings.minFare,
        max_fare: mockData.settings.maxFare,
        first_km_fare: mockData.settings.first_km_fare || 20,
        extra_km_fare: mockData.settings.extra_km_fare || 5,
        ac_km_fare: mockData.settings.ac_km_fare || 1,
        heat_hour_km_fare: mockData.settings.heat_hour_km_fare || 1,
        heat_start_hour: mockData.settings.heat_start_hour || 11,
        heat_end_hour: mockData.settings.heat_end_hour || 15
      };

      const { error } = await supabaseClient
        .from('app_settings')
        .upsert({ id: 'default', ...updateObj });

      if (!error) {
        settingsDirty = false;
        renderPage(currentPage);
        showToast('✅ تم حفظ الإعدادات في Supabase بنجاح');
      } else {
        showToast(`❌ فشل حفظ الإعدادات في Supabase: ${error.message}`);
      }
    } catch (e) {
      showToast(`❌ خطأ: ${e.message}`);
    }
  } else {
    settingsDirty = false;
    renderPage(currentPage);
    showToast('✅ تم حفظ الإعدادات محلياً (وضع التجربة)');
  }
}

// ============================================
// TOAST NOTIFICATIONS
// ============================================

// ============================================
// OPERATIONS DASHBOARD - EXTRA STATE & RENDERING FUNCTIONS
// ============================================

// Extend mockData with support tickets, coupons, banners, and audit logs
mockData.supportTickets = [
  { id: 'TKT-9102', user: 'محمد أحمد', type: 'راكب', subject: 'تأخر الكابتن في الوصول', date: 'اليوم، 12:30', status: 'open', statusAr: 'جديد', replies: [{ sender: 'user', text: 'الكابتن واقف بعيد ومبيتحركش وعايزني ألغي' }] },
  { id: 'TKT-8291', user: 'عمر خالد', type: 'سائق', subject: 'مشكلة في احتساب عمولة الرحلة', date: 'أمس، 18:15', status: 'pending', statusAr: 'قيد المتابعة', replies: [{ sender: 'user', text: 'تم خصم عمولة أعلى من 10%' }, { sender: 'admin', text: 'جاري مراجعة سجلات الرحلة المالية' }] },
  { id: 'TKT-7128', user: 'سارة يوسف', type: 'راكب', subject: 'نسيت حقيبة اليد بالسيارة', date: '14 يوليو 2026', status: 'resolved', statusAr: 'تم الحل', replies: [{ sender: 'user', text: 'الحمد لله تم التواصل واستلام الحقيبة من الكابتن شكراً لكم' }] }
];

mockData.coupons = [
  { code: 'RIDE20', discount: 20, maxUsage: 100, used: 45, status: 'active' },
  { code: 'EID50', discount: 50, maxUsage: 500, used: 500, status: 'expired' }
];

mockData.banners = [
  { id: 'ban1', title: 'خصم 50% على رحلتك الأولى', image: 'https://images.unsplash.com/photo-1449965408869-eaa3f722e40d?q=80&w=300', active: true },
  { id: 'ban2', title: 'سافر بأمان مع درع الحماية الجديد', image: 'https://images.unsplash.com/photo-1549317661-bd32c8ce0db2?q=80&w=300', active: true }
];

mockData.auditLogs = [
  { employee: 'أحمد محمد', role: 'مدير النظام', action: 'تعديل أسعار رحلات السيارات', date: 'اليوم، 14:10', ip: '197.34.120.12' },
  { employee: 'أحمد محمد', role: 'مدير النظام', action: 'اعتماد السائق كابتن هاني سليم', date: 'اليوم، 11:22', ip: '197.34.120.12' },
  { employee: 'رشا أحمد', role: 'عميل دعم', action: 'حل تذكرة الشكوى TKT-7128', date: 'أمس، 15:40', ip: '197.22.90.15' }
];

mockData.monitoringStats = {
  onlineUsers: 142,
  availableDrivers: 38,
  activeTrips: 12,
  serverStatus: 'ممتاز',
  serverLatency: '32ms',
  dbConnected: true,
  maintenanceMode: false,
  registrationOpen: true,
  driverRegistrationOpen: true,
  tripReceivingOpen: true,
  minAppVersion: '2.0.4'
};

// Current active support ticket ID for reply chat
let activeTicketId = null;

// Track actions in AuditLogs
function logAction(action) {
  const newLog = {
    employee: 'أحمد محمد',
    role: 'مدير النظام',
    action: action,
    date: new Date().toLocaleString('ar-EG'),
    ip: '197.34.120.12'
  };
  mockData.auditLogs.unshift(newLog);
  
  if (supabaseClient) {
    supabaseClient.from('audit_logs').insert({
      employee: 'أحمد محمد',
      role: 'مدير النظام',
      action: action,
      ip: '197.34.120.12',
      created_at: new Date().toISOString()
    }).then(({ error }) => {
      if (error) console.error("Error adding audit log to Supabase:", error);
    }).catch(err => console.error("Error adding audit log:", err));
  }
}

// ---- PRICING & REGIONS ----
function renderPricing() {
  return `
    <div class="page-section">
      <div class="stats-grid" style="grid-template-columns: repeat(3, 1fr); margin-bottom: 24px;">
        <div class="stat-card blue">
          <div class="stat-card-label">سعر الكيلومتر الأول</div>
          <div class="stat-card-value font-outfit">${mockData.settings.first_km_fare || 20} <span style="font-size:16px;">ج.م</span></div>
        </div>
        <div class="stat-card green">
          <div class="stat-card-label">سعر الكيلومتر الإضافي</div>
          <div class="stat-card-value font-outfit">${mockData.settings.extra_km_fare || 5} <span style="font-size:16px;">ج.م</span></div>
        </div>
        <div class="stat-card red">
          <div class="stat-card-label">إضافة ساعة الحر (11-3)</div>
          <div class="stat-card-value font-outfit">+${mockData.settings.heat_hour_km_fare || 1} <span style="font-size:16px;">ج.م</span></div>
        </div>
      </div>

      <div style="display:grid;grid-template-columns: 2fr 1fr; gap:24px;">
        <!-- Pricing settings form -->
        <div class="card">
          <div class="card-header">
            <h3><i class="ri-price-tag-3-line text-blue" style="margin-left:8px;"></i> إدارة قواعد التسعير والعمولات الديناميكية</h3>
          </div>
          <div class="card-body">
            <div style="display:grid; grid-template-columns:1fr 1fr; gap:20px; margin-bottom:20px;">
              <div>
                <label class="form-label" style="display:block;margin-bottom:8px;font-weight:700;">تسعيرة الكيلومتر الأول شامل الأول (First 1 Km)</label>
                <input type="number" class="form-control" style="width:100%;padding:10px;border:1px solid var(--border-color);border-radius:var(--radius-md);" value="${mockData.settings.first_km_fare || 20}" onchange="updateSetting('first_km_fare', this.value)">
              </div>
              <div>
                <label class="form-label" style="display:block;margin-bottom:8px;font-weight:700;">سعر الكيلومتر الإضافي (Extra Km Fare)</label>
                <input type="number" class="form-control" style="width:100%;padding:10px;border:1px solid var(--border-color);border-radius:var(--radius-md);" value="${mockData.settings.extra_km_fare || 5}" onchange="updateSetting('extra_km_fare', this.value)">
              </div>
              <div>
                <label class="form-label" style="display:block;margin-bottom:8px;font-weight:700;">إضافة تكييف السيارة لكل كم (Car AC Surcharge)</label>
                <input type="number" class="form-control" style="width:100%;padding:10px;border:1px solid var(--border-color);border-radius:var(--radius-md);" value="${mockData.settings.ac_km_fare || 1}" onchange="updateSetting('ac_km_fare', this.value)">
              </div>
              <div>
                <label class="form-label" style="display:block;margin-bottom:8px;font-weight:700;">إضافة ساعة الحر لكل كم (Heat Surge Surcharge)</label>
                <input type="number" class="form-control" style="width:100%;padding:10px;border:1px solid var(--border-color);border-radius:var(--radius-md);" value="${mockData.settings.heat_hour_km_fare || 1}" onchange="updateSetting('heat_hour_km_fare', this.value)">
              </div>
              <div>
                <label class="form-label" style="display:block;margin-bottom:8px;font-weight:700;">ساعة بدء الحر (تبدأ من: 11 مثلاً)</label>
                <input type="number" class="form-control" style="width:100%;padding:10px;border:1px solid var(--border-color);border-radius:var(--radius-md);" value="${mockData.settings.heat_start_hour || 11}" onchange="updateSetting('heat_start_hour', this.value)">
              </div>
              <div>
                <label class="form-label" style="display:block;margin-bottom:8px;font-weight:700;">ساعة انتهاء الحر (تنتهي في: 15 مثلاً)</label>
                <input type="number" class="form-control" style="width:100%;padding:10px;border:1px solid var(--border-color);border-radius:var(--radius-md);" value="${mockData.settings.heat_end_hour || 15}" onchange="updateSetting('heat_end_hour', this.value)">
              </div>
              
              <div>
                <label class="form-label" style="display:block;margin-bottom:8px;font-weight:700;">تسعيرة السيارة الافتراضية (Car Base)</label>
                <input type="number" class="form-control" style="width:100%;padding:10px;border:1px solid var(--border-color);border-radius:var(--radius-md);" value="${mockData.settings.defaultFareCar}" onchange="updateSetting('defaultFareCar', this.value)">
              </div>
              <div>
                <label class="form-label" style="display:block;margin-bottom:8px;font-weight:700;">تسعيرة الاسكوتر الافتراضية (Scooter Base)</label>
                <input type="number" class="form-control" style="width:100%;padding:10px;border:1px solid var(--border-color);border-radius:var(--radius-md);" value="${mockData.settings.defaultFareScooter}" onchange="updateSetting('defaultFareScooter', this.value)">
              </div>
              <div>
                <label class="form-label" style="display:block;margin-bottom:8px;font-weight:700;">تسعيرة الموتوسيكل الافتراضية (Motorcycle Base)</label>
                <input type="number" class="form-control" style="width:100%;padding:10px;border:1px solid var(--border-color);border-radius:var(--radius-md);" value="${mockData.settings.defaultFareMotorcycle}" onchange="updateSetting('defaultFareMotorcycle', this.value)">
              </div>
              <div>
                <label class="form-label" style="display:block;margin-bottom:8px;font-weight:700;">عمولة التطبيق (Platform Commission %)</label>
                <input type="number" class="form-control" style="width:100%;padding:10px;border:1px solid var(--border-color);border-radius:var(--radius-md);" value="${mockData.settings.commissionRate}" onchange="updateSetting('commissionRate', this.value)">
              </div>
              <div>
                <label class="form-label" style="display:block;margin-bottom:8px;font-weight:700;">الحد الأدنى للأجرة (Min Fare)</label>
                <input type="number" class="form-control" style="width:100%;padding:10px;border:1px solid var(--border-color);border-radius:var(--radius-md);" value="${mockData.settings.minFare}" onchange="updateSetting('minFare', this.value)">
              </div>
              <div>
                <label class="form-label" style="display:block;margin-bottom:8px;font-weight:700;">الحد الأقصى للأجرة (Max Fare)</label>
                <input type="number" class="form-control" style="width:100%;padding:10px;border:1px solid var(--border-color);border-radius:var(--radius-md);" value="${mockData.settings.maxFare}" onchange="updateSetting('maxFare', this.value)">
              </div>
            </div>
            
            <div id="pricing-save-container" style="display:${settingsDirty ? 'flex' : 'none'};justify-content:flex-end;">
              <button class="btn btn-primary" onclick="saveSettings(); logAction('تحديث إعدادات التسعير والعمولات');">
                <i class="ri-save-line"></i> حفظ إعدادات الأسعار
              </button>
            </div>
          </div>
        </div>

        <!-- Surge Pricing and Regions -->
        <div class="card">
          <div class="card-header">
            <h3><i class="ri-map-pin-2-line text-blue" style="margin-left:8px;"></i> ذروة الأسعار (Surge)</h3>
          </div>
          <div class="card-body">
            <div style="background:var(--bg-primary);padding:14px;border-radius:var(--radius-md);margin-bottom:16px;">
              <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:10px;">
                <span style="font-weight:700;font-size:13px;">تفعيل ذروة الأسعار الذكي</span>
                <input type="checkbox" checked style="width:40px;height:20px;cursor:pointer;" onchange="logAction('تغيير وضع Surge pricing المجدول')">
              </div>
              <p style="font-size:11px;color:var(--text-secondary);">يقوم برفع الأسعار بنسبة 1.2x إلى 1.8x تلقائياً في حالة زيادة طلبات العملاء عن السائقين المتاحين.</p>
            </div>

            <div style="border-top:1px solid var(--border-color);padding-top:14px;">
              <h4 style="font-size:13px;font-weight:700;margin-bottom:12px;">تسعير خاص بالمناطق</h4>
              <div style="display:flex;gap:6px;flex-direction:column;">
                <div style="display:flex;justify-content:space-between;font-size:12px;padding:8px 0;border-bottom:1px solid var(--border-light);">
                  <span>القاهرة الكبرى</span>
                  <span style="font-weight:700;color:var(--medium-blue);">افتراضي</span>
                </div>
                <div style="display:flex;justify-content:space-between;font-size:12px;padding:8px 0;border-bottom:1px solid var(--border-light);">
                  <span>الإسكندرية (الساحل)</span>
                  <span style="font-weight:700;color:var(--success);">+5 ج.م (إضافي)</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  `;
}

// ---- MESSAGES & NOTIFICATIONS ----
function renderMessages() {
  return `
    <div class="page-section">
      <!-- Top Grid: Form & Preview -->
      <div style="display:grid;grid-template-columns: 1.2fr 1fr; gap:24px; margin-bottom: 24px;">
        <!-- Notification Form -->
        <div class="card">
          <div class="card-header">
            <h3><i class="ri-notification-badge-line text-blue" style="margin-left:8px;"></i> إرسال إشعار فوري / مجدول</h3>
          </div>
          <div class="card-body">
            <div style="display:grid; grid-template-columns: 1fr 1fr; gap:16px; margin-bottom:16px;">
              <div>
                <label style="display:block;margin-bottom:8px;font-weight:700;font-size:13px;">الفئة المستهدفة</label>
                <select id="notifTarget" class="form-control" style="width:100%;padding:10px;border:1px solid var(--border-color);border-radius:var(--radius-md);" onchange="toggleNotificationTargetFields(this.value)">
                  <option value="all">جميع المستخدمين (سائقين وركاب)</option>
                  <option value="riders">الركاب فقط</option>
                  <option value="drivers">السائقين فقط</option>
                  <option value="specific">مستخدم محدد (UID)</option>
                  <option value="city">حسب المدينة</option>
                </select>
              </div>

              <div>
                <label style="display:block;margin-bottom:8px;font-weight:700;font-size:13px;">نوع الإشعار</label>
                <select id="notifType" class="form-control" style="width:100%;padding:10px;border:1px solid var(--border-color);border-radius:var(--radius-md);" onchange="updatePreview()">
                  <option value="admin_notifications">إشعار إداري / عام</option>
                  <option value="offers">عرض ترويجي / خصم</option>
                  <option value="app_updates">تحديث التطبيق</option>
                </select>
              </div>
            </div>

            <div id="specificUserContainer" style="margin-bottom:16px; display:none;">
              <label style="display:block;margin-bottom:8px;font-weight:700;font-size:13px;">كود المستخدم الفريد (UID)</label>
              <input type="text" id="notifUid" class="form-control" style="width:100%;padding:10px;border:1px solid var(--border-color);border-radius:var(--radius-md);" placeholder="مثال: qW2eR3tY4uI5oP6">
            </div>

            <div id="cityUserContainer" style="margin-bottom:16px; display:none;">
              <label style="display:block;margin-bottom:8px;font-weight:700;font-size:13px;">المدينة المستهدفة</label>
              <select id="notifCity" class="form-control" style="width:100%;padding:10px;border:1px solid var(--border-color);border-radius:var(--radius-md);">
                <option value="مدينة السادات">مدينة السادات</option>
                <option value="القاهرة">القاهرة</option>
                <option value="الجيزة">الجيزة</option>
                <option value="الإسكندرية">الإسكندرية</option>
                <option value="طنطا">طنطا</option>
              </select>
            </div>

            <div style="margin-bottom:16px;">
              <label style="display:block;margin-bottom:8px;font-weight:700;font-size:13px;">عنوان الإشعار</label>
              <input type="text" id="notifTitle" class="form-control" style="width:100%;padding:10px;border:1px solid var(--border-color);border-radius:var(--radius-md);" placeholder="اكتب عنواناً جذاباً..." oninput="updatePreview()">
            </div>

            <div style="margin-bottom:16px;">
              <label style="display:block;margin-bottom:8px;font-weight:700;font-size:13px;">نص الرسالة</label>
              <textarea id="notifBody" rows="3" class="form-control" style="width:100%;padding:10px;border:1px solid var(--border-color);border-radius:var(--radius-md);resize:vertical;" placeholder="اكتب نص الإشعار بالكامل هنا..." oninput="updatePreview()"></textarea>
            </div>

            <div style="margin-bottom:20px;display:flex;gap:12px;align-items:center;">
              <div style="flex:1;">
                <label style="display:block;margin-bottom:8px;font-weight:700;font-size:13px;">جدولة الإشعار (اختياري)</label>
                <input type="datetime-local" id="notifSchedule" class="form-control" style="width:100%;padding:8px;border:1px solid var(--border-color);border-radius:var(--radius-md);">
              </div>
            </div>

            <div style="display:flex;justify-content:flex-end;">
              <button class="btn btn-primary" onclick="sendCustomNotification()">
                <i class="ri-send-plane-fill" style="margin-left:6px;"></i> إرسال الإشعار الآن
              </button>
            </div>
          </div>
        </div>

        <!-- Phone Preview -->
        <div class="card">
          <div class="card-header" style="display:flex;justify-content:space-between;align-items:center;">
            <h3><i class="ri-smartphone-line text-blue" style="margin-left:8px;"></i> معاينة الإشعار الفورية</h3>
            <div style="display:flex;gap:10px;font-size:12px;">
              <label style="cursor:pointer;display:flex;align-items:center;gap:4px;">
                <input type="radio" name="previewMode" id="previewModeLock" checked onchange="updatePreview()"> قفل الشاشة
              </label>
              <label style="cursor:pointer;display:flex;align-items:center;gap:4px;">
                <input type="radio" name="previewMode" id="previewModeForeground" onchange="updatePreview()"> داخل التطبيق
              </label>
            </div>
          </div>
          <div class="card-body" style="display:flex;justify-content:center;align-items:center;padding:12px;background:#f5f5f5;">
            <div id="mobilePreviewContainer" style="width:100%;max-width:280px;">
              <!-- Dynamic Phone mockup will render here -->
            </div>
          </div>
        </div>
      </div>

      <!-- Bottom Row: Templates & Sent History -->
      <div style="display:grid;grid-template-columns: 1fr 2fr; gap:24px;">
        <!-- Templates List -->
        <div class="card">
          <div class="card-header">
            <h3><i class="ri-file-list-line text-blue" style="margin-left:8px;"></i> قوالب جاهزة للإشعارات</h3>
          </div>
          <div class="card-body" style="display:flex;flex-direction:column;gap:12px;max-height:400px;overflow-y:auto;">
            <div style="padding:12px;background:var(--bg-primary);border-radius:var(--radius-md);border-right:4px solid var(--medium-blue);cursor:pointer;" onclick="loadTemplate('تنبيه المستندات الناقصة', 'عزيزي الكابتن، يرجى استكمال رفع صورة رخصة القيادة السارية لتفعيل الحساب بالكامل.', 'admin_notifications')">
              <h4 style="font-size:12px;font-weight:700;margin-bottom:4px;">تنبيه المستندات الناقصة 🔒</h4>
              <p style="font-size:10px;color:var(--text-secondary);margin:0;">عزيزي الكابتن، يرجى استكمال رفع صورة رخصة القيادة السارية...</p>
            </div>
            
            <div style="padding:12px;background:var(--bg-primary);border-radius:var(--radius-md);border-right:4px solid var(--success);cursor:pointer;" onclick="loadTemplate('عروض بايك نهاية الأسبوع', 'استمتع بخصم 25% على جميع مشاوير الويك إند باستخدام كوبون RIDE20. اطلب بايك دلوقتي!', 'offers')">
              <h4 style="font-size:12px;font-weight:700;margin-bottom:4px;">عروض نهاية الأسبوع 🔥</h4>
              <p style="font-size:10px;color:var(--text-secondary);margin:0;">استمتع بخصم 25% على جميع مشاوير الويك إند باستخدام...</p>
            </div>

            <div style="padding:12px;background:var(--bg-primary);border-radius:var(--radius-md);border-right:4px solid #607d8b;cursor:pointer;" onclick="loadTemplate('تحديث جديد للتطبيق', 'يتوفر إصدار جديد من تطبيق inRide الآن. يرجى التحديث لتجربة أفضل ومميزات أكثر أماناً.', 'app_updates')">
              <h4 style="font-size:12px;font-weight:700;margin-bottom:4px;">تحديث جديد متوفر 🚀</h4>
              <p style="font-size:10px;color:var(--text-secondary);margin:0;">يتوفر إصدار جديد من تطبيق inRide الآن. يرجى التحديث لتجربة...</p>
            </div>
          </div>
        </div>

        <!-- Sent Notifications History -->
        <div class="card">
          <div class="card-header">
            <h3><i class="ri-history-line text-blue" style="margin-left:8px;"></i> سجل الإشعارات المرسلة</h3>
          </div>
          <div class="card-body" style="padding:0;max-height:400px;overflow-y:auto;" id="notifHistoryList">
            <!-- Dynamically populated from Firestore -->
            <div style="text-align:center;color:var(--text-light);padding:20px;">جاري تحميل السجل...</div>
          </div>
        </div>
      </div>
    </div>
  `;
}

function toggleNotificationTargetFields(val) {
  const specificEl = document.getElementById('specificUserContainer');
  const cityEl = document.getElementById('cityUserContainer');
  if (specificEl) specificEl.style.display = val === 'specific' ? 'block' : 'none';
  if (cityEl) cityEl.style.display = val === 'city' ? 'block' : 'none';
}

function loadTemplate(title, body, type) {
  const tEl = document.getElementById('notifTitle');
  const bEl = document.getElementById('notifBody');
  const typeEl = document.getElementById('notifType');
  if (tEl && bEl && typeEl) {
    tEl.value = title;
    bEl.value = body;
    typeEl.value = type;
    updatePreview();
    showToast('📋 تم تحميل قالب الرسالة');
  }
}

function updatePreview() {
  const title = document.getElementById('notifTitle').value || 'عنوان الإشعار';
  const body = document.getElementById('notifBody').value || 'نص الإشعار يظهر هنا بالتفصيل عند كتابته...';
  const type = document.getElementById('notifType').value;
  const isForeground = document.getElementById('previewModeForeground').checked;

  const previewContainer = document.getElementById('mobilePreviewContainer');
  if (!previewContainer) return;

  // Icons and colors configuration
  let iconClass = 'ri-notification-3-fill';
  let iconColor = '#1e88e5'; // Blue
  let typeLabel = 'إشعار إداري';

  if (type === 'offers') {
    iconClass = 'ri-price-tag-3-fill';
    iconColor = '#9c27b0'; // Purple
    typeLabel = 'عرض خاص';
  } else if (type === 'app_updates') {
    iconClass = 'ri-refresh-line';
    iconColor = '#607d8b'; // Grey Blue
    typeLabel = 'تحديث التطبيق';
  }

  if (isForeground) {
    previewContainer.innerHTML = `
      <div style="width:100%;padding:10px;background:#eef2f3;border-radius:20px;height:320px;display:flex;flex-direction:column;justify-content:flex-start;align-items:center;position:relative;border:8px solid #222;box-sizing:border-box;">
        <div style="width:50px;height:4px;background:#222;border-radius:2px;margin-bottom:12px;"></div>
        <!-- Toast mockup -->
        <div style="width:96%;background:white;border-radius:12px;box-shadow:0 6px 12px rgba(0,0,0,0.12);padding:10px 12px;display:flex;align-items:center;border:1px solid #e0e0e0;box-sizing:border-box;direction:rtl;margin-top:5px;">
          <div style="width:34px;height:34px;border-radius:50%;background:${iconColor}22;display:flex;align-items:center;justify-content:center;margin-left:10px;flex-shrink:0;">
            <i class="${iconClass}" style="color:${iconColor};font-size:16px;"></i>
          </div>
          <div style="flex:1;min-width:0;text-align:right;">
            <h5 style="font-size:11px;font-weight:700;margin:0;color:#222;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">${title}</h5>
            <p style="font-size:9.5px;color:#666;margin:2px 0 0 0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">${body}</p>
          </div>
          <div style="color:#aaa;font-size:12px;margin-right:6px;"><i class="ri-close-line"></i></div>
        </div>
        
        <!-- Screen details mockup -->
        <div style="flex:1;display:flex;flex-direction:column;justify-content:center;align-items:center;opacity:0.25;">
          <i class="ri-map-pin-2-line" style="font-size:42px;color:#888;"></i>
          <span style="font-size:9px;font-weight:bold;margin-top:6px;">inRide 2026</span>
        </div>
      </div>
    `;
  } else {
    previewContainer.innerHTML = `
      <div style="width:100%;padding:10px;background:linear-gradient(to bottom, #111 20%, #444);border-radius:20px;height:320px;display:flex;flex-direction:column;justify-content:flex-start;align-items:center;position:relative;border:8px solid #222;box-sizing:border-box;color:white;">
        <div style="width:50px;height:4px;background:#222;border-radius:2px;margin-bottom:12px;z-index:2;"></div>
        <!-- Time and Status bar -->
        <div style="width:90%;display:flex;justify-content:space-between;font-size:9px;color:rgba(255,255,255,0.7);margin-bottom:15px;direction:rtl;z-index:2;">
          <span>١٢:٣٠ م</span>
          <div style="display:flex;gap:4px;">
            <i class="ri-wifi-line"></i>
            <i class="ri-battery-fill"></i>
          </div>
        </div>

        <!-- Lockscreen Time -->
        <div style="text-align:center;margin-bottom:24px;z-index:2;">
          <h2 style="font-size:28px;font-weight:300;margin:0;font-family:'Outfit',sans-serif;">12:30</h2>
          <p style="font-size:9px;color:rgba(255,255,255,0.8);margin:2px 0 0 0;">الجمعة، ١٧ يوليو</p>
        </div>
        
        <!-- Lockscreen Notification Card -->
        <div style="width:96%;background:rgba(255,255,255,0.18);backdrop-filter:blur(8px);border-radius:12px;padding:10px 12px;box-sizing:border-box;direction:rtl;z-index:2;">
          <div style="display:flex;justify-content:space-between;align-items:center;font-size:8px;color:rgba(255,255,255,0.85);margin-bottom:6px;">
            <div style="display:flex;align-items:center;gap:4px;">
              <div style="width:14px;height:14px;border-radius:3px;background:#1e88e5;display:flex;align-items:center;justify-content:center;">
                <span style="font-size:7px;font-weight:bold;color:white;font-family:'Outfit';">iR</span>
              </div>
              <span style="font-weight:bold;">inRide</span>
              <span style="opacity:0.75;">• ${typeLabel}</span>
            </div>
            <span>الآن</span>
          </div>
          <h5 style="font-size:10.5px;font-weight:700;margin:0;color:white;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">${title}</h5>
          <p style="font-size:9.5px;color:rgba(255,255,255,0.9);margin:4px 0 0 0;line-height:1.3;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;">${body}</p>
        </div>
      </div>
    `;
  }
}

function sendCustomNotification() {
  const title = document.getElementById('notifTitle').value.trim();
  const body = document.getElementById('notifBody').value.trim();
  const target = document.getElementById('notifTarget').value;
  const type = document.getElementById('notifType').value;
  const scheduleTime = document.getElementById('notifSchedule').value;
  
  let targetUid = '';
  let targetCity = '';

  if (target === 'specific') {
    targetUid = document.getElementById('notifUid').value.trim();
    if (!targetUid) {
      showToast('⚠️ يرجى إدخال كود المعرف UID الخاص بالمستخدم المستهدف');
      return;
    }
  } else if (target === 'city') {
    targetCity = document.getElementById('notifCity').value;
  }

  if (!title || !body) {
    showToast('⚠️ يرجى كتابة عنوان الإشعار والرسالة أولاً');
    return;
  }

  if (supabaseClient) {
    (async () => {
      try {
        const notifId = generateUUID();
        const notifData = {
          id: notifId,
          title: title,
          body: body,
          type: type,
          target: target,
          target_uid: targetUid || null,
          target_city: targetCity || null,
          created_at: new Date().toISOString(),
          scheduled_at: scheduleTime ? new Date(scheduleTime).toISOString() : null,
          sent: scheduleTime ? false : true,
        };

        const { error: notifError } = await supabaseClient.from('admin_notifications').insert(notifData);
        if (notifError) throw notifError;

        if (!scheduleTime && target === 'specific') {
          const { error: userNotifError } = await supabaseClient.from('notifications').insert({
            id: generateUUID(),
            user_id: targetUid,
            title: title,
            body: body,
            type: type,
            created_at: new Date().toISOString(),
            is_read: false,
            data: {
              id: notifId,
              adminNotificationId: notifId,
              type: type,
              recipientId: targetUid
            }
          });
          if (userNotifError) throw userNotifError;
        }

        showToast(scheduleTime ? '✅ تم جدولة الإشعار بنجاح' : '✅ تم إرسال الإشعار لجميع الأجهزة النشطة بنجاح');
        
        document.getElementById('notifTitle').value = '';
        document.getElementById('notifBody').value = '';
        document.getElementById('notifSchedule').value = '';
        if (document.getElementById('notifUid')) {
          document.getElementById('notifUid').value = '';
        }
        updatePreview();
        logAction(`إرسال إشعار (${title}) الفئة: ${target}`);
      } catch (err) {
        showToast(`❌ فشل في إرسال الإشعار: ${err.message}`);
      }
    })();
  } else {
    showToast('✅ تم المحاكاة محلياً بنجاح (بدون اتصال قاعدة بيانات)');
  }
}

function initMessagesPage() {
  updatePreview();

  if (supabaseClient) {
    const fetchHistory = async () => {
      const { data: notificationsList, error } = await supabaseClient
        .from('admin_notifications')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(10);
      
      const historyContainer = document.getElementById('notifHistoryList');
      if (!historyContainer) return;

      if (error || !notificationsList || notificationsList.length === 0) {
        historyContainer.innerHTML = '<div style="text-align:center;color:var(--text-light);padding:20px;">لا توجد إشعارات مرسلة مسبقاً.</div>';
        return;
      }

      let html = '';
      for (const notif of notificationsList) {
        const id = notif.id;
        const dateObj = new Date(notif.created_at || Date.now());
        const date = dateObj.toLocaleString('ar-EG');
        
        const isScheduled = notif.scheduled_at && new Date(notif.scheduled_at) > new Date();
        const statusText = isScheduled ? 'مجدول' : 'تم الإرسال';
        const statusClass = isScheduled ? 'submitted' : 'completed';
        
        let targetText = '';
        if (notif.target === 'all') targetText = 'الكل';
        else if (notif.target === 'drivers') targetText = 'الكباتن فقط';
        else if (notif.target === 'riders') targetText = 'الركاب فقط';
        else if (notif.target === 'specific') targetText = `مستخدم: ${(notif.target_uid || '').substring(0, 6)}...`;
        else if (notif.target === 'city') targetText = `مدينة: ${notif.target_city}`;

        html += `
          <div style="padding:14px;border-bottom:1px solid var(--border-light);display:flex;justify-content:space-between;align-items:center;">
            <div>
              <h4 style="font-size:13px;font-weight:700;margin-bottom:4px;color:var(--text-primary);">${notif.title}</h4>
              <p style="font-size:11px;color:var(--text-secondary);margin-bottom:6px;max-width:250px;text-overflow:ellipsis;overflow:hidden;white-space:nowrap;">${notif.body}</p>
              <div style="display:flex;gap:10px;font-size:10px;color:var(--text-light);">
                <span>الهدف: <strong>${targetText}</strong></span>
                <span>•</span>
                <span>التاريخ: ${date}</span>
              </div>
            </div>
            <div style="text-align:left;display:flex;flex-direction:column;align-items:flex-end;gap:6px;">
              <span class="status-badge ${statusClass}" style="font-size:10px;padding:3px 8px;">${statusText}</span>
              <span style="font-size:11px;color:var(--medium-blue);font-weight:700;">
                <i class="ri-check-double-fill"></i> المستلمون: <span id="delivered-${id}">0</span>
              </span>
            </div>
          </div>
        `;

        supabaseClient
          .from('admin_notification_receipts')
          .select('id', { count: 'exact' })
          .eq('notification_id', id)
          .then(({ count, error: countErr }) => {
            const el = document.getElementById(`delivered-${id}`);
            if (el && !countErr) el.innerText = count || 0;
          });
      }

      historyContainer.innerHTML = html;
    };

    fetchHistory();

    supabaseClient.channel('public:admin_notifications')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'admin_notifications' }, () => fetchHistory())
      .subscribe();
  } else {
    const historyContainer = document.getElementById('notifHistoryList');
    if (historyContainer) {
      historyContainer.innerHTML = '<div style="text-align:center;color:var(--text-light);padding:20px;">لوحة تحكم محلية (بدون اتصال قاعدة بيانات).</div>';
    }
  }
}

// ---- TECHNICAL SUPPORT & COMPLAINTS ----
function renderSupport() {
  return `
    <div class="page-section">
      <div style="display:grid;grid-template-columns: 1fr 2fr; gap:24px;">
        <!-- Complaints list -->
        <div class="card" style="max-height:600px;overflow-y:auto;">
          <div class="card-header">
            <h3>تذاكر الدعم والشكاوى</h3>
          </div>
          <div class="card-body" style="padding:0;display:flex;flex-direction:column;">
            ${mockData.supportTickets.map(tkt => `
              <div onclick="selectTicket('${tkt.id}')" style="padding:14px;border-bottom:1px solid var(--border-light);cursor:pointer;background:${activeTicketId === tkt.id ? 'rgba(30,136,229,0.06)' : 'transparent'};transition:all 0.2s;">
                <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:6px;">
                  <span style="font-weight:700;font-size:12px;color:var(--medium-blue);">${tkt.id}</span>
                  <span class="status-badge ${tkt.status === 'open' ? 'pending' : (tkt.status === 'resolved' ? 'completed' : 'active')}">${tkt.statusAr}</span>
                </div>
                <div style="font-weight:700;font-size:13px;color:var(--text-primary);margin-bottom:4px;">${tkt.subject}</div>
                <div style="display:flex;justify-content:space-between;font-size:11px;color:var(--text-light);">
                  <span>بواسطة: ${tkt.user} (${tkt.type})</span>
                  <span>${tkt.date}</span>
                </div>
              </div>
            `).join('')}
          </div>
        </div>

        <!-- Ticket details and chat -->
        <div class="card" style="display:flex;flex-direction:column;min-height:500px;">
          ${activeTicketId ? renderTicketChat() : `
            <div style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;color:var(--text-light);">
              <i class="ri-customer-service-2-line" style="font-size:64px;margin-bottom:16px;"></i>
              <p>يرجى اختيار شكوى من القائمة الجانبية للرد ومتابعة الشكاوى مباشرة</p>
            </div>
          `}
        </div>
      </div>
    </div>
  `;
}

function renderTicketChat() {
  const tkt = mockData.supportTickets.find(t => t.id === activeTicketId);
  if (!tkt) return '';
  
  return `
    <div class="card-header" style="display:flex;justify-content:space-between;align-items:center;border-bottom:1px solid var(--border-color);">
      <div>
        <h3 style="margin-bottom:2px;">${tkt.subject}</h3>
        <p style="font-size:12px;color:var(--text-secondary);">كود التذكرة: ${tkt.id} • العميل: ${tkt.user} (${tkt.type})</p>
      </div>
      <div style="display:flex;gap:8px;">
        <button class="btn btn-outline btn-sm" onclick="assignTicket('${tkt.id}')"><i class="ri-user-shared-line"></i> تحويل لموظف</button>
        <button class="btn btn-primary btn-sm" style="background:var(--success);" onclick="resolveTicket('${tkt.id}')"><i class="ri-check-line"></i> إغلاق وحل الشكوى</button>
      </div>
    </div>
    
    <div style="flex:1;padding:20px;overflow-y:auto;background:var(--bg-primary);display:flex;flex-direction:column;gap:14px;max-height:360px;">
      ${tkt.replies.map(rep => `
        <div style="align-self:${rep.sender === 'user' ? 'flex-start' : 'flex-end'};max-width:70%;">
          <div style="padding:10px 16px;border-radius:var(--radius-md);background:${rep.sender === 'user' ? 'white' : 'var(--medium-blue)'};color:${rep.sender === 'user' ? 'var(--text-primary)' : 'white'};box-shadow:var(--shadow-sm);font-size:13px;">
            ${rep.text}
          </div>
          <div style="font-size:10px;color:var(--text-light);text-align:${rep.sender === 'user' ? 'right' : 'left'};margin-top:4px;">
            ${rep.sender === 'user' ? tkt.user : 'الدعم الفني (أحمد)'}
          </div>
        </div>
      `).join('')}
    </div>

    <div style="padding:16px;border-top:1px solid var(--border-color);display:flex;gap:12px;align-items:center;">
      <textarea id="replyText" placeholder="اكتب ردك هنا..." rows="1" style="flex:1;padding:12px;border:1px solid var(--border-color);border-radius:var(--radius-md);resize:none;font-family:inherit;"></textarea>
      <button class="btn btn-primary" style="padding:12px 20px;" onclick="sendReply('${tkt.id}')"><i class="ri-send-plane-fill"></i> رد</button>
    </div>
  `;
}

function selectTicket(id) {
  activeTicketId = id;
  renderPage('support');
}

function sendReply(id) {
  const text = document.getElementById('replyText').value;
  if (!text.trim()) return;
  
  const tkt = mockData.supportTickets.find(t => t.id === id);
  if (tkt) {
    tkt.replies.push({ sender: 'admin', text: text });
    tkt.status = 'pending';
    tkt.statusAr = 'قيد المتابعة';
    logAction(`إضافة رد على تذكرة الدعم ${id}`);
    renderPage('support');
  }
}

function resolveTicket(id) {
  const tkt = mockData.supportTickets.find(t => t.id === id);
  if (tkt) {
    tkt.status = 'resolved';
    tkt.statusAr = 'تم الحل';
    logAction(`إغلاق وحل الشكوى للتذكرة ${id}`);
    renderPage('support');
    showToast(`✅ تم إغلاق تذكرة الشكوى ${id}`);
  }
}

function assignTicket(id) {
  showToast('👤 تم تحويل تذكرة الدعم للموظف المختص بالمراجعة المالية');
  logAction(`تحويل التذكرة ${id} إلى موظف المراجعة المالية`);
}

// ---- CONTENT MANAGER (Banners, Coupons, FAQs) ----
function renderContent() {
  return `
    <div class="page-section">
      <div style="display:grid;grid-template-columns: 1fr 1fr; gap:24px; margin-bottom:24px;">
        <!-- Coupons management -->
        <div class="card">
          <div class="card-header" style="display:flex;justify-content:space-between;align-items:center;">
            <h3>كوبونات الخصم الفعالة</h3>
            <button class="btn btn-primary btn-sm" onclick="showNewCouponPrompt()"><i class="ri-add-line"></i> إضافة كود</button>
          </div>
          <div class="card-body" style="padding:0;">
            <table class="data-table">
              <thead>
                <tr>
                  <th>كود الخصم</th>
                  <th>النسبة %</th>
                  <th>الاستخدام</th>
                  <th>الحالة</th>
                  <th>إجراء</th>
                </tr>
              </thead>
              <tbody>
                ${mockData.coupons.map(cpn => `
                  <tr>
                    <td><span class="font-outfit fw-700" style="color:var(--medium-blue);">${cpn.code}</span></td>
                    <td><span class="font-outfit">${cpn.discount}%</span></td>
                    <td><span class="font-outfit">${cpn.used}/${cpn.maxUsage}</span></td>
                    <td><span class="status-badge ${cpn.status === 'active' ? 'completed' : 'cancelled'}">${cpn.status === 'active' ? 'نشط' : 'منتهي'}</span></td>
                    <td>
                      <button class="btn btn-outline btn-sm" style="color:var(--error);border-color:var(--error);" onclick="deleteCoupon('${cpn.code}')"><i class="ri-delete-bin-line"></i></button>
                    </td>
                  </tr>
                `).join('')}
              </tbody>
            </table>
          </div>
        </div>

        <!-- Banners and Ads -->
        <div class="card">
          <div class="card-header" style="display:flex;justify-content:space-between;align-items:center;">
            <h3>إعلانات وبانرات التطبيق</h3>
            <button class="btn btn-primary btn-sm" onclick="showToast('إضافة إعلان قريباً')"><i class="ri-add-line"></i> إضافة بانر</button>
          </div>
          <div class="card-body" style="display:grid;grid-template-columns:1fr 1fr; gap:16px;">
            ${mockData.banners.map(ban => `
              <div style="background:var(--bg-primary);border-radius:var(--radius-md);overflow:hidden;border:1px solid var(--border-color);">
                <img src="${ban.image}" style="width:100%;height:100px;object-fit:cover;">
                <div style="padding:10px;">
                  <h4 style="font-size:12px;font-weight:700;margin-bottom:6px;">${ban.title}</h4>
                  <div style="display:flex;justify-content:space-between;align-items:center;">
                    <span style="font-size:10px;color:var(--success);font-weight:700;">فعال</span>
                    <button class="btn btn-outline btn-sm" style="padding:2px 6px;font-size:10px;color:var(--error);border-color:var(--error);" onclick="showToast('تم تعطيل البانر')">تعطيل</button>
                  </div>
                </div>
              </div>
            `).join('')}
          </div>
        </div>
      </div>

      <!-- FAQs and static Pages editor -->
      <div class="card">
        <div class="card-header">
          <h3>تعديل محتوى الصفحات والأسئلة الشائعة</h3>
        </div>
        <div class="card-body">
          <div style="display:grid;grid-template-columns:1fr 2fr; gap:20px;">
            <div>
              <h4 style="font-size:13px;font-weight:700;margin-bottom:10px;">اختر الصفحة للتعديل</h4>
              <select id="staticPageSelect" class="form-control" style="width:100%;padding:10px;border:1px solid var(--border-color);border-radius:var(--radius-md);margin-bottom:12px;">
                <option value="terms">شروط الخدمة والاستخدام</option>
                <option value="privacy">سياسة الخصوصية والأمان</option>
                <option value="about">عن تطبيق inRide</option>
              </select>
              <button class="btn btn-outline" style="width:100%;" onclick="showToast('تم تحميل بيانات الصفحة بنجاح')">تحميل المحتوى</button>
            </div>
            <div>
              <label style="display:block;margin-bottom:8px;font-weight:700;font-size:13px;">المحتوى المكتوب (HTML/نص عادي)</label>
              <textarea rows="6" class="form-control" style="width:100%;padding:12px;border:1px solid var(--border-color);border-radius:var(--radius-md);font-family:inherit;resize:vertical;" placeholder="اكتب محتوى الصفحة الافتراضي هنا...">نرحب بكم في تطبيق inRide. يقدم تطبيقنا خدمات توصيل الركاب بالبايك والسيارات وخدمات الديلفري الذكي السريعة داخل المحافظات بأسعار تنافسية...</textarea>
              <div style="display:flex;justify-content:flex-end;margin-top:12px;">
                <button class="btn btn-primary" onclick="showToast('✅ تم حفظ تعديلات الصفحة الثابتة بنجاح'); logAction('تعديل نص صفحة معلومات الخدمة');"><i class="ri-save-fill"></i> حفظ التحديث</button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  `;
}

function showNewCouponPrompt() {
  const code = prompt('ادخل رمز الكوبون الجديد (مثال: RIDE30):');
  if (!code) return;
  const discountStr = prompt('ادخل نسبة الخصم % (رقم فقط):');
  const discount = parseInt(discountStr);
  if (isNaN(discount)) {
    alert('الرجاء إدخال رقم صحيح');
    return;
  }
  
  mockData.coupons.push({
    code: code.toUpperCase(),
    discount: discount,
    maxUsage: 100,
    used: 0,
    status: 'active'
  });
  logAction(`إنشاء كوبون خصم جديد: ${code}`);
  renderPage('content');
  showToast(`✅ تم إضافة كوبون الخصم ${code} بنجاح`);
}

function deleteCoupon(code) {
  mockData.coupons = mockData.coupons.filter(c => c.code !== code);
  logAction(`حذف كوبون الخصم: ${code}`);
  renderPage('content');
  showToast(`❌ تم حذف الكوبون ${code}`);
}

// ---- SYSTEM MONITORING & LOGS ----
function renderMonitoring() {
  return `
    <div class="page-section">
      <div class="stats-grid" style="grid-template-columns: repeat(4, 1fr); margin-bottom: 24px;">
        <div class="stat-card blue">
          <div class="stat-card-label">أشخاص متصلون حالياً</div>
          <div class="stat-card-value font-outfit" style="color:var(--medium-blue);">${mockData.monitoringStats.onlineUsers}</div>
        </div>
        <div class="stat-card green">
          <div class="stat-card-label">سائقين متصلين</div>
          <div class="stat-card-value font-outfit" style="color:var(--success);">${mockData.monitoringStats.availableDrivers}</div>
        </div>
        <div class="stat-card orange">
          <div class="stat-card-label">رحلات نشطة جارية</div>
          <div class="stat-card-value font-outfit" style="color:var(--warning);">${mockData.monitoringStats.activeTrips}</div>
        </div>
        <div class="stat-card red">
          <div class="stat-card-label">استجابة الخادم API</div>
          <div class="stat-card-value font-outfit" style="color:var(--error);">${mockData.monitoringStats.serverLatency}</div>
        </div>
      </div>

      <div style="display:grid;grid-template-columns: 2fr 1fr; gap:24px;">
        <!-- Terminal log viewer -->
        <div class="card">
          <div class="card-header">
            <h3><i class="ri-terminal-box-line text-blue" style="margin-left:8px;"></i> مراقبة الأخطاء وسجلات تشغيل الخادم</h3>
          </div>
          <div class="card-body" style="padding:0;">
            <div style="background:#1E293B;color:#38BDF8;font-family:'Courier New', monospace;font-size:12px;padding:20px;border-radius:0 0 var(--radius-lg) var(--radius-lg);max-height:300px;overflow-y:auto;direction:ltr;text-align:left;">
              <div>[2026-07-16 15:35:10] INFO: Listening on Firestore snapshot collections...</div>
              <div>[2026-07-16 15:35:12] INFO: Firebase connection successfully established. Latency: 32ms</div>
              <div>[2026-07-16 15:35:28] WARN: User token refreshed for passenger UID: n9B231oPp9</div>
              <div>[2026-07-16 15:36:01] INFO: Completed payouts check routine. Total payouts scheduled: 0</div>
              <div style="color:#F87171;">[2026-07-16 15:36:12] ERROR: FirebaseStorage: Object 'users/mock_id/profile.png' not found (ignored)</div>
              <div style="color:#4ADE80;">[2026-07-16 15:36:45] SUCCESS: Handshake complete for driver verification status listener.</div>
            </div>
          </div>
        </div>

        <!-- Feature flags and Maintenance -->
        <div class="card">
          <div class="card-header">
            <h3><i class="ri-toggle-line text-blue" style="margin-left:8px;"></i> مفاتيح التحكم والتعطيل</h3>
          </div>
          <div class="card-body" style="display:flex;flex-direction:column;gap:14px;">
            <div style="display:flex;justify-content:space-between;align-items:center;">
              <span style="font-size:13px;font-weight:700;">وضع الصيانة (Maintenance Mode)</span>
              <input type="checkbox" ${mockData.monitoringStats.maintenanceMode ? 'checked' : ''} style="width:36px;height:18px;cursor:pointer;" onchange="toggleMonitorFlag('maintenanceMode')">
            </div>
            
            <div style="display:flex;justify-content:space-between;align-items:center;">
              <span style="font-size:13px;font-weight:700;">فتح تسجيل الركاب الجدد</span>
              <input type="checkbox" ${mockData.monitoringStats.registrationOpen ? 'checked' : ''} style="width:36px;height:18px;cursor:pointer;" onchange="toggleMonitorFlag('registrationOpen')">
            </div>

            <div style="display:flex;justify-content:space-between;align-items:center;">
              <span style="font-size:13px;font-weight:700;">فتح تسجيل الكباتن الجدد</span>
              <input type="checkbox" ${mockData.monitoringStats.driverRegistrationOpen ? 'checked' : ''} style="width:36px;height:18px;cursor:pointer;" onchange="toggleMonitorFlag('driverRegistrationOpen')">
            </div>

            <div style="display:flex;justify-content:space-between;align-items:center;">
              <span style="font-size:13px;font-weight:700;">تمكين استقبال الرحلات الحية</span>
              <input type="checkbox" ${mockData.monitoringStats.tripReceivingOpen ? 'checked' : ''} style="width:36px;height:18px;cursor:pointer;" onchange="toggleMonitorFlag('tripReceivingOpen')">
            </div>

            <div style="border-top:1px solid var(--border-color);padding-top:14px;">
              <label style="display:block;margin-bottom:8px;font-weight:700;font-size:12px;">أقل إصدار إجباري للتطبيق (Force Update)</label>
              <div style="display:flex;gap:8px;">
                <input type="text" id="minVerField" class="form-control" style="flex:1;padding:8px;border:1px solid var(--border-color);border-radius:var(--radius-md);" value="${mockData.monitoringStats.minAppVersion}">
                <button class="btn btn-primary btn-sm" onclick="saveMinVersion()">تحديث</button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  `;
}

function toggleMonitorFlag(flag) {
  mockData.monitoringStats[flag] = !mockData.monitoringStats[flag];
  logAction(`تعديل إعداد التحكم بنظام التشغيل: ${flag} إلى ${mockData.monitoringStats[flag]}`);
  showToast(`✅ تم حفظ إعداد المراقبة بنجاح`);
}

function saveMinVersion() {
  const ver = document.getElementById('minVerField').value;
  mockData.monitoringStats.minAppVersion = ver;
  logAction(`تعديل أقل إصدار إجباري للتطبيق إلى ${ver}`);
  showToast(`✅ تم فرض الإصدار الجديد ${ver}`);
}

// ---- AUDIT LOGS & ACCESS PERMISSIONS (RBAC) ----
function renderLogs() {
  return `
    <div class="page-section">
      <div style="display:grid;grid-template-columns: 2fr 1fr; gap:24px;">
        <!-- Audit Logs table -->
        <div class="card">
          <div class="card-header">
            <h3>سجل عمليات الموظفين والمشرفين (Audit Logs)</h3>
          </div>
          <div class="card-body" style="padding:0;">
            <table class="data-table">
              <thead>
                <tr>
                  <th>المشرف / الموظف</th>
                  <th>الرتبة</th>
                  <th>العملية / الإجراء</th>
                  <th>التاريخ والوقت</th>
                  <th>عنوان IP</th>
                </tr>
              </thead>
              <tbody>
                ${mockData.auditLogs.map(log => `
                  <tr>
                    <td><span style="font-weight:700;color:var(--text-primary);">${log.employee}</span></td>
                    <td><span style="font-size:12px;font-weight:600;color:var(--text-secondary);">${log.role}</span></td>
                    <td><span style="font-weight:600;color:var(--medium-blue);">${log.action}</span></td>
                    <td><span style="font-size:12px;font-weight:600;color:var(--text-light);">${log.date}</span></td>
                    <td><span class="font-outfit" style="font-size:12px;color:var(--text-light);">${log.ip}</span></td>
                  </tr>
                `).join('')}
              </tbody>
            </table>
          </div>
        </div>

        <!-- RBAC Settings -->
        <div class="card">
          <div class="card-header">
            <h3>صلاحيات المشرفين (RBAC)</h3>
          </div>
          <div class="card-body">
            <p style="font-size:12px;color:var(--text-secondary);margin-bottom:16px;">
              حماية لوحات التحكم وعرض الميزات بنظام مستويات الوصول للأمان وقوانين سرية البيانات.
            </p>
            
            <div style="display:flex;flex-direction:column;gap:12px;">
              <div style="padding:10px;background:var(--bg-primary);border-radius:var(--radius-md);">
                <div style="font-weight:700;font-size:13px;color:var(--text-primary);margin-bottom:4px;">مدير النظام (Admin)</div>
                <div style="font-size:11px;color:var(--success);font-weight:700;">صلاحيات كاملة للوصول، التعديل والتسعير المالي.</div>
              </div>
              <div style="padding:10px;background:var(--bg-primary);border-radius:var(--radius-md);">
                <div style="font-weight:700;font-size:13px;color:var(--text-primary);margin-bottom:4px;">عميل الدعم (Support Agent)</div>
                <div style="font-size:11px;color:var(--medium-blue);font-weight:700;">صلاحية قراءة المشاوير، الرد على الشكاوى واعتماد السائقين فقط.</div>
              </div>
              <div style="padding:10px;background:var(--bg-primary);border-radius:var(--radius-md);">
                <div style="font-weight:700;font-size:13px;color:var(--text-primary);margin-bottom:4px;">موزع المشاوير (Dispatcher)</div>
                <div style="font-size:11px;color:var(--warning);font-weight:700;">صلاحية مراقبة مسارات الرحلات وإلغاء/إنهاء المشاوير يدوياً.</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  `;
}

// ---- INTERACTION HANDLERS FOR OTHER SECTIONS ----

// In-line actions for trips manually (Trip cancel/complete)
function modifyTripStatus(requestId, newStatus) {
  if (supabaseClient) {
    supabaseClient.from('ride_requests').update({ status: newStatus }).eq('id', requestId)
      .then(({ error }) => {
        if (!error) {
          logAction(`تغيير حالة الرحلة ${requestId} إلى ${newStatus} يدوياً من الإدارة`);
          showToast(`✅ تم تحديث حالة الرحلة بنجاح إلى ${newStatus}`);
        } else {
          showToast(`❌ فشل التحديث: ${error.message}`);
        }
      }).catch(err => {
        showToast(`❌ فشل التحديث: ${err.message}`);
      });
  } else {
    // Local update
    const trip = mockData.trips.find(t => t.requestId === requestId);
    if (trip) {
      trip.status = newStatus === 'Completed' ? 'مكتملة' : (newStatus === 'Cancelled' ? 'ملغاة' : 'جارية');
      logAction(`تحديث حالة الرحلة ${requestId} محلياً إلى ${newStatus}`);
      renderPage('trips');
      showToast(`✅ تم التحديث محلياً`);
    }
  }
}

// User action handler (Verify, Suspend, Ban, Reset Pass)
function modifyUserStatus(uid, action, userRole) {
  if (supabaseClient) {
    (async () => {
      try {
        let updateFields = {};
        if (action === 'suspend') {
          updateFields.status = 'suspended';
        } else if (action === 'activate') {
          updateFields.status = 'active';
        } else if (action === 'ban') {
          updateFields.status = 'banned';
        } else if (action === 'verify') {
          updateFields.status = 'active';
        }
        
        const { error: userError } = await supabaseClient.from('users').update(updateFields).eq('id', uid);
        if (userError) throw userError;

        if (userRole === 'driver' && action === 'verify') {
          const { error: driverError } = await supabaseClient.from('drivers').update({ verification_status: 'verified' }).eq('id', uid);
          if (driverError) throw driverError;
        }

        logAction(`إجراء (${action}) على حساب المستخدم/السائق: ${uid}`);
        showToast(`✅ تم تنفيذ الإجراء ${action} بنجاح`);
      } catch (err) {
        showToast(`❌ فشل الإجراء: ${err.message}`);
      }
    })();
  } else {
    // Local mock action
    if (userRole === 'driver') {
      const driver = mockData.drivers.find(d => d.uid === uid);
      if (driver) {
        if (action === 'verify') {
          driver.status = 'verified';
          driver.statusAr = 'معتمد';
        } else if (action === 'suspend') {
          driver.status = 'unregistered';
          driver.statusAr = 'غير نشط';
        }
        logAction(`إجراء (${action}) محلياً على السائق: ${uid}`);
        renderPage('drivers');
        showToast('✅ تم التحديث محلياً');
      }
    } else {
      const passenger = mockData.passengers.find(p => p.uid === uid);
      if (passenger) {
        if (action === 'suspend') {
          passenger.status = 'inactive';
          passenger.statusAr = 'غير نشط';
        } else if (action === 'activate') {
          passenger.status = 'active';
          passenger.statusAr = 'نشط';
        }
        logAction(`إجراء (${action}) محلياً على الراكب: ${uid}`);
        renderPage('passengers');
        showToast('✅ تم التحديث محلياً');
      }
    }
  }
}

// Financial balance management
function adjustUserWallet(uid, amountStr, role) {
  const amount = parseFloat(amountStr);
  if (isNaN(amount)) {
    showToast('⚠️ يرجى إدخال مبلغ صحيح');
    return;
  }
  
  if (supabaseClient) {
    (async () => {
      try {
        const { data: userData, error: getError } = await supabaseClient
          .from('users')
          .select('wallet_balance')
          .eq('id', uid)
          .maybeSingle();
        if (getError || !userData) throw new Error("المستخدم غير موجود");
        
        const currentBal = parseFloat(userData.wallet_balance || 0.0);
        const newBal = currentBal + amount;
        
        const { error: updateError } = await supabaseClient
          .from('users')
          .update({ wallet_balance: newBal })
          .eq('id', uid);
        if (updateError) throw updateError;
        
        // Add to wallet_transactions
        const txnId = 'TXN-' + Math.random().toString(36).substr(2, 9).toUpperCase();
        await supabaseClient.from('wallet_transactions').insert({
          id: txnId,
          user_id: uid,
          amount: amount,
          type: amount >= 0 ? 'deposit' : 'withdrawal',
          description: 'تعديل الرصيد من الإدارة',
          status: 'completed',
          created_at: new Date().toISOString()
        });

        logAction(`تعديل رصيد محفظة ${uid} بقيمة ${amount} ج.م`);
        showToast('✅ تم تحديث الرصيد بنجاح في Supabase');
      } catch (err) {
        showToast(`❌ فشل التحديث: ${err.message}`);
      }
    })();
  } else {
    // Local mock
    if (role === 'rider') {
      const p = mockData.passengers.find(pass => pass.uid === uid);
      if (p) {
        p.totalSpent += amount;
        logAction(`تعديل رصيد محفظة الراكب ${uid} محلياً بقيمة ${amount} ج.م`);
        renderPage('passengers');
        showToast('✅ تم تعديل الرصيد محلياً');
      }
    } else {
      const d = mockData.drivers.find(dr => dr.uid === uid);
      if (d) {
        d.earnings += amount;
        logAction(`تعديل رصيد محفظة السائق ${uid} محلياً بقيمة ${amount} ج.م`);
        renderPage('drivers');
        showToast('✅ تم تعديل الرصيد محلياً');
      }
    }
  }
}

// Modal helper to review documents
function reviewDriverDocs(uid) {
  const driver = mockData.drivers.find(d => d.uid === uid);
  if (!driver) return;
  
  const modal = document.createElement('div');
  modal.className = 'modal-backdrop';
  modal.style.cssText = `
    position: fixed; top:0; left:0; width:100%; height:100%;
    background: rgba(0,0,0,0.5); z-index:10000;
    display:flex; align-items:center; justify-content:center;
    font-family: 'Cairo', sans-serif;
  `;
  
  modal.innerHTML = `
    <div style="background:white; padding:24px; border-radius:var(--radius-lg); width:650px; max-width:95%; max-height:85vh; overflow-y:auto; box-shadow: 0 10px 25px rgba(0,0,0,0.2);">
      <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:20px; border-bottom:1px solid var(--border-color); padding-bottom:12px; position:sticky; top:0; background:white; z-index:10;">
        <h3 style="font-weight:700; margin:0;">📋 مراجعة مستندات الكابتن: ${driver.name}</h3>
        <button onclick="this.closest('.modal-backdrop').remove()" style="font-size:24px;color:var(--text-light);background:none;border:none;cursor:pointer;"><i class="ri-close-line"></i></button>
      </div>
      
      <div style="display:flex; flex-direction:column; gap:20px; margin-bottom:24px;">
        <!-- National ID -->
        <div style="background:var(--bg-primary); padding:16px; border-radius:var(--radius-md); border:1px solid var(--border-color);">
          <div style="font-weight:700;font-size:14px;margin-bottom:10px;color:var(--text-primary);"><i class="ri-profile-line"></i> صورة بطاقة الرقم القومي (وجهين)</div>
          <div style="display:grid; grid-template-columns:1fr 1fr; gap:12px;">
            <div>
              <div style="font-size:11px;color:var(--text-secondary);margin-bottom:4px;text-align:center;">الوجه الرئيسي</div>
              ${driver.idCardFrontUrl ? `<img src="${driver.idCardFrontUrl}" style="width:100%; height:130px; object-fit:cover; border-radius:6px; border:1px solid var(--border-color); cursor:pointer;" onclick="window.open(this.src)" title="اضغط للتكبير">` : `<div style="height:130px;background:#e2e8f0;border-radius:6px;display:flex;align-items:center;justify-content:center;font-size:12px;color:var(--text-secondary);">لم يتم الرفع بعد</div>`}
            </div>
            <div>
              <div style="font-size:11px;color:var(--text-secondary);margin-bottom:4px;text-align:center;">الظهر الخلفي</div>
              ${driver.idCardBackUrl ? `<img src="${driver.idCardBackUrl}" style="width:100%; height:130px; object-fit:cover; border-radius:6px; border:1px solid var(--border-color); cursor:pointer;" onclick="window.open(this.src)" title="اضغط للتكبير">` : `<div style="height:130px;background:#e2e8f0;border-radius:6px;display:flex;align-items:center;justify-content:center;font-size:12px;color:var(--text-secondary);">لم يتم الرفع بعد</div>`}
            </div>
          </div>
        </div>
        
        <!-- Driver License -->
        <div style="background:var(--bg-primary); padding:16px; border-radius:var(--radius-md); border:1px solid var(--border-color);">
          <div style="font-weight:700;font-size:14px;margin-bottom:10px;color:var(--text-primary);"><i class="ri-steering-line"></i> رخصة القيادة السارية (وجهين)</div>
          <div style="display:grid; grid-template-columns:1fr 1fr; gap:12px;">
            <div>
              <div style="font-size:11px;color:var(--text-secondary);margin-bottom:4px;text-align:center;">الوجه</div>
              ${driver.driverLicenseFrontUrl ? `<img src="${driver.driverLicenseFrontUrl}" style="width:100%; height:130px; object-fit:cover; border-radius:6px; border:1px solid var(--border-color); cursor:pointer;" onclick="window.open(this.src)" title="اضغط للتكبير">` : `<div style="height:130px;background:#e2e8f0;border-radius:6px;display:flex;align-items:center;justify-content:center;font-size:12px;color:var(--text-secondary);">لم يتم الرفع بعد</div>`}
            </div>
            <div>
              <div style="font-size:11px;color:var(--text-secondary);margin-bottom:4px;text-align:center;">الظهر</div>
              ${driver.driverLicenseBackUrl ? `<img src="${driver.driverLicenseBackUrl}" style="width:100%; height:130px; object-fit:cover; border-radius:6px; border:1px solid var(--border-color); cursor:pointer;" onclick="window.open(this.src)" title="اضغط للتكبير">` : `<div style="height:130px;background:#e2e8f0;border-radius:6px;display:flex;align-items:center;justify-content:center;font-size:12px;color:var(--text-secondary);">لم يتم الرفع بعد</div>`}
            </div>
          </div>
        </div>

        <!-- Vehicle/Motorcycle License -->
        <div style="background:var(--bg-primary); padding:16px; border-radius:var(--radius-md); border:1px solid var(--border-color);">
          <div style="font-weight:700;font-size:14px;margin-bottom:10px;color:var(--text-primary);"><i class="ri-file-text-line"></i> رخصة السيارة أو الدراجة النارية (وجهين)</div>
          <div style="display:grid; grid-template-columns:1fr 1fr; gap:12px;">
            <div>
              <div style="font-size:11px;color:var(--text-secondary);margin-bottom:4px;text-align:center;">الوجه</div>
              ${driver.vehicleLicenseFrontUrl ? `<img src="${driver.vehicleLicenseFrontUrl}" style="width:100%; height:130px; object-fit:cover; border-radius:6px; border:1px solid var(--border-color); cursor:pointer;" onclick="window.open(this.src)" title="اضغط للتكبير">` : `<div style="height:130px;background:#e2e8f0;border-radius:6px;display:flex;align-items:center;justify-content:center;font-size:12px;color:var(--text-secondary);">لم يتم الرفع بعد</div>`}
            </div>
            <div>
              <div style="font-size:11px;color:var(--text-secondary);margin-bottom:4px;text-align:center;">الظهر</div>
              ${driver.vehicleLicenseBackUrl ? `<img src="${driver.vehicleLicenseBackUrl}" style="width:100%; height:130px; object-fit:cover; border-radius:6px; border:1px solid var(--border-color); cursor:pointer;" onclick="window.open(this.src)" title="اضغط للتكبير">` : `<div style="height:130px;background:#e2e8f0;border-radius:6px;display:flex;align-items:center;justify-content:center;font-size:12px;color:var(--text-secondary);">لم يتم الرفع بعد</div>`}
            </div>
          </div>
        </div>

        <!-- Vehicle Images (outside/inside) -->
        <div style="background:var(--bg-primary); padding:16px; border-radius:var(--radius-md); border:1px solid var(--border-color);">
          <div style="font-weight:700;font-size:14px;margin-bottom:10px;color:var(--text-primary);"><i class="ri-car-fill"></i> صور المركبة من الداخل والخارج (4 صور)</div>
          <div style="display:grid; grid-template-columns:repeat(4, 1fr); gap:8px;">
            ${[0, 1, 2, 3].map(i => {
              const imgUrl = (driver.vehicleImages && driver.vehicleImages.length > i) ? driver.vehicleImages[i] : null;
              return `
                <div>
                  ${imgUrl ? `<img src="${imgUrl}" style="width:100%; height:90px; object-fit:cover; border-radius:6px; border:1px solid var(--border-color); cursor:pointer;" onclick="window.open(this.src)" title="اضغط للتكبير">` : `<div style="height:90px;background:#e2e8f0;border-radius:6px;display:flex;align-items:center;justify-content:center;font-size:10px;color:var(--text-secondary);text-align:center;padding:4px;">لم يتم الرفع</div>`}
                </div>
              `;
            }).join('')}
          </div>
        </div>
      </div>
      
      <div style="margin-bottom:20px;">
        <label style="display:block;margin-bottom:8px;font-weight:700;font-size:12px;color:var(--text-primary);">سبب الرفض (في حالة الرفض فقط)</label>
        <input type="text" id="rejectReason" class="form-control" style="width:100%;padding:10px;border:1px solid var(--border-color);border-radius:var(--radius-md);" placeholder="مثال: رخصة القيادة منتهية...">
      </div>

      <div style="display:flex; justify-content:flex-end; gap:10px; border-top:1px solid var(--border-color); padding-top:16px; position:sticky; bottom:0; background:white; z-index:10;">
        <button class="btn btn-outline" style="color:var(--error);border-color:var(--error);" onclick="submitDocApproval('${uid}', 'reject')">رفض المستندات</button>
        <button class="btn btn-primary" onclick="submitDocApproval('${uid}', 'approve')">قبول واعتماد الكابتن</button>
      </div>
    </div>
  `;
  document.body.appendChild(modal);
}

function submitDocApproval(uid, decision) {
  const modal = document.querySelector('.modal-backdrop');
  const reason = document.getElementById('rejectReason')?.value || '';
  
  if (modal) modal.remove();
  
  if (decision === 'approve') {
    modifyUserStatus(uid, 'verify', 'driver');
  } else {
    // Rejected
    if (supabaseClient) {
      supabaseClient.from('drivers').update({
        verification_status: 'rejected',
        rejection_reason: reason
      }).eq('id', uid)
        .then(({ error }) => {
          if (!error) {
            logAction(`رفض مستندات الكابتن ${uid} بسبب: ${reason}`);
            showToast('❌ تم رفض السائق وإرسال الإشعار بنجاح');
          } else {
            showToast(`❌ فشل: ${error.message}`);
          }
        }).catch(err => showToast(`❌ فشل: ${err.message}`));
    } else {
      const d = mockData.drivers.find(dr => dr.uid === uid);
      if (d) {
        d.status = 'rejected';
        d.statusAr = 'مرفوض';
        logAction(`رفض مستندات الكابتن ${uid} محلياً بسبب: ${reason}`);
        renderPage('drivers');
        showToast('❌ تم الرفض محلياً');
      }
    }
  }
}

// ---- TOAST NOTIFICATIONS (EXISTING FUNCTION CONTINUED) ----


// ============================================
// SUPABASE REAL-TIME SYNCHRONIZATION
// ============================================

function initSupabaseSync() {
  if (!supabaseClient) {
    console.warn("Supabase SDK is not loaded. Operating in mock mode.");
    return;
  }

  try {
    const usersMap = {};

    const fetchSettings = async () => {
      const { data: sData, error } = await supabaseClient
        .from('app_settings')
        .select('*')
        .eq('id', 'default')
        .maybeSingle();

      if (!error && sData) {
        mockData.settings = {
          defaultFareCar: parseFloat(sData.default_fare_car || 45),
          defaultFareScooter: parseFloat(sData.default_fare_scooter || 20),
          defaultFareMotorcycle: parseFloat(sData.default_fare_motorcycle || 15),
          commissionRate: parseFloat(sData.commission_rate || 10),
          minFare: parseFloat(sData.min_fare || 10),
          maxFare: parseFloat(sData.max_fare || 500),
          first_km_fare: parseFloat(sData.first_km_fare || 20),
          extra_km_fare: parseFloat(sData.extra_km_fare || 5),
          ac_km_fare: parseFloat(sData.ac_km_fare || 1),
          heat_hour_km_fare: parseFloat(sData.heat_hour_km_fare || 1),
          heat_start_hour: parseInt(sData.heat_start_hour || 11),
          heat_end_hour: parseInt(sData.heat_end_hour || 15)
        };
        renderPage(currentPage);
      }
    };

    fetchSettings();

    supabaseClient.channel('public:app_settings')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'app_settings' }, () => fetchSettings())
      .subscribe();

    const recalculatePassengerStats = () => {
      if (!mockData.passengers || !mockData.tripsDataMap) return;
      const statsMap = {};
      Object.values(mockData.tripsDataMap).forEach(req => {
        const pId = req.passenger_id || req.passengerId;
        if (!pId) return;
        if (!statsMap[pId]) statsMap[pId] = { trips: 0, spent: 0 };
        if (req.status === 'Completed') {
          statsMap[pId].trips += 1;
          statsMap[pId].spent += (parseFloat(req.offered_fare || req.offeredFare || 0));
        }
      });
      mockData.passengers.forEach(p => {
        const s = statsMap[p.uid] || { trips: 0, spent: 0 };
        p.totalTrips = s.trips;
        p.totalSpent = s.spent;
      });
    };

    const fetchUsers = async () => {
      const { data: usersData, error } = await supabaseClient.from('users').select('*');
      if (!error && usersData) {
        const passengers = [];
        usersData.forEach(data => {
          usersMap[data.id] = data;
          if (data.role === 'rider' || !data.role) {
            const dateObj = new Date(data.created_at || Date.now());
            passengers.push({
              id: data.id.substring(0, 8).toUpperCase(),
              uid: data.id,
              name: data.name || data.full_name || 'مستخدم جديد',
              phone: data.phone_number || data.phone || '—',
              email: data.email || '—',
              address: data.address || '—',
              rating: data.rating || 5.0,
              totalTrips: 0,
              totalSpent: 0,
              joinDate: dateObj.toLocaleDateString('ar-EG'),
              status: data.status || 'active',
              statusAr: data.status === 'suspended' ? 'معلق' : (data.status === 'banned' ? 'محظور' : 'نشط'),
              lastTrip: '—',
              avatar: (data.name || data.full_name || 'م').charAt(0),
            });
          }
        });
        mockData.passengers = passengers;
        mockData.stats.totalPassengers = passengers.length;
        recalculatePassengerStats();
        updatePendingBadge();
        renderPage(currentPage);
        if (typeof fetchDrivers === 'function') {
          fetchDrivers();
        }
      }
    };

    fetchUsers();

    supabaseClient.channel('public:users')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'users' }, () => {
        fetchUsers();
      })
      .subscribe();

    const fetchTrips = async () => {
      const { data: tripsData, error } = await supabaseClient
        .from('ride_requests')
        .select('*')
        .order('created_at', { ascending: false });

      if (!error && tripsData) {
        mockData.tripsDataMap = mockData.tripsDataMap || {};
        const trips = [];
        let revenue = 0;
        tripsData.forEach(data => {
          mockData.tripsDataMap[data.id] = data;
          const tripPrice = data.offered_fare || data.offeredFare || 0;
          if (data.status === 'Completed') revenue += tripPrice;
          const dateObj = new Date(data.created_at || Date.now());
          const dateStr = `${dateObj.getHours()}:${dateObj.getMinutes().toString().padStart(2, '0')}`;
          const localeDate = dateObj.toLocaleDateString('ar-EG');

          const pId = data.passenger_id || data.passengerId;
          const dId = data.driver_id || data.driverId;
          const passenger = usersMap[pId] || {};
          const driver = usersMap[dId] || {};

          trips.push({
            id: (data.id || '').substring(0, 8).toUpperCase(),
            requestId: data.id,
            date: `${localeDate}، ${dateStr}`,
            riderName: passenger.name || 'عميل',
            riderPhone: passenger.phone_number || '—',
            driverName: dId ? (driver.name || 'سائق') : '—',
            from: data.pickup_address || data.pickupAddress || '—',
            to: data.destination_address || data.destinationAddress || '—',
            price: tripPrice,
            status: data.status === 'Completed' ? 'مكتملة' : (data.status === 'Cancelled' ? 'ملغاة' : 'جارية'),
            vehicle: data.vehicle_type === 'scooter' ? 'اسكوتر' : 'عربية',
            isDeliveryLocationConfirmed: data.is_delivery_location_confirmed || false,
          });
        });

        mockData.trips = trips;
        mockData.stats.totalTrips = trips.length;
        mockData.stats.totalRevenue = revenue;
        recalculatePassengerStats();
        renderPage(currentPage);
      }
    };

    fetchTrips();

    const fetchDrivers = async () => {
      const { data: driversData, error } = await supabaseClient.from('drivers').select('*');
      if (!error && driversData) {
        const driversList = [];
        for (const data of driversData) {
          const user = usersMap[data.id] || {};
          let vehicle = {};
          if (data.vehicle_id) {
            try {
              const { data: vData } = await supabaseClient.from('vehicles').select('*').eq('id', data.vehicle_id).maybeSingle();
              if (vData) vehicle = vData;
            } catch (e) {}
          }

          const dateObj = new Date(data.updated_at || Date.now());
          const statusVal = data.verification_status || 'unregistered';
          driversList.push({
            id: (data.id || '').substring(0, 8).toUpperCase(),
            uid: data.id,
            name: user.name || 'سائق جديد',
            phone: user.phone_number || user.phone || '—',
            email: user.email || '—',
            address: user.address || '—',
            rating: user.rating || 5.0,
            vehicleType: vehicle.vehicle_category || vehicle.type || 'car',
            vehicleName: vehicle.model || 'مركبة',
            vehicleColor: vehicle.color || 'فضي',
            licensePlate: vehicle.number_plate || '—',
            status: statusVal,
            statusAr: statusVal === 'verified' ? 'معتمد' : (statusVal === 'submitted' ? 'قيد المراجعة' : (statusVal === 'rejected' ? 'مرفوض' : 'غير مسجل')),
            totalTrips: data.total_trips || 0,
            earnings: data.total_earnings || 0,
            isOnline: data.is_online || false,
            joinDate: dateObj.toLocaleDateString('ar-EG'),
            avatar: (user.name || 'س').charAt(0),
            idCardFrontUrl: data.national_id_url || '',
            idCardBackUrl: data.national_id_back_url || '',
            driverLicenseFrontUrl: data.license_url || '',
            driverLicenseBackUrl: data.license_back_url || '',
            vehicleLicenseFrontUrl: data.vehicle_front_url || '',
            vehicleLicenseBackUrl: data.vehicle_back_url || '',
            vehicleImages: vehicle.images || []
          });
        }

        mockData.drivers = driversList;
        mockData.stats.activeDrivers = driversList.filter(d => d.isOnline).length;
        updatePendingBadge();
        renderPage(currentPage);
      }
    };

    fetchDrivers();

    supabaseClient.channel('public:drivers')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'drivers' }, () => {
        fetchDrivers();
      })
      .subscribe();

  } catch (err) {
    console.error("Global Supabase sync initialization error:", err);
  }
}

// ============================================
// INITIALIZATION
// ============================================

document.addEventListener('DOMContentLoaded', () => {
  // Initialize navigation
  document.querySelectorAll('.nav-item[data-page]').forEach(item => {
    item.addEventListener('click', (e) => {
      e.preventDefault();
      navigateTo(item.dataset.page);
    });
  });

  // Mobile overlay close
  const overlay = document.getElementById('overlay');
  if (overlay) {
    overlay.addEventListener('click', closeSidebar);
  }

  // Global search input listener
  const searchInput = document.getElementById('globalSearch');
  if (searchInput) {
    searchInput.addEventListener('input', (e) => {
      searchQuery = e.target.value.toLowerCase().trim();
      if (currentPages[currentPage]) {
        currentPages[currentPage] = 1;
      }
      renderPage(currentPage);
    });
  }

  // Restore saved page before initializing sync
  const savedPage = sessionStorage.getItem('admin_currentPage');
  if (savedPage) {
    currentPage = savedPage;
    if (savedPage === 'driver-profile' || savedPage === 'passenger-profile') {
      activeProfileUid = sessionStorage.getItem('admin_activeProfileUid');
      activeProfileRole = sessionStorage.getItem('admin_activeProfileRole');
    }
  }

  // Initialize Supabase real-time sync
  initSupabaseSync();

  // Render initial page
  navigateTo(currentPage);

  // Update pending badge
  updatePendingBadge();
});

// ---- PAGINATION AND EXPORT HELPERS ----
function changePage(pageName, newPage) {
  currentPages[pageName] = newPage;
  renderPage(currentPage);
}

function downloadCSV(filename, data, headers) {
  let csv = '\ufeff' + headers.join(',') + '\n';
  data.forEach(row => {
    csv += row.map(val => `"${String(val).replace(/"/g, '""')}"`).join(',') + '\n';
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
  const headers = ['رقم الرحلة', 'التاريخ', 'الراكب', 'الهاتف', 'السائق', 'البداية', 'النهاية', 'السعر (ج.م)', 'المركبة', 'الحالة'];
  const data = mockData.trips.map(t => [t.id, t.date, t.riderName, t.riderPhone, t.driverName, t.from, t.to, t.price, t.vehicle, t.status]);
  downloadCSV('inride_trips_report.csv', data, headers);
  logAction('تصدير بيانات الرحلات كتقرير CSV');
  showToast('📥 تم تحميل ملف تقرير الرحلات بنجاح');
}

function exportDriversCSV() {
  const headers = ['الكود', 'الاسم', 'الهاتف', 'نوع المركبة', 'اللوحة', 'التقييم', 'إجمالي الرحلات', 'الحالة'];
  const data = mockData.drivers.map(d => [d.id, d.name, d.phone, d.vehicleType, d.licensePlate, d.rating, d.totalTrips, d.statusAr]);
  downloadCSV('inride_drivers_report.csv', data, headers);
  logAction('تصدير بيانات الكباتن كتقرير CSV');
  showToast('📥 تم تحميل ملف تقرير السائقين بنجاح');
}

function exportPassengersCSV() {
  const headers = ['الكود', 'الاسم', 'الهاتف', 'التقييم', 'إجمالي الرحلات', 'تاريخ الانضمام', 'الحالة'];
  const data = mockData.passengers.map(p => [p.id, p.name, p.phone, p.rating, p.totalTrips, p.joinDate, p.statusAr]);
  downloadCSV('inride_passengers_report.csv', data, headers);
  logAction('تصدير بيانات الركاب كتقرير CSV');
  showToast('📥 تم تحميل ملف تقرير المستخدمين بنجاح');
}

// ============================================
// PROFILE PAGES AND SUPPORT CHAT FOR INDIVIDUAL USERS
// ============================================

let activeProfileUid = null;
let activeProfileRole = null;
let profileChatUnsubscribe = null;

// Initialize mock support message cache if needed
if (!mockData.supportChats) {
  mockData.supportChats = {};
}

function viewUserProfile(uid, role) {
  activeProfileUid = uid;
  activeProfileRole = role;
  navigateTo(role === 'driver' ? 'driver-profile' : 'passenger-profile');
}

function renderDriverProfile() {
  const driver = mockData.drivers.find(d => d.uid === activeProfileUid);
  if (!driver) {
    return `<div style="padding:24px;text-align:center;color:var(--text-light);">لم يتم العثور على بيانات هذا الكابتن.</div>`;
  }

  // Find driver's trips
  const driverTrips = mockData.trips.filter(t => t.driverName === driver.name || (t.driverId && t.driverId === driver.uid));

  return `
    <div class="page-section">
      <!-- Back button and title -->
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:24px;">
        <button class="btn btn-outline btn-sm" onclick="navigateTo('drivers')" style="display:flex;align-items:center;gap:6px;">
          <i class="ri-arrow-right-line" style="font-size:16px;"></i> العودة لقائمة الكباتن
        </button>
        <span class="text-light" style="font-size:13px;">تاريخ الانضمام: ${driver.joinDate}</span>
      </div>

      <div class="profile-details-grid">
        <!-- Left Side: Support Chat -->
        <div class="card" style="display:flex;flex-direction:column;height:650px;">
          <div class="card-header" style="border-bottom:1px solid var(--border-color);padding-bottom:14px;">
            <h3 style="display:flex;align-items:center;gap:8px;">
              <i class="ri-customer-service-2-fill text-blue"></i>
              محادثة الدعم الفني المباشرة
            </h3>
            <span class="status-badge completed" style="font-size:11px;">
              <span class="status-dot"></span> متصل
            </span>
          </div>
          
          <!-- Message History -->
          <div id="profileChatMessages" style="flex:1;padding:20px;overflow-y:auto;background:var(--bg-primary);display:flex;flex-direction:column;gap:12px;">
            <div style="text-align:center;padding:24px;color:var(--text-light);font-size:13px;">جاري تحميل المحادثة...</div>
          </div>

          <!-- Message Input -->
          <div style="padding:16px;border-top:1px solid var(--border-color);display:flex;gap:12px;align-items:center;">
            <input type="text" id="profileChatInput" placeholder="اكتب رسالتك للكابتن..." style="flex:1;padding:12px;border:1px solid var(--border-color);border-radius:var(--radius-md);background:var(--bg-primary);" onkeydown="if(event.key === 'Enter') sendProfileChatMessage()">
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
              <h3><i class="ri-user-3-fill text-blue" style="margin-left:8px;"></i> البيانات الشخصية</h3>
            </div>
            <div class="card-body">
              <div style="display:flex;gap:20px;align-items:center;margin-bottom:20px;">
                <div class="user-avatar-placeholder" style="width:72px;height:72px;font-size:28px;">${driver.avatar}</div>
                <div>
                  <h3 style="font-weight:800;font-size:18px;margin-bottom:4px;">${driver.name}</h3>
                  <span style="font-size:12px;color:var(--text-light);font-family:monospace;direction:ltr;display:inline-block;">UID: ${driver.uid}</span>
                </div>
              </div>

              <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-bottom:20px;">
                <div style="background:var(--bg-primary);padding:12px;border-radius:var(--radius-md);">
                  <div style="font-size:11px;color:var(--text-secondary);margin-bottom:4px;">رقم الهاتف</div>
                  <span style="font-weight:700;font-size:13px;direction:ltr;display:inline-block;">${driver.phone}</span>
                </div>
                <div style="background:var(--bg-primary);padding:12px;border-radius:var(--radius-md);">
                  <div style="font-size:11px;color:var(--text-secondary);margin-bottom:4px;">البريد الإلكتروني</div>
                  <span style="font-weight:700;font-size:13px;direction:ltr;display:inline-block;word-break:break-all;">${driver.email || '—'}</span>
                </div>
                <div style="background:var(--bg-primary);padding:12px;border-radius:var(--radius-md);">
                  <div style="font-size:11px;color:var(--text-secondary);margin-bottom:4px;">العنوان المسجل</div>
                  <span style="font-weight:700;font-size:13px;">${driver.address || '—'}</span>
                </div>
                <div style="background:var(--bg-primary);padding:12px;border-radius:var(--radius-md);">
                  <div style="font-size:11px;color:var(--text-secondary);margin-bottom:4px;">نوع وحالة المركبة</div>
                  <span class="vehicle-badge" style="font-weight:700;font-size:13px;">
                    <i class="${getVehicleIcon(driver.vehicleType)}"></i>
                    ${driver.vehicleName || 'لم تحدد'} (${driver.licensePlate || '—'})
                  </span>
                </div>
                <div style="background:var(--bg-primary);padding:12px;border-radius:var(--radius-md);">
                  <div style="font-size:11px;color:var(--text-secondary);margin-bottom:4px;">التقييم العام</div>
                  <div class="rating" style="font-size:14px;font-weight:800;color:var(--warning);">
                    <i class="ri-star-fill"></i>
                    <span>${driver.rating}</span>
                  </div>
                </div>
                <div style="background:var(--bg-primary);padding:12px;border-radius:var(--radius-md);">
                  <div style="font-size:11px;color:var(--text-secondary);margin-bottom:4px;">رصيد الأرباح والمحفظة</div>
                  <span style="font-weight:900;font-size:14px;color:var(--success);">${(driver.earnings || 0).toLocaleString()} ج.م</span>
                </div>
              </div>

              <!-- Quick Actions -->
              <div style="display:flex;gap:10px;flex-wrap:wrap;border-top:1px solid var(--border-light);padding-top:16px;">
                <button class="btn btn-outline btn-sm" onclick="showEditUserModal('${driver.uid}', 'driver')">
                  <i class="ri-edit-line"></i> تعديل البيانات الشخصية
                </button>
                <button class="btn btn-outline btn-sm" onclick="adjustWalletPrompt('${driver.uid}', 'driver')">
                  <i class="ri-wallet-3-line"></i> شحن المحفظة
                </button>
                ${driver.status === 'verified' ? `
                  <button class="btn btn-outline btn-sm" style="color:var(--error);border-color:var(--error);" onclick="modifyUserStatus('${driver.uid}', 'suspend', 'driver'); setTimeout(() => viewUserProfile('${driver.uid}', 'driver'), 500);">
                    <i class="ri-lock-line"></i> تعليق الحساب
                  </button>
                ` : `
                  <button class="btn btn-success btn-sm" style="background:var(--success);" onclick="modifyUserStatus('${driver.uid}', 'verify', 'driver'); setTimeout(() => viewUserProfile('${driver.uid}', 'driver'), 500);">
                    <i class="ri-lock-unlock-line"></i> تفعيل الحساب
                  </button>
                `}
                <button class="btn btn-outline btn-sm" style="color:var(--error);border-color:var(--error);" onclick="modifyUserStatus('${driver.uid}', 'ban', 'driver'); setTimeout(() => viewUserProfile('${driver.uid}', 'driver'), 500);">
                  <i class="ri-user-unfollow-line"></i> حظر الكابتن
                </button>
                <button class="btn btn-outline btn-sm" style="color:var(--error);border-color:var(--error);" onclick="deleteUserPrompt('${driver.uid}', 'driver')">
                  <i class="ri-delete-bin-line"></i> حذف الحساب نهائياً
                </button>
              </div>
            </div>
          </div>

          <!-- Documents -->
          <div class="card">
            <div class="card-header" style="display:flex;justify-content:space-between;align-items:center;">
              <h3><i class="ri-file-text-fill text-blue" style="margin-left:8px;"></i> المستندات والأوراق الثبوتية</h3>
              <span class="status-badge ${driver.status}">
                <span class="status-dot"></span> ${driver.statusAr}
              </span>
            </div>
            <div class="card-body">
              <div style="display:flex;flex-direction:column;gap:12px;">
                <div style="display:flex;justify-content:space-between;align-items:center;background:var(--bg-primary);padding:12px;border-radius:var(--radius-md);">
                  <span style="font-size:13px;font-weight:700;">الأوراق الرسمية المرفوعة</span>
                  <button class="btn btn-primary btn-sm" onclick="reviewDriverDocs('${driver.uid}')">
                    <i class="ri-file-search-line"></i> عرض ومراجعة المستندات
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Bottom: Trip History -->
      <div class="card">
        <div class="card-header">
          <h3><i class="ri-route-fill text-blue" style="margin-left:8px;"></i> سجل رحلات الكابتن (${driverTrips.length} رحلة)</h3>
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
              ${driverTrips.length === 0 ? `<tr><td colspan="6" style="text-align:center;padding:24px;color:var(--text-light);">لا توجد رحلات مسجلة لهذا الكابتن</td></tr>` : ''}
              ${driverTrips.map(trip => `
                <tr>
                  <td><span class="font-outfit fw-700" style="color:var(--medium-blue);">${trip.id}</span></td>
                  <td><span style="font-size:12px;color:var(--text-light);font-weight:600;">${trip.date}</span></td>
                  <td><span class="user-name">${trip.riderName}</span></td>
                  <td>
                    <div class="route-cell">
                      <div class="route-addresses">
                        <div class="route-from" style="font-size:11px;">${trip.from}</div>
                        <div class="route-to" style="font-size:11px;">${trip.to}</div>
                      </div>
                    </div>
                  </td>
                  <td>
                    <span class="price font-outfit">${trip.price}</span>
                    <span class="price-currency">ج.م</span>
                  </td>
                  <td>
                    <span class="status-badge ${getStatusClass(trip.status)}">
                      <span class="status-dot"></span>
                      ${trip.status}
                    </span>
                  </td>
                </tr>
              `).join('')}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  `;
}

function renderPassengerProfile() {
  const passenger = mockData.passengers.find(p => p.uid === activeProfileUid);
  if (!passenger) {
    return `<div style="padding:24px;text-align:center;color:var(--text-light);">لم يتم العثور على بيانات هذا الراكب.</div>`;
  }

  // Find passenger's trips
  const passengerTrips = mockData.trips.filter(t => t.riderName === passenger.name || t.riderPhone === passenger.phone);

  return `
    <div class="page-section">
      <!-- Back button and title -->
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:24px;">
        <button class="btn btn-outline btn-sm" onclick="navigateTo('passengers')" style="display:flex;align-items:center;gap:6px;">
          <i class="ri-arrow-right-line" style="font-size:16px;"></i> العودة لقائمة الركاب
        </button>
        <span class="text-light" style="font-size:13px;">تاريخ الانضمام: ${passenger.joinDate}</span>
      </div>

      <div class="profile-details-grid">
        <!-- Left Side: Support Chat -->
        <div class="card" style="display:flex;flex-direction:column;height:550px;">
          <div class="card-header" style="border-bottom:1px solid var(--border-color);padding-bottom:14px;">
            <h3 style="display:flex;align-items:center;gap:8px;">
              <i class="ri-customer-service-2-fill text-blue"></i>
              محادثة الدعم الفني المباشرة
            </h3>
            <span class="status-badge completed" style="font-size:11px;">
              <span class="status-dot"></span> متصل
            </span>
          </div>
          
          <!-- Message History -->
          <div id="profileChatMessages" style="flex:1;padding:20px;overflow-y:auto;background:var(--bg-primary);display:flex;flex-direction:column;gap:12px;">
            <div style="text-align:center;padding:24px;color:var(--text-light);font-size:13px;">جاري تحميل المحادثة...</div>
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
              <h3><i class="ri-user-3-fill text-blue" style="margin-left:8px;"></i> البيانات الشخصية</h3>
            </div>
            <div class="card-body">
              <div style="display:flex;gap:20px;align-items:center;margin-bottom:20px;">
                <div class="user-avatar-placeholder" style="width:72px;height:72px;font-size:28px;">${passenger.avatar}</div>
                <div>
                  <h3 style="font-weight:800;font-size:18px;margin-bottom:4px;">${passenger.name}</h3>
                  <span style="font-size:12px;color:var(--text-light);font-family:monospace;direction:ltr;display:inline-block;">UID: ${passenger.uid}</span>
                </div>
              </div>

              <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-bottom:20px;">
                <div style="background:var(--bg-primary);padding:12px;border-radius:var(--radius-md);">
                  <div style="font-size:11px;color:var(--text-secondary);margin-bottom:4px;">رقم الهاتف</div>
                  <span style="font-weight:700;font-size:13px;direction:ltr;display:inline-block;">${passenger.phone}</span>
                </div>
                <div style="background:var(--bg-primary);padding:12px;border-radius:var(--radius-md);">
                  <div style="font-size:11px;color:var(--text-secondary);margin-bottom:4px;">البريد الإلكتروني</div>
                  <span style="font-weight:700;font-size:13px;direction:ltr;display:inline-block;word-break:break-all;">${passenger.email || '—'}</span>
                </div>
                <div style="background:var(--bg-primary);padding:12px;border-radius:var(--radius-md);">
                  <div style="font-size:11px;color:var(--text-secondary);margin-bottom:4px;">العنوان المسجل</div>
                  <span style="font-weight:700;font-size:13px;">${passenger.address || '—'}</span>
                </div>
                <div style="background:var(--bg-primary);padding:12px;border-radius:var(--radius-md);">
                  <div style="font-size:11px;color:var(--text-secondary);margin-bottom:4px;">حالة الحساب</div>
                  <span class="status-badge ${getStatusClass(passenger.status)}" style="font-weight:700;font-size:13px;">
                    <span class="status-dot"></span>
                    ${passenger.statusAr}
                  </span>
                </div>
                <div style="background:var(--bg-primary);padding:12px;border-radius:var(--radius-md);">
                  <div style="font-size:11px;color:var(--text-secondary);margin-bottom:4px;">التقييم العام</div>
                  <div class="rating" style="font-size:14px;font-weight:800;color:var(--warning);">
                    <i class="ri-star-fill"></i>
                    <span>${passenger.rating}</span>
                  </div>
                </div>
                <div style="background:var(--bg-primary);padding:12px;border-radius:var(--radius-md);">
                  <div style="font-size:11px;color:var(--text-secondary);margin-bottom:4px;">إجمالي المدفوعات والإنفاق</div>
                  <span style="font-weight:900;font-size:14px;color:var(--medium-blue);">${(passenger.totalSpent || 0).toLocaleString()} ج.م</span>
                </div>
              </div>

              <!-- Quick Actions -->
              <div style="display:flex;gap:10px;flex-wrap:wrap;border-top:1px solid var(--border-light);padding-top:16px;">
                <button class="btn btn-outline btn-sm" onclick="showEditUserModal('${passenger.uid}', 'rider')">
                  <i class="ri-edit-line"></i> تعديل البيانات الشخصية
                </button>
                <button class="btn btn-outline btn-sm" onclick="adjustWalletPrompt('${passenger.uid}', 'rider')">
                  <i class="ri-wallet-3-line"></i> شحن المحفظة
                </button>
                ${passenger.status === 'active' ? `
                  <button class="btn btn-outline btn-sm" style="color:var(--error);border-color:var(--error);" onclick="modifyUserStatus('${passenger.uid}', 'suspend', 'rider'); setTimeout(() => viewUserProfile('${passenger.uid}', 'rider'), 500);">
                    <i class="ri-lock-line"></i> تعليق الحساب
                  </button>
                ` : `
                  <button class="btn btn-success btn-sm" style="background:var(--success);" onclick="modifyUserStatus('${passenger.uid}', 'activate', 'rider'); setTimeout(() => viewUserProfile('${passenger.uid}', 'rider'), 500);">
                    <i class="ri-lock-unlock-line"></i> تفعيل الحساب
                  </button>
                `}
                <button class="btn btn-outline btn-sm" style="color:var(--error);border-color:var(--error);" onclick="modifyUserStatus('${passenger.uid}', 'ban', 'rider'); setTimeout(() => viewUserProfile('${passenger.uid}', 'rider'), 500);">
                  <i class="ri-user-unfollow-line"></i> حظر الراكب
                </button>
                <button class="btn btn-outline btn-sm" style="color:var(--error);border-color:var(--error);" onclick="deleteUserPrompt('${passenger.uid}', 'rider')">
                  <i class="ri-delete-bin-line"></i> حذف الحساب نهائياً
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Bottom: Trip History -->
      <div class="card">
        <div class="card-header">
          <h3><i class="ri-route-fill text-blue" style="margin-left:8px;"></i> سجل رحلات الراكب (${passengerTrips.length} رحلة)</h3>
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
              ${passengerTrips.length === 0 ? `<tr><td colspan="6" style="text-align:center;padding:24px;color:var(--text-light);">لا توجد رحلات مسجلة لهذا الراكب</td></tr>` : ''}
              ${passengerTrips.map(trip => `
                <tr>
                  <td><span class="font-outfit fw-700" style="color:var(--medium-blue);">${trip.id}</span></td>
                  <td><span style="font-size:12px;color:var(--text-light);font-weight:600;">${trip.date}</span></td>
                  <td><span class="user-name">${trip.driverName}</span></td>
                  <td>
                    <div class="route-cell">
                      <div class="route-addresses">
                        <div class="route-from" style="font-size:11px;">${trip.from}</div>
                        <div class="route-to" style="font-size:11px;">${trip.to}</div>
                      </div>
                    </div>
                  </td>
                  <td>
                    <span class="price font-outfit">${trip.price}</span>
                    <span class="price-currency">ج.م</span>
                  </td>
                  <td>
                    <span class="status-badge ${getStatusClass(trip.status)}">
                      <span class="status-dot"></span>
                      ${trip.status}
                    </span>
                  </td>
                </tr>
              `).join('')}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  `;
}

function initProfileChatSync(uid, role) {
  if (profileChatUnsubscribe) {
    profileChatUnsubscribe();
    profileChatUnsubscribe = null;
  }

  const chatContainer = document.getElementById('profileChatMessages');
  if (!chatContainer) return;

  if (typeof firebase === 'undefined') {
    renderLocalProfileChat(uid);
    return;
  }

  const db = firebase.firestore();

  // Mark messages as read by admin
  db.collection('SupportChats').doc(uid).set({
    unreadByAdmin: false
  }, { merge: true }).catch(err => console.warn("Error marking chat read by admin:", err));

  profileChatUnsubscribe = db.collection('SupportChats').doc(uid).collection('Messages')
    .orderBy('createdAt', 'asc')
    .onSnapshot(snapshot => {
      let html = '';
      if (snapshot.empty) {
        html = '<div style="text-align:center;padding:24px;color:var(--text-light);font-size:13px;">لا توجد رسائل سابقة. ابدأ المحادثة الآن.</div>';
      } else {
        snapshot.forEach(doc => {
          const msg = doc.data();
          const isSupport = msg.senderId === 'support';
          const dateObj = msg.createdAt ? (msg.createdAt.toDate ? msg.createdAt.toDate() : new Date(msg.createdAt)) : new Date();
          const time = dateObj.toLocaleTimeString('ar-EG', {hour: '2-digit', minute:'2-digit'});
          
          html += `
            <div style="align-self: ${isSupport ? 'flex-end' : 'flex-start'}; max-width: 75%; margin-bottom: 12px; display: flex; flex-direction: column;">
              <div style="padding: 10px 14px; border-radius: var(--radius-md); background: ${isSupport ? 'var(--medium-blue)' : 'white'}; color: ${isSupport ? 'white' : 'var(--text-primary)'}; box-shadow: var(--shadow-sm); font-size: 13px; border: ${isSupport ? 'none' : '1px solid var(--border-color)'};">
                ${msg.text}
              </div>
              <div style="font-size: 10px; color: var(--text-light); text-align: ${isSupport ? 'left' : 'right'}; margin-top: 4px;">
                ${isSupport ? 'الدعم الفني' : 'المستخدم'} • ${time}
              </div>
            </div>
          `;
        });
      }
      chatContainer.innerHTML = html;
      chatContainer.scrollTop = chatContainer.scrollHeight;
    }, err => {
      console.warn("Firestore support chat listener error:", err);
      chatContainer.innerHTML = `<div style="text-align:center;color:var(--error);font-size:12px;padding:12px;">خطأ في تحميل المحادثة: ${err.message}</div>`;
    });
}

function renderLocalProfileChat(uid) {
  const chatContainer = document.getElementById('profileChatMessages');
  if (!chatContainer) return;

  const msgs = mockData.supportChats[uid] || [
    { senderId: 'user', text: 'مرحباً، أريد التواصل مع الدعم الفني لمشكلة ما.', createdAt: new Date(Date.now() - 3600000) },
    { senderId: 'support', text: 'أهلاً بك! يرجى إيضاح تفاصيل استفسارك وسنقوم بالرد عليك فوراً.', createdAt: new Date(Date.now() - 1800000) }
  ];

  // save back to cache if newly initialized
  if (!mockData.supportChats[uid]) {
    mockData.supportChats[uid] = msgs;
  }

  let html = '';
  msgs.forEach(msg => {
    const isSupport = msg.senderId === 'support';
    const time = msg.createdAt.toLocaleTimeString('ar-EG', {hour: '2-digit', minute:'2-digit'});
    html += `
      <div style="align-self: ${isSupport ? 'flex-end' : 'flex-start'}; max-width: 75%; margin-bottom: 12px; display: flex; flex-direction: column;">
        <div style="padding: 10px 14px; border-radius: var(--radius-md); background: ${isSupport ? 'var(--medium-blue)' : 'white'}; color: ${isSupport ? 'white' : 'var(--text-primary)'}; box-shadow: var(--shadow-sm); font-size: 13px; border: ${isSupport ? 'none' : '1px solid var(--border-color)'};">
          ${msg.text}
        </div>
        <div style="font-size: 10px; color: var(--text-light); text-align: ${isSupport ? 'left' : 'right'}; margin-top: 4px;">
          ${isSupport ? 'الدعم الفني' : 'المستخدم'} • ${time}
        </div>
      </div>
    `;
  });

  chatContainer.innerHTML = html;
  chatContainer.scrollTop = chatContainer.scrollHeight;
}

function sendProfileChatMessage() {
  const input = document.getElementById('profileChatInput');
  if (!input) return;
  const text = input.value.trim();
  if (!text) return;

  const uid = activeProfileUid;
  const role = activeProfileRole;

  if (supabaseClient) {
    // Assuming support_messages and support_chats tables for Supabase if implemented.
    // For now we will just use local fallback until the schema is fully ready.
    addLocalProfileChatMessage(uid, text);
    input.value = '';
    
    // Future Supabase Implementation:
    /*
    supabaseClient.from('support_messages').insert({
      chat_id: uid,
      sender_id: 'support',
      text: text,
      is_seen: false
    }).then(() => {
      // update support_chats
    });
    */
  } else {
    // Local fallback
    addLocalProfileChatMessage(uid, text);
    input.value = '';
  }
}

function addLocalProfileChatMessage(uid, text) {
  if (!mockData.supportChats[uid]) {
    mockData.supportChats[uid] = [];
  }
  
  mockData.supportChats[uid].push({
    senderId: 'support',
    text: text,
    createdAt: new Date()
  });

  renderLocalProfileChat(uid);
  logAction(`إرسال رسالة دعم محلياً للمستخدم: ${uid}`);
}


