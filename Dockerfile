FROM quay.io/outline/shadowbox:stable

# ပိတ်ထားတဲ့ ENTRYPOINT ကို ဖျက်ပစ်ခြင်း
ENTRYPOINT []

# လိုအပ်တဲ့ ဖိုင်တွဲများအားလုံးကို Build လုပ်ကတည်းက ကြိုဆောက်ထားခြင်း
RUN mkdir -p /root/shadowbox/persisted-state/prometheus/data

# Prometheus အတွက် မရှိမဖြစ်လိုအပ်တဲ့ config.yml ကို ကြိုတင်ဖန်တီးပေးခြင်း
RUN echo "global:\n  scrape_interval: 15s\nscrape_configs:\n  - job_name: 'prometheus'\n    static_configs:\n      - targets: ['localhost:9090']" > /root/shadowbox/persisted-state/prometheus/config.yml

# Render ပေါ်မှာ အလုပ်လုပ်မယ့် Environment Variables များကို Docker ထဲမှာတင် အသေ သတ်မှတ်ပေးခြင်း
ENV SB_PUBLIC_IP=0.0.0.0
ENV SB_API_PORT=7085
ENV ROOT_DIR=/root/shadowbox

# Config ဖိုင်ကို ဆောက်ပြီးမှ နောက်ကွယ်မှာ စနစ်အားလုံးကို အတင်း မောင်းနှင်ခိုင်းခြင်း
CMD ["sh", "-c", "echo '{\"id\":\"render-outline\",\"key\":[1,2,3]}' > /root/shadowbox/persisted-state/shadowbox_server_config.json && node /opt/outline-server/app/main.js"]
