from pathlib import Path

import requests
from requests.exceptions import RequestException


DATA_URL = (
    "https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2025-01.parquet"
)

OUTPUT_PATH = Path("data/raw/yellow_tripdata_2025-01.parquet")

CHUNK_SIZE_BYTES = 1024 * 1024


def download_file(url: str, destination: Path) -> None:
    """Download a file without loading its entire content into memory."""

    destination.parent.mkdir(parents=True, exist_ok=True)

    if destination.exists():
        print(f"File already exists: {destination}")
        return

    print(f"Downloading: {url}")
    print(f"Destination: {destination}")

    try:
        with requests.get(
            url,
            stream=True,
            timeout=60,
        ) as response:
            response.raise_for_status()

            downloaded_bytes = 0

            with destination.open("wb") as file:
                for chunk in response.iter_content(chunk_size=CHUNK_SIZE_BYTES):
                    if not chunk:
                        continue

                    file.write(chunk)
                    downloaded_bytes += len(chunk)

                    downloaded_megabytes = downloaded_bytes / 1024**2

                    print(
                        f"\rDownloaded: {downloaded_megabytes:.1f} MB",
                        end="",
                    )

        print()
        print("Download completed successfully.")

    except RequestException as error:
        if destination.exists():
            destination.unlink()

        print("The dataset could not be downloaded.")
        print(f"Details: {error}")
        raise SystemExit(1) from error


def main() -> None:
    """Download the initial Yellow Taxi dataset."""

    download_file(
        url=DATA_URL,
        destination=OUTPUT_PATH,
    )


if __name__ == "__main__":
    main()
