"""测试优化后的后端识别效果"""
import requests
import base64

IMAGE_PATH = r"c:\Users\roarp\Desktop\TMP\Code\AICode\fat-battle\scripts\app_photo.jpg"

with open(IMAGE_PATH, "rb") as f:
    image_b64 = base64.b64encode(f.read()).decode("utf-8")

print("=== 测试优化后的后端 /api/food-recognize ===")
resp = requests.post(
    "http://localhost:7860/api/food-recognize",
    json={"image": image_b64, "topNum": 15, "filterThreshold": 0.1},
    timeout=60,
)
result = resp.json()
print(f"来源: {result.get('source')}")
print(f"返回结果数: {len(result.get('items', []))}")
print()
for i, item in enumerate(result.get("items", []), 1):
    name = item.get("name", "")
    prob = item.get("probability", "")
    calorie = item.get("calorie", "")
    src = item.get("source", "")
    variant = item.get("variant", "")
    print(f"  {i:2d}. {name:15s}  置信度:{prob:.6f}  卡路里:{calorie:>5s}  类型:{src}  变体:{variant}")
