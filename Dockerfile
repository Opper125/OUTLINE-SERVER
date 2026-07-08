FROM quay.io/outline/shadowbox:stable

# Render ပေါ်မှာ လိုအပ်တဲ့ ပတ်ဝန်းကျင်ဖိုင်တွဲကို အတင်းဆောက်ခိုင်းခြင်း
RUN mkdir -p /root/shadowbox/persisted-state

# မောင်းနှင်တဲ့အခါ Certificate မရှိတဲ့ပြဿနာကို ကျော်လွှားရန် အလိုအလျောက် config ထုတ်ပေးခြင်း
CMD ["sh", "-c", "echo '{\"id\":\"render-outline\",\"key\":[1,2,3]}' > /root/shadowbox/persisted-state/shadowbox_server_config.json && node /opt/outline-server/app/main.js"]
