"""
测试百度食物识别API完整流程
菜品识别 + 果蔬识别 + 组合服务（果蔬+植物+动物）
"""
import requests
import base64
import json
import os
from dotenv import load_dotenv

# 加载环境变量
load_dotenv(r"c:\Users\roarp\Desktop\TMP\Code\AICode\fat-battle\web\.env")

BAIDU_API_KEY = os.getenv("BAIDU_API_KEY", "")
BAIDU_SECRET_KEY = os.getenv("BAIDU_SECRET_KEY", "")
IMAGE_PATH = r"C:\Users\roarp\Downloads\R.jpg"

print("=" * 60)
print("百度食物识别API测试")
print("=" * 60)
print(f"API Key: {BAIDU_API_KEY[:8]}..." if BAIDU_API_KEY else "API Key: 未配置")
print(f"Secret Key: {BAIDU_SECRET_KEY[:8]}..." if BAIDU_SECRET_KEY else "Secret Key: 未配置")
print(f"测试图片: {IMAGE_PATH}")

# 读取图片
with open(IMAGE_PATH, "rb") as f:
    image_bytes = f.read()
image_b64 = base64.b64encode(image_bytes).decode("utf-8")
print(f"图片大小: {len(image_bytes)} 字节")
print(f"Base64长度: {len(image_b64)}")
print()


def get_access_token():
    """获取百度access_token"""
    url = "https://aip.baidubce.com/oauth/2.0/token"
    params = {
        "grant_type": "client_credentials",
        "client_id": BAIDU_API_KEY,
        "client_secret": BAIDU_SECRET_KEY,
    }
    resp = requests.post(url, params=params, timeout=10)
    data = resp.json()
    if "access_token" not in data:
        print(f"获取token失败: {data}")
        return None
    return data["access_token"]


def test_dish_api(token, image_b64, top_num=5, filter_threshold=0.5):
    """测试菜品识别API"""
    print("-" * 60)
    print("【测试1】百度菜品识别 API")
    print("-" * 60)
    url = f"https://aip.baidubce.com/rest/2.0/image-classify/v2/dish?access_token={token}"
    data = {
        "image": image_b64,
        "top_num": top_num,
        "filter_threshold": filter_threshold,
    }
    resp = requests.post(url, data=data, timeout=15)
    result = resp.json()

    if "error_code" in result:
        print(f"API错误: {result.get('error_code')} - {result.get('error_msg')}")
        return []

    dishes = result.get("result", [])
    print(f"返回结果数: {len(dishes)}")
    for i, dish in enumerate(dishes, 1):
        name = dish.get("name", "")
        calorie = dish.get("calorie", "0")
        prob = dish.get("probability", "0")
        has_cal = dish.get("has_calorie", False)
        print(f"  {i}. {name} (概率:{prob}, 卡路里:{calorie}, 有卡路里:{has_cal})")
    print()
    return dishes


def test_ingredient_api(token, image_b64, top_num=5):
    """测试果蔬识别API"""
    print("-" * 60)
    print("【测试2】百度果蔬识别 API")
    print("-" * 60)
    url = f"https://aip.baidubce.com/rest/2.0/image-classify/v1/classify/ingredient?access_token={token}"
    data = {
        "image": image_b64,
        "top_num": str(top_num),
    }
    resp = requests.post(url, data=data, timeout=15)
    result = resp.json()

    if "error_code" in result:
        print(f"API错误: {result.get('error_code')} - {result.get('error_msg')}")
        return []

    dishes = result.get("result", [])
    print(f"返回结果数: {len(dishes)}")
    for i, dish in enumerate(dishes, 1):
        name = dish.get("name", "")
        calorie = dish.get("calorie", "0")
        prob = dish.get("probability", "0")
        print(f"  {i}. {name} (概率:{prob}, 卡路里:{calorie})")
    print()
    return dishes


def test_combination_api(token, image_b64):
    """测试组合服务API（果蔬+植物+动物）"""
    print("-" * 60)
    print("【测试3】百度组合服务 API (果蔬+植物+动物)")
    print("-" * 60)
    url = f"https://aip.baidubce.com/api/v1/solution/direct/imagerecognition/combination?access_token={token}"
    payload = {
        "image": image_b64,
        "scenes": ["ingredient", "plant", "animal"],
    }
    resp = requests.post(url, json=payload, timeout=15)
    result = resp.json()

    if "error_code" in result:
        print(f"API错误: {result.get('error_code')} - {result.get('error_msg')}")
        return []

    all_items = []
    result_data = result.get("result", {})

    # 解析果蔬
    ingredient = result_data.get("ingredient", {})
    if ingredient:
        ing_results = ingredient.get("result", [])
        print(f"果蔬识别结果: {len(ing_results)}个")
        for i, item in enumerate(ing_results, 1):
            name = item.get("name", "")
            score = item.get("score", 0)
            print(f"  {i}. {name} (分数:{score})")
            all_items.append({"name": name, "score": score, "source": "果蔬"})

    # 解析植物
    plant = result_data.get("plant", {})
    if plant:
        plant_results = plant.get("result", [])
        print(f"植物识别结果: {len(plant_results)}个")
        for i, item in enumerate(plant_results, 1):
            name = item.get("name", "")
            score = item.get("score", 0)
            print(f"  {i}. {name} (分数:{score})")
            all_items.append({"name": name, "score": score, "source": "植物"})

    # 解析动物
    animal = result_data.get("animal", {})
    if animal:
        animal_results = animal.get("result", [])
        print(f"动物识别结果: {len(animal_results)}个")
        for i, item in enumerate(animal_results, 1):
            name = item.get("name", "")
            score = item.get("score", 0)
            print(f"  {i}. {name} (分数:{score})")
            all_items.append({"name": name, "score": score, "source": "动物"})

    print()
    return all_items


def main():
    if not BAIDU_API_KEY or not BAIDU_SECRET_KEY:
        print("错误: 百度API凭据未配置")
        return

    # 1. 获取token
    print("正在获取 access_token...")
    token = get_access_token()
    if not token:
        print("获取token失败")
        return
    print(f"token获取成功: {token[:20]}...")
    print()

    # 2. 测试菜品识别
    dish_results = test_dish_api(token, image_b64, top_num=5, filter_threshold=0.5)

    # 3. 测试果蔬识别
    ingredient_results = test_ingredient_api(token, image_b64, top_num=5)

    # 4. 测试组合服务
    combo_results = test_combination_api(token, image_b64)

    # 5. 汇总结果
    print("=" * 60)
    print("【最终汇总】")
    print("=" * 60)
    print(f"菜品识别: {len(dish_results)}个结果")
    print(f"果蔬识别: {len(ingredient_results)}个结果")
    print(f"组合服务: {len(combo_results)}个结果")

    # 过滤有效结果（排除"非菜"）
    valid_dishes = [d for d in dish_results if d.get("name") != "非菜"]
    valid_ingredients = [d for d in ingredient_results if d.get("name")]
    valid_combos = [d for d in combo_results if d.get("name")]

    print()
    print(f"有效菜品: {len(valid_dishes)}个")
    for d in valid_dishes:
        print(f"  - {d.get('name')} (卡路里:{d.get('calorie', '0')})")

    print(f"有效果蔬: {len(valid_ingredients)}个")
    for d in valid_ingredients:
        print(f"  - {d.get('name')} (卡路里:{d.get('calorie', '0')})")

    print(f"有效组合: {len(valid_combos)}个")
    for d in valid_combos:
        print(f"  - {d.get('name')} [{d.get('source')}] (分数:{d.get('score')})")


if __name__ == "__main__":
    main()
