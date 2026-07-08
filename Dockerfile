FROM quay.io/outline/shadowbox:stable

# ပိတ်ထားတဲ့ ENTRYPOINT ကို လုံးဝ ပယ်ဖျက်ပစ်ခြင်း (အရေးကြီးဆုံး)
ENTRYPOINT []

# လိုအပ်တဲ့ ပတ်ဝန်းကျင်ဖိုင်တွဲကို အတင်းဆောက်ခိုင်းခြင်း
RUN mkdir -p /root/shadowbox/persisted-state

# Config ဖိုင်ကို ဆောက်ပြီးမှ Outline ရဲ့ စနစ်နှစ်ခုလုံး (Shadowbox ကော Prometheus ပါ) ကို အတင်း မောင်းနှင်ခိုင်းခြင်း
CMD ["sh", "-c", "echo '{\"id\":\"render-outline\",\"key\":[1,2,3]}' > /root/shadowbox/persisted-state/shadowbox_server_config.json && /opt/outline-server/bin/prometheus --config.file=/root/shadowbox/persisted-state/prometheus/config.yml & node /opt/outline-server/app/main.js"]
