"""查看图片信息"""
from PIL import Image
import os

path = r"C:\Users\roarp\Downloads\R.jpg"
img = Image.open(path)
print(f"尺寸: {img.size}")
print(f"模式: {img.mode}")
print(f"文件大小: {os.path.getsize(path)} bytes")

# 保存缩略图
img.thumbnail((100, 100))
img.save(r"c:\Users\roarp\Desktop\TMP\Code\AICode\fat-battle\scripts\thumb.jpg")
print("已生成缩略图: scripts/thumb.jpg")
