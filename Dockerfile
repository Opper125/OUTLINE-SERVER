FROM quay.io/outline/shadowbox:stable

# (၁) ပိတ်ထားတဲ့ ENTRYPOINT ကို လုံးဝ ဖြုတ်ချခြင်း
ENTRYPOINT []

# (၂) လိုအပ်တဲ့ ဖိုင်တွဲများအားလုံးကို Build လုပ်ကတည်းက ကြိုဆောက်ထားခြင်း
RUN mkdir -p /root/shadowbox/persisted-state/prometheus/data

# (၃) Prometheus အတွက် မရှိမဖြစ်လိုအပ်တဲ့ config.yml ကို ဖန်တီးပေးခြင်း
RUN echo "global:\n  scrape_interval: 15s\nscrape_configs:\n  - job_name: 'prometheus'\n    static_configs:\n      - targets: ['localhost:9090']" > /root/shadowbox/persisted-state/prometheus/config.yml

# (၄) Render မှာ Env ထဲ သွားထည့်စရာမလိုအောင် Docker ထဲမှာတင် အသေ သတ်မှတ်ပေးခြင်း (နာမည်မှန် ပြင်ထားသည်)
ENV SB_PUBLIC_IP=0.0.0.0
ENV SB_API_PORT=7085
ENV ROOT_DIR=/root/shadowbox
ENV SB_CERT_FILE=/root/shadowbox/persisted-state/shadowbox_server_certificates.json

# (၅) မရှိမဖြစ်လိုအပ်တဲ့ Config ဖိုင်ကော၊ Certificate ဖိုင်ကိုကော ကြိုဆောက်ပြီးမှ Node.js ကို မောင်းနှင်ခြင်း
CMD ["sh", "-c", "echo '{\"id\":\"render-outline\",\"key\":[1,2,3]}' > /root/shadowbox/persisted-state/shadowbox_server_config.json && echo '{\"cert\":\"test\",\"key\":\"test\"}' > /root/shadowbox/persisted-state/shadowbox_server_certificates.json && node /opt/outline-server/app/main.js"]
