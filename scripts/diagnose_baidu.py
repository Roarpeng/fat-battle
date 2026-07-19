"""
诊断百度API权限问题
逐一测试各个识别接口，查看哪些有权限，哪些没有
"""
import requests
import base64
import os
from dotenv import load_dotenv

load_dotenv(r"c:\Users\roarp\Desktop\TMP\Code\AICode\fat-battle\web\.env")

BAIDU_API_KEY = os.getenv("BAIDU_API_KEY", "")
BAIDU_SECRET_KEY = os.getenv("BAIDU_SECRET_KEY", "")
IMAGE_PATH = r"C:\Users\roarp\Downloads\R.jpg"

# 读取图片
with open(IMAGE_PATH, "rb") as f:
    image_bytes = f.read()
image_b64 = base64.b64encode(image_bytes).decode("utf-8")

print(f"API Key: {BAIDU_API_KEY}")
print(f"Secret Key: {BAIDU_SECRET_KEY}")
print(f"图片大小: {len(image_bytes)} bytes")
print()

# 获取token
url = "https://aip.baidubce.com/oauth/2.0/token"
params = {
    "grant_type": "client_credentials",
    "client_id": BAIDU_API_KEY,
    "client_secret": BAIDU_SECRET_KEY,
}
resp = requests.post(url, params=params, timeout=10)
token_data = resp.json()
token = token_data.get("access_token")
print(f"Token: {token[:30]}...")
print(f"Token权限范围(scope): {token_data.get('scope', '未返回')}")
print()

# 测试所有可能的识别接口
apis = [
    ("菜品识别", "https://aip.baidubce.com/rest/2.0/image-classify/v2/dish", "form"),
    ("果蔬识别", "https://aip.baidubce.com/rest/2.0/image-classify/v1/classify/ingredient", "form"),
    ("植物识别", "https://aip.baidubce.com/rest/2.0/image-classify/v1/plant", "form"),
    ("动物识别", "https://aip.baidubce.com/rest/2.0/image-classify/v1/animal", "form"),
    ("logo识别", "https://aip.baidubce.com/rest/2.0/image-classify/v2/logo", "form"),
    ("通用物体识别", "https://aip.baidubce.com/rest/2.0/image-classify/v2/advanced_general", "form"),
    ("组合服务", "https://aip.baidubce.com/api/v1/solution/direct/imagerecognition/combination", "json"),
]

for name, api_url, req_type in apis:
    print(f"--- {name} ---")
    full_url = f"{api_url}?access_token={token}"
    try:
        if req_type == "form":
            resp = requests.post(full_url, data={"image": image_b64, "top_num": "5"}, timeout=15)
        else:
            resp = requests.post(full_url, json={"image": image_b64, "scenes": ["ingredient", "plant", "animal"]}, timeout=15)
        result = resp.json()
        if "error_code" in result:
            print(f"  ❌ 错误: {result.get('error_code')} - {result.get('error_msg')}")
        else:
            result_items = result.get("result", [])
            print(f"  ✅ 成功，返回 {len(result_items)} 个结果")
            for i, item in enumerate(result_items[:3], 1):
                if isinstance(item, dict):
                    name_val = item.get("name", "")
                    score = item.get("probability", item.get("score", ""))
                    print(f"     {i}. {name_val} (分数:{score})")
    except Exception as e:
        print(f"  ❌ 异常: {e}")
    print()
