#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ============================================================
#  xraay-bot — Bot Telegram CONFIG LIST (Panel Xray VLESS)
# ------------------------------------------------------------
#  Aliran kerja:
#    1. User hantar User ID (UUID) dalam Telegram
#    2. Bot cari UUID tu dalam /usr/local/etc/xray/config.json
#       dan /usr/local/etc/xray/none.json
#    3. Bot baca /etc/xray/configlist/*.conf (ikut susunan telco
#       yang sama macam dalam panel VPS)
#    4. Bot bina semula link VLESS untuk user tersebut
#    5. Bot papar ikut nama config + emoji warna telco dalam
#       blockquote + monospace supaya senang copy-paste
#
#  Hanya telco yang BETUL-BETUL ada config dalam VPS dipaparkan.
#  Tiada dependency luar — guna stdlib Python 3 sahaja.
#
#  Ujian tanpa Telegram:
#      xraay-bot --dump <UUID>
# ============================================================

import hashlib
import html
import json
import os
import re
import signal
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

CONFIG_PATH = os.environ.get("XRAY_BOT_CONFIG", "/etc/xraay-bot/config.json")

DEFAULT_CONFIG = {
    "bot_token": "",
    "allowed_chat_ids": [],
    "configlist_dir": "/etc/xray/configlist",
    "xray_configs": [
        "/usr/local/etc/xray/config.json",
        "/usr/local/etc/xray/none.json",
    ],
    "log_install": "/root/log-install.txt",
    "ports": {
        "ws_tls": "443",
        "ws_none": "80",
        "hu_tls": "443",
        "hu_none": "80",
        "xhttp_tls": "443",
        "xhttp_none": "80",
    },
    "poll_timeout": 50,
    # Tag hujung link (#...):
    #   "name"      -> ikut Nama config      contoh: #DIGI%20LIVE%2FEXP
    #   "name-srv"  -> Nama config + -SN     contoh: #DIGI%20LIVE%2FEXP-S1
    #                  (SN diambil dari host, cth s1.nullbytes.vip -> S1)
    "fragment_style": "name",
    # ---- Panel admin ----
    # Chat ID yang boleh guna /admin. [] = tiada admin (hantar /admin untuk
    # tahu chat ID kau sendiri, lepas tu masukkan di sini).
    "admin_ids": [],
    # Note disimpan di /var/lib (bukan /etc) sebab service guna
    # ProtectSystem=full — /etc read-only untuk bot.
    "note_file": "/var/lib/xraay-bot/note.txt",
    "note_max_len": 800,
    # Note per-config (bawah nama config)
    "config_note_file": "/var/lib/xraay-bot/config-notes.json",
    # true = papar nama config dengan tag server, cth "YES LIVE/EXP-S1"
    "display_server_tag": False,
}

# Label dalam ~/log-install.txt untuk setiap jenis port
PORT_LABELS = {
    "ws_tls": "Vless Ws Tls",
    "ws_none": "Vless Ws None Tls",
    "hu_tls": "Xray HttpUpgrade Tls",
    "hu_none": "Xray HttpUpgrade None Tls",
    "xhttp_tls": "Xray Vless Xhttp Tls",
    "xhttp_none": "Xray Vless Xhttp None Tls",
}

# Susunan & warna telco — SAMA dengan config_provider_name/config_provider_color
# dalam script panel (256-color ANSI dipetakan ke emoji bulat yang paling dekat).
PROVIDERS = [
    ("umobile",  "🟠"),   # 208  orange
    ("yes",      "🟣"),   # 93   purple
    ("digi",     "🟡"),   # 226  yellow
    ("celcom",   "🔵"),   # 33   blue
    ("maxis",    "🔴"),   # 196  red
    ("eastel",   "🩵"),   # 51   cyan
    ("yoodo",    "🟢"),   # 46   green
    ("tunetalk", "🩷"),   # 197  pink
    ("tonewow",  "🟦"),   # 44   teal
    ("redone",   "🟤"),   # 160  dark red
]

# proto -> (jenis port, jenis network, guna TLS?)
PROTO_MAP = {
    1: ("ws_tls",     "ws",          True),
    2: ("ws_none",    "ws",          False),
    3: ("hu_tls",     "httpupgrade", True),
    4: ("hu_none",    "httpupgrade", False),
    5: ("xhttp_tls",  "xhttp",       True),
    6: ("xhttp_none", "xhttp",       False),
}

MARKER_RE = re.compile(r"^#vls(?:-http|-xhttp)?\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s*$")
ANY_MARKER_RE = re.compile(r"^#(vms|vls|vls-http|vls-xhttp|vxtls)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s*$")
ID_RE = re.compile(r'"id"\s*:\s*"([^"]+)"')
EMAIL_RE = re.compile(r'"email"\s*:\s*"([^"]+)"')

UUID_INPUT_RE = re.compile(r"^[A-Za-z0-9_\-]{4,120}$")

TELEGRAM_MSG_LIMIT = 3800   # had sebenar 4096, tinggalkan buffer

_running = True


# ============================================================
#  KONFIGURASI
# ============================================================
def load_config(path=CONFIG_PATH):
    cfg = json.loads(json.dumps(DEFAULT_CONFIG))  # deep copy
    try:
        with open(path, "r", encoding="utf-8") as f:
            user_cfg = json.load(f)
    except FileNotFoundError:
        user_cfg = {}
    except Exception as exc:
        log(f"Config {path} tak dapat dibaca: {exc}")
        user_cfg = {}

    for key, val in user_cfg.items():
        if key == "ports" and isinstance(val, dict):
            cfg["ports"].update({k: str(v) for k, v in val.items()})
        elif val is not None:
            cfg[key] = val

    # port sebenar dari ~/log-install.txt (kalau ada), tapi config user menang
    detected = detect_ports(cfg.get("log_install", ""))
    for key, val in detected.items():
        if key not in (user_cfg.get("ports") or {}):
            cfg["ports"][key] = val

    return cfg


def detect_ports(log_path):
    out = {}
    if not log_path:
        return out
    try:
        with open(log_path, "r", encoding="utf-8", errors="ignore") as f:
            text = f.read()
    except OSError:
        return out
    for key, label in PORT_LABELS.items():
        m = re.search(r"^\s*" + re.escape(label) + r"\s*:\s*(\d+)", text, re.M)
        if m:
            out[key] = m.group(1)
    return out


def log(msg):
    sys.stdout.write("%s %s\n" % (time.strftime("%Y-%m-%d %H:%M:%S"), msg))
    sys.stdout.flush()


# ============================================================
#  NOTE (panel admin)
# ============================================================
def note_path(cfg):
    return cfg.get("note_file") or "/var/lib/xraay-bot/note.txt"


def read_note(cfg):
    try:
        with open(note_path(cfg), "r", encoding="utf-8") as f:
            return f.read().strip("\n")
    except OSError:
        return ""


def save_note(cfg, text):
    path = note_path(cfg)
    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text.strip("\n") + "\n")
    try:
        os.chmod(path, 0o600)
    except OSError:
        pass


def clear_note(cfg):
    try:
        os.remove(note_path(cfg))
        return True
    except OSError:
        return False


def is_admin(cfg, chat_id):
    ids = {str(x).strip() for x in (cfg.get("admin_ids") or [])}
    return str(chat_id) in ids


# ---------------- Note per-config ----------------
def cnote_path(cfg):
    return cfg.get("config_note_file") or "/var/lib/xraay-bot/config-notes.json"


def load_cnotes(cfg):
    try:
        with open(cnote_path(cfg), "r", encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def save_cnotes(cfg, data):
    path = cnote_path(cfg)
    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2, sort_keys=True)
    os.replace(tmp, path)
    try:
        os.chmod(path, 0o600)
    except OSError:
        pass


def cnote_key(provider, name):
    return "%s|%s" % (provider, name)


def get_cnote(cfg, provider, name):
    return load_cnotes(cfg).get(cnote_key(provider, name), "")


def set_cnote(cfg, provider, name, text):
    data = load_cnotes(cfg)
    data[cnote_key(provider, name)] = text.strip("\n")
    save_cnotes(cfg, data)


def del_cnote(cfg, provider, name):
    data = load_cnotes(cfg)
    if cnote_key(provider, name) in data:
        del data[cnote_key(provider, name)]
        save_cnotes(cfg, data)
        return True
    return False


def config_hash(provider, name):
    return hashlib.sha1(cnote_key(provider, name).encode("utf-8")).hexdigest()[:12]


def all_configs(cfg):
    out = []
    for provider, emoji, entries in collect_configs(cfg):
        for entry in entries:
            out.append((provider, emoji, entry))
    return out


def find_by_hash(cfg, h):
    for provider, emoji, entry in all_configs(cfg):
        if config_hash(provider, entry["name"]) == h:
            return provider, emoji, entry
    return None


def display_name(cfg, entry):
    name = entry["name"]
    if cfg.get("display_server_tag"):
        tag = server_tag(entry["extra"]) or server_tag(entry["addr"])
        if tag and not name.upper().endswith("-" + tag.upper()):
            name = "%s-%s" % (name, tag)
    return name


# ============================================================
#  CARI USER IKUT USER ID (UUID)
# ============================================================
def read_lines(path):
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            return f.read().splitlines()
    except OSError:
        return []


def find_marker_by_user(paths, username):
    """Cari exp/harini untuk username tertentu (fallback)."""
    for path in paths:
        for ln in read_lines(path):
            m = ANY_MARKER_RE.match(ln)
            if m and m.group(2).lower() == username.lower():
                return {"user": m.group(2), "exp": m.group(3), "created": m.group(4),
                        "uuid": m.group(5), "proto": m.group(1)}
    return None


def find_user(cfg, uid):
    """Pulangkan dict {user, exp, created, uuid, blocked} atau None."""
    uid_l = uid.strip().lower()
    paths = cfg["xray_configs"]

    # 1) marker VLESS: #vls / #vls-http / #vls-xhttp
    for path in paths:
        for ln in read_lines(path):
            m = MARKER_RE.match(ln)
            if m and m.group(4).lower() == uid_l:
                return {
                    "user": m.group(1),
                    "exp": m.group(2),
                    "created": m.group(3),
                    "uuid": m.group(4),
                    "blocked": False,
                }

    # 2) marker protokol lain (vmess/xtls) — tolak awal sebelum fallback id/email
    for path in paths:
        for ln in read_lines(path):
            m = ANY_MARKER_RE.match(ln)
            if not m or m.group(5).lower() != uid_l:
                continue
            if m.group(1) in ("vms", "vxtls"):
                return {"other_proto": m.group(1), "user": m.group(2)}

    # 3) fallback: pasangan "id" + "email" dalam baris JSON yang sama
    #    (config lama tanpa marker — anggap VLESS)
    for path in paths:
        for ln in read_lines(path):
            mi = ID_RE.search(ln)
            if not mi or mi.group(1).lower() != uid_l:
                continue
            me = EMAIL_RE.search(ln)
            user = me.group(1) if me else ""
            blocked = user.startswith("blocked-")
            if blocked:
                user = user[len("blocked-"):]
            info = find_marker_by_user(paths, user) or {}
            return {
                "user": user,
                "exp": info.get("exp", ""),
                "created": info.get("created", ""),
                "uuid": mi.group(1),
                "blocked": blocked,
            }

    return None


# ============================================================
#  BACA CONFIG LIST
# ============================================================
def read_provider_entries(cfg, provider):
    """Baca <provider>.conf, pulangkan senarai entry VLESS sahaja."""
    path = os.path.join(cfg["configlist_dir"], provider + ".conf")
    entries = []
    for raw in read_lines(path):
        line = raw.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        parts = line.split("\t")
        # format lama (tanpa medan mode): nama | proto | addr | path | extra
        if len(parts) >= 5 and parts[1] not in ("vmess", "vless", "xtls"):
            parts = [parts[0], "vless", parts[1], parts[2], parts[3], parts[4]]
        if len(parts) < 6:
            continue
        name, mode, proto, addr, cpath, extra = (p.strip() for p in parts[:6])
        if mode.lower() != "vless":
            continue
        if not name or not addr:
            continue
        try:
            pnum = int(proto)
        except ValueError:
            continue
        if pnum not in PROTO_MAP:
            continue
        entries.append({
            "name": name,
            "proto": pnum,
            "addr": addr,
            "path": cpath or "/vless",
            "extra": extra,
        })
    return entries


def collect_configs(cfg):
    """Pulangkan [(provider, emoji, entries)] untuk telco yang ada config sahaja."""
    out = []
    for provider, emoji in PROVIDERS:
        entries = read_provider_entries(cfg, provider)
        if entries:
            out.append((provider, emoji, entries))
    return out


# ============================================================
#  BINA LINK
# ============================================================
def server_tag(host):
    """Ambil tag server dari host: s1.nullbytes.vip / x.s1.abc -> 'S1'."""
    m = re.search(r"(?:^|\.)s(\d+)\.", (host or "").lower())
    return "S" + m.group(1) if m else ""


def build_link(uuid, entry, ports, fragment_style="name"):
    pnum = entry["proto"]
    port_key, net, use_tls = PROTO_MAP[pnum]
    port = ports.get(port_key, "443" if use_tls else "80")

    path = urllib.parse.quote(entry["path"], safe="")
    extra = entry["extra"]

    frag_src = entry["name"]
    if fragment_style == "name-srv":
        tag = server_tag(extra) or server_tag(entry["addr"])
        if tag:
            frag_src = "%s-%s" % (frag_src, tag)
    frag = urllib.parse.quote(frag_src, safe="")

    if use_tls:
        query = "path=%s&security=tls&encryption=none&sni=%s&type=%s" % (path, extra, net)
    else:
        query = "path=%s&security=none&encryption=none&host=%s&type=%s" % (path, extra, net)

    return "vless://%s@%s:%s?%s#%s" % (uuid, entry["addr"], port, query, frag)


# ============================================================
#  RENDER MESEJ
# ============================================================
def render_messages(cfg, info, groups):
    """Pulangkan senarai mesej HTML (dah dipecah ikut had Telegram)."""
    esc = lambda s: html.escape(str(s), quote=False)

    head = ["👤 User: <b>%s</b>" % esc(info["user"])]
    if info.get("exp"):
        head.append("📅 Expired: <b>%s</b>" % esc(info["exp"]))
    if info.get("blocked"):
        head.append("⚠️ Status: <b>BLOCKED</b> (limit IP / quota)")
    total_cfg = sum(len(e) for _, _, e in groups)
    head.append("📡 Config List: <b>%d telco</b> • <b>%d config</b>" % (len(groups), total_cfg))
    head.append("━━━━━━━━━━━━━━━━━━━━")
    note = read_note(cfg)
    if note:
        # baris kedua dan seterusnya diindent supaya sejajar dengan "Note : "
        head.append("Note : " + esc(note).replace("\n", "\n       "))
    header = "\n".join(head)

    blocks = []
    for provider, emoji, entries in groups:
        for entry in entries:
            link = build_link(info["uuid"], entry, cfg["ports"],
                              cfg.get("fragment_style", "name"))
            head_block = "%s%s" % (emoji, esc(display_name(cfg, entry)))
            cnote = get_cnote(cfg, provider, entry["name"])
            if cnote:
                head_block += "\nNote : " + esc(cnote).replace("\n", "\n       ")
            blocks.append(head_block + "\n<blockquote><code>%s</code></blockquote>"
                          % esc(link))

    messages, buf = [], header
    for blk in blocks:
        if len(buf) + len(blk) + 2 > TELEGRAM_MSG_LIMIT:
            messages.append(buf)
            buf = blk
        else:
            buf += "\n\n" + blk
    messages.append(buf)
    return messages


def build_reply(cfg, text):
    """Pulangkan (list_mesej, ok)."""
    uid = text.strip()
    if not UUID_INPUT_RE.match(uid):
        return ([
            "❌ Format User ID tak sah.\n\n"
            "Hantar <b>User ID</b> sahaja, contoh:\n"
            "<code>ee89fe76-4b35-4b25-835d-d6d141b93bf7</code>"
        ], False)

    info = find_user(cfg, uid)
    if info is None:
        return ([
            "❌ User ID <code>%s</code> tak dijumpai dalam server.\n\n"
            "Pastikan ID betul atau akaun masih wujud." % html.escape(uid)
        ], False)

    if "other_proto" in info:
        proto = info["other_proto"]
        nama = {"vms": "VMess WS", "vxtls": "VLESS XTLS"}.get(proto, proto)
        return ([
            "ℹ️ User ID ni milik akaun <b>%s</b> (user: <b>%s</b>).\n\n"
            "Bot ni khusus untuk <b>PANEL XRAY VLESS WEBSOCKET</b> sahaja."
            % (html.escape(nama), html.escape(info["user"]))
        ], False)

    groups = collect_configs(cfg)
    if not groups:
        return ([
            "⚠️ Tiada config dalam CONFIG LIST VPS.\n\n"
            "Sila tambah config melalui menu panel dahulu."
        ], False)

    return (render_messages(cfg, info, groups), True)


# ============================================================
#  TELEGRAM API
# ============================================================
def tg_call(token, method, http_timeout=90, **params):
    """Panggil Bot API.

    Parameter HTTP sengaja dinamakan `http_timeout` supaya TIDAK bercanggah
    dengan parameter API Telegram bernama `timeout` (long-poll getUpdates).
    """
    url = "https://api.telegram.org/bot%s/%s" % (token, method)
    data = urllib.parse.urlencode(params).encode("utf-8")
    req = urllib.request.Request(url, data=data)
    with urllib.request.urlopen(req, timeout=http_timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def send_text(token, chat_id, text, reply_markup=None):
    params = dict(chat_id=chat_id, text=text,
                  parse_mode="HTML", disable_web_page_preview=True)
    if reply_markup:
        params["reply_markup"] = reply_markup
    try:
        tg_call(token, "sendMessage", **params)
        return True
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", "ignore")
        # fallback: kalau HTML tak diterima, hantar teks biasa
        if exc.code == 400 and "parse" in body.lower():
            params.pop("parse_mode", None)
            params["text"] = re.sub(r"<[^>]+>", "", text)
            try:
                tg_call(token, "sendMessage", **params)
                return True
            except Exception as exc2:
                log("send plain gagal: %s" % exc2)
                return False
        log("sendMessage gagal (%s): %s" % (exc.code, body[:200]))
        return False
    except Exception as exc:
        log("sendMessage gagal: %s" % exc)
        return False


def delete_message(token, chat_id, message_id):
    try:
        tg_call(token, "deleteMessage", chat_id=chat_id, message_id=message_id)
    except Exception:
        pass


def answer_callback(token, cq_id, text=None):
    try:
        params = {"callback_query_id": cq_id}
        if text:
            params["text"] = text
        tg_call(token, "answerCallbackQuery", http_timeout=15, **params)
    except Exception as exc:
        log("answerCallbackQuery gagal: %s" % exc)


# ============================================================
#  PANEL ADMIN
# ============================================================
ADMIN_KEYBOARD = json.dumps({
    "inline_keyboard": [
        [{"text": "📝 Lihat Note", "callback_data": "note:view"},
         {"text": "✏️ Tukar Note", "callback_data": "note:set"}],
        [{"text": "🗑 Padam Note", "callback_data": "note:del"},
         {"text": "📌 Note Config", "callback_data": "note:cfg"}],
        [{"text": "❌ Tutup", "callback_data": "note:close"}],
    ]
})

PENDING_NOTE = set()        # chat_id menunggu teks note umum
PENDING_CNOTE = {}          # chat_id -> (provider, name) menunggu teks note config


def esc_html(s):
    return html.escape(str(s), quote=False)


def admin_panel_text(cfg):
    note = read_note(cfg)
    if note:
        note_txt = "<blockquote>%s</blockquote>" % esc_html(note)
    else:
        note_txt = "<i>(kosong — tiada note dipaparkan)</i>"
    return (
        "🔧 <b>PANEL ADMIN</b>\n"
        "━━━━━━━━━━━━━━━━━━━━\n"
        "Note semasa:\n%s\n\n"
        "Note ni muncul pada <b>setiap</b> reply config list, di bawah garis "
        "pemisah. Had: <b>%d</b> aksara.\n\n"
        "Arahan: /setnote &lt;teks&gt; · /note · /delnote · /cancel"
        % (note_txt, int(cfg.get("note_max_len", 800)))
    )


def send_admin_panel(cfg, chat_id):
    send_text(cfg["bot_token"], chat_id, admin_panel_text(cfg), ADMIN_KEYBOARD)


def apply_note(cfg, chat_id, text):
    token = cfg["bot_token"]
    limit = int(cfg.get("note_max_len", 800))
    note = text.strip()
    if not note:
        send_text(token, chat_id, "❌ Note kosong, tak disimpan.")
        return True
    if len(note) > limit:
        send_text(token, chat_id,
                  "❌ Note terlalu panjang: <b>%d</b> aksara (had %d).\n"
                  "Pendekkan sikit." % (len(note), limit))
        return True
    save_note(cfg, note)
    PENDING_NOTE.discard(chat_id)
    send_text(token, chat_id,
              "✅ Note disimpan (%d aksara).\n\n"
              "Pratonton:\n<blockquote>%s</blockquote>" % (len(note), esc_html(note)))
    return True


def cnote_keyboard(h):
    return json.dumps({"inline_keyboard": [
        [{"text": "✏️ Tukar Note", "callback_data": "cn:s:" + h},
         {"text": "🗑 Padam Note", "callback_data": "cn:d:" + h}],
        [{"text": "⬅️ Kembali", "callback_data": "note:cfg"}],
    ]})


def config_note_menu(cfg, chat_id):
    token = cfg["bot_token"]
    items = all_configs(cfg)
    if not items:
        send_text(token, chat_id, "⚠️ Tiada config dalam CONFIG LIST.")
        return
    kb = []
    for provider, emoji, entry in items:
        label = "%s%s" % (emoji, display_name(cfg, entry))
        if len(label) > 58:
            label = label[:57] + "…"
        kb.append([{"text": label,
                    "callback_data": "cn:v:" + config_hash(provider, entry["name"])}])
    kb.append([{"text": "⬅️ Kembali", "callback_data": "note:panel"}])
    send_text(token, chat_id,
              "📌 <b>NOTE PER-CONFIG</b>\n"
              "Pilih config yang nak diberi note.\n"
              "<i>Note akan muncul bawah nama config tu.</i>",
              json.dumps({"inline_keyboard": kb}))


def config_note_detail(cfg, chat_id, h):
    token = cfg["bot_token"]
    found = find_by_hash(cfg, h)
    if not found:
        send_text(token, chat_id,
                  "⚠️ Config tak jumpa (mungkin dah dipadam/diubah). "
                  "Buka semula /admin → Note Config.")
        return
    provider, emoji, entry = found
    note = get_cnote(cfg, provider, entry["name"])
    note_txt = ("<blockquote>%s</blockquote>" % esc_html(note)) if note else "<i>(kosong)</i>"
    txt = ("📌 <b>%s%s</b>\n"
           "Telco: %s\n\n"
           "Note semasa:\n%s"
           % (emoji, esc_html(display_name(cfg, entry)), provider, note_txt))
    send_text(token, chat_id, txt, cnote_keyboard(h))


def apply_cnote(cfg, chat_id, text):
    token = cfg["bot_token"]
    provider, name = PENDING_CNOTE[chat_id]
    limit = int(cfg.get("note_max_len", 800))
    note = text.strip()
    if not note:
        send_text(token, chat_id, "❌ Note kosong, tak disimpan.")
        return
    if len(note) > limit:
        send_text(token, chat_id,
                  "❌ Note terlalu panjang: <b>%d</b> aksara (had %d)."
                  % (len(note), limit))
        return
    set_cnote(cfg, provider, name, note)
    PENDING_CNOTE.pop(chat_id, None)
    send_text(token, chat_id,
              "✅ Note disimpan untuk <b>%s</b> (%d aksara).\n\n"
              "Pratonton:\n<blockquote>%s</blockquote>"
              % (esc_html(name), len(note), esc_html(note)))


def handle_cnote_callback(cfg, chat_id, message_id, data):
    token = cfg["bot_token"]
    parts = data.split(":")
    if len(parts) < 3:
        return
    act, h = parts[1], parts[2]
    found = find_by_hash(cfg, h)
    if not found:
        send_text(token, chat_id,
                  "⚠️ Config tak jumpa (mungkin dah dipadam/diubah). "
                  "Buka semula /admin → Note Config.")
        return
    provider, emoji, entry = found

    if act == "v":
        config_note_detail(cfg, chat_id, h)
    elif act == "s":
        PENDING_CNOTE[chat_id] = (provider, entry["name"])
        PENDING_NOTE.discard(chat_id)
        send_text(token, chat_id,
                  "✏️ Hantar teks note untuk <b>%s%s</b>.\n"
                  "<i>/cancel untuk batal.</i>"
                  % (emoji, esc_html(display_name(cfg, entry))))
    elif act == "d":
        ok = del_cnote(cfg, provider, entry["name"])
        send_text(token, chat_id,
                  ("🗑 Note untuk <b>%s</b> dipadam." % esc_html(entry["name"]))
                  if ok else
                  ("ℹ️ Memang tiada note untuk <b>%s</b>." % esc_html(entry["name"])))
    else:
        config_note_detail(cfg, chat_id, h)


def handle_admin_command(cfg, chat_id, text):
    """Kendali arahan admin. Pulang True kalau dah diuruskan."""
    token = cfg["bot_token"]
    low = text.lower().strip()

    prefixes = ("/admin", "/note", "/delnote", "/setnote", "/cancel")
    if not low.startswith(prefixes):
        return False

    # Setiap arahan admin membatalkan mod "tunggu teks" yang terdahulu,
    # supaya mesej seterusnya tak tertelan jadi note yang salah.
    had_pending = chat_id in PENDING_NOTE or chat_id in PENDING_CNOTE
    PENDING_NOTE.discard(chat_id)
    PENDING_CNOTE.pop(chat_id, None)

    if low.startswith("/admin"):
        if not is_admin(cfg, chat_id):
            send_text(token, chat_id,
                      "\u26d4 Kau bukan admin.\n\n"
                      "Chat ID kau: <code>%s</code>\n"
                      "Masukkan dalam <code>admin_ids</code> pada "
                      "<code>/etc/xraay-bot/config.json</code>, lepas tu "
                      "<code>systemctl restart xraay-bot</code>."
                      % chat_id)
            return True
        send_admin_panel(cfg, chat_id)
        return True

    if not is_admin(cfg, chat_id):
        return False

    if low.startswith("/note"):
        note = read_note(cfg)
        if note:
            send_text(token, chat_id,
                      "\U0001f4dd <b>Note semasa:</b>\n<blockquote>%s</blockquote>"
                      % esc_html(note))
        else:
            send_text(token, chat_id, "\U0001f4dd Note kosong. Guna /setnote &lt;teks&gt;.")
        return True

    if low.startswith("/delnote"):
        if clear_note(cfg):
            send_text(token, chat_id, "\U0001f5d1 Note dipadam.")
        else:
            send_text(token, chat_id, "\u2139\ufe0f Memang tiada note.")
        return True

    if low.startswith("/setnote"):
        arg = text[len("/setnote"):].strip()
        if arg:
            return apply_note(cfg, chat_id, arg)
        PENDING_NOTE.add(chat_id)
        send_text(token, chat_id,
                  "\u270f\ufe0f Hantar teks note sekarang (satu mesej).\n"
                  "Boleh guna berbilang baris. /cancel untuk batal.")
        return True

    if low.startswith("/cancel"):
        send_text(token, chat_id,
                  "\u274c Dibatalkan." if had_pending else "\u2139\ufe0f Tiada apa nak dibatalkan.")
        return True

    return False


def handle_callback(cfg, cq):
    token = cfg["bot_token"]
    cq_id = cq.get("id")
    msg = cq.get("message") or {}
    chat_id = (msg.get("chat") or {}).get("id")
    message_id = msg.get("message_id")
    data = cq.get("data") or ""

    if chat_id is None:
        answer_callback(token, cq_id)
        return

    allowed = cfg.get("allowed_chat_ids") or []
    if allowed and chat_id not in allowed:
        log("tolak callback chat_id %s (bukan dalam allowlist)" % chat_id)
        answer_callback(token, cq_id)
        return

    if not is_admin(cfg, chat_id):
        answer_callback(token, cq_id, "Bukan admin")
        return

    if data.startswith("cn:"):
        handle_cnote_callback(cfg, chat_id, message_id, data)
        answer_callback(token, cq_id)
        return

    if data == "note:panel":
        answer_callback(token, cq_id)
        send_admin_panel(cfg, chat_id)
        return

    action = data.split(":", 1)[1] if ":" in data else data

    if action == "view":
        answer_callback(token, cq_id)
        note = read_note(cfg)
        send_text(token, chat_id,
                  ("📝 <b>Note semasa:</b>\n<blockquote>%s</blockquote>" % esc_html(note))
                  if note else "📝 Note kosong.")
    elif action == "set":
        answer_callback(token, cq_id)
        PENDING_NOTE.add(chat_id)
        send_text(token, chat_id,
                  "✏️ Hantar teks note sekarang (satu mesej).\n"
                  "Boleh guna berbilang baris. /cancel untuk batal.")
    elif action == "del":
        answer_callback(token, cq_id)
        ok = clear_note(cfg)
        send_text(token, chat_id,
                  "🗑 Note dipadam." if ok else "ℹ️ Memang tiada note.")
    elif action == "cfg":
        answer_callback(token, cq_id)
        config_note_menu(cfg, chat_id)
    elif action == "close":
        answer_callback(token, cq_id)
        if message_id:
            delete_message(token, chat_id, message_id)
    else:
        answer_callback(token, cq_id)


def handle_update(cfg, upd):
    if "callback_query" in upd:
        handle_callback(cfg, upd["callback_query"])
        return

    msg = upd.get("message") or upd.get("edited_message")
    if not msg:
        return
    chat_id = (msg.get("chat") or {}).get("id")
    text = (msg.get("text") or "").strip()
    if chat_id is None or not text:
        return

    allowed = cfg.get("allowed_chat_ids") or []
    if allowed and chat_id not in allowed:
        log("tolak chat_id %s (bukan dalam allowlist)" % chat_id)
        return

    token = cfg["bot_token"]

    # ---- arahan admin ----
    if text.startswith("/"):
        if handle_admin_command(cfg, chat_id, text):
            return

    # ---- admin sedang taip note config ----
    if chat_id in PENDING_CNOTE:
        apply_cnote(cfg, chat_id, text)
        return

    # ---- admin sedang taip note umum ----
    if chat_id in PENDING_NOTE:
        apply_note(cfg, chat_id, text)
        return

    low = text.lower()
    if low in ("/start", "/help", "start", "help", "/menu"):
        help_txt = (
            "👋 <b>Bot Config List VLESS</b>\n\n"
            "Hantar <b>User ID</b> akaun kau dan bot akan paparkan "
            "semua config list yang ada dalam server.\n\n"
            "Contoh:\n<code>ee89fe76-4b35-4b25-835d-d6d141b93bf7</code>"
        )
        if is_admin(cfg, chat_id):
            help_txt += "\n\n🔧 Admin: /admin"
        send_text(token, chat_id, help_txt)
        return

    messages, _ok = build_reply(cfg, text)
    for m in messages:
        if not send_text(token, chat_id, m):
            break


def check_token(token):
    """Sahkan token di awal supaya salah config nampak terus dalam log."""
    try:
        res = tg_call(token, "getMe", http_timeout=15)
        if res.get("ok"):
            return res["result"].get("username", "?")
        return None
    except urllib.error.HTTPError as exc:
        log("Token DITOLAK oleh Telegram (HTTP %s). Semak bot_token." % exc.code)
        return None
    except Exception as exc:
        log("Tak dapat hubungi Telegram: %s" % exc)
        return None


def poll_loop(cfg):
    global _running
    token = cfg["bot_token"]
    offset = None

    username = check_token(token)
    if username:
        log("Token OK — bot @%s" % username)
    else:
        log("Amaran: token tak dapat disahkan. Terus cuba juga...")

    log("Bot bermula. Config list: %s" % cfg["configlist_dir"])

    while _running:
        params = {"timeout": cfg.get("poll_timeout", 50),
                  "allowed_updates": json.dumps(["message", "edited_message", "callback_query"])}
        if offset is not None:
            params["offset"] = offset
        try:
            res = tg_call(token, "getUpdates", http_timeout=90, **params)
        except urllib.error.HTTPError as exc:
            body = exc.read().decode("utf-8", "ignore")
            if exc.code == 401:
                log("Token bot tak sah. Berhenti.")
                return
            if exc.code == 409:
                log("Konflik getUpdates (ada instance lain berjalan?) — tunggu 5s")
                time.sleep(5)
                continue
            log("HTTP %s: %s" % (exc.code, body[:200]))
            time.sleep(5)
            continue
        except Exception as exc:
            log("Ralat rangkaian: %s" % exc)
            time.sleep(5)
            continue

        if not res.get("ok"):
            time.sleep(3)
            continue

        for upd in res.get("result", []):
            offset = upd["update_id"] + 1
            try:
                handle_update(cfg, upd)
            except Exception as exc:
                log("Ralat proses update %s: %s" % (upd.get("update_id"), exc))


# ============================================================
#  MAIN
# ============================================================
def _sigterm(_signum, _frame):
    global _running
    _running = False


def main():
    signal.signal(signal.SIGTERM, _sigterm)
    signal.signal(signal.SIGINT, _sigterm)

    cfg = load_config()

    if "--dump" in sys.argv:
        idx = sys.argv.index("--dump")
        if idx + 1 >= len(sys.argv):
            print("Guna: xraay-bot --dump <UUID>")
            return 2
        messages, _ok = build_reply(cfg, sys.argv[idx + 1])
        print("\n\n===== MESEJ =====\n\n".join(messages))
        return 0

    if not cfg.get("bot_token"):
        log("bot_token kosong. Isi dalam %s" % CONFIG_PATH)
        return 2

    poll_loop(cfg)
    log("Bot berhenti.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
