FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    SENTENCE_TRANSFORMERS_HOME=/opt/models \
    OMP_NUM_THREADS=1 \
    TOKENIZERS_PARALLELISM=false \
    VECTOR_STORE_BACKEND=azure

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends libgomp1 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

RUN python -m pip install --upgrade pip \
    && python -m pip install torch \
       --index-url https://download.pytorch.org/whl/cpu \
    && python -m pip install -r requirements.txt

RUN python -c "from sentence_transformers import SentenceTransformer; model = SentenceTransformer('all-MiniLM-L6-v2'); model.encode(['Build check'])"

ENV HF_HUB_OFFLINE=1 \
    TRANSFORMERS_OFFLINE=1

COPY app/ ./app/
COPY run.py gunicorn.conf.py ./

RUN useradd --create-home appuser

USER appuser

EXPOSE 8080

CMD ["gunicorn", "--config", "gunicorn.conf.py", "run:app"]