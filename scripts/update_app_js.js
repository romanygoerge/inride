const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, '..', 'admin-dashboard', 'app.js');
let code = fs.readFileSync(filePath, 'utf8');

const oldSendReply = `async function sendSupportReply(id) {
  const textEl = document.getElementById('replyText');
  if (!textEl) return;
  const text = textEl.value.trim();
  if (!text || !supabaseClient) return;

  textEl.value = '';
  const nowStr = new Date().toISOString();
  const msgId = crypto.randomUUID ? crypto.randomUUID() : ('admin_msg_' + Date.now());

  console.log("[SupportChat Log] Support Message Sent: id=" + msgId + " to recipient=" + id);

  try {
    // 1. Insert message
    await supabaseClient.from('support_messages').insert({
      id: msgId,
      conversation_id: id,
      user_id: id,
      sender_id: currentAdminUser ? currentAdminUser.id : id,
      receiver_id: id,
      sender_type: 'admin',
      message: text,
      text: text,
      status: 'sent',
      is_admin: true,
      created_at: nowStr
    });`;

const newSendReply = `async function sendSupportReply(id) {
  const textEl = document.getElementById('replyText');
  if (!textEl) return;
  const text = textEl.value.trim();
  if (!text || !supabaseClient) return;

  textEl.value = '';
  const nowStr = new Date().toISOString();
  const msgId = crypto.randomUUID ? crypto.randomUUID() : ('admin_msg_' + Date.now());
  const adminSenderId = (currentAdminUser && currentAdminUser.id) ? currentAdminUser.id : 'd8daab61-f140-4c1d-a90e-2657499c94ad';

  console.log("[SupportChat Log] Support Message Sent: id=" + msgId + " to recipient=" + id);

  try {
    // 1. Insert message
    const { error: insErr } = await supabaseClient.from('support_messages').insert({
      id: msgId,
      conversation_id: id,
      user_id: id,
      sender_id: adminSenderId,
      receiver_id: id,
      sender_type: 'admin',
      message: text,
      text: text,
      status: 'sent',
      is_admin: true,
      created_at: nowStr
    });

    if (insErr) {
      console.warn('[SupportChat Log] Retry inserting support_message with recipient id as sender:', insErr.message);
      await supabaseClient.from('support_messages').insert({
        id: msgId,
        conversation_id: id,
        user_id: id,
        sender_id: id,
        receiver_id: id,
        sender_type: 'admin',
        message: text,
        text: text,
        status: 'sent',
        is_admin: true,
        created_at: nowStr
      });
    }`;

if (code.includes(oldSendReply)) {
  code = code.replace(oldSendReply, newSendReply);
  console.log('Replaced sendSupportReply successfully');
  fs.writeFileSync(filePath, code, 'utf8');
} else {
  console.log('oldSendReply pattern not found');
}
