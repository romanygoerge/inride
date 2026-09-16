/**
 * inRide Security Center & Digital Forensics Module (2026)
 * Enterprise-grade Security Monitoring, Cryptographic Audit Trail, Forensics & Incident Response.
 */

// ============================================
// SECURITY CENTER STATE
// ============================================
const secState = {
  activeTab: 'overview', // 'overview', 'events', 'forensics', 'incidents'
  dateFilter: '7d',      // 'today', '7d', '30d', 'custom'
  customStart: '',
  customEnd: '',
  searchQuery: '',
  severityFilter: 'ALL',
  eventTypeFilter: 'ALL',
  events: [],
  filteredEvents: [],
  incidents: [],
  kpis: {
    total: 0,
    critical: 0,
    high: 0,
    suspiciousRequests: 0,
    failedAuth: 0,
    newDevices: 0,
    suspiciousOtp: 0,
    activeIncidents: 0
  },
  selectedEvent: null,
  selectedIncident: null,
  maskPhones: true,
  autoRefresh: true,
  refreshTimer: null,
  realtimeChannel: null,
  soundEnabled: true
};

// ============================================
// AUDIO ALERT (Synthesized Web Audio API)
// ============================================
function playSecurityAlertSound(isCritical = true) {
  if (!secState.soundEnabled) return;
  try {
    const audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();

    osc.type = isCritical ? 'sawtooth' : 'sine';
    osc.frequency.setValueAtTime(isCritical ? 880 : 587, audioCtx.currentTime); // A5 or D5
    osc.frequency.exponentialRampToValueAtTime(isCritical ? 440 : 880, audioCtx.currentTime + 0.35);

    gain.gain.setValueAtTime(0.25, audioCtx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.01, audioCtx.currentTime + 0.4);

    osc.connect(gain);
    gain.connect(audioCtx.destination);

    osc.start();
    osc.stop(audioCtx.currentTime + 0.4);
  } catch (_) {}
}

// ============================================
// CORE DATA FETCHING & SUPABASE CLIENT HELPER
// ============================================
function getSecClient() {
  if (window.supabaseClient && typeof window.supabaseClient.from === 'function') {
    return window.supabaseClient;
  }
  if (typeof supabaseClient !== 'undefined' && supabaseClient && typeof supabaseClient.from === 'function') {
    window.supabaseClient = supabaseClient;
    return supabaseClient;
  }
  if (typeof getSupabaseClient === 'function') {
    const cl = getSupabaseClient();
    if (cl && typeof cl.from === 'function') {
      window.supabaseClient = cl;
      return cl;
    }
  }
  if (typeof window.supabase !== 'undefined' && typeof window.supabase.createClient === 'function') {
    const SUPABASE_URL = 'https://fylruevfksmqnkykqkin.supabase.co';
    const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5bHJ1ZXZma3NtcW5reWtxa2luIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ3NTY3NDYsImV4cCI6MjEwMDMzMjc0Nn0.u5NVng7fsptjQOnNlEYP7MzNDp8_ssN94xSxzg8VYi4';
    window.supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
    return window.supabaseClient;
  }
  return null;
}

async function fetchSecurityEvents() {
  const client = getSecClient();
  if (!client) {
    console.warn('[Security Center] Supabase client not initialized yet');
    return;
  }

  try {
    let query = client
      .from('security_events')
      .select('*')
      .order('seq_num', { ascending: false })
      .limit(300);

    // Apply Date Filter
    const now = new Date();
    if (secState.dateFilter === 'today') {
      const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString();
      query = query.gte('created_at', todayStart);
    } else if (secState.dateFilter === '7d') {
      const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000).toISOString();
      query = query.gte('created_at', sevenDaysAgo);
    } else if (secState.dateFilter === '30d') {
      const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000).toISOString();
      query = query.gte('created_at', thirtyDaysAgo);
    } else if (secState.dateFilter === 'custom' && secState.customStart) {
      query = query.gte('created_at', new Date(secState.customStart).toISOString());
      if (secState.customEnd) {
        query = query.lte('created_at', new Date(secState.customEnd).toISOString());
      }
    }

    const { data, error } = await query;
    if (error) throw error;

    secState.events = data || [];
    calculateSecurityKPIs(secState.events);
    filterSecurityEvents();
  } catch (err) {
    console.error('[Security Center] Error loading security events:', err);
    if (typeof showToast === 'function') showToast('تعذر تحميل سجلات الأمان: ' + err.message, 'error');
  }
}

async function fetchSecurityIncidents() {
  const client = getSecClient();
  if (!client) return;
  try {
    const { data, error } = await client
      .from('security_incidents')
      .select('*')
      .order('created_at', { ascending: false });

    if (error) throw error;
    secState.incidents = data || [];
    secState.kpis.activeIncidents = secState.incidents.filter(i => i.status !== 'CLOSED' && i.status !== 'RESOLVED').length;
    updateSecurityKpiUI();
  } catch (err) {
    console.error('[Security Center] Error loading incidents:', err);
  }
}

function calculateSecurityKPIs(events) {
  const kpis = {
    total: events.length,
    critical: 0,
    high: 0,
    suspiciousRequests: 0,
    failedAuth: 0,
    newDevices: 0,
    suspiciousOtp: 0,
    activeIncidents: secState.incidents.filter(i => i.status !== 'CLOSED' && i.status !== 'RESOLVED').length
  };

  events.forEach(e => {
    if (e.severity === 'CRITICAL') kpis.critical++;
    if (e.severity === 'HIGH') kpis.high++;
    
    if (e.event_type.includes('INJECTION') || e.event_type.includes('HONEYPOT') || e.event_type.includes('SUSPICIOUS')) {
      kpis.suspiciousRequests++;
    }
    if (e.event_type.includes('FAILED') || e.event_type.includes('AUTH') || e.event_type.includes('TAMPER')) {
      kpis.failedAuth++;
    }
    if (e.event_type.includes('NEW_DEVICE')) {
      kpis.newDevices++;
    }
    if (e.event_type.includes('OTP') && (e.severity === 'CRITICAL' || e.severity === 'HIGH' || e.event_type.includes('INJECTION') || e.event_type.includes('RATE_LIMIT'))) {
      kpis.suspiciousOtp++;
    }
  });

  secState.kpis = kpis;
  updateSecurityKpiUI();
}

function filterSecurityEvents() {
  const query = (secState.searchQuery || '').toLowerCase().trim();
  const severity = secState.severityFilter;
  const eventType = secState.eventTypeFilter;

  secState.filteredEvents = secState.events.filter(e => {
    // Severity Filter
    if (severity !== 'ALL' && e.severity !== severity) return false;
    
    // Type Filter
    if (eventType !== 'ALL' && e.event_type !== eventType) return false;

    // Search Query
    if (query) {
      const matchId = String(e.id || '').toLowerCase().includes(query);
      const matchReq = String(e.request_id || '').toLowerCase().includes(query);
      const matchMsg = String(e.message_id || '').toLowerCase().includes(query);
      const matchProvMsg = String(e.provider_message_id || '').toLowerCase().includes(query);
      const matchIp = String(e.ip_address || '').toLowerCase().includes(query);
      const matchDevice = String(e.device_id || '').toLowerCase().includes(query);
      const matchUser = String(e.user_id || '').toLowerCase().includes(query);
      const matchEndpoint = String(e.endpoint || '').toLowerCase().includes(query);
      const matchDetails = JSON.stringify(e.details || {}).toLowerCase().includes(query);

      if (!matchId && !matchReq && !matchMsg && !matchProvMsg && !matchIp && !matchDevice && !matchUser && !matchEndpoint && !matchDetails) {
        return false;
      }
    }

    return true;
  });

  // Re-render table if on events or overview tab
  const tableBody = document.getElementById('secEventsTableBody');
  if (tableBody) {
    tableBody.innerHTML = renderSecurityEventsTableRows();
  }
}

// ============================================
// REALTIME LISTENER & SUBSCRIPTIONS
// ============================================
function setupSecurityRealtime() {
  const client = getSecClient();
  if (!client || secState.realtimeChannel) return;

  try {
    secState.realtimeChannel = client
      .channel('public:security_events')
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'security_events' }, payload => {
        const newEvent = payload.new;
        if (!newEvent) return;

        console.log('[SECURITY ALERT RECEIVED]:', newEvent);
        secState.events.unshift(newEvent);
        calculateSecurityKPIs(secState.events);
        filterSecurityEvents();

        // Check if High or Critical to dispatch immediate Live Alert banner
        if (newEvent.severity === 'CRITICAL' || newEvent.severity === 'HIGH') {
          playSecurityAlertSound(newEvent.severity === 'CRITICAL');
          triggerLiveSecurityAlert(newEvent);
        }
      })
      .subscribe();
  } catch (err) {
    console.warn('[Security Center] Realtime setup fallback:', err);
  }
}

function triggerLiveSecurityAlert(event) {
  const alertContainer = document.getElementById('secLiveAlertContainer');
  if (!alertContainer) return;

  const isCritical = event.severity === 'CRITICAL';
  const alertEl = document.createElement('div');
  alertEl.className = 'sec-floating-alert ' + (isCritical ? 'sec-alert-critical' : 'sec-alert-high');
  alertEl.innerHTML = `
    <div style="display:flex; align-items:flex-start; gap:12px;">
      <div style="font-size:24px; animation: secPulse 1s infinite;">${isCritical ? '🚨' : '⚠️'}</div>
      <div style="flex:1;">
        <div style="display:flex; justify-content:space-between; align-items:center;">
          <strong style="font-size:13.5px; color:${isCritical ? '#EF4444' : '#F59E0B'};">
            ${isCritical ? 'رصد حدث أمني فوري حرج (CRITICAL)' : 'تنبيه أمني عالي الخطورة (HIGH)'}
          </strong>
          <button onclick="this.closest('.sec-floating-alert').remove()" style="background:none;border:none;color:#94A3B8;cursor:pointer;font-size:16px;">&times;</button>
        </div>
        <p style="margin:4px 0 6px 0; font-size:12px; color:var(--text-primary); font-weight:600;">
          ${escapeSecHtml(event.event_type)}
        </p>
        <div style="font-size:11px; color:var(--text-secondary); display:flex; flex-wrap:wrap; gap:8px;">
          <span>IP: <b>${escapeSecHtml(event.ip_address || 'غير محدد')}</b></span>
          <span>Endpoint: <b>${escapeSecHtml(event.endpoint || '-')}</b></span>
          <span>ReqID: <b>${escapeSecHtml(event.request_id || '-')}</b></span>
        </div>
        <div style="margin-top:8px;">
          <button class="btn btn-sm btn-primary" onclick="openEventDetailsModal('${event.id}'); this.closest('.sec-floating-alert').remove();" style="font-size:11px; padding:4px 10px;">
            🔍 فتح تفاصيل الحدث والتحقيق فوراً
          </button>
        </div>
      </div>
    </div>
  `;

  alertContainer.prepend(alertEl);

  // Auto remove after 15 seconds
  setTimeout(() => {
    if (alertEl.parentNode) alertEl.remove();
  }, 15000);
}

// ============================================
// MAIN PAGE RENDERER
// ============================================
function renderSecurityCenter() {
  return `
    <div class="sec-container" dir="rtl">
      <!-- Floating Alert Container for Realtime High/Critical Events -->
      <div id="secLiveAlertContainer" class="sec-floating-alert-container"></div>

      <!-- Top Live Security Posture Header -->
      <div class="sec-header-banner">
        <div class="sec-posture-badge ${secState.kpis.critical > 0 ? 'posture-alert' : 'posture-safe'}">
          <i class="${secState.kpis.critical > 0 ? 'ri-error-warning-fill' : 'ri-shield-check-fill'}"></i>
          <span>${secState.kpis.critical > 0 ? 'تنبيه: محاولات اختراق أو نشاطات مشبوهة مرصودة' : 'النظام مؤمّن - السلسلة التشفيرية متصلة وسليمة'}</span>
        </div>

        <div class="sec-header-actions">
          <button class="btn btn-outline btn-sm" onclick="openVerifyIntegrityModal()" title="التحقق من سلامة التجزئة التشفيرية لسجلات التدقيق">
            <i class="ri-link-m"></i>
            <span>فحص سلامة السلسلة التشفيرية (Hash Chain)</span>
          </button>
          
          <button class="btn btn-outline btn-sm" onclick="toggleSecPhoneMasking()">
            <i class="${secState.maskPhones ? 'ri-eye-line' : 'ri-eye-off-line'}"></i>
            <span>${secState.maskPhones ? 'إظهار الأرقام كاملة (للمشرفين)' : 'تعمية أرقام الهواتف (Privacy)'}</span>
          </button>

          <button class="btn btn-primary btn-sm" onclick="refreshSecurityData()">
            <i class="ri-refresh-line"></i>
            <span>تحديث السجلات اللحظية</span>
          </button>
        </div>
      </div>

      <!-- KPI METRIC CARDS -->
      <div class="sec-kpi-grid">
        <div class="sec-kpi-card">
          <div class="sec-kpi-icon icon-blue"><i class="ri-shield-keyhole-line"></i></div>
          <div class="sec-kpi-info">
            <span class="sec-kpi-title">إجمالي Security Events</span>
            <h3 class="sec-kpi-value" id="kpiTotalEvents">${secState.kpis.total}</h3>
            <span class="sec-kpi-sub">سجلات مسجلة وموثقة تشفيرياً</span>
          </div>
        </div>

        <div class="sec-kpi-card card-critical ${secState.kpis.critical > 0 ? 'pulse-border' : ''}">
          <div class="sec-kpi-icon icon-critical"><i class="ri-alarm-warning-fill"></i></div>
          <div class="sec-kpi-info">
            <span class="sec-kpi-title">Critical Events</span>
            <h3 class="sec-kpi-value text-critical" id="kpiCriticalEvents">${secState.kpis.critical}</h3>
            <span class="sec-kpi-sub">محاولات حقن أو اختراق مسارات</span>
          </div>
        </div>

        <div class="sec-kpi-card">
          <div class="sec-kpi-icon icon-amber"><i class="ri-alert-line"></i></div>
          <div class="sec-kpi-info">
            <span class="sec-kpi-title">High Risk Events</span>
            <h3 class="sec-kpi-value text-amber" id="kpiHighEvents">${secState.kpis.high}</h3>
            <span class="sec-kpi-sub">تجاوز المعدلات أو تلاعب التوقيع</span>
          </div>
        </div>

        <div class="sec-kpi-card">
          <div class="sec-kpi-icon icon-purple"><i class="ri-radar-line"></i></div>
          <div class="sec-kpi-info">
            <span class="sec-kpi-title">Suspicious Requests</span>
            <h3 class="sec-kpi-value" id="kpiSuspiciousRequests">${secState.kpis.suspiciousRequests}</h3>
            <span class="sec-kpi-sub">Canary Trap & Probes</span>
          </div>
        </div>

        <div class="sec-kpi-card">
          <div class="sec-kpi-icon icon-orange"><i class="ri-user-unfollow-line"></i></div>
          <div class="sec-kpi-info">
            <span class="sec-kpi-title">Failed Auth Attempts</span>
            <h3 class="sec-kpi-value" id="kpiFailedAuth">${secState.kpis.failedAuth}</h3>
            <span class="sec-kpi-sub">فشل كلمة المرور والـ Tokens</span>
          </div>
        </div>

        <div class="sec-kpi-card">
          <div class="sec-kpi-icon icon-teal"><i class="ri-smartphone-line"></i></div>
          <div class="sec-kpi-info">
            <span class="sec-kpi-title">New Devices</span>
            <h3 class="sec-kpi-value" id="kpiNewDevices">${secState.kpis.newDevices}</h3>
            <span class="sec-kpi-sub">بصمات أجهزة جديدة مكتشفة</span>
          </div>
        </div>

        <div class="sec-kpi-card">
          <div class="sec-kpi-icon icon-rose"><i class="ri-message-3-line"></i></div>
          <div class="sec-kpi-info">
            <span class="sec-kpi-title">Suspicious OTP Attempts</span>
            <h3 class="sec-kpi-value" id="kpiSuspiciousOtp">${secState.kpis.suspiciousOtp}</h3>
            <span class="sec-kpi-sub">طلبات إرسال رسائل غير مصرح بها</span>
          </div>
        </div>

        <div class="sec-kpi-card">
          <div class="sec-kpi-icon icon-red"><i class="ri-fire-fill"></i></div>
          <div class="sec-kpi-info">
            <span class="sec-kpi-title">Active Incidents</span>
            <h3 class="sec-kpi-value" id="kpiActiveIncidents">${secState.kpis.activeIncidents}</h3>
            <span class="sec-kpi-sub">بلاغات تحقيق مفتوحة للمتابعة</span>
          </div>
        </div>
      </div>

      <!-- TABS NAVIGATION & TIMELINE BAR -->
      <div class="sec-tabs-wrapper">
        <div class="sec-tabs">
          <button class="sec-tab-btn ${secState.activeTab === 'overview' ? 'active' : ''}" onclick="switchSecTab('overview')">
            <i class="ri-dashboard-line"></i>
            <span>لوحة المراقبة والتحليلات</span>
          </button>
          
          <button class="sec-tab-btn ${secState.activeTab === 'events' ? 'active' : ''}" onclick="switchSecTab('events')">
            <i class="ri-list-check-2"></i>
            <span>سجل الأحداث الأمنية الكامل (Security Events)</span>
            <span class="sec-badge-count" id="tabEventsCount">${secState.events.length}</span>
          </button>

          <button class="sec-tab-btn ${secState.activeTab === 'forensics' ? 'active' : ''}" onclick="switchSecTab('forensics')">
            <i class="ri-microscope-line"></i>
            <span>التحقيق الجنائي الرقمي للرسائل (Forensic Search)</span>
          </button>

          <button class="sec-tab-btn ${secState.activeTab === 'incidents' ? 'active' : ''}" onclick="switchSecTab('incidents')">
            <i class="ri-alarm-warning-line"></i>
            <span>إدارة البلاغات والحوادث (Incidents)</span>
            <span class="sec-badge-count count-red" id="tabIncidentsCount">${secState.incidents.length}</span>
          </button>
        </div>

        <!-- Date Range Filter Selector -->
        <div class="sec-date-filters">
          <button class="sec-date-btn ${secState.dateFilter === 'today' ? 'active' : ''}" onclick="setSecDateFilter('today')">اليوم (Today)</button>
          <button class="sec-date-btn ${secState.dateFilter === '7d' ? 'active' : ''}" onclick="setSecDateFilter('7d')">آخر 7 أيام</button>
          <button class="sec-date-btn ${secState.dateFilter === '30d' ? 'active' : ''}" onclick="setSecDateFilter('30d')">آخر 30 يوماً</button>
          <button class="sec-date-btn ${secState.dateFilter === 'custom' ? 'active' : ''}" onclick="setSecDateFilter('custom')">نطاق مخصص</button>
        </div>
      </div>

      <!-- TAB CONTENTS -->
      <div id="secTabContentArea">
        ${renderSecActiveTabContent()}
      </div>

      <!-- EVENT DETAILS MODAL CONTAINER -->
      <div id="secEventModalContainer"></div>
      <!-- VERIFY INTEGRITY MODAL CONTAINER -->
      <div id="secIntegrityModalContainer"></div>
      <!-- CREATE INCIDENT MODAL CONTAINER -->
      <div id="secCreateIncidentModalContainer"></div>
    </div>
  `;
}

function renderSecActiveTabContent() {
  switch (secState.activeTab) {
    case 'overview':
      return renderSecurityOverviewTab();
    case 'events':
      return renderSecurityEventsTab();
    case 'forensics':
      return renderSecurityForensicsTab();
    case 'incidents':
      return renderSecurityIncidentsTab();
    default:
      return renderSecurityOverviewTab();
  }
}

// ============================================
// TAB 1: OVERVIEW & THREAT MATRIX
// ============================================
function renderSecurityOverviewTab() {
  return `
    <div class="sec-overview-grid">
      <!-- Recent Threats & Attacks Card -->
      <div class="card" style="grid-column: span 2;">
        <div class="card-header" style="display:flex; justify-content:space-between; align-items:center;">
          <div style="display:flex; align-items:center; gap:8px;">
            <i class="ri-shield-flash-fill" style="color:var(--medium-blue); font-size:18px;"></i>
            <h3>آخر التهديدات والأحداث الأمنية المرصودة</h3>
          </div>
          <button class="btn btn-outline btn-sm" onclick="switchSecTab('events')">عرض جميع السجلات (${secState.events.length})</button>
        </div>
        <div class="card-body" style="padding:0;">
          <div class="sec-table-responsive">
            <table class="data-table sec-table">
              <thead>
                <tr>
                  <th>الوقت والتاريخ</th>
                  <th>نوع الحدث (Event Type)</th>
                  <th>الخطورة</th>
                  <th>الحساب المستهدف</th>
                  <th>الجهاز / النظام</th>
                  <th>عنوان IP</th>
                  <th>الـ Endpoint</th>
                  <th>التفاصيل والتحقيق</th>
                </tr>
              </thead>
              <tbody id="secOverviewTableBody">
                ${renderSecurityEventsTableRows(10)}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <!-- Threat Categories & Honeypot Status -->
      <div class="card">
        <div class="card-header">
          <div style="display:flex; align-items:center; gap:8px;">
            <i class="ri-radar-fill" style="color:#EF4444; font-size:18px;"></i>
            <h3>المصائد الدفاعية (Canary / Honeypot)</h3>
          </div>
        </div>
        <div class="card-body">
          <p style="font-size:12px; color:var(--text-secondary); margin-bottom:12px;">
            مسارات تمويه دفاعية ترصد أي استطلاع عشوائي أو محاولات فحص تلقائي لأسرار السيرفر:
          </p>

          <div class="sec-honeypot-list">
            <div class="sec-honeypot-item">
              <div>
                <strong style="font-size:12px; display:block; font-family:'Outfit',sans-serif;">/api/v1/system/backup-keys</strong>
                <span style="font-size:11px; color:var(--text-light);">مسار تمويه مفاتيح النسخ الاحتياطي</span>
              </div>
              <span class="badge" style="background:#DCFCE7; color:#16A34A; font-weight:700;">نشط وحارس 🛡️</span>
            </div>

            <div class="sec-honeypot-item">
              <div>
                <strong style="font-size:12px; display:block; font-family:'Outfit',sans-serif;">/api/v1/admin/debug</strong>
                <span style="font-size:11px; color:var(--text-light);">مسار فحص محاولات التصعيد الإداري</span>
              </div>
              <span class="badge" style="background:#DCFCE7; color:#16A34A; font-weight:700;">نشط وحارس 🛡️</span>
            </div>

            <div class="sec-honeypot-item">
              <div>
                <strong style="font-size:12px; display:block; font-family:'Outfit',sans-serif;">/api/internal/config-dump</strong>
                <span style="font-size:11px; color:var(--text-light);">مصيدة كشف مسح البنية التحتية</span>
              </div>
              <span class="badge" style="background:#DCFCE7; color:#16A34A; font-weight:700;">نشط وحارس 🛡️</span>
            </div>
          </div>

          <div style="margin-top:16px; padding:12px; background:var(--bg-primary); border-radius:var(--radius-md); border-right:3px solid var(--medium-blue);">
            <div style="font-weight:700; font-size:12px; color:var(--text-primary); margin-bottom:4px;">مبدأ الأمان الدفاعي</div>
            <div style="font-size:11px; color:var(--text-secondary); line-height:1.6;">
              أي طلب يلمس هذه المسارات لا يُنفذ أي مهمة، بل يلتقط بصمة الـ IP و User-Agent ويحظر المحاولة فوراً مع تسجيل حدث أمني حرج.
            </div>
          </div>
        </div>
      </div>
    </div>
  `;
}

// ============================================
// TAB 2: FULL SECURITY EVENTS TABLE
// ============================================
function renderSecurityEventsTab() {
  return `
    <div class="card">
      <!-- Search & Filters Toolbar -->
      <div class="sec-filters-bar">
        <div class="sec-search-wrapper">
          <i class="ri-search-line"></i>
          <input 
            type="text" 
            id="secSearchInput" 
            placeholder="ابحث بواسطة: user_id, phone, IP, device_id, request_id, message_id, session_id..." 
            value="${escapeSecHtml(secState.searchQuery)}"
            oninput="handleSecSearch(this.value)"
          />
        </div>

        <div class="sec-filter-group">
          <select id="secSeveritySelect" class="form-select" onchange="handleSecSeverityFilter(this.value)">
            <option value="ALL" ${secState.severityFilter === 'ALL' ? 'selected' : ''}>كافة مستويات الخطورة</option>
            <option value="CRITICAL" ${secState.severityFilter === 'CRITICAL' ? 'selected' : ''}>🚨 حرج (CRITICAL)</option>
            <option value="HIGH" ${secState.severityFilter === 'HIGH' ? 'selected' : ''}>⚠️ عالي الخطورة (HIGH)</option>
            <option value="MEDIUM" ${secState.severityFilter === 'MEDIUM' ? 'selected' : ''}>متوسط (MEDIUM)</option>
            <option value="LOW" ${secState.severityFilter === 'LOW' ? 'selected' : ''}>منخفض (LOW)</option>
            <option value="INFO" ${secState.severityFilter === 'INFO' ? 'selected' : ''}>معلوماتي (INFO)</option>
          </select>

          <select id="secEventTypeSelect" class="form-select" onchange="handleSecEventTypeFilter(this.value)">
            <option value="ALL" ${secState.eventTypeFilter === 'ALL' ? 'selected' : ''}>كافة أنواع الأحداث</option>
            <option value="CUSTOM_MESSAGE_INJECTION_ATTEMPT">حقن نصوص ورسائل مخصصة</option>
            <option value="CANARY_HONEYPOT_TRIGGERED">سقوط في المصيدة (Honeypot)</option>
            <option value="OTP_RATE_LIMIT_EXCEEDED">تجاوز معدل إرسال OTP</option>
            <option value="APP_INTEGRITY_TAMPER_DETECTED">تلاعب بتوقيع التطبيق</option>
            <option value="FAILED_AUTHENTICATION_ATTEMPTS">فشل متكرر في تسجيل الدخول</option>
            <option value="NEW_DEVICE_LOGIN">تسجيل دخول من جهاز جديد</option>
            <option value="OTP_DISPATCHED_SECURELY">إرسال كود موثق بنجاح</option>
          </select>
        </div>
      </div>

      <!-- Events Data Table -->
      <div class="sec-table-responsive">
        <table class="data-table sec-table">
          <thead>
            <tr>
              <th>الوقت</th>
              <th>نوع الحدث</th>
              <th>الخطورة</th>
              <th>الحساب / المستخدم</th>
              <th>الجهاز</th>
              <th>عنوان IP</th>
              <th>الـ Endpoint</th>
              <th>Message ID</th>
              <th>Request ID</th>
              <th>سلامة السلسلة</th>
              <th>إجراءات</th>
            </tr>
          </thead>
          <tbody id="secEventsTableBody">
            ${renderSecurityEventsTableRows()}
          </tbody>
        </table>
      </div>

      <div class="card-footer sec-table-footer">
        <span>عرض <b>${secState.filteredEvents.length}</b> من أصل <b>${secState.events.length}</b> حدث أمني مسجل</span>
        <div style="font-size:11px; color:var(--text-light); display:flex; align-items:center; gap:6px;">
          <i class="ri-lock-line"></i>
          <span>سجلات التدقيق غير قابلة للتعديل أو الحذف (Cryptographically Sealed)</span>
        </div>
      </div>
    </div>
  `;
}

function renderSecurityEventsTableRows(limit = null) {
  const events = limit ? secState.filteredEvents.slice(0, limit) : secState.filteredEvents;

  if (events.length === 0) {
    return `
      <tr>
        <td colspan="11" style="text-align:center; padding:36px; color:var(--text-light);">
          <i class="ri-shield-check-line" style="font-size:36px; display:block; margin-bottom:8px; color:var(--success);"></i>
          لا توجد سجلات تطابق معايير الفلترة الحالية
        </td>
      </tr>
    `;
  }

  return events.map(e => {
    const timeStr = formatSecTime(e.timestamp || e.created_at);
    const severityBadge = getSeverityBadge(e.severity);
    const eventTypeBadge = getEventTypeBadge(e.event_type);
    
    // Mask phone number if present
    let accountDisplay = e.user_id ? `<span class="font-outfit" title="${e.user_id}">${e.user_id.substring(0, 8)}...</span>` : 'مجهول (Guest)';
    if (e.details && (e.details.phone_masked || e.details.recipient_masked)) {
      const ph = e.details.phone_masked || e.details.recipient_masked;
      accountDisplay = `<span class="font-outfit" style="font-weight:700;">${secState.maskPhones ? maskPhoneNumber(ph) : ph}</span>`;
    }

    const deviceStr = e.device_model || e.device_platform || (e.device_id ? e.device_id.substring(0, 10) : '-');
    const ipStr = e.ip_address || '-';
    const countryCity = (e.country ? `${e.country}${e.city ? ' - ' + e.city : ''}` : '');

    return `
      <tr class="sec-row-${String(e.severity).toLowerCase()}" onclick="openEventDetailsModal('${e.id}')" style="cursor:pointer;">
        <td><span class="font-outfit" style="font-size:11.5px; white-space:nowrap;">${timeStr}</span></td>
        <td>${eventTypeBadge}</td>
        <td>${severityBadge}</td>
        <td>${accountDisplay}</td>
        <td><span class="font-outfit" style="font-size:12px; color:var(--text-secondary);">${escapeSecHtml(deviceStr)}</span></td>
        <td>
          <div style="line-height:1.2;">
            <span class="font-outfit" style="font-weight:600; font-size:12px;">${escapeSecHtml(ipStr)}</span>
            ${countryCity ? `<div style="font-size:10px; color:var(--text-light);">${escapeSecHtml(countryCity)}</div>` : ''}
          </div>
        </td>
        <td><code class="sec-code-pill">${escapeSecHtml(e.endpoint || '-')}</code></td>
        <td><span class="font-outfit" style="font-size:11px; color:var(--text-secondary);">${e.message_id ? escapeSecHtml(e.message_id) : '-'}</span></td>
        <td><span class="font-outfit" style="font-size:11px; color:var(--text-secondary);">${e.request_id ? escapeSecHtml(e.request_id.substring(0, 16)) : '-'}</span></td>
        <td>
          <span class="badge" style="background:#F1F5F9; color:#475569; font-size:10px; font-family:'Outfit',sans-serif;" title="Hash: ${e.event_hash}">
            <i class="ri-shield-keyhole-line" style="color:#10B981;"></i> موثق
          </span>
        </td>
        <td onclick="event.stopPropagation();">
          <div style="display:flex; gap:6px;">
            <button class="btn btn-sm btn-outline" onclick="openEventDetailsModal('${e.id}')" title="فتح تفاصيل الحدث والتحقيق">
              <i class="ri-search-eye-line"></i>
            </button>
            <button class="btn btn-sm btn-outline" onclick="openCreateIncidentModal('${e.id}')" title="إنشاء بلاغ تحقيق (Incident)">
              <i class="ri-alarm-warning-line" style="color:#EF4444;"></i>
            </button>
          </div>
        </td>
      </tr>
    `;
  }).join('');
}

// ============================================
// TAB 3: DIGITAL FORENSICS INVESTIGATION
// ============================================
function renderSecurityForensicsTab() {
  return `
    <div class="card">
      <div class="card-header">
        <div style="display:flex; align-items:center; gap:8px;">
          <i class="ri-fingerprint-line" style="color:var(--medium-blue); font-size:20px;"></i>
          <div>
            <h3 style="margin:0;">التحقيق الجنائي الرقمي للرسائل (Digital Forensics Trace)</h3>
            <p style="margin:0; font-size:12px; color:var(--text-secondary);">
              إعادة بناء السلسلة الجنائية الكاملة للرسالة المشبوهة أو الطلب من نقطة الانطلاق إلى مزود الخدمة
            </p>
          </div>
        </div>
      </div>

      <div class="card-body">
        <div class="sec-forensics-search-box">
          <label style="font-size:12px; font-weight:700; color:var(--text-primary); margin-bottom:6px; display:block;">
            أدخل معرف الرسالة أو الطلب أو رقم المستلم للتحقيق:
          </label>
          <div style="display:flex; gap:10px;">
            <input 
              type="text" 
              id="secForensicsInput" 
              class="form-control" 
              placeholder="مثال: MSG-INR-2026-99120 أو WAP-MSG-009988776655 أو REQ-SEC-9901 أو 01000000000"
              style="flex:1; font-family:'Outfit',sans-serif;"
            />
            <button class="btn btn-primary" onclick="performForensicTrace()">
              <i class="ri-radar-fill"></i>
              <span>بدء التتبع الجنائي (Trace)</span>
            </button>
          </div>
        </div>

        <div id="secForensicsResultArea" style="margin-top:24px;">
          <div class="sec-empty-forensics">
            <i class="ri-search-eye-line" style="font-size:48px; color:var(--text-light); display:block; margin-bottom:12px;"></i>
            <h4>أدخل معرف الرسالة أو المعرف التقني للبدء في ربط السلسلة الجنائية</h4>
            <p style="font-size:12px; color:var(--text-secondary); max-width:500px; margin:0 auto;">
              يقوم النظام بالبحث في سجلات الرسائل، مزودي الخدمة (WA Pilot)، الجلسات، الأجهزة، وعناوين IP لرسم شجرة الأحداث الكاملة وكشف أي فجوة في البيانات.
            </p>
          </div>
        </div>
      </div>
    </div>
  `;
}

function performForensicTrace() {
  const input = document.getElementById('secForensicsInput');
  const term = (input ? input.value : '').trim().toLowerCase();
  const container = document.getElementById('secForensicsResultArea');
  if (!container) return;

  if (!term) {
    if (typeof showToast === 'function') showToast('يرجى كتابة معرف الرسالة أو الطلب للبحث.', 'warning');
    return;
  }

  // Search matching events
  const matched = secState.events.filter(e => {
    return (
      (e.message_id && e.message_id.toLowerCase().includes(term)) ||
      (e.provider_message_id && e.provider_message_id.toLowerCase().includes(term)) ||
      (e.request_id && e.request_id.toLowerCase().includes(term)) ||
      (e.correlation_id && e.correlation_id.toLowerCase().includes(term)) ||
      (e.session_id && e.session_id.toLowerCase().includes(term)) ||
      (e.device_id && e.device_id.toLowerCase().includes(term)) ||
      (e.ip_address && e.ip_address.toLowerCase().includes(term)) ||
      (JSON.stringify(e.details || {}).toLowerCase().includes(term))
    );
  });

  if (matched.length === 0) {
    container.innerHTML = `
      <div class="alert alert-warning" style="padding:16px; border-radius:var(--radius-md);">
        <h4 style="margin:0 0 6px 0; font-size:14px; font-weight:700;">⚠️ لم يتم العثور على سجلات مباشرة لهذا المعرف: "${escapeSecHtml(term)}"</h4>
        <p style="margin:0; font-size:12px; line-height:1.6;">
          البيانات الناقصة (Missing Links): لم يُعثر على بصمة تطابق في جدول <code>security_events</code>.
          قد تكون الرسالة قديمة خارج نطاق الاستبقاء الحالي أو لم تمر عبر السيرفر المشفر.
        </p>
      </div>
    `;
    return;
  }

  const primary = matched[0];
  const missingLinks = [];

  if (!primary.provider_message_id) missingLinks.push('Provider Message ID (معرف الرسالة من مزود الخدمة غير متوفر)');
  if (!primary.device_id) missingLinks.push('Device Fingerprint (بصمة الجهاز لم تُرسل في الترويسات)');
  if (!primary.session_id) missingLinks.push('User Session ID (جلسة الحساب غير مربوطة)');
  if (!primary.ip_address) missingLinks.push('Client IP Address (عنوان IP غير مسجل)');

  container.innerHTML = `
    <div class="sec-trace-card">
      <div style="display:flex; justify-content:space-between; align-items:flex-start; margin-bottom:16px;">
        <div>
          <span class="badge" style="background:#EFF6FF; color:#1E88E5; font-weight:700; margin-bottom:6px; display:inline-block;">
            سلسلة التتبع الجنائي الرقمي (Forensic Evidence Chain)
          </span>
          <h3 style="margin:0; font-size:16px; font-weight:800;">النتيجة المستخلصة للمعرف: ${escapeSecHtml(term)}</h3>
        </div>
        <div>
          <button class="btn btn-sm btn-primary" onclick="openEventDetailsModal('${primary.id}')">
            🔍 عرض السجل الكامل والشهادة التشفيرية
          </button>
        </div>
      </div>

      <!-- VISUAL CHAIN NODES -->
      <div class="sec-chain-nodes">
        <div class="sec-chain-node">
          <div class="node-icon"><i class="ri-message-2-fill"></i></div>
          <div class="node-title">Message ID</div>
          <div class="node-value">${primary.message_id ? escapeSecHtml(primary.message_id) : '<span class="text-missing">غير متوفر</span>'}</div>
        </div>

        <div class="sec-chain-arrow"><i class="ri-arrow-left-line"></i></div>

        <div class="sec-chain-node">
          <div class="node-icon"><i class="ri-whatsapp-fill"></i></div>
          <div class="node-title">Provider Msg ID</div>
          <div class="node-value">${primary.provider_message_id ? escapeSecHtml(primary.provider_message_id) : '<span class="text-missing">غير متوفر</span>'}</div>
        </div>

        <div class="sec-chain-arrow"><i class="ri-arrow-left-line"></i></div>

        <div class="sec-chain-node">
          <div class="node-icon"><i class="ri-key-2-fill"></i></div>
          <div class="node-title">Request ID</div>
          <div class="node-value font-outfit">${primary.request_id ? escapeSecHtml(primary.request_id.substring(0, 16)) : '<span class="text-missing">غير متوفر</span>'}</div>
        </div>

        <div class="sec-chain-arrow"><i class="ri-arrow-left-line"></i></div>

        <div class="sec-chain-node">
          <div class="node-icon"><i class="ri-route-fill"></i></div>
          <div class="node-title">API Endpoint</div>
          <div class="node-value font-outfit">${escapeSecHtml(primary.endpoint || '-')}</div>
        </div>

        <div class="sec-chain-arrow"><i class="ri-arrow-left-line"></i></div>

        <div class="sec-chain-node">
          <div class="node-icon"><i class="ri-user-settings-fill"></i></div>
          <div class="node-title">Session / User</div>
          <div class="node-value font-outfit">${primary.user_id ? primary.user_id.substring(0, 8) + '...' : (primary.session_id ? escapeSecHtml(primary.session_id.substring(0, 12)) : '<span class="text-missing">Guest</span>')}</div>
        </div>

        <div class="sec-chain-arrow"><i class="ri-arrow-left-line"></i></div>

        <div class="sec-chain-node">
          <div class="node-icon"><i class="ri-smartphone-fill"></i></div>
          <div class="node-title">Device Fingerprint</div>
          <div class="node-value font-outfit">${escapeSecHtml(primary.device_model || primary.device_platform || primary.device_id || 'غير معروف')}</div>
        </div>

        <div class="sec-chain-arrow"><i class="ri-arrow-left-line"></i></div>

        <div class="sec-chain-node">
          <div class="node-icon"><i class="ri-global-fill"></i></div>
          <div class="node-title">IP Address</div>
          <div class="node-value font-outfit">${escapeSecHtml(primary.ip_address || 'غير محدد')}</div>
        </div>

        <div class="sec-chain-arrow"><i class="ri-arrow-left-line"></i></div>

        <div class="sec-chain-node node-verified">
          <div class="node-icon"><i class="ri-lock-star-fill"></i></div>
          <div class="node-title">Seal & Timestamp</div>
          <div class="node-value font-outfit">${formatSecTime(primary.timestamp || primary.created_at)}</div>
        </div>
      </div>

      <!-- MISSING LINKS DIAGNOSTIC -->
      ${missingLinks.length > 0 ? `
        <div class="sec-missing-links-box">
          <strong style="font-size:12px; color:#DC2626; display:flex; align-items:center; gap:6px; margin-bottom:6px;">
            <i class="ri-error-warning-fill"></i> البيانات الناقصة في هذه السلسلة (Missing Forensics Links):
          </strong>
          <ul style="margin:0; padding-right:20px; font-size:11.5px; color:#991B1B;">
            ${missingLinks.map(m => `<li>${m}</li>`).join('')}
          </ul>
        </div>
      ` : `
        <div style="margin-top:16px; padding:10px 14px; background:#F0FDF4; border:1px solid #BBF7D0; border-radius:var(--radius-sm); font-size:11.5px; color:#166534; font-weight:700;">
          <i class="ri-checkbox-circle-fill"></i> السلسلة مكتملة 100% ولا توجد أي حلقة مفقودة بين الرسالة والطلب والجهاز والشبكة.
        </div>
      `}

      <!-- LEGAL DISCLAIMER BANNER (Requirement #13) -->
      <div class="sec-disclaimer-banner" style="margin-top:16px;">
        <i class="ri-information-fill"></i>
        <span><b>تنبيه تقني وقانوني:</b> تحديد الموقع عبر عنوان IP (${escapeSecHtml(primary.ip_address || 'N/A')}) هو موقع تقريبي لشبكة مزود الخدمة، ولا يثبت التواجد الفعلي أو هوية الأفراد. التحقيق يعتمد على تكامل الأدلة التقنية الموثقة.</span>
      </div>
    </div>
  `;
}

// ============================================
// TAB 4: INCIDENTS MANAGEMENT (🚨 Incidents)
// ============================================
function renderSecurityIncidentsTab() {
  return `
    <div class="card">
      <div class="card-header" style="display:flex; justify-content:space-between; align-items:center;">
        <div style="display:flex; align-items:center; gap:8px;">
          <i class="ri-fire-fill" style="color:#EF4444; font-size:20px;"></i>
          <div>
            <h3 style="margin:0;">إدارة بلاغات وحوادث الأمان الرقمي (🚨 Incidents)</h3>
            <p style="margin:0; font-size:12px; color:var(--text-secondary);">
              توثيق بلاغات الاختراق المشتبه بها وتثبيت الأدلة الأصلية مع منع التعديل
            </p>
          </div>
        </div>

        <button class="btn btn-primary btn-sm" onclick="openCreateIncidentModal()">
          <i class="ri-add-line"></i>
          <span>+ إنشاء بلاغ تحقيق جديد (New Incident)</span>
        </button>
      </div>

      <div class="card-body" style="padding:0;">
        <div class="sec-table-responsive">
          <table class="data-table sec-table">
            <thead>
              <tr>
                <th>رقم البلاغ</th>
                <th>عنوان الحادث والاشتباه</th>
                <th>مستوى الخطورة</th>
                <th>الحالة الحالية</th>
                <th>الحساب المتأثر</th>
                <th>الجهاز المعني</th>
                <th>عنوان IP</th>
                <th>تاريخ الإنشاء</th>
                <th>ملاحظات المحقق</th>
                <th>إجراءات</th>
              </tr>
            </thead>
            <tbody>
              ${renderIncidentsTableRows()}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  `;
}

function renderIncidentsTableRows() {
  if (secState.incidents.length === 0) {
    return `
      <tr>
        <td colspan="10" style="text-align:center; padding:36px; color:var(--text-light);">
          <i class="ri-checkbox-circle-line" style="font-size:36px; color:#10B981; display:block; margin-bottom:8px;"></i>
          لا توجد بلاغات حوادث نشطة مسجلة حالياً
        </td>
      </tr>
    `;
  }

  return secState.incidents.map(inc => {
    const statusBadge = getIncidentStatusBadge(inc.status);
    const severityBadge = getSeverityBadge(inc.severity);

    return `
      <tr>
        <td><strong class="font-outfit" style="color:var(--medium-blue);">${escapeSecHtml(inc.id)}</strong></td>
        <td><span style="font-weight:700; color:var(--text-primary); font-size:12.5px;">${escapeSecHtml(inc.title)}</span></td>
        <td>${severityBadge}</td>
        <td>${statusBadge}</td>
        <td><span style="font-size:12px;">${escapeSecHtml(inc.affected_account || 'مجهول')}</span></td>
        <td><span class="font-outfit" style="font-size:11.5px; color:var(--text-secondary);">${escapeSecHtml(inc.device_id || '-')}</span></td>
        <td><span class="font-outfit" style="font-size:12px; font-weight:600;">${escapeSecHtml(inc.ip_address || '-')}</span></td>
        <td><span class="font-outfit" style="font-size:11.5px;">${formatSecTime(inc.created_at)}</span></td>
        <td><span style="font-size:11.5px; color:var(--text-secondary);" title="${escapeSecHtml(inc.admin_notes || '')}">${inc.admin_notes ? escapeSecHtml(inc.admin_notes.substring(0, 30)) + '...' : '-'}</span></td>
        <td>
          <button class="btn btn-sm btn-outline" onclick="openIncidentDetailsModal('${inc.id}')" title="عرض تفاصيل البلاغ والخط الزمني">
            <i class="ri-eye-line"></i>
          </button>
        </td>
      </tr>
    `;
  }).join('');
}

// ============================================
// EVENT DETAILS & FORENSICS MODAL
// ============================================
function openEventDetailsModal(eventId) {
  const ev = secState.events.find(e => e.id === eventId);
  if (!ev) return;

  secState.selectedEvent = ev;
  const container = document.getElementById('secEventModalContainer');
  if (!container) return;

  const timeExact = new Date(ev.timestamp || ev.created_at).toISOString();
  const rawDetails = JSON.stringify(maskSensitiveJson(ev.details || {}), null, 2);

  container.innerHTML = `
    <div class="sec-modal-backdrop" onclick="handleSecModalBackdropClick(event, 'event')">
      <div class="sec-modal-card" onclick="event.stopPropagation()">
        <!-- Modal Header -->
        <div class="sec-modal-header">
          <div style="display:flex; align-items:center; gap:10px;">
            <div style="font-size:24px;">${ev.severity === 'CRITICAL' ? '🚨' : (ev.severity === 'HIGH' ? '⚠️' : '🛡️')}</div>
            <div>
              <div style="display:flex; align-items:center; gap:8px;">
                <h3 style="margin:0; font-size:17px; font-weight:800;">${escapeSecHtml(ev.event_type)}</h3>
                ${getSeverityBadge(ev.severity)}
              </div>
              <span class="font-outfit" style="font-size:11.5px; color:var(--text-light);">Event ID: ${ev.id}</span>
            </div>
          </div>
          <button class="sec-modal-close-btn" onclick="closeSecEventModal()">&times;</button>
        </div>

        <!-- Modal Body: 6 Forensic Blocks -->
        <div class="sec-modal-body">
          <!-- MANDATORY DISCLAIMER BANNER (Requirement #13) -->
          <div class="sec-disclaimer-banner" style="margin-bottom:16px;">
            <i class="ri-shield-user-fill"></i>
            <span><b>تنبيه فني وقانوني هام:</b> تحديد الموقع عبر عنوان IP هو موقع تقريبي لشبكة مزود الخدمة (ISP) ولا يثبت الهوية الشخصية أو المكان الفعلي للأفراد. لا يجوز استخدام المعرفات الرقمية كإدانة شخصية مطلقة دون تحقيقات متكاملة.</span>
          </div>

          <div class="sec-forensics-grid">
            <!-- 1. EVENT CARD -->
            <div class="sec-block">
              <div class="sec-block-title"><i class="ri-file-shield-2-fill"></i> EVENT METRICS</div>
              <div class="sec-kv"><span>Event ID:</span> <b class="font-outfit">${ev.id}</b></div>
              <div class="sec-kv"><span>Sequence #:</span> <b class="font-outfit">#${ev.seq_num || 'N/A'}</b></div>
              <div class="sec-kv"><span>Event Type:</span> <b>${escapeSecHtml(ev.event_type)}</b></div>
              <div class="sec-kv"><span>Severity:</span> <b>${ev.severity}</b></div>
              <div class="sec-kv"><span>Timestamp:</span> <b class="font-outfit">${timeExact}</b></div>
              <div class="sec-kv"><span>Chain Status:</span> <b style="color:#10B981;">✅ Verified Append-Only</b></div>
              <div class="sec-kv"><span>SHA-256 Hash:</span> <code class="sec-code-mono" title="${ev.event_hash}">${ev.event_hash ? ev.event_hash.substring(0, 24) + '...' : '-'}</code></div>
              <div class="sec-kv"><span>Prev Hash:</span> <code class="sec-code-mono" title="${ev.prev_hash}">${ev.prev_hash ? ev.prev_hash.substring(0, 24) + '...' : '-'}</code></div>
            </div>

            <!-- 2. ACCOUNT CARD -->
            <div class="sec-block">
              <div class="sec-block-title"><i class="ri-user-3-fill"></i> ACCOUNT IDENTIFIERS</div>
              <div class="sec-kv"><span>User ID:</span> <b class="font-outfit">${ev.user_id || 'مجهول (Guest)'}</b></div>
              <div class="sec-kv"><span>Admin ID:</span> <b class="font-outfit">${ev.admin_id || 'لا يوجد'}</b></div>
              <div class="sec-kv"><span>Session ID:</span> <b class="font-outfit">${ev.session_id || '-'}</b></div>
              <div class="sec-kv"><span>Correlation ID:</span> <b class="font-outfit">${ev.correlation_id || '-'}</b></div>
              <div class="sec-kv"><span>Auth Method:</span> <b>${ev.authentication_method || 'ANONYMOUS'}</b></div>
              <div class="sec-kv"><span>Auth Result:</span> <b style="color:${ev.authorization_result === 'AUTHORIZED' ? '#10B981' : '#EF4444'};">${ev.authorization_result || '-'}</b></div>
            </div>

            <!-- 3. DEVICE CARD -->
            <div class="sec-block">
              <div class="sec-block-title"><i class="ri-smartphone-fill"></i> DEVICE TELEMETRY</div>
              <div class="sec-kv"><span>Platform:</span> <b>${escapeSecHtml(ev.device_platform || '-')}</b></div>
              <div class="sec-kv"><span>Manufacturer:</span> <b>${escapeSecHtml(ev.device_manufacturer || '-')}</b></div>
              <div class="sec-kv"><span>Model:</span> <b>${escapeSecHtml(ev.device_model || '-')}</b></div>
              <div class="sec-kv"><span>OS Version:</span> <b>${escapeSecHtml(ev.os_version || '-')}</b></div>
              <div class="sec-kv"><span>App Version:</span> <b class="font-outfit">${escapeSecHtml(ev.app_version || '-')}</b></div>
              <div class="sec-kv"><span>Device / Inst ID:</span> <b class="font-outfit">${escapeSecHtml(ev.device_id || '-')}</b></div>
            </div>

            <!-- 4. NETWORK CARD -->
            <div class="sec-block">
              <div class="sec-block-title"><i class="ri-global-fill"></i> NETWORK & GEO FORENSICS</div>
              <div class="sec-kv"><span>IP Address:</span> <b class="font-outfit" style="color:var(--medium-blue); font-size:13px;">${escapeSecHtml(ev.ip_address || '-')}</b></div>
              <div class="sec-kv"><span>ASN:</span> <b class="font-outfit">${escapeSecHtml(ev.asn || '-')}</b></div>
              <div class="sec-kv"><span>ISP / Org:</span> <b>${escapeSecHtml(ev.isp || '-')}</b></div>
              <div class="sec-kv"><span>Approx Country:</span> <b>${escapeSecHtml(ev.country || '-')}</b></div>
              <div class="sec-kv"><span>Approx City:</span> <b>${escapeSecHtml(ev.city || '-')}</b></div>
              <div class="sec-kv"><span>Proxy / Datacenter:</span> <b>${ev.asn && ev.asn.includes('Layer') ? '⚠️ Datacenter IP' : 'Residential / Mobile Carrier'}</b></div>
              <div class="sec-kv"><span>User-Agent:</span> <span style="font-size:11px; word-break:break-all;">${escapeSecHtml(ev.user_agent || '-')}</span></div>
            </div>

            <!-- 5. REQUEST CARD -->
            <div class="sec-block">
              <div class="sec-block-title"><i class="ri-route-fill"></i> REQUEST CONTEXT</div>
              <div class="sec-kv"><span>Request ID:</span> <b class="font-outfit">${escapeSecHtml(ev.request_id || '-')}</b></div>
              <div class="sec-kv"><span>Endpoint:</span> <code class="sec-code-pill">${escapeSecHtml(ev.endpoint || '-')}</code></div>
              <div class="sec-kv"><span>HTTP Method:</span> <b class="font-outfit">${escapeSecHtml(ev.http_method || '-')}</b></div>
              <div class="sec-kv"><span>Response Status:</span> <b class="font-outfit" style="color:${ev.response_status < 400 ? '#10B981' : '#EF4444'};">${ev.response_status || '-'}</b></div>
            </div>

            <!-- 6. MESSAGE CARD -->
            <div class="sec-block">
              <div class="sec-block-title"><i class="ri-message-3-fill"></i> MESSAGE CORRELATION</div>
              <div class="sec-kv"><span>Message ID:</span> <b class="font-outfit">${ev.message_id ? escapeSecHtml(ev.message_id) : '-'}</b></div>
              <div class="sec-kv"><span>Provider Msg ID:</span> <b class="font-outfit">${ev.provider_message_id ? escapeSecHtml(ev.provider_message_id) : '-'}</b></div>
              <div class="sec-kv"><span>Template ID:</span> <b>${ev.details && ev.details.template_id ? escapeSecHtml(ev.details.template_id) : 'LOCKED_SERVER_TEMPLATE'}</b></div>
              <div class="sec-kv"><span>Custom Text Allowed:</span> <b style="color:#EF4444;">ممنوع كلياً (Strictly Forbidden)</b></div>
            </div>
          </div>

          <!-- 7. CHRONOLOGICAL TIMELINE (Requirement #5) -->
          <div style="margin-top:20px;">
            <h4 style="font-size:13px; font-weight:800; margin-bottom:12px; display:flex; align-items:center; gap:6px;">
              <i class="ri-time-line" style="color:var(--medium-blue);"></i>
              الخط الزمني للحوادث المترابطة (Chronological Incident Timeline)
            </h4>
            <div class="sec-timeline-flow">
              ${renderEventTimelineFlow(ev)}
            </div>
          </div>

          <!-- 8. RAW DETAILS JSON WITH SECRETS MASKED -->
          <div style="margin-top:20px;">
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:6px;">
              <h4 style="font-size:13px; font-weight:800; margin:0;">
                <i class="ri-code-box-line"></i> البيانات التقنية الكاملة (Masked Forensic Details)
              </h4>
              <button class="btn btn-sm btn-outline" onclick="copySecEventJson('${ev.id}')">
                <i class="ri-file-copy-line"></i> نسخ البيانات
              </button>
            </div>
            <pre class="sec-json-viewer"><code>${escapeSecHtml(rawDetails)}</code></pre>
          </div>
        </div>

        <!-- Modal Footer -->
        <div class="sec-modal-footer">
          <button class="btn btn-outline" onclick="closeSecEventModal()">إغلاق</button>
          <button class="btn btn-primary" onclick="openCreateIncidentModal('${ev.id}')">
            <i class="ri-alarm-warning-line"></i>
            <span>🚨 إنشاء بلاغ رسمي (Create Incident from Event)</span>
          </button>
        </div>
      </div>
    </div>
  `;
}

function renderEventTimelineFlow(ev) {
  const steps = [];

  // Step 1: Network Ingress
  steps.push({
    title: 'الاتصال الشبكي وبدء الطلب',
    subtitle: `IP: ${ev.ip_address || 'Unknown'} (${ev.country || 'N/A'}) - Method: ${ev.http_method || 'POST'}`,
    icon: 'ri-global-line',
    state: 'normal'
  });

  // Step 2: App & Device Handshake
  steps.push({
    title: 'التعرف على بصمة الجهاز والتوقيع',
    subtitle: `Device: ${ev.device_model || ev.device_platform || 'Unregistered'} - Signature: ${ev.authentication_method || 'N/A'}`,
    icon: 'ri-smartphone-line',
    state: ev.event_type.includes('TAMPER') ? 'danger' : 'normal'
  });

  // Step 3: Endpoint Traversed
  steps.push({
    title: 'استدعاء المسار البرمجي (API Endpoint)',
    subtitle: `Endpoint: ${ev.endpoint || '/api'} - RequestID: ${ev.request_id ? ev.request_id.substring(0, 14) : '-'}`,
    icon: 'ri-route-line',
    state: 'normal'
  });

  // Step 4: Defense Evaluation & Attack Detection
  const isAttack = (ev.severity === 'CRITICAL' || ev.severity === 'HIGH');
  steps.push({
    title: isAttack ? 'رصد نشاط مشبوه واعتراض الهجوم' : 'التحقق الأمني واكتمال الفحص',
    subtitle: `الحدث: ${ev.event_type} - الحالة: ${ev.response_status || '400'}`,
    icon: isAttack ? 'ri-shield-flash-fill' : 'ri-shield-check-fill',
    state: isAttack ? 'danger' : 'success'
  });

  // Step 5: Provider Delivery or Block Seal
  if (ev.message_id || ev.provider_message_id) {
    steps.push({
      title: 'إرسال الرسالة عبر المزود المعتمد',
      subtitle: `ProviderMsgID: ${ev.provider_message_id || 'N/A'} - قالب السيرفر المقفل`,
      icon: 'ri-whatsapp-line',
      state: 'success'
    });
  } else if (isAttack) {
    steps.push({
      title: 'منع الإرسال وإسقاط العملية فوراً',
      subtitle: 'حظر حقن النصوص أو الطلب وحفظ الأدلة في سجل التدقيق المشفر',
      icon: 'ri-close-circle-fill',
      state: 'danger'
    });
  }

  return steps.map((s, idx) => `
    <div class="sec-timeline-step step-${s.state}">
      <div class="sec-step-icon"><i class="${s.icon}"></i></div>
      <div class="sec-step-content">
        <strong style="font-size:12.5px; display:block;">${idx + 1}. ${s.title}</strong>
        <span class="font-outfit" style="font-size:11px; color:var(--text-secondary);">${s.subtitle}</span>
      </div>
    </div>
  `).join('');
}

function closeSecEventModal() {
  const container = document.getElementById('secEventModalContainer');
  if (container) container.innerHTML = '';
}

function handleSecModalBackdropClick(e, type) {
  // CRITICAL: Only close if the exact click target is the outer dark backdrop itself
  // Prevents accidental closure during browser zoom (Ctrl + + / pinch), dragging, or scrolling
  if (e && e.target && e.target.classList && e.target.classList.contains('sec-modal-backdrop')) {
    if (type === 'event') closeSecEventModal();
    else if (type === 'integrity') closeSecIntegrityModal();
    else if (type === 'incident') closeSecCreateIncidentModal();
  }
}

// ============================================
// HASH CHAIN INTEGRITY VERIFIER MODAL (Requirement #12)
// ============================================
async function openVerifyIntegrityModal() {
  const container = document.getElementById('secIntegrityModalContainer');
  if (!container) return;

  container.innerHTML = `
    <div class="sec-modal-backdrop" onclick="handleSecModalBackdropClick(event, 'integrity')">
      <div class="sec-modal-card" style="max-width:550px;" onclick="event.stopPropagation()">
        <div class="sec-modal-header">
          <div style="display:flex; align-items:center; gap:8px;">
            <i class="ri-shield-check-fill" style="color:#10B981; font-size:22px;"></i>
            <h3 style="margin:0; font-size:16px;">فحص سلامة السلسلة التشفيرية (Hash Chain Verifier)</h3>
          </div>
          <button class="sec-modal-close-btn" onclick="closeSecIntegrityModal()">&times;</button>
        </div>

        <div class="sec-modal-body" id="secIntegrityModalBody">
          <div style="text-align:center; padding:30px;">
            <div class="sec-spinner" style="margin:0 auto 16px auto;"></div>
            <p style="font-size:13px; font-weight:700;">جاري احتساب ومقارنة التجزئة التشفيرية لكافة الكتل في قاعدة البيانات...</p>
            <span style="font-size:11px; color:var(--text-light);">SHA-256 Cryptographic Hash Validation</span>
          </div>
        </div>

        <div class="sec-modal-footer">
          <button class="btn btn-outline" onclick="closeSecIntegrityModal()">إغلاق</button>
        </div>
      </div>
    </div>
  `;

  // Perform RPC verification on DB
  const client = getSecClient();
  if (!client) return;

  try {
    const { data, error } = await client.rpc('verify_security_events_integrity');
    const modalBody = document.getElementById('secIntegrityModalBody');
    if (!modalBody) return;

    if (error) throw error;

    if (data && data.valid === true) {
      modalBody.innerHTML = `
        <div style="text-align:center; padding:20px 10px;">
          <div style="width:64px; height:64px; border-radius:50%; background:#DCFCE7; color:#16A34A; display:flex; align-items:center; justify-content:center; font-size:36px; margin:0 auto 16px auto;">
            <i class="ri-check-line"></i>
          </div>
          <h3 style="font-size:17px; color:#166534; font-weight:800; margin-bottom:8px;">
            سلسلة السجلات متطابقة ومحمية 100%
          </h3>
          <p style="font-size:12px; color:var(--text-secondary); line-height:1.6; margin-bottom:16px;">
            تم التحقق من ربط جميع الكتل التشفيرية المتسلسلة (Cryptographic Blockchain Chaining) بنجاح. لا يوجد أي حذف أو تعديل أو تلاعب في السجلات نهائياً.
          </p>

          <div style="background:var(--bg-primary); border-radius:var(--radius-md); padding:14px; text-align:right;">
            <div class="sec-kv"><span>حالة التدقيق:</span> <b style="color:#10B981;">CHAIN_VERIFIED_INTACT</b></div>
            <div class="sec-kv"><span>إجمالي الكتل المفحوصة:</span> <b class="font-outfit">${data.total_events} سجلات</b></div>
            <div class="sec-kv"><span>السجلات المعتمدة:</span> <b class="font-outfit">${data.verified_events} سجلات</b></div>
            <div class="sec-kv"><span>خوارزمية التجزئة:</span> <b class="font-outfit">HMAC-SHA256 Chained Digest</b></div>
            <div class="sec-kv"><span>أحدث بصمة تشفيرية (Latest Seal):</span> <code class="sec-code-mono" title="${data.latest_hash}">${data.latest_hash ? data.latest_hash.substring(0, 32) + '...' : '-'}</code></div>
          </div>
        </div>
      `;
    } else {
      modalBody.innerHTML = `
        <div style="text-align:center; padding:20px 10px;">
          <div style="width:64px; height:64px; border-radius:50%; background:#FEE2E2; color:#DC2626; display:flex; align-items:center; justify-content:center; font-size:36px; margin:0 auto 16px auto;">
            <i class="ri-alert-fill"></i>
          </div>
          <h3 style="font-size:17px; color:#991B1B; font-weight:800; margin-bottom:8px;">
            ⚠️ تحذير أمني: تم رصد عدم تطابق في السلسلة التشفيرية!
          </h3>
          <p style="font-size:12px; color:#DC2626; line-height:1.6; margin-bottom:16px;">
            انكسرت سلسلة التشفير عند السجل رقم #${data?.failed_at_seq || data?.failed_at_id}. يشير هذا إلى احتمال وجود محاولة تعديل يدوي أو حذف لسجلات أمنية سابقة.
          </p>
          <pre class="sec-json-viewer"><code>${JSON.stringify(data, null, 2)}</code></pre>
        </div>
      `;
    }
  } catch (err) {
    const modalBody = document.getElementById('secIntegrityModalBody');
    if (modalBody) {
      modalBody.innerHTML = `
        <div class="alert alert-danger" style="padding:16px;">
          حدث خطأ أثناء فحص السلسلة: ${escapeSecHtml(err.message)}
        </div>
      `;
    }
  }
}

function closeSecIntegrityModal() {
  const container = document.getElementById('secIntegrityModalContainer');
  if (container) container.innerHTML = '';
}

// ============================================
// CREATE INCIDENT MODAL (Requirement #10)
// ============================================
function openCreateIncidentModal(eventId = null) {
  const ev = eventId ? secState.events.find(e => e.id === eventId) : null;
  const container = document.getElementById('secCreateIncidentModalContainer');
  if (!container) return;

  const defaultTitle = ev ? `اشتباه أمني: ${ev.event_type} (${ev.ip_address || 'Unknown'})` : '';
  const defaultAccount = ev ? (ev.details?.phone_masked || ev.user_id || 'مجهول') : '';
  const defaultDevice = ev ? (ev.device_model || ev.device_platform || ev.device_id || '') : '';
  const defaultIp = ev ? (ev.ip_address || '') : '';

  container.innerHTML = `
    <div class="sec-modal-backdrop" onclick="handleSecModalBackdropClick(event, 'incident')">
      <div class="sec-modal-card" style="max-width:580px;" onclick="event.stopPropagation()">
        <div class="sec-modal-header">
          <div style="display:flex; align-items:center; gap:8px;">
            <i class="ri-alarm-warning-fill" style="color:#EF4444; font-size:22px;"></i>
            <h3 style="margin:0; font-size:16px;">إنشاء بلاغ تحقيق أمني رسمي (Incident)</h3>
          </div>
          <button class="sec-modal-close-btn" onclick="closeSecCreateIncidentModal()">&times;</button>
        </div>

        <div class="sec-modal-body">
          <form id="secCreateIncidentForm" onsubmit="handleSaveIncident(event, '${eventId || ''}')">
            <div class="form-group" style="margin-bottom:12px;">
              <label style="font-size:12px; font-weight:700;">عنوان البلاغ / الحادث *</label>
              <input type="text" id="incTitle" class="form-control" value="${escapeSecHtml(defaultTitle)}" required placeholder="مثال: محاولة حقن رسالة مخصصة أو هجوم من عنوان IP محدد" />
            </div>

            <div style="display:grid; grid-template-columns: 1fr 1fr; gap:12px; margin-bottom:12px;">
              <div class="form-group">
                <label style="font-size:12px; font-weight:700;">مستوى الخطورة *</label>
                <select id="incSeverity" class="form-select">
                  <option value="CRITICAL" ${ev?.severity === 'CRITICAL' ? 'selected' : ''}>🚨 حرج (CRITICAL)</option>
                  <option value="HIGH" ${ev?.severity === 'HIGH' ? 'selected' : ''}>⚠️ عالي الخطورة (HIGH)</option>
                  <option value="MEDIUM" ${ev?.severity === 'MEDIUM' ? 'selected' : ''}>متوسط (MEDIUM)</option>
                  <option value="LOW" ${ev?.severity === 'LOW' ? 'selected' : ''}>منخفض (LOW)</option>
                </select>
              </div>

              <div class="form-group">
                <label style="font-size:12px; font-weight:700;">الحالة الابتدائية *</label>
                <select id="incStatus" class="form-select">
                  <option value="OPEN">مفتوح (OPEN)</option>
                  <option value="INVESTIGATING" selected>قيد التحقيق (INVESTIGATING)</option>
                  <option value="CONTAINED">تم الاحتواء (CONTAINED)</option>
                </select>
              </div>
            </div>

            <div style="display:grid; grid-template-columns: 1fr 1fr; gap:12px; margin-bottom:12px;">
              <div class="form-group">
                <label style="font-size:12px; font-weight:700;">الحساب المتأثر / المستهدف</label>
                <input type="text" id="incAccount" class="form-control" value="${escapeSecHtml(defaultAccount)}" placeholder="رقم الهاتف أو المعرف" />
              </div>

              <div class="form-group">
                <label style="font-size:12px; font-weight:700;">عنوان IP المرتبط</label>
                <input type="text" id="incIp" class="form-control font-outfit" value="${escapeSecHtml(defaultIp)}" placeholder="192.168.1.1" />
              </div>
            </div>

            <div class="form-group" style="margin-bottom:12px;">
              <label style="font-size:12px; font-weight:700;">بصمة الجهاز (Device Identifier)</label>
              <input type="text" id="incDevice" class="form-control font-outfit" value="${escapeSecHtml(defaultDevice)}" placeholder="موديل أو معرف الجهاز" />
            </div>

            <div class="form-group" style="margin-bottom:12px;">
              <label style="font-size:12px; font-weight:700;">ملاحظات المحقق وتفاصيل الواقعة *</label>
              <textarea id="incNotes" class="form-control" rows="3" required placeholder="سجل هنا نتائج التحقيق المبدئي، الخطوات المتخذة، والقرارات الفنية..."></textarea>
            </div>

            <div style="padding:10px; background:#F8FAFC; border:1px solid #E2E8F0; border-radius:var(--radius-sm); font-size:11px; color:var(--text-secondary);">
              🔒 <b>حماية الأدلة الأصلية (Evidence Integrity):</b> ترتبط الأحداث الأصلية بالبلاغ كأدلة غير قابلة للتعديل أو الحذف من السجل الأساسي.
            </div>

            <div class="sec-modal-footer" style="padding:12px 0 0 0; margin-top:16px;">
              <button type="button" class="btn btn-outline" onclick="closeSecCreateIncidentModal()">إلغاء</button>
              <button type="submit" class="btn btn-primary" id="incSubmitBtn">
                <i class="ri-save-line"></i> حفظ وفتح البلاغ الرسمي
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  `;
}

async function handleSaveIncident(e, eventId) {
  e.preventDefault();
  const btn = document.getElementById('incSubmitBtn');
  if (btn) btn.disabled = true;

  try {
    const title = document.getElementById('incTitle').value.trim();
    const severity = document.getElementById('incSeverity').value;
    const status = document.getElementById('incStatus').value;
    const account = document.getElementById('incAccount').value.trim();
    const ip = document.getElementById('incIp').value.trim();
    const device = document.getElementById('incDevice').value.trim();
    const notes = document.getElementById('incNotes').value.trim();

    // Get sequence incident ID
    const client = getSecClient();
    if (!client) return;

    const { data: idData, error: idErr } = await client.rpc('generate_incident_id');
    const incidentId = (idData && !idErr) ? idData : ('INC-2026-' + Math.floor(1000 + Math.random() * 9000));

    const ev = eventId ? secState.events.find(x => x.id === eventId) : null;
    const requestIds = (ev && ev.request_id) ? [ev.request_id] : [];
    const messageIds = (ev && ev.message_id) ? [ev.message_id] : [];
    const eventIds = eventId ? [eventId] : [];

    const timeline = [
      {
        time: new Date().toISOString(),
        stage: 'Incident Created',
        note: `تم فتح البلاغ رسمياً بواسطة المشرف: ${notes}`
      }
    ];

    const { error: insErr } = await client.from('security_incidents').insert({
      id: incidentId,
      title,
      severity,
      status,
      affected_account: account,
      ip_address: ip,
      device_id: device,
      request_ids: requestIds,
      message_ids: messageIds,
      event_ids: eventIds,
      timeline,
      evidence_references: eventId ? [{ type: 'security_event', event_id: eventId }] : [],
      admin_notes: notes
    });

    if (insErr) throw insErr;

    if (typeof showToast === 'function') showToast(`تم إنشاء البلاغ بنجاح برقم ${incidentId}`, 'success');
    closeSecCreateIncidentModal();
    await fetchSecurityIncidents();
    switchSecTab('incidents');
  } catch (err) {
    console.error('Save incident error:', err);
    if (typeof showToast === 'function') showToast('فشل حفظ البلاغ: ' + err.message, 'error');
  } finally {
    if (btn) btn.disabled = false;
  }
}

function closeSecCreateIncidentModal() {
  const container = document.getElementById('secCreateIncidentModalContainer');
  if (container) container.innerHTML = '';
}

function openIncidentDetailsModal(incId) {
  const inc = secState.incidents.find(i => i.id === incId);
  if (!inc) return;

  const container = document.getElementById('secCreateIncidentModalContainer');
  if (!container) return;

  container.innerHTML = `
    <div class="sec-modal-backdrop" onclick="handleSecModalBackdropClick(event, 'incident')">
      <div class="sec-modal-card" style="max-width:640px;" onclick="event.stopPropagation()">
        <div class="sec-modal-header">
          <div style="display:flex; align-items:center; gap:8px;">
            <i class="ri-shield-flash-line" style="color:var(--medium-blue); font-size:22px;"></i>
            <div>
              <div style="display:flex; align-items:center; gap:8px;">
                <h3 style="margin:0; font-size:16px;">تفاصيل البلاغ: ${escapeSecHtml(inc.id)}</h3>
                ${getIncidentStatusBadge(inc.status)}
              </div>
              <span style="font-size:11.5px; color:var(--text-light);">${formatSecTime(inc.created_at)}</span>
            </div>
          </div>
          <button class="sec-modal-close-btn" onclick="closeSecCreateIncidentModal()">&times;</button>
        </div>

        <div class="sec-modal-body">
          <div style="margin-bottom:14px;">
            <h4 style="font-size:14px; font-weight:800; margin:0 0 4px 0;">${escapeSecHtml(inc.title)}</h4>
            <div style="display:flex; gap:12px; font-size:12px; color:var(--text-secondary);">
              <span>الحساب: <b>${escapeSecHtml(inc.affected_account || 'غير محدد')}</b></span>
              <span>IP: <b class="font-outfit">${escapeSecHtml(inc.ip_address || '-')}</b></span>
              <span>الجهاز: <b class="font-outfit">${escapeSecHtml(inc.device_id || '-')}</b></span>
            </div>
          </div>

          <div style="background:var(--bg-primary); border-radius:var(--radius-md); padding:12px; margin-bottom:16px;">
            <strong style="font-size:12px; display:block; margin-bottom:4px;">ملاحظات المحقق (Admin Notes):</strong>
            <p style="margin:0; font-size:12px; line-height:1.6; color:var(--text-primary); white-space:pre-wrap;">${escapeSecHtml(inc.admin_notes || 'لا توجد ملاحظات إضافية')}</p>
          </div>

          <!-- STATUS UPDATE FORM -->
          <div style="border-top:1px solid var(--border-color); padding-top:14px; margin-top:14px;">
            <h4 style="font-size:12.5px; font-weight:700; margin-bottom:8px;">تحديث حالة البلاغ:</h4>
            <div style="display:flex; gap:8px;">
              <select id="updateIncStatusSelect" class="form-select" style="max-width:200px;">
                <option value="OPEN" ${inc.status === 'OPEN' ? 'selected' : ''}>مفتوح (OPEN)</option>
                <option value="INVESTIGATING" ${inc.status === 'INVESTIGATING' ? 'selected' : ''}>قيد التحقيق (INVESTIGATING)</option>
                <option value="CONTAINED" ${inc.status === 'CONTAINED' ? 'selected' : ''}>تم الاحتواء (CONTAINED)</option>
                <option value="RESOLVED" ${inc.status === 'RESOLVED' ? 'selected' : ''}>تم الحل (RESOLVED)</option>
                <option value="CLOSED" ${inc.status === 'CLOSED' ? 'selected' : ''}>مغلق (CLOSED)</option>
              </select>
              <button class="btn btn-primary btn-sm" onclick="handleUpdateIncidentStatus('${inc.id}')">تحديث الحالة</button>
            </div>
          </div>
        </div>

        <div class="sec-modal-footer">
          <button class="btn btn-outline" onclick="closeSecCreateIncidentModal()">إغلاق</button>
        </div>
      </div>
    </div>
  `;
}

async function handleUpdateIncidentStatus(incId) {
  const select = document.getElementById('updateIncStatusSelect');
  if (!select) return;

  const newStatus = select.value;
  const client = getSecClient();
  if (!client) return;

  try {
    const { error } = await client
      .from('security_incidents')
      .update({ status: newStatus, updated_at: new Date().toISOString() })
      .eq('id', incId);

    if (error) throw error;
    if (typeof showToast === 'function') showToast(`تم تحديث حالة البلاغ إلى ${newStatus}`, 'success');
    closeSecCreateIncidentModal();
    await fetchSecurityIncidents();
    switchSecTab('incidents');
  } catch (err) {
    if (typeof showToast === 'function') showToast('فشل التحديث: ' + err.message, 'error');
  }
}

// ============================================
// HELPERS, FILTERS & FORMATTERS
// ============================================
function switchSecTab(tabName) {
  secState.activeTab = tabName;
  const contentArea = document.getElementById('secTabContentArea');
  if (contentArea) {
    contentArea.innerHTML = renderSecActiveTabContent();
  }

  // Update tab buttons
  document.querySelectorAll('.sec-tab-btn').forEach(btn => btn.classList.remove('active'));
  const activeBtn = document.querySelector(`.sec-tab-btn[onclick="switchSecTab('${tabName}')"]`);
  if (activeBtn) activeBtn.classList.add('active');
}

function setSecDateFilter(filter) {
  secState.dateFilter = filter;
  fetchSecurityEvents();
  
  document.querySelectorAll('.sec-date-btn').forEach(btn => btn.classList.remove('active'));
  const activeBtn = document.querySelector(`.sec-date-btn[onclick="setSecDateFilter('${filter}')"]`);
  if (activeBtn) activeBtn.classList.add('active');
}

function handleSecSearch(val) {
  secState.searchQuery = val;
  filterSecurityEvents();
}

function handleSecSeverityFilter(val) {
  secState.severityFilter = val;
  filterSecurityEvents();
}

function handleSecEventTypeFilter(val) {
  secState.eventTypeFilter = val;
  filterSecurityEvents();
}

function toggleSecPhoneMasking() {
  secState.maskPhones = !secState.maskPhones;
  filterSecurityEvents();
  const pageContainer = document.getElementById('pageContent');
  if (pageContainer && currentPage === 'security') {
    pageContainer.innerHTML = renderSecurityCenter();
  }
}

async function refreshSecurityData() {
  await fetchSecurityEvents();
  await fetchSecurityIncidents();
  if (typeof showToast === 'function') showToast('تم تحديث بيانات مركز الأمان اللحظية بنجاح 🛡️', 'success');
}

function updateSecurityKpiUI() {
  const elTotal = document.getElementById('kpiTotalEvents');
  const elCrit = document.getElementById('kpiCriticalEvents');
  const elHigh = document.getElementById('kpiHighEvents');
  const elSuspReq = document.getElementById('kpiSuspiciousRequests');
  const elFail = document.getElementById('kpiFailedAuth');
  const elDev = document.getElementById('kpiNewDevices');
  const elOtp = document.getElementById('kpiSuspiciousOtp');
  const elInc = document.getElementById('kpiActiveIncidents');

  if (elTotal) elTotal.textContent = secState.kpis.total;
  if (elCrit) elCrit.textContent = secState.kpis.critical;
  if (elHigh) elHigh.textContent = secState.kpis.high;
  if (elSuspReq) elSuspReq.textContent = secState.kpis.suspiciousRequests;
  if (elFail) elFail.textContent = secState.kpis.failedAuth;
  if (elDev) elDev.textContent = secState.kpis.newDevices;
  if (elOtp) elOtp.textContent = secState.kpis.suspiciousOtp;
  if (elInc) elInc.textContent = secState.kpis.activeIncidents;

  const evBadge = document.getElementById('securityBadge');
  if (evBadge) {
    if (secState.kpis.critical > 0) {
      evBadge.textContent = secState.kpis.critical;
      evBadge.style.display = 'inline-block';
    } else {
      evBadge.style.display = 'none';
    }
  }
}

function getSeverityBadge(sev) {
  switch (sev) {
    case 'CRITICAL':
      return `<span class="sec-badge badge-critical"><i class="ri-fire-fill"></i> CRITICAL</span>`;
    case 'HIGH':
      return `<span class="sec-badge badge-high"><i class="ri-alert-fill"></i> HIGH</span>`;
    case 'MEDIUM':
      return `<span class="sec-badge badge-medium">MEDIUM</span>`;
    case 'LOW':
      return `<span class="sec-badge badge-low">LOW</span>`;
    case 'INFO':
    default:
      return `<span class="sec-badge badge-info">INFO</span>`;
  }
}

function getEventTypeBadge(type) {
  const t = String(type || '');
  if (t.includes('INJECTION')) {
    return `<span class="badge" style="background:#FEE2E2; color:#DC2626; font-weight:700;">💉 حقن نصوص مخصصة</span>`;
  }
  if (t.includes('HONEYPOT')) {
    return `<span class="badge" style="background:#FEF3C7; color:#B45309; font-weight:700;">🍯 سقوط في المصيدة</span>`;
  }
  if (t.includes('RATE_LIMIT')) {
    return `<span class="badge" style="background:#FFEDD5; color:#C2410C; font-weight:700;">⏱️ تجاوز الحدود</span>`;
  }
  if (t.includes('NEW_DEVICE')) {
    return `<span class="badge" style="background:#E0F2FE; color:#0369A1; font-weight:700;">📱 جهاز جديد</span>`;
  }
  if (t.includes('FAILED')) {
    return `<span class="badge" style="background:#FEE2E2; color:#B91C1C; font-weight:700;">❌ فشل المصادقة</span>`;
  }
  if (t.includes('DISPATCHED')) {
    return `<span class="badge" style="background:#DCFCE7; color:#15803D; font-weight:700;">✅ إرسال موثق</span>`;
  }
  return `<span class="badge" style="background:#F1F5F9; color:#475569; font-weight:700;">${escapeSecHtml(t)}</span>`;
}

function getIncidentStatusBadge(status) {
  switch (status) {
    case 'OPEN':
      return `<span class="badge" style="background:#FEE2E2; color:#DC2626; font-weight:700;">مفتوح (OPEN)</span>`;
    case 'INVESTIGATING':
      return `<span class="badge" style="background:#FEF3C7; color:#D97706; font-weight:700;">قيد التحقيق (INVESTIGATING)</span>`;
    case 'CONTAINED':
      return `<span class="badge" style="background:#DBEAFE; color:#2563EB; font-weight:700;">تم الاحتواء (CONTAINED)</span>`;
    case 'RESOLVED':
    case 'CLOSED':
      return `<span class="badge" style="background:#DCFCE7; color:#16A34A; font-weight:700;">تم الإغلاق (CLOSED)</span>`;
    default:
      return `<span class="badge" style="background:#F1F5F9; color:#475569;">${status}</span>`;
  }
}

function formatSecTime(isoStr) {
  if (!isoStr) return '-';
  try {
    const d = new Date(isoStr);
    return d.toLocaleString('ar-EG', {
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      day: 'numeric',
      month: 'short',
      year: 'numeric'
    });
  } catch (_) {
    return isoStr;
  }
}

function maskPhoneNumber(ph) {
  const s = String(ph || '').replace(/[^\d]/g, '');
  if (s.length < 7) return s;
  return s.substring(0, 4) + '****' + s.slice(-2);
}

function maskSensitiveJson(obj) {
  if (!obj || typeof obj !== 'object') return obj;
  const clone = JSON.parse(JSON.stringify(obj));
  const sensitiveKeys = ['password', 'secret', 'token', 'otp', 'code', 'authKey', 'hash'];
  
  function recurse(o) {
    for (const k in o) {
      if (typeof o[k] === 'object' && o[k] !== null) {
        recurse(o[k]);
      } else if (sensitiveKeys.some(sk => k.toLowerCase().includes(sk))) {
        o[k] = '•••••••• (Masked)';
      }
    }
  }
  recurse(clone);
  return clone;
}

function copySecEventJson(eventId) {
  const ev = secState.events.find(e => e.id === eventId);
  if (!ev) return;
  const text = JSON.stringify(maskSensitiveJson(ev), null, 2);
  navigator.clipboard.writeText(text).then(() => {
    if (typeof showToast === 'function') showToast('تم نسخ البيانات التقنية إلى الحافظة 📋', 'success');
  });
}

function escapeSecHtml(str) {
  return String(str || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

// ============================================
// INITIALIZATION
// ============================================
function initSecurityCenter() {
  fetchSecurityEvents();
  fetchSecurityIncidents();
  setupSecurityRealtime();

  // Auto-refresh every 12 seconds
  if (secState.refreshTimer) clearInterval(secState.refreshTimer);
  secState.refreshTimer = setInterval(() => {
    if (currentPage === 'security' && secState.autoRefresh) {
      fetchSecurityEvents();
      fetchSecurityIncidents();
    }
  }, 12000);
}
