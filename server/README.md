# 분리 서버 (개발용)

앱이 올린 곡을 Demucs(`htdemucs_6s`)로 파트 5개(vocals · drums · bass · guitar · piano)로 나눈다. 개발 중에는 각자 Mac에서 로컬로 실행한다.

## 설치 (처음 한 번)

저장소 맨 위에서 실행한다. Apple Silicon Mac에서 Apple GPU(`mps`)로 분리한다.

```bash
brew install ffmpeg
python3 -m venv .venv
.venv/bin/pip install -r server/requirements.txt
```

## 실행

```bash
.venv/bin/uvicorn server.server:app --host 0.0.0.0 --port 8756
```

- 시뮬레이터: `http://127.0.0.1:8756`
- iPad: 같은 Wi-Fi에서 `http://<Mac IP>:8756` (Mac IP는 시스템 설정 → Wi-Fi → 세부 정보)
- 오래 켜 둘 때는 잠자기를 막는다: `caffeinate -i .venv/bin/uvicorn server.server:app --host 0.0.0.0 --port 8756`

## 확인

```bash
curl http://127.0.0.1:8756/health
curl -F "file=@곡.mp3" http://127.0.0.1:8756/jobs          # → {"job_id": "..."}
curl http://127.0.0.1:8756/jobs/<job_id>                   # status가 done이 될 때까지
curl -o vocals.mp3 http://127.0.0.1:8756/jobs/<job_id>/stems/vocals.mp3
```

올린 곡과 나뉜 파트는 `server/data/`에 쌓인다. 이 폴더는 git에 올리지 않는다.
