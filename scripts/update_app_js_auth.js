const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, '..', 'admin-dashboard', 'app.js');
let code = fs.readFileSync(filePath, 'utf8');

// 1. Replace auth state and view functions
const oldStateAndViews = `// ============================================
// AUTHENTICATION & AUTHORIZATION STATE (Open Access Mode)
// ============================================
let currentAdminUser = { id: 'd8daab61-f140-4c1d-a90e-2657499c94ad', email: 'admin@inride.com' };
let currentAdminProfile = { id: 'd8daab61-f140-4c1d-a90e-2657499c94ad', name: 'مدير النظام', role: 'admin', email: 'admin@inride.com' };
let isAuthenticatedAdmin = true;
let isSyncStarted = false;

function showLoginAlert(message, type = 'danger') {
  // Disabled in open access mode
}

function clearLoginAlert() {
  // Disabled in open access mode
}

function showLoginView(message = null, type = 'danger') {
  showDashboardView();
}

function showDashboardView() {
  const loginScreen = document.getElementById('loginScreen');
  const appLayout = document.querySelector('.app-layout');

  if (loginScreen) loginScreen.style.display = 'none';
  if (appLayout) appLayout.classList.remove('hidden-layout');
}

async function verifyAndApplyAdminSession(session) {
  if (!session || !session.user) {
    showLoginView();
    return false;
  }

  try {
    const userId = session.user.id;

    // Retrieve authenticated user profile from 'users' table
    const { data: userProfile, error } = await supabaseClient
      .from('users')
      .select('*')
      .eq('id', userId)
      .maybeSingle();

    if (error) {
      console.error("Error fetching user profile:", error);
      await supabaseClient.auth.signOut();
      showLoginView("حدث خطأ أثناء التحقق من صلاحيات حسابك. يرجى المحاولة لاحقاً.");
      return false;
    }

    // Verify user role is strictly 'admin'
    // Open Access Mode: Keep admin profile enabled
    currentAdminUser = session.user || { id: 'd8daab61-f140-4c1d-a90e-2657499c94ad', email: 'admin@inride.com' };
    currentAdminProfile = userProfile || { id: 'd8daab61-f140-4c1d-a90e-2657499c94ad', name: 'مدير النظام', role: 'admin', email: 'admin@inride.com' };
    isAuthenticatedAdmin = true;
    showDashboardView();
    return true;
  } catch (err) {
    console.error("Session verification error:", err);
    isAuthenticatedAdmin = true;
    currentAdminProfile = { id: 'd8daab61-f140-4c1d-a90e-2657499c94ad', name: 'مدير النظام', role: 'admin', email: 'admin@inride.com' };
    showDashboardView();
    return true;
  }
}`;

const newStateAndViews = `// ============================================
// AUTHENTICATION & AUTHORIZATION STATE (Supabase Auth)
// ============================================
let currentAdminUser = null;
let currentAdminProfile = null;
let isAuthenticatedAdmin = false;
let isSyncStarted = false;

function showLoginAlert(message, type = 'danger') {
  const alertEl = document.getElementById('loginAlert');
  if (!alertEl) return;
  alertEl.className = \`login-alert alert-\${type}\`;
  alertEl.innerHTML = \`<i class="ri-error-warning-line"></i> <span>\${message}</span>\`;
  alertEl.style.display = 'flex';
}

function clearLoginAlert() {
  const alertEl = document.getElementById('loginAlert');
  if (alertEl) {
    alertEl.style.display = 'none';
    alertEl.innerHTML = '';
  }
}

function showLoginView(message = null, type = 'danger') {
  const loginScreen = document.getElementById('loginScreen');
  const appLayout = document.querySelector('.app-layout');

  if (loginScreen) loginScreen.style.display = 'flex';
  if (appLayout) appLayout.classList.add('hidden-layout');

  if (message) {
    showLoginAlert(message, type);
  } else {
    clearLoginAlert();
  }
}

function showDashboardView() {
  const loginScreen = document.getElementById('loginScreen');
  const appLayout = document.querySelector('.app-layout');

  if (loginScreen) loginScreen.style.display = 'none';
  if (appLayout) appLayout.classList.remove('hidden-layout');
}

async function verifyAndApplyAdminSession(session) {
  if (!session || !session.user) {
    showLoginView();
    return false;
  }

  try {
    const userId = session.user.id;

    // Retrieve authenticated user profile from 'users' table
    let { data: userProfile, error } = await supabaseClient
      .from('users')
      .select('*')
      .eq('id', userId)
      .maybeSingle();

    if (error) {
      console.warn("Error fetching user profile:", error);
    }

    currentAdminUser = session.user;
    currentAdminProfile = userProfile || {
      id: userId,
      name: session.user.email ? session.user.email.split('@')[0] : 'مدير النظام',
      role: 'admin',
      email: session.user.email
    };

    isAuthenticatedAdmin = true;
    showDashboardView();

    // Update UI sidebar user details
    const userNameEl = document.getElementById('sidebarUserName');
    const userEmailEl = document.getElementById('sidebarUserEmail');
    const userAvatarEl = document.getElementById('sidebarUserAvatar');

    if (userNameEl) userNameEl.textContent = currentAdminProfile.name || 'مدير النظام';
    if (userEmailEl) userEmailEl.textContent = session.user.email || 'admin@inride.com';
    if (userAvatarEl) userAvatarEl.textContent = (currentAdminProfile.name || 'م').charAt(0).toUpperCase();

    if (!isSyncStarted) {
      isSyncStarted = true;
      initSupabaseSync();
    }

    const savedPage = sessionStorage.getItem('admin_currentPage') || 'dashboard';
    renderPage(savedPage);
    updateHeaderTitle(savedPage);

    return true;
  } catch (err) {
    console.error("Session verification error:", err);
    showLoginView("حدث خطأ أثناء التحقق من صلاحيات حسابك.");
    return false;
  }
}`;

if (code.includes(oldStateAndViews)) {
  code = code.replace(oldStateAndViews, newStateAndViews);
  console.log('Replaced auth state and views successfully');
} else {
  console.log('oldStateAndViews pattern not found');
}

// 2. Replace logout and initAdminAuth
const oldLogoutAndInit = `async function handleLogout() {
  showToast("تم إفراغ الذاكرة التخزينية ومزامنة اللوحة بنجاح.");
  renderPage('dashboard');
}

async function initAdminAuth() {
  showDashboardView();

  // Initialize UI sidebar user details
  const userNameEl = document.getElementById('sidebarUserName');
  const userEmailEl = document.getElementById('sidebarUserEmail');
  const userAvatarEl = document.getElementById('sidebarUserAvatar');

  if (userNameEl) userNameEl.textContent = 'مدير النظام';
  if (userEmailEl) userEmailEl.textContent = 'admin@inride.com';
  if (userAvatarEl) userAvatarEl.textContent = 'م';

  if (!isSyncStarted) {
    isSyncStarted = true;
    initSupabaseSync();
  }

  const savedPage = sessionStorage.getItem('admin_currentPage') || 'dashboard';
  renderPage(savedPage);
  updateHeaderTitle(savedPage);
}`;

const newLogoutAndInit = `async function handleLogout() {
  try {
    if (supabaseClient && supabaseClient.auth) {
      await supabaseClient.auth.signOut();
    }
  } catch (e) {}
  isAuthenticatedAdmin = false;
  currentAdminUser = null;
  currentAdminProfile = null;
  showToast("تم تسجيل الخروج بنجاح.");
  showLoginView();
}

async function initAdminAuth() {
  if (!supabaseClient) {
    showDashboardView();
    return;
  }

  try {
    const { data: { session } } = await supabaseClient.auth.getSession();
    if (session && session.user) {
      await verifyAndApplyAdminSession(session);
    } else {
      showLoginView();
    }
  } catch (e) {
    console.warn("Session check error:", e);
    showLoginView();
  }
}`;

if (code.includes(oldLogoutAndInit)) {
  code = code.replace(oldLogoutAndInit, newLogoutAndInit);
  console.log('Replaced logout and initAdminAuth successfully');
} else {
  console.log('oldLogoutAndInit pattern not found');
}

fs.writeFileSync(filePath, code, 'utf8');
console.log('Auth update complete.');
