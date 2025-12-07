
ARG PYTHON_VERSION=3.12
FROM python:${PYTHON_VERSION}-slim AS base

ENV APP_HOME=/app/skytorch \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    POETRY_VIRTUALENVS_CREATE=false \
    PIP_DEFAULT_TIMEOUT=1000 \
    POETRY_REQUESTS_TIMEOUT=1000

WORKDIR ${APP_HOME}

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    libpq-dev \
    gcc \
    g++ \
    && \
    rm -rf /var/lib/apt/lists/*

COPY skytorch/pyproject.toml skytorch/poetry.lock* ./ 
RUN pip install --upgrade pip && \
    pip install poetry && \
    poetry install --only main && \
    python -m spacy download en_core_web_sm

FROM base AS dev
ENV ENVIRONMENT=development
COPY skytorch/skytorch ./skytorch
COPY skytorch/pyproject.toml skytorch/poetry.lock* ./
CMD ["uvicorn", "skytorch.main:app", "--host", "0.0.0.0", "--port", "5000", "--reload"]

FROM base AS production
ENV ENVIRONMENT=production
COPY skytorch/skytorch ./skytorch
COPY skytorch/pyproject.toml skytorch/poetry.lock* ./
RUN poetry install --only main
CMD ["uvicorn", "skytorch.main:app", "--host", "0.0.0.0", "--port", "5000"]

