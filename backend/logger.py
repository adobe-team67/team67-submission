# app/logger.py
import logging
import os
from pathlib import Path

LOG_DIR = os.getenv("LOG_DIR", "logs")
LOG_FILE = os.getenv("LOG_FILE", "server.log")


def setup_logger(name: str = "app"):
    logger = logging.getLogger(name)

    if logger.handlers:
        return logger  

    logger.setLevel(logging.INFO)


    log_dir_path = Path(LOG_DIR)
    log_dir_path.mkdir(parents=True, exist_ok=True)


    log_file_path = log_dir_path / LOG_FILE
    file_handler = logging.FileHandler(log_file_path)
    file_handler.setLevel(logging.INFO)

    formatter = logging.Formatter(
        "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
    )
    file_handler.setFormatter(formatter)

    logger.addHandler(file_handler)

    return logger
