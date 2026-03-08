
# 3D Room Tour MVP

Upload an MP4 and view it as a 360 degrees view you can navigate with arrow buttons.

**Stack:** Python, FastAPI, Three.js

---

## Install & Run (tested on Windows)

Make sure you have Python

```
py --version
py -m pip install fastapi uvicorn python-multipart
py -m uvicorn Backend.main:app --reload
```
Open port [http://127.0.0.1:8000]


---
If you have errors in main.py, then make sure to use correct intepreter:


> In VS Code: `Ctrl + Shift + P` → **Python: Select Interpreter** → choose the recommended one before running.

---

## How to use the website:

1. Pick an MP4 → **Upload**
2. Press **Process →**
3. Navigate with the **▲ ◀ ▼ ▶** buttons on screen
