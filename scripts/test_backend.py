"""通过后端代理测试新API Key"""
import requests
import base64

with open(r"C:\Users\roarp\Downloads\R.jpg", "rb") as f:
    image_b64 = base64.b64encode(f.read()).decode("utf-8")

print("=== 测试后端 /api/food-recognize 接口 ===")
resp = requests.post(
    "http://localhost:7860/api/food-recognize",
    json={"image": image_b64},
    timeout=30,
)
print(f"HTTP状态: {resp.status_code}")
result = resp.json()
print(f"返回结果: {result}")
