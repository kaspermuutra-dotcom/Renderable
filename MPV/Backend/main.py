# Backend/main.py
import os
from fastapi import FastAPI, File, UploadFile
from fastapi.responses import JSONResponse, FileResponse
from fastapi.staticfiles import StaticFiles

app = FastAPI()

# BASE_DIR points to Backend folder
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Uploads folder inside Backend/
UPLOAD_DIR = os.path.join(BASE_DIR, "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)

# Frontend folder (one level up from Backend/)
FRONTEND_DIR = os.path.join(BASE_DIR, "..", "frontend")

# Serve frontend JS/CSS under /static
app.mount("/static", StaticFiles(directory=FRONTEND_DIR), name="static")

# Serve uploaded videos under /uploads
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

# Serve index.html for root
@app.get("/")
async def index():
    return FileResponse(os.path.join(FRONTEND_DIR, "index.html"))

# Upload endpoint
@app.post("/upload/")
async def upload_file(file: UploadFile = File(...)):
    file_location = os.path.join(UPLOAD_DIR, file.filename)
    with open(file_location, "wb") as f:
        f.write(await file.read())
    return JSONResponse({"filename": file.filename, "url": f"/uploads/{file.filename}"})