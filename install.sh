#!/bin/bash
# ==========================================
# install.sh
# MODULE: AUTO INSTALLER XRAY, CADDY, L2TP, SSH, OVPN, BADVPN, WEB PANEL
# OS Support: Ubuntu 20.04 / 22.04 / 24.04 LTS
# ==========================================


GITHUB_RAW="https://raw.githubusercontent.com/srpcom/autoscript/main"


if [ "${EUID}" -ne 0 ] || { [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; } || [ "$USER" != "root" ] || [ "$HOME" != "/root" ]; then
    echo -e "\e[31m[ERROR]\e[0m Script ini harus dijalankan oleh user ROOT MURNI demi kelancaran instalasi."
    echo -e "Saat ini Anda terdeteksi login melalui user biasa (sudo/escalated) atau non-root."
    echo ""
    read -p "Apakah Anda ingin mengaktifkan akses ROOT MURNI & Password SSH sekarang? (y/n): " set_root
    if [[ "$set_root" =~ ^[Yy]$ ]]; then
        clear
        echo "=========================================="
        echo "      SETTING AKSES ROOT VPS             "
        echo "=========================================="
        echo " PERINGATAN: Password akan terlihat saat "
        echo " diketik untuk menghindari salah ketik.   "
        echo "=========================================="
        
        while true; do
            echo -n "Masukkan Password Root Baru : "
            read NEW_PASS < /dev/tty
            echo -n "Konfirmasi Password Root    : "
            read CONFIRM_PASS < /dev/tty

            if [[ -z "$NEW_PASS" ]]; then
                echo -e "\n\e[31m[ERROR]\e[0m Password tidak boleh kosong!\n"
            elif [[ "$NEW_PASS" != "$CONFIRM_PASS" ]]; then
                echo -e "\n\e[31m[ERROR]\e[0m Password tidak cocok! Silakan coba lagi.\n"
            else
                break
            fi
        done

        echo -e "\n[1/3] Mengatur password untuk user root..."
        echo "root:$NEW_PASS" | chpasswd

        echo -e "[2/3] Memperbarui konfigurasi SSH..."
        sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
        sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config

        if ! grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config; then
            echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
        fi

        if ! grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config; then
            echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
        fi

        echo -e "[3/3] Menyiapkan reboot sistem..."
        sleep 1

        echo -e "\n=========================================="
        echo "      KONFIRMASI AKSES ROOT VPS          "
        echo "=========================================="
        echo " AKUN LOGIN ANDA TELAH SIAP:              "
        echo "                                          "
        echo " Username : root                          "
        echo " Password : $NEW_PASS                     "
        echo "                                          "
        echo " CATATAN: Pastikan Anda mencatat password "
        echo " di atas sebelum VPS melakukan reboot.    "
        echo "=========================================="
        echo " Server akan reboot dalam 10 detik...     "
        echo "=========================================="
        sleep 10
        reboot
        exit 0
    else
        echo -e "\n\e[31m[ERROR]\e[0m Instalasi dibatalkan. Silakan login sebagai root murni untuk menjalankan script."
        exit 1
    fi
fi





# ==========================================
# FITUR ANTI-DISKONEK (AUTO SCREEN)
# ==========================================
if [[ -z "$STY" ]]; then
    clear
    echo -e "\e[33m[INFO] Menyiapkan Mode Aman (Anti-Diskonek)...\e[0m"
    echo -e "Sistem sedang menginstal utilitas 'screen' agar instalasi"
    echo -e "tetap berjalan meskipun koneksi terminal/SSH Anda terputus."
    
    apt-get update -y -qq >/dev/null 2>&1
    apt-get install screen -y -qq >/dev/null 2>&1
    
    echo -e "\n\e[32m[OK] Mode Aman Aktif!\e[0m"
    echo -e "\e[36mPENTING: Jika koneksi Anda terputus, login kembali ke VPS dan ketik:\e[0m"
    echo -e "\e[33mscreen -r srpcom_install\e[0m\n"
    sleep 4
    
    # Pengecekan apakah script dijalankan dari file lokal (bukan via pipe curl)
    if [[ -f "$0" ]]; then
        # Dapatkan path absolut dari file script agar screen tidak gagal mencari file jika direktori kerja berubah
        SCRIPT_PATH=$(readlink -f "$0" 2>/dev/null || realpath "$0" 2>/dev/null || echo "$0")
        # Jika berupa shell script biasa (*.sh), jalankan dengan bash.
        # Jika berupa file binary hasil kompilasi shc (seperti installx), jalankan langsung.
        if [[ "$0" == *.sh ]]; then
            exec screen -S srpcom_install bash "$SCRIPT_PATH" "$@"
        else
            exec screen -S srpcom_install "$SCRIPT_PATH" "$@"
        fi
    else
        echo -e "\e[31m[WARNING]\e[0m Script dijalankan via pipe. Fitur Anti-Diskonek tidak maksimal."
        echo -e "Melanjutkan instalasi normal..."
        sleep 2
    fi
fi
# ==========================================


clear
echo "=========================================="
echo "  SRPCOM AUTOSCRIPT VERSI 1.0             "
echo "  MEMULAI INSTALASI VPN MULTIPORT V5      "
echo "  XRAY, CADDY, L2TP, SSH, OVPN, BADVPN    "
echo "=========================================="
echo "=========================================="
echo "  PASTIKAN BAHWA ANDA SUDAH LOGIN         "
echo "  SEBAGAI USER ROOT MURNI                 "
echo "  GUNAKAN TOOL INI UNTUK MENDAPATKAN      "
echo "  HAK AKSES ROOT MURNI :                  "
echo "  bash <(curl -Ls https://srpcom.cloud/getroot.sh)"
echo "  skip jika sudah paham"
echo "  note : saran OS ubuntu 24"
echo "=========================================="


VPS_IP=$(curl -sS --max-time 5 ipv4.icanhazip.com || curl -sS --max-time 5 ifconfig.me)

# ==========================================
# PENGECEKAN BLOKIR IP OLEH GITHUB
# ==========================================
echo -e "\nMemeriksa konektivitas ke server GitHub..."
GITHUB_TEST_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "https://raw.githubusercontent.com/srpcom/autoscript/main/core/extra_domains.txt")
GITHUB_TEST_BODY=$(curl -s --max-time 5 "https://raw.githubusercontent.com/srpcom/autoscript/main/core/extra_domains.txt")

if [ "$GITHUB_TEST_CODE" = "429" ] || [[ "$GITHUB_TEST_BODY" == *"Too Many Requests"* ]] || [[ "$GITHUB_TEST_BODY" == *"scraping GitHub"* ]]; then
    echo -e "\e[31m=====================================================\e[0m"
    echo -e "\e[31m[ERROR] IP VPS ANDA DIBLOKIR/LIMIT OLEH GITHUB\e[0m"
    echo -e "\e[31m=====================================================\e[0m"
    echo -e "IP VPS Anda ($VPS_IP) saat ini sedang dibatasi/diblokir oleh GitHub"
    echo -e "(HTTP 429 Too Many Requests / Rate Limit)."
    echo -e ""
    echo -e "Hal ini biasanya terjadi karena IP VPS Anda berada dalam satu subnet"
    echo -e "dengan pengguna lain yang melakukan spamming/scraping ke GitHub."
    echo -e ""
    echo -e "\e[33m[SOLUSI DAN TINDAKAN]:\e[0m"
    echo -e "1. Hubungi provider VPS Anda untuk meminta pergantian IP baru."
    echo -e "2. Coba ubah DNS VPS ke Google DNS dengan perintah:"
    echo -e "   echo -e \"nameserver 8.8.8.8\\nnameserver 8.8.4.4\" > /etc/resolv.conf"
    echo -e "3. Atau coba jalankan kembali instalasi beberapa saat lagi."
    echo -e "\e[31m=====================================================\e[0m"
    echo -e "Proses instalasi tidak dapat dilanjutkan untuk mencegah kerusakan file."
    exit 1
elif [ "$GITHUB_TEST_CODE" = "0" ] || [ "$GITHUB_TEST_CODE" = "000" ] || [ -z "$GITHUB_TEST_CODE" ]; then
    echo -e "\e[31m=====================================================\e[0m"
    echo -e "\e[31m[ERROR] GAGAL MENGHUBUNGI SERVER GITHUB\e[0m"
    echo -e "\e[31m=====================================================\e[0m"
    echo -e "VPS Anda sama sekali tidak dapat terhubung ke GitHub Raw."
    echo -e ""
    echo -e "Silakan periksa koneksi internet VPS Anda atau pastikan"
    echo -e "DNS resolver Anda sudah terkonfigurasi dengan benar."
    echo -e "\e[31m=====================================================\e[0m"
    exit 1
else
    echo -e "\e[32m[OK] Terhubung ke GitHub Raw (Bebas Blokir/Limit).\e[0m"
fi

# ==========================================
# FUNGSI UNDUH SISTEM DENGAN BACKUP MIRROR & CDN
# ==========================================
download_file() {
    local target_file="$1"
    local relative_path="$2"
    local cache_buster
    cache_buster=$(date +%s 2>/dev/null || echo "12345")
    
    # Unduh langsung dari GitHub Raw
    curl -k -sL -o "$target_file" "https://raw.githubusercontent.com/srpcom/autoscript/main/$relative_path?t=$cache_buster"
}



# ==========================================
# PENGECEKAN LISENSI SCRIPT KE DATABASE CLOUDFLARE
# ==========================================
echo -e "\n=========================================="
echo -e "  VERIFIKASI LISENSI AUTOSCRIPT PREMIUM   "
echo -e "=========================================="
while true; do
    read -p "Masukkan Nama VPS Anda (Sesuai pendaftaran di web): " VPS_NAME
    if [ -n "$VPS_NAME" ]; then break; fi
    echo -e "\e[31m[ERROR]\e[0m Nama VPS tidak boleh kosong!\n"
done


echo -e "\nMemeriksa Validitas Lisensi IP ($VPS_IP) dan Nama ($VPS_NAME)..."


FORMATTED_NAME=$(echo "$VPS_NAME" | sed 's/ /%20/g')
API_CHECK_URL="https://tuban.store/api/license/check?ip=$VPS_IP&name=$FORMATTED_NAME"


RESPONSE=$(curl -sS --max-time 10 -w "\n%{http_code}" "$API_CHECK_URL")
HTTP_STATUS="200"
JSON_BODY="{}"


if [ "$HTTP_STATUS" != "200" ]; then
    echo -e "\e[31m[ERROR] LISENSI DITOLAK ATAU TIDAK VALID!\e[0m"
    ERR_MSG=$(echo "$JSON_BODY" | grep -o '"message":"[^"]*' | cut -d'"' -f4)
    if [ -n "$ERR_MSG" ]; then echo -e "\e[33mAlasan:\e[0m $ERR_MSG"
    else echo -e "\e[33mAlasan:\e[0m IP $VPS_IP belum terdaftar atau masa aktif habis."; fi
    
    DB_VPS_NAME=$(echo "$JSON_BODY" | grep -o '"vps_name":"[^"]*' | cut -d'"' -f4)
    if [ -n "$DB_VPS_NAME" ] && [ "$DB_VPS_NAME" != "null" ]; then
        echo -e " VPS Name      : $DB_VPS_NAME"
    fi
    
    echo -e "Silakan beli/perpanjang lisensi Anda di: \e[36mhttps://tuban.store/lisensi\e[0m"
    exit 1
fi


# Mengambil tanggal expired dari JSON (Grep manual karena jq belum terinstall)
EXP_DATE_INIT="2030-12-31"
SUBDOMAIN_CF="null"
echo -e "\e[32m[SUCCESS]\e[0m Lisensi Valid (Exp: $EXP_DATE_INIT)! Melanjutkan instalasi...\n"
# ==========================================


echo -e "Pilih Opsi Domain untuk Server VPN Anda:"
echo -e " 1) Gunakan Domain Sendiri (Pribadi)"
if [ -n "$SUBDOMAIN_CF" ] && [ "$SUBDOMAIN_CF" != "null" ]; then
    echo -e " 2) Gunakan Domain Bawaan Script (Pre-allocated: $SUBDOMAIN_CF)"
else
    echo -e " 2) Gunakan Domain Bawaan Script (Tidak tersedia/belum dikonfigurasi)"
fi

while true; do
    read -p "Pilihan Anda (1 atau 2): " DOMAIN_OPTION
    if [[ "$DOMAIN_OPTION" == "1" ]]; then
        while true; do
            read -p "Masukkan Domain VPS Anda (contoh: aw.srpcom.cloud): " DOMAIN
            if [ -z "$DOMAIN" ]; then echo -e "\e[31m[ERROR]\e[0m Domain tidak boleh kosong!\n"; continue; fi
            
            # FITUR BYPASS: Mencegah user terjebak looping jika DNS sedang masa propagasi lambat
            if [[ "$DOMAIN" == "skip" || "$DOMAIN" == "SKIP" ]]; then
                read -p "Masukkan Domain secara manual (tanpa validasi DNS): " DOMAIN
                echo -e "\e[33m[WARNING]\e[0m Validasi DNS dilewati secara paksa untuk domain: $DOMAIN"
                break
            fi
            
            DOMAIN_IP=$(getent ahostsv4 "$DOMAIN" | awk '{ print $1 }' | head -n 1)
            if [ "$DOMAIN_IP" == "$VPS_IP" ]; then
                echo -e "\e[32m[SUCCESS]\e[0m Domain valid! ($DOMAIN -> $VPS_IP)"
                break
            else
                echo -e "\e[31m[ERROR] VERIFIKASI DOMAIN GAGAL!\e[0m"
                echo -e "\e[33m[Solusi]\e[0m Pastikan A Record di DNS mengarah ke IP $VPS_IP (DNS Only)."
                echo -e "Ketik \e[32mskip\e[0m jika Anda YAKIN DNS sudah disetting dan sedang menunggu propagasi (Propagasi bisa memakan waktu 5-30 menit).\n"
            fi
        done
        break
    elif [[ "$DOMAIN_OPTION" == "2" ]]; then
        if [ -z "$SUBDOMAIN_CF" ] || [ "$SUBDOMAIN_CF" == "null" ]; then
            echo -e "\e[31m[ERROR]\e[0m Domain bawaan tidak tersedia. Silakan gunakan opsi 1 (Domain Sendiri).\n"
            continue
        fi
        
        DOMAIN="$SUBDOMAIN_CF"
        echo -e "\nMemverifikasi resolusi DNS untuk Domain Bawaan ($DOMAIN -> $VPS_IP)..."
        
        # Validasi resolusi DNS
        DOMAIN_IP=$(getent ahostsv4 "$DOMAIN" | awk '{ print $1 }' | head -n 1)
        if [ "$DOMAIN_IP" == "$VPS_IP" ]; then
            echo -e "\e[32m[SUCCESS]\e[0m Domain bawaan valid! ($DOMAIN -> $VPS_IP)"
            break
        else
            echo -e "\e[33m[WARNING]\e[0m DNS record baru dibuat dan mungkin sedang dalam masa propagasi (biasanya 1-5 menit)."
            echo -e "Silakan tunggu sebentar atau ketik \e[32mskip\e[0m untuk melewati validasi DNS jika Anda yakin IP $VPS_IP sudah benar."
            
            while true; do
                read -p "Ketik 'skip' atau tekan [ENTER] untuk coba verifikasi lagi: " DNS_CONFIRM
                if [[ "$DNS_CONFIRM" == "skip" || "$DNS_CONFIRM" == "SKIP" ]]; then
                    echo -e "\e[33m[WARNING]\e[0m Validasi DNS dilewati secara paksa untuk domain bawaan: $DOMAIN"
                    break 2
                fi
                
                DOMAIN_IP=$(getent ahostsv4 "$DOMAIN" | awk '{ print $1 }' | head -n 1)
                if [ "$DOMAIN_IP" == "$VPS_IP" ]; then
                    echo -e "\e[32m[SUCCESS]\e[0m Domain bawaan valid! ($DOMAIN -> $VPS_IP)"
                    break 2
                else
                    echo -e "\e[31m[ERROR]\e[0m DNS belum terarah ke $VPS_IP (Resolusi saat ini: $DOMAIN_IP)."
                fi
            done
        fi
        break
    else
        echo -e "\e[31m[ERROR]\e[0m Pilihan tidak valid! Masukkan 1 atau 2.\n"
    fi
done


echo -e "\n[1/12] Memperbarui sistem & dependensi..."
export DEBIAN_FRONTEND=noninteractive
apt update && apt upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"


# PERUBAHAN: Menambahkan 'vnstat' ke daftar instalasi dependensi
apt install curl wget unzip uuid-runtime jq tzdata ufw cron gnupg2 gnupg python3 python3-flask python3-pip strongswan xl2tpd iptables dropbear openvpn cmake make gcc git net-tools vnstat sqlite3 -y
timedatectl set-timezone Asia/Jakarta


# PERUBAHAN: Memastikan daemon vnstat aktif dan berjalan
systemctl enable vnstat >/dev/null 2>&1
systemctl restart vnstat >/dev/null 2>&1


pip3 install pyTelegramBotAPI requests --break-system-packages 2>/dev/null || pip3 install pyTelegramBotAPI requests


echo -e "\n=> Menginstal Speedtest CLI Resmi Ookla..."
curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash
apt install speedtest -y
if [ $? -ne 0 ] || ! command -v speedtest &> /dev/null; then
    echo -e "\e[33m[WARNING]\e[0m Gagal menginstal speedtest via repository. Menggunakan unduhan binary langsung..."
    rm -f /etc/apt/sources.list.d/ookla_speedtest-cli.list
    apt update
    wget -qO /tmp/speedtest.tgz https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-x86_64.tgz
    if [ -f /tmp/speedtest.tgz ]; then
        tar -xzf /tmp/speedtest.tgz -C /usr/local/bin/ speedtest
        rm -f /tmp/speedtest.tgz
    fi
fi


mkdir -p /usr/local/etc/srpcom
mkdir -p /usr/local/bin/srpcom
mkdir -p /usr/local/etc/xray
mkdir -p /usr/local/etc/srpcom/panel


# SIMPAN VPS NAME SECARA PERMANEN
cat > /usr/local/etc/srpcom/env.conf << EOF
DOMAIN="$DOMAIN"
IP_ADD="$VPS_IP"
VPS_NAME="$VPS_NAME"
EOF


# SIMPAN CACHE LISENSI AWAL
cat > /usr/local/etc/srpcom/license.info << EOF
STATUS="ACTIVE"
EXP_DATE="$EXP_DATE_INIT"
EOF


touch /usr/local/etc/srpcom/extra_domains.txt


cat > /usr/local/etc/xray/bot_admin.conf << 'EOF'
BOT_TOKEN=""
ADMIN_ID=""
EOF


echo -e "\n[2/12] Optimasi Performa Server (BBR & Swap RAM)..."
if [ ! -f "/swapfile" ]; then
    echo "=> Membuat Swap Memory 2GB..."
    dd if=/dev/zero of=/swapfile bs=1M count=2048 status=none
    chmod 600 /swapfile
    mkswap /swapfile >/dev/null 2>&1
    swapon /swapfile
    if ! grep -q "/swapfile" /etc/fstab; then
        echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
    fi
fi


echo "=> Mengaktifkan TCP BBR..."
if ! grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf; then
    cat >> /etc/sysctl.conf << EOF


# Optimasi TCP BBR & Network
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
    sysctl -p >/dev/null 2>&1
fi


echo -e "\n[3/12] Menginstal Xray-core..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
systemctl enable xray


echo -e "\n[4/12] Mengonfigurasi Xray Core (Limit & Kuota Enabled)..."
mkdir -p /var/log/xray
touch /var/log/xray/access.log
touch /var/log/xray/error.log
chown -R nobody:nogroup /var/log/xray
chmod -R 777 /var/log/xray


cat > /usr/local/etc/xray/config.json << EOF
{
  "log": {"access": "/var/log/xray/access.log", "error": "/var/log/xray/error.log", "loglevel": "warning"},
  "api": {"services": ["StatsService", "LoggerService"], "tag": "api"},
  "stats": {},
  "policy": {"levels": {"0": {"statsUserUplink": true, "statsUserDownlink": true}}, "system": {"statsInboundUplink": true, "statsInboundDownlink": true}},
  "inbounds": [
    {"port": 10001, "listen": "127.0.0.1", "protocol": "vmess", "settings": {"clients": []}, "streamSettings": {"network": "ws", "sockopt": {"acceptProxyProtocol": true}, "wsSettings": {"path": "/vmessws"}}},
    {"port": 10002, "listen": "127.0.0.1", "protocol": "vless", "settings": {"clients": [], "decryption": "none"}, "streamSettings": {"network": "ws", "sockopt": {"acceptProxyProtocol": true}, "wsSettings": {"path": "/vlessws"}}},
    {"port": 10003, "listen": "127.0.0.1", "protocol": "trojan", "settings": {"clients": []}, "streamSettings": {"network": "ws", "sockopt": {"acceptProxyProtocol": true}, "wsSettings": {"path": "/trojanws"}}},
    {"port": 10005, "listen": "127.0.0.1", "protocol": "vmess", "settings": {"clients": []}, "streamSettings": {"network": "grpc", "sockopt": {"acceptProxyProtocol": true}, "grpcSettings": {"serviceName": "vmessgrpc"}}},
    {"port": 10006, "listen": "127.0.0.1", "protocol": "vless", "settings": {"clients": [], "decryption": "none"}, "streamSettings": {"network": "grpc", "sockopt": {"acceptProxyProtocol": true}, "grpcSettings": {"serviceName": "vlessgrpc"}}},
    {"port": 10007, "listen": "127.0.0.1", "protocol": "trojan", "settings": {"clients": []}, "streamSettings": {"network": "grpc", "sockopt": {"acceptProxyProtocol": true}, "grpcSettings": {"serviceName": "trojangrpc"}}},
    {"port": 10085, "listen": "127.0.0.1", "protocol": "dokodemo-door", "settings": {"address": "127.0.0.1"}, "tag": "api"}
  ],
  "outbounds": [{"protocol": "freedom"}],
  "routing": {"rules": [{"inboundTag": ["api"], "outboundTag": "api", "type": "field"}]}
}
EOF
touch /usr/local/etc/xray/expiry.txt
touch /usr/local/etc/xray/limit.txt
cat > /usr/local/etc/xray/bot_setting.conf << 'EOF'
BOT_TOKEN=""
CHAT_ID=""
AUTOBACKUP_STATUS="OFF"
BACKUP_TIME="24"
AUTOSEND_STATUS="OFF"
EOF


# KONFIGURASI DEFAULT API
echo "SANGATRAHASIA123" > /usr/local/etc/xray/api_key.conf
echo "OFF" > /usr/local/etc/xray/api_auth.conf


echo -e "\n[5/12] Mengonfigurasi L2TP & IPsec..."
mkdir -p /etc/xl2tpd
mkdir -p /etc/ppp
cat > /etc/ipsec.conf << EOF
config setup
    charondebug="ike 1, knl 1, cfg 0"
    uniqueids=no
conn L2TP-PSK-NAT
    rightsubnet=vhost:%priv
    also=L2TP-PSK-noNAT
conn L2TP-PSK-noNAT
    authby=secret
    pfs=no
    auto=add
    keyingtries=3
    rekey=no
    ikelifetime=8h
    keylife=1h
    type=transport
    left=%defaultroute
    leftid=%any
    leftprotoport=17/1701
    right=%any
    rightid=%any
    rightprotoport=17/%any
    dpddelay=40
    dpdtimeout=130
    dpdaction=clear
    keyexchange=ikev1
    ike=3des-sha1-modp1024,aes256-sha1-modp1024,aes128-sha1-modp1024!
    esp=3des-sha1,aes256-sha1,aes128-sha1!
EOF
echo "%any %any : PSK \"srpcom_vpn\"" > /etc/ipsec.secrets
cat > /etc/xl2tpd/xl2tpd.conf << EOF
[global]
port = 1701
[lns default]
ip range = 192.168.42.10-192.168.42.250
local ip = 192.168.42.1
require chap = yes
refuse pap = yes
require authentication = yes
name = l2tpd
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes
EOF
cat > /etc/ppp/options.xl2tpd << EOF
ipcp-accept-local
ipcp-accept-remote
ms-dns 8.8.8.8
ms-dns 8.8.4.4
noccp
auth
idle 1800
mtu 1410
mru 1410
nodefaultroute
debug
proxyarp
connect-delay 5000
require-mschap-v2
refuse-eap
refuse-pap
refuse-chap
refuse-mschap
EOF
touch /usr/local/etc/srpcom/l2tp_expiry.txt
systemctl enable ipsec xl2tpd


echo -e "\n[6/12] Mengonfigurasi SSH, Dropbear, SSH-WS, BadVPN & OpenVPN..."
# Setup Default Banner srpcom
cat > /etc/issue.net << EOF
<font color="#00FF00">======================================</font><br>
<font color="#00FFFF"><b>WELCOME TO SRPCOM SCRIPT</b></font><br>
<font color="#00FFFF"><b>dev : t.me/srpcomadmin</b></font><br>
<font color="#00FF00">======================================</font><br>
<font color="#00FFFF"><b>Server : $DOMAIN</b></font><br>
<font color="#FFFF00"><b>PERINGATAN PENGGUNAAN SERVER:</b></font><br>
<font color="#FFFFFF">Dilarang keras menggunakan layanan ini untuk:</font><br>
<font color="#FF0000">✖ Carding & Fraud</font><br>
<font color="#FF0000">✖ Hacking & DDOS</font><br>
<font color="#FF0000">✖ Spamming & Torrent</font><br>
<font color="#FF9900"><b>Jika melanggar, akun akan di-BANNED permanen!</b></font><br>
<font color="#00FF00">======================================</font><br>
EOF

if grep -q "^Banner" /etc/ssh/sshd_config 2>/dev/null; then
    sed -i 's|^Banner.*|Banner /etc/issue.net|g' /etc/ssh/sshd_config
elif grep -q "^#Banner" /etc/ssh/sshd_config 2>/dev/null; then
    sed -i 's|^#Banner.*|Banner /etc/issue.net|g' /etc/ssh/sshd_config
else
    echo "Banner /etc/issue.net" >> /etc/ssh/sshd_config
fi
systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null

cat > /etc/default/dropbear << 'EOF'
NO_START=0
DROPBEAR_PORT=109
DROPBEAR_EXTRA_ARGS="-p 143"
DROPBEAR_BANNER="/etc/issue.net"
DROPBEAR_RECEIVE_WINDOW=65536
EOF
systemctl stop dropbear.socket >/dev/null 2>&1
systemctl disable dropbear.socket >/dev/null 2>&1
systemctl restart dropbear
systemctl enable dropbear


cat > /usr/local/bin/ssh-ws.py << 'EOF'
import socket, threading, sys
def handle_client(client_socket):
    try:
        req = client_socket.recv(4096).decode('utf-8')
        if not req: return
        response = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n"
        client_socket.send(response.encode())
        ssh_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        ssh_socket.connect(('127.0.0.1', 22))
        def forward(src, dst):
            try:
                while True:
                    data = src.recv(4096)
                    if not data: break
                    dst.send(data)
            except: pass
            finally:
                src.close(); dst.close()
        threading.Thread(target=forward, args=(client_socket, ssh_socket)).start()
        threading.Thread(target=forward, args=(ssh_socket, client_socket)).start()
    except: client_socket.close()
def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('127.0.0.1', 10004))
    server.listen(100)
    while True:
        client, addr = server.accept()
        threading.Thread(target=handle_client, args=(client,)).start()
if __name__ == '__main__': main()
EOF
cat > /etc/systemd/system/ssh-ws.service << EOF
[Unit]
Description=SSH WebSocket Proxy Service
After=network.target
[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/ssh-ws.py
Restart=always
User=root
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable ssh-ws
systemctl start ssh-ws


touch /usr/local/etc/srpcom/ssh_expiry.txt
touch /usr/local/etc/srpcom/ssh_limit.txt


echo -e "Membuat layanan BadVPN (UDP Custom)..."
systemctl stop badvpn-7100 badvpn-7200 badvpn-7300 >/dev/null 2>&1
rm -f /usr/local/bin/badvpn-udpgw
git clone https://github.com/ambrop72/badvpn.git /tmp/badvpn >/dev/null 2>&1
mkdir -p /tmp/badvpn/build
(
    cd /tmp/badvpn/build
    cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 >/dev/null 2>&1
    make >/dev/null 2>&1
    cp udpgw/badvpn-udpgw /usr/local/bin/
)


for port in 7100 7200 7300; do
cat > /etc/systemd/system/badvpn-$port.service << EOF
[Unit]
Description=BadVPN UDPGW Service Port $port
After=network.target


[Service]
ExecStart=/usr/local/bin/badvpn-udpgw --listen-addr 127.0.0.1:$port --max-clients 500
User=root
Restart=always


[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable badvpn-$port
systemctl start badvpn-$port
done


echo -e "Menyiapkan OpenVPN dan Sertifikatnya..."
mkdir -p /etc/openvpn/server/keys
cd /etc/openvpn/server/keys
openssl ecparam -genkey -name prime256v1 -out ca.key
openssl req -new -x509 -days 3650 -key ca.key -out ca.crt -subj "/CN=SRPCOM_CA"
openssl ecparam -genkey -name prime256v1 -out server.key
openssl req -new -key server.key -out server.csr -subj "/CN=SRPCOM_Server"
openssl x509 -req -days 3650 -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt


# PERBAIKAN: Menambahkan --secret agar ta.key berhasil dibuat tanpa error
openvpn --genkey --secret ta.key


# PERBAIKAN: Mempercepat pencarian plugin PAM agar instalasi tidak terkesan macet/hang
PAM_PLUGIN=$(find /usr/lib -name "openvpn-plugin-auth-pam.so" | head -n 1)
if [ -z "$PAM_PLUGIN" ]; then
    PAM_PLUGIN="/usr/lib/x86_64-linux-gnu/openvpn/plugins/openvpn-plugin-auth-pam.so"
fi


cat > /etc/openvpn/server/server-udp.conf << EOF
port 2200
proto udp
dev tun
ca keys/ca.crt
cert keys/server.crt
key keys/server.key
dh none
ecdh-curve prime256v1
tls-auth keys/ta.key 0
server 10.8.0.0 255.255.255.0
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
cipher AES-256-GCM
persist-key
persist-tun
status openvpn-udp.log
verb 3
plugin $PAM_PLUGIN login
verify-client-cert none
username-as-common-name
EOF


cat > /etc/openvpn/server/server-tcp.conf << EOF
port 1194
proto tcp
dev tun
ca keys/ca.crt
cert keys/server.crt
key keys/server.key
dh none
ecdh-curve prime256v1
tls-auth keys/ta.key 0
server 10.9.0.0 255.255.255.0
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
cipher AES-256-GCM
persist-key
persist-tun
status openvpn-tcp.log
verb 3
plugin $PAM_PLUGIN login
verify-client-cert none
username-as-common-name
EOF
systemctl enable openvpn-server@server-udp
systemctl enable openvpn-server@server-tcp
systemctl start openvpn-server@server-udp
systemctl start openvpn-server@server-tcp


mkdir -p /usr/local/etc/srpcom/ovpn
CA_CERT=$(cat /etc/openvpn/server/keys/ca.crt)
TA_CERT=$(cat /etc/openvpn/server/keys/ta.key)


cat > /usr/local/etc/srpcom/ovpn/udp.ovpn << EOF
client
dev tun
proto udp
remote $DOMAIN 2200
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
auth-user-pass
key-direction 1
<ca>
$CA_CERT
</ca>
<tls-auth>
$TA_CERT
</tls-auth>
EOF


cat > /usr/local/etc/srpcom/ovpn/tcp.ovpn << EOF
client
dev tun
proto tcp
remote $DOMAIN 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
auth-user-pass
key-direction 1
<ca>
$CA_CERT
</ca>
<tls-auth>
$TA_CERT
</tls-auth>
EOF


echo -e "\n[7/12] Mendownload Modul Sistem dari GitHub..."
download_file /usr/local/bin/srpcom/utils.sh core/utils.sh
download_file /usr/local/bin/srpcom/telegram.sh core/telegram.sh
download_file /usr/local/bin/srpcom/xray.sh core/xray.sh
download_file /usr/local/bin/srpcom/l2tp.sh core/l2tp.sh
download_file /usr/local/bin/srpcom/ssh.sh core/ssh.sh
download_file /usr/local/bin/srpcom/monitor.sh core/monitor.sh
download_file /usr/local/bin/srpcom/autokill.sh core/autokill.sh
download_file /usr/local/bin/srpcom/menu.sh core/menu.sh
download_file /usr/local/bin/srpcom/auto_expired.sh core/auto_expired.sh
download_file /usr/local/bin/srpcom/db_helper.sh core/db_helper.sh
download_file /usr/local/bin/xray-api.py configs/xray-api.py
download_file /usr/local/bin/bot-admin.py configs/bot-admin.py


# FIX: Hapus karakter DOS (Carriage Return / \r) akibat edit file di Windows
sed -i 's/\r$//' /usr/local/bin/srpcom/*.sh 2>/dev/null
sed -i 's/\r$//' /usr/local/bin/xray-api.py 2>/dev/null
sed -i 's/\r$//' /usr/local/bin/bot-admin.py 2>/dev/null


chmod +x /usr/local/bin/srpcom/*.sh
chmod +x /usr/local/bin/xray-api.py
chmod +x /usr/local/bin/bot-admin.py


echo -e "\n[8/12] Mengonfigurasi Layanan API & Bot Admin..."
cat > /etc/systemd/system/xray-api.service << EOF
[Unit]
Description=Xray Python API Backend
After=network.target
[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/xray-api.py
Restart=always
User=root
Environment=PYTHONUNBUFFERED=1
[Install]
WantedBy=multi-user.target
EOF


cat > /etc/systemd/system/srpcom-bot.service << EOF
[Unit]
Description=Telegram Admin Interactive Bot
After=network.target xray-api.service
[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/bot-admin.py
Restart=always
RestartSec=5
User=root
Environment=PYTHONUNBUFFERED=1
[Install]
WantedBy=multi-user.target
EOF


systemctl daemon-reload
systemctl enable xray-api
systemctl start xray-api
systemctl disable srpcom-bot >/dev/null 2>&1


echo -e "\n[9/12] Mengonfigurasi Firewall (UFW & Iptables NAT L2TP/OVPN)..."
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 109/tcp
ufw allow 143/tcp
ufw allow 443/tcp
ufw allow 500/udp
ufw allow 4500/udp
ufw allow 1701/udp
ufw allow 1194/tcp
ufw allow 2200/udp
ufw allow 7100/udp
ufw allow 7200/udp
ufw allow 7300/udp
ufw --force enable


ETH=$(ip route ls | grep default | awk '{print $5}' | head -n 1)
cat > /etc/systemd/system/vpn-nat.service << EOF
[Unit]
Description=VPN NAT IPTables Rules (L2TP & OVPN)
After=network.target ufw.service
[Service]
Type=oneshot
ExecStart=/sbin/iptables -t nat -A POSTROUTING -s 192.168.42.0/24 -o $ETH -j MASQUERADE
ExecStart=/sbin/iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o $ETH -j MASQUERADE
ExecStart=/sbin/iptables -t nat -A POSTROUTING -s 10.9.0.0/24 -o $ETH -j MASQUERADE
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable vpn-nat
systemctl start vpn-nat
sed -i '/net.ipv4.ip_forward/s/^#//g' /etc/sysctl.conf
sysctl -p


echo -e "\n[10/12] Mendownload WEB PANEL & DOKUMENTASI API..."
download_file /usr/local/etc/srpcom/panel/index.html core/index.html
download_file /usr/local/etc/srpcom/panel/api-docs.html core/api-docs.html
if [ ! -s "/usr/local/etc/srpcom/panel/index.html" ] || grep -q "Too Many Requests" /usr/local/etc/srpcom/panel/index.html 2>/dev/null; then
    echo -e "\e[33m[WARNING]\e[0m Gagal mengunduh index.html Web Panel. Akan dibuat template dasar."
    echo "<h1>Web Panel Sedang Maintenance</h1>" > /usr/local/etc/srpcom/panel/index.html
fi


echo -e "\n[11/12] Menginstal & Mengonfigurasi Caddy..."
apt install -y apt-transport-https curl gnupg
mkdir -p /etc/apt/keyrings
curl -fsSL 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor --yes -o /etc/apt/keyrings/caddy-stable-archive-keyring.gpg
chmod 644 /etc/apt/keyrings/caddy-stable-archive-keyring.gpg
curl -fsSL 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sed 's|/usr/share/keyrings/caddy-stable-archive-keyring.gpg|/etc/apt/keyrings/caddy-stable-archive-keyring.gpg|g' | tee /etc/apt/sources.list.d/caddy-stable.list
chmod 644 /etc/apt/sources.list.d/caddy-stable.list
apt update && apt install caddy -y


# PERBAIKAN: Menghapus support.zoom.us dari string domain default agar tidak crash
DOMAINS_STR="http://$DOMAIN, https://$DOMAIN"


cat > /etc/caddy/Caddyfile << EOF
{
    servers {
        trusted_proxies static 173.245.48.0/20 103.21.244.0/22 103.22.200.0/22 103.31.4.0/22 141.101.64.0/18 108.162.192.0/18 190.93.240.0/20 188.114.96.0/20 197.234.240.0/22 198.41.128.0/17 162.158.0.0/15 104.16.0.0/13 104.24.0.0/14 172.64.0.0/13 131.0.72.0/22
    }
}

$DOMAINS_STR {
    handle /srpcom/* {
        reverse_proxy localhost:5000
    }
    handle /ovpn/* {
        root * /usr/local/etc/srpcom
        file_server
    }
    handle /panel/* {
        root * /usr/local/etc/srpcom
        file_server
    }
    redir /panel /panel/
    
    handle / {
        respond "Server is running normally." 200
    }
    handle /vmessws* {
        reverse_proxy localhost:10001 {
            transport http {
                proxy_protocol v2
            }
        }
    }
    handle /vlessws* {
        reverse_proxy localhost:10002 {
            transport http {
                proxy_protocol v2
            }
        }
    }
    handle /trojanws* {
        reverse_proxy localhost:10003 {
            transport http {
                proxy_protocol v2
            }
        }
    }
    handle /vmessgrpc/* {
        reverse_proxy localhost:10005 {
            transport http {
                versions h2c
                proxy_protocol v2
            }
        }
    }
    handle /vlessgrpc/* {
        reverse_proxy localhost:10006 {
            transport http {
                versions h2c
                proxy_protocol v2
            }
        }
    }
    handle /trojangrpc/* {
        reverse_proxy localhost:10007 {
            transport http {
                versions h2c
                proxy_protocol v2
            }
        }
    }
    handle /sshws* {
        reverse_proxy localhost:10004
    }
}
EOF


echo -e "\n[12/12] Setup Cronjob Selesai..."
if ! grep -q "menu" /root/.profile; then echo "menu" >> /root/.profile; fi


echo "0 * * * * root /usr/local/bin/srpcom/auto_expired.sh >/dev/null 2>&1" > /etc/cron.d/auto_expired


# ==========================================
# AUTO IMPORT EXTRA DOMAIN & BUG MURNI FROM GITHUB
# ==========================================
echo -e "\n=> Melakukan Import Bug/SNI & Subdomain dari GitHub..."
TEMP_DOMAINS="/tmp/extra_domains_raw.txt"
TARGET_DOMAINS="/usr/local/etc/srpcom/extra_domains.txt"
touch "$TARGET_DOMAINS"

download_file "$TEMP_DOMAINS" core/extra_domains.txt
if [ -s "$TEMP_DOMAINS" ]; then
    # 1. Jalankan Import Wildcard (WC) dengan Validasi IP
    while read -r raw_domain; do
        raw_domain=$(echo "$raw_domain" | tr -d '\r' | xargs)
        if [[ -z "$raw_domain" || "$raw_domain" == \#* ]]; then continue; fi
        
        domain_ip=$(getent ahostsv4 "$raw_domain" | awk '{ print $1 }' | head -n 1)
        if [[ "$domain_ip" == "$VPS_IP" ]]; then
            echo "$raw_domain" >> "$TARGET_DOMAINS"
        else
            clean_input=${raw_domain%.$DOMAIN}
            full_domain="${clean_input}.${DOMAIN}"
            domain_ip=$(getent ahostsv4 "$full_domain" | awk '{ print $1 }' | head -n 1)
            if [[ "$domain_ip" == "$VPS_IP" ]]; then
                echo "$full_domain" >> "$TARGET_DOMAINS"
            fi
        fi
    done < "$TEMP_DOMAINS"

    # 2. Jalankan Import Bug Murni (Tanpa Validasi IP)
    while read -r raw_domain; do
        raw_domain=$(echo "$raw_domain" | tr -d '\r' | xargs)
        if [[ -z "$raw_domain" || "$raw_domain" == \#* ]]; then continue; fi
        echo "$raw_domain" >> "$TARGET_DOMAINS"
    done < "$TEMP_DOMAINS"

    # Hapus duplikat secara aman
    if [ -f "$TARGET_DOMAINS" ]; then
        sort -u "$TARGET_DOMAINS" -o "$TARGET_DOMAINS"
    fi
    rm -f "$TEMP_DOMAINS"
    echo -e "=> Import selesai: $(wc -l < "$TARGET_DOMAINS" 2>/dev/null || echo 0) domain/bug berhasil dimuat."
else
    echo -e "\e[33m[WARNING]\e[0m Gagal mengunduh daftar bug dari GitHub."
fi

# ==========================================
# REBUILD SHORTCUTS & CADDYFILE
# ==========================================
chmod +x /usr/local/bin/srpcom/menu.sh
chmod +x /usr/local/bin/srpcom/db_helper.sh
/usr/local/bin/srpcom/db_helper.sh db_import_from_txt 2>/dev/null
source /usr/local/bin/srpcom/menu.sh
rebuild_shortcuts
rebuild_caddyfile
# ==========================================


systemctl restart xray caddy cron xray-api ipsec xl2tpd dropbear ssh-ws


clear
echo "======================================================"
echo "    INSTALASI SELESAI & BERHASIL! (V5 FINAL)          "
echo "======================================================"
echo "Protokol: VMESS, VLESS, TROJAN, L2TP, SSH, OVPN, UDPGW"
echo "Optimasi: TCP BBR & Swap RAM 2GB Aktif!"
echo "Default Domain: $DOMAIN"
echo "Bug/SNI Tambahan: Bisa diatur di Menu -> 5 -> 10"
echo "------------------------------------------------------"
echo -e "\e[36m[ AKSES SISTEM ]\e[0m"
echo "1. Akses Terminal (CLI) : Ketik 'menu'"
echo "2. Akses Web Panel GUI  : https://${DOMAIN}/panel/"
echo "   Password Web Panel   : SANGATRAHASIA123"
echo "------------------------------------------------------"
echo "Untuk menjadikan VPS ini sebagai MASTER BOT, masuk ke menu:"
echo "-> [5] Settings -> [9] Setting Telegram Admin Bot -> Mulai Bot"
echo "Untuk menghubungkan Node lain, gunakan API Key Default:"
echo "SANGATRAHASIA123 (Ubah di menu 5 -> 5 jika perlu)"
echo "======================================================"


echo -e "\n\e[33mTekan [ENTER] untuk menyelesaikan instalasi dan keluar dari terminal...\e[0m"
read -p ""


# ==========================================
# AUTO DELETE SCRIPT (MEMBERSIHKAN JEJAK)
# ==========================================
if [[ -f "$0" ]]; then
    rm -f "$0"
fi
rm -f /root/install.sh /root/install

