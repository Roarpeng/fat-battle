"""对比测试：APP拍的照片 vs 后端识别结果"""
import requests
import base64
import os
from PIL import Image

IMAGE_PATH = r"c:\Users\roarp\Desktop\TMP\Code\AICode\fat-battle\scripts\app_photo.jpg"

# 读取图片
with open(IMAGE_PATH, "rb") as f:
    image_bytes = f.read()
image_b64 = base64.b64encode(image_bytes).decode("utf-8")

img = Image.open(IMAGE_PATH)
print("=" * 60)
print("APP拍摄照片信息")
print("=" * 60)
print(f"文件大小: {len(image_bytes)} 字节 ({len(image_bytes)/1024:.1f} KB)")
print(f"尺寸: {img.size}")
print(f"模式: {img.mode}")
print()

# 1. 测试后端代理接口
print("=" * 60)
print("【测试1】后端 /api/food-recognize (新 recognizeFood)")
print("=" * 60)
resp = requests.post(
    "http://localhost:7860/api/food-recognize",
    json={"image": image_b64, "topNum": 8, "filterThreshold": 0.5},
    timeout=30,
)
result = resp.json()
print(f"来源: {result.get('source')}")
print(f"返回结果数: {len(result.get('items', []))}")
for i, item in enumerate(result.get("items", []), 1):
    name = item.get("name", "")
    prob = item.get("probability", "")
    calorie = item.get("calorie", "")
    src = item.get("source", "")
    print(f"  {i}. {name} (置信度:{prob}, 卡路里:{calorie}, 类型:{src})")
print()

# 2. 直接测试百度菜品识别
API_KEY = "DjbfF71WlxtwLcYuedPrmzM8"
SECRET_KEY = "5tw6jUMhciBm7ZVzOPAKuuWCk38sIzln"

print("正在获取百度 token...")
token_resp = requests.post(
    "https://aip.baidubce.com/oauth/2.0/token",
    params={
        "grant_type": "client_credentials",
        "client_id": API_KEY,
        "client_secret": SECRET_KEY,
    },
    timeout=10,
)
token = token_resp.json().get("access_token", "")
print()

# 菜品识别
print("=" * 60)
print("【测试2】百度菜品识别 (直接调用)")
print("=" * 60)
dish_resp = requests.post(
    f"https://aip.baidubce.com/rest/2.0/image-classify/v2/dish?access_token={token}",
    data={"image": image_b64, "top_num": "8", "filter_threshold": "0.5"},
    timeout=15,
)
dish_data = dish_resp.json()
dishes = dish_data.get("result", [])
print(f"返回结果数: {len(dishes)}")
for i, d in enumerate(dishes, 1):
    name = d.get("name", "")
    prob = d.get("probability", "")
    cal = d.get("calorie", "")
    has_cal = d.get("has_calorie", "")
    print(f"  {i}. {name} (置信度:{prob}, 卡路里:{cal}, 有卡路里:{has_cal})")
print()

# 果蔬识别
print("=" * 60)
print("【测试3】百度果蔬识别 (直接调用)")
print("=" * 60)
ing_resp = requests.post(
    f"https://aip.baidubce.com/rest/2.0/image-classify/v1/classify/ingredient?access_token={token}",
    data={"image": image_b64, "top_num": "8"},
    timeout=15,
)
ing_data = ing_resp.json()
ings = ing_data.get("result", [])
print(f"返回结果数: {len(ings)}")
for i, d in enumerate(ings, 1):
    name = d.get("name", "")
    prob = d.get("probability", "")
    cal = d.get("calorie", "")
    print(f"  {i}. {name} (置信度:{prob}, 卡路里:{cal})")
print()

# 植物识别
print("=" * 60)
print("【测试4】百度植物识别 (直接调用)")
print("=" * 60)
plant_resp = requests.post(
    f"https://aip.baidubce.com/rest/2.0/image-classify/v1/plant?access_token={token}",
    data={"image": image_b64, "top_num": "5"},
    timeout=15,
)
plant_data = plant_resp.json()
plants = plant_data.get("result", [])
print(f"返回结果数: {len(plants)}")
for i, d in enumerate(plants, 1):
    name = d.get("name", "")
    score = d.get("score", "")
    print(f"  {i}. {name} (分数:{score})")
print()

# 动物识别
print("=" * 60)
print("【测试5】百度动物识别 (直接调用)")
print("=" * 60)
animal_resp = requests.post(
    f"https://aip.baidubce.com/rest/2.0/image-classify/v1/animal?access_token={token}",
    data={"image": image_b64, "top_num": "5"},
    timeout=15,
)
animal_data = animal_resp.json()
animals = animal_data.get("result", [])
print(f"返回结果数: {len(animals)}")
for i, d in enumerate(animals, 1):
    name = d.get("name", "")
    score = d.get("score", "")
    print(f"  {i}. {name} (分数:{score})")
print()
