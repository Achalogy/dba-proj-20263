
import os

MONGO_URI = os.environ["MONGO_URI"]

DATABASE_NAME = os.getenv(
    "MONGO_DATABASE",
    "upme_pdet"
)

COLLECTION_BUILDINGS = "google_open_buildings"
COLLECTION_IMPORTS = "importaciones"

BATCH_SIZE = 500

DATA_DIR = "/data/raw"
