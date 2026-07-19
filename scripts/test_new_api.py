"""用新API Key测试百度识别"""
import requests
import base64

API_KEY = "DjbfF71WlxtwLcYuedPrmzM8"
SECRET_KEY = "5tw6jUMhciBm7ZVzOPAKuuWCk38sIzln"

with open(r"C:\Users\roarp\Downloads\R.jpg", "rb") as f:
    image_b64 = base64.b64encode(f.read()).decode("utf-8")

print("=== 获取token ===")
resp = requests.post(
    "https://aip.baidubce.com/oauth/2.0/token",
    params={"grant_type": "client_credentials", "client_id": API_KEY, "client_secret": SECRET_KEY},
    timeout=10,
)
token_data = resp.json()
token = token_data.get("access_token")
scope = token_data.get("scope", "未返回")
print(f"Token scope: {scope}")
print()

apis = [
    ("菜品识别", "https://aip.baidubce.com/rest/2.0/image-classify/v2/dish"),
    ("果蔬识别", "https://aip.baidubce.com/rest/2.0/image-classify/v1/classify/ingredient"),
    ("植物识别", "https://aip.baidubce.com/rest/2.0/image-classify/v1/plant"),
    ("动物识别", "https://aip.baidubce.com/rest/2.0/image-classify/v1/animal"),
    ("通用物体识别", "https://aip.baidubce.com/rest/2.0/image-classify/v2/advanced_general"),
]

for name, url in apis:
    print(f"--- {name} ---")
    full_url = f"{url}?access_token={token}"
    resp = requests.post(full_url, data={"image": image_b64, "top_num": "5"}, timeout=15)
    result = resp.json()
    if "error_code" in result:
        print(f"  X 错误: {result.get('error_code')} - {result.get('error_msg')}")
    else:
        items = result.get("result", [])
        print(f"  OK 成功，返回 {len(items)} 个结果")
        for i, item in enumerate(items[:5], 1):
            n = item.get("name", "")
            s = item.get("probability", item.get("score", ""))
            c = item.get("calorie", "")
            print(f"    {i}. {n} (分数:{s}, 卡路里:{c})")
    print()
