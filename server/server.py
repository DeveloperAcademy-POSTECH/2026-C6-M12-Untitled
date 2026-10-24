"""
Syncy 분리 서버 (개발용)

앱이 곡 파일을 올리면 Demucs(htdemucs_6s)로 파트를 나누고, 파트 mp3를 내려준다.

  GET  /health                          -> {"ok": true}
  POST /jobs            (multipart file) -> {"job_id": ...}
  GET  /jobs/{job_id}                    -> {"job_id", "status", "stems", "error"}
  GET  /jobs/{job_id}/stems/{name}.mp3   -> mp3 파일

분리는 백그라운드 스레드에서 한 번에 하나씩 실행하고, 앱은 상태를 반복해서 확인한다.
"""
import shutil
import subprocess
import sys
import threading
import uuid
from pathlib import Path
from typing import Dict

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.responses import FileResponse

BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"
DATA_DIR.mkdir(exist_ok=True)

MODEL_NAME = "htdemucs_6s"
# htdemucs_6s는 6파트를 만들지만 앱은 5파트만 쓴다 (other 제외). 이름은 앱의 SessionID rawValue와 같다.
EXPOSED_STEMS = ["vocals", "drums", "bass", "guitar", "piano"]

app = FastAPI(title="Syncy Separation Server")

# job_id -> {"status": "queued"|"processing"|"done"|"error", "error": str|None, "stems_dir": Path|None}
JOBS: Dict[str, dict] = {}
JOBS_LOCK = threading.Lock()
# Demucs는 무거워서 한 번에 하나만 돌린다.
SEPARATION_LOCK = threading.Lock()


def run_separation(job_id: str, input_path: Path):
    job_dir = DATA_DIR / job_id
    with SEPARATION_LOCK:
        try:
            with JOBS_LOCK:
                JOBS[job_id]["status"] = "processing"

            cmd = [
                sys.executable, "-m", "demucs",
                "-n", MODEL_NAME,
                "-d", "mps",
                "--mp3", "--mp3-bitrate", "320",
                "-o", str(job_dir / "out"),
                str(input_path),
            ]
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode != 0:
                raise RuntimeError(result.stderr[-2000:])

            # Demucs는 out/<모델>/<입력 파일 이름>/ 아래에 파트를 쓴다.
            produced_dir = job_dir / "out" / MODEL_NAME / input_path.stem
            if not produced_dir.exists():
                raise RuntimeError(f"expected output dir not found: {produced_dir}")

            stems_dir = job_dir / "stems"
            stems_dir.mkdir(parents=True, exist_ok=True)
            for stem in EXPOSED_STEMS:
                src = produced_dir / f"{stem}.mp3"
                if src.exists():
                    shutil.copy(src, stems_dir / f"{stem}.mp3")
            shutil.rmtree(job_dir / "out", ignore_errors=True)

            with JOBS_LOCK:
                JOBS[job_id]["status"] = "done"
                JOBS[job_id]["stems_dir"] = stems_dir
        except Exception as e:  # noqa: BLE001
            with JOBS_LOCK:
                JOBS[job_id]["status"] = "error"
                JOBS[job_id]["error"] = str(e)


def restore_finished_jobs():
    """서버를 다시 켜도 이전에 분리한 곡을 내려받을 수 있게 한다."""
    for job_dir in DATA_DIR.iterdir():
        stems_dir = job_dir / "stems"
        if job_dir.is_dir() and stems_dir.is_dir():
            JOBS[job_dir.name] = {"status": "done", "error": None, "stems_dir": stems_dir}


restore_finished_jobs()


@app.get("/health")
async def health():
    return {"ok": True}


@app.post("/jobs")
async def create_job(file: UploadFile = File(...)):
    job_id = uuid.uuid4().hex[:12]
    job_dir = DATA_DIR / job_id
    job_dir.mkdir(parents=True, exist_ok=True)

    suffix = Path(file.filename or "input.mp3").suffix or ".mp3"
    input_path = job_dir / f"input{suffix}"
    with input_path.open("wb") as f:
        shutil.copyfileobj(file.file, f)

    with JOBS_LOCK:
        JOBS[job_id] = {"status": "queued", "error": None, "stems_dir": None}

    threading.Thread(target=run_separation, args=(job_id, input_path), daemon=True).start()
    return {"job_id": job_id}


@app.get("/jobs/{job_id}")
async def get_job(job_id: str):
    with JOBS_LOCK:
        job = JOBS.get(job_id)
    if job is None:
        raise HTTPException(404, "job not found")

    stems = []
    if job["status"] == "done" and job["stems_dir"]:
        stems = [s for s in EXPOSED_STEMS if (job["stems_dir"] / f"{s}.mp3").exists()]
    return {"job_id": job_id, "status": job["status"], "stems": stems, "error": job["error"]}


@app.get("/jobs/{job_id}/stems/{stem_name}.mp3")
async def get_stem(job_id: str, stem_name: str):
    if stem_name not in EXPOSED_STEMS:
        raise HTTPException(404, "unknown stem")
    with JOBS_LOCK:
        job = JOBS.get(job_id)
    if job is None or job["status"] != "done" or job["stems_dir"] is None:
        raise HTTPException(404, "stems not ready")

    path = job["stems_dir"] / f"{stem_name}.mp3"
    if not path.exists():
        raise HTTPException(404, "stem not found")
    return FileResponse(path, media_type="audio/mpeg")
