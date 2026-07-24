import pandas as pd


SOURCE_TO_RAW_COLUMNS = {
    "VendorID": "vendor_id",
    "tpep_pickup_datetime": "pickup_datetime",
    "tpep_dropoff_datetime": "dropoff_datetime",
    "passenger_count": "passenger_count",
    "trip_distance": "trip_distance",
    "RatecodeID": "ratecode_id",
    "store_and_fwd_flag": "store_and_fwd_flag",
    "PULocationID": "pickup_location_id",
    "DOLocationID": "dropoff_location_id",
    "payment_type": "payment_type",
    "fare_amount": "fare_amount",
    "extra": "extra",
    "mta_tax": "mta_tax",
    "tip_amount": "tip_amount",
    "tolls_amount": "tolls_amount",
    "improvement_surcharge": "improvement_surcharge",
    "total_amount": "total_amount",
    "congestion_surcharge": "congestion_surcharge",
    "Airport_fee": "airport_fee",
    "cbd_congestion_fee": "cbd_congestion_fee",
}


INTEGER_COLUMNS = [
    "vendor_id",
    "passenger_count",
    "ratecode_id",
    "pickup_location_id",
    "dropoff_location_id",
    "payment_type",
]


DATETIME_COLUMNS = [
    "pickup_datetime",
    "dropoff_datetime",
]


FLOAT_COLUMNS = [
    "trip_distance",
    "fare_amount",
    "extra",
    "mta_tax",
    "tip_amount",
    "tolls_amount",
    "improvement_surcharge",
    "total_amount",
    "congestion_surcharge",
    "airport_fee",
    "cbd_congestion_fee",
]


RAW_COLUMN_ORDER = [
    "vendor_id",
    "pickup_datetime",
    "dropoff_datetime",
    "passenger_count",
    "trip_distance",
    "ratecode_id",
    "store_and_fwd_flag",
    "pickup_location_id",
    "dropoff_location_id",
    "payment_type",
    "fare_amount",
    "extra",
    "mta_tax",
    "tip_amount",
    "tolls_amount",
    "improvement_surcharge",
    "total_amount",
    "congestion_surcharge",
    "airport_fee",
    "cbd_congestion_fee",
]


def validate_source_columns(dataframe: pd.DataFrame) -> None:
    """Validate that the source DataFrame contains all expected columns."""

    expected_columns = set(SOURCE_TO_RAW_COLUMNS)
    actual_columns = set(dataframe.columns)

    missing_columns = sorted(expected_columns - actual_columns)

    if missing_columns:
        raise ValueError(
            f"The source DataFrame is missing required columns: {missing_columns}"
        )


def rename_source_columns(
    dataframe: pd.DataFrame,
) -> pd.DataFrame:
    """Rename source columns to the raw database naming convention."""

    return dataframe.rename(columns=SOURCE_TO_RAW_COLUMNS)


def convert_raw_column_types(
    dataframe: pd.DataFrame,
) -> pd.DataFrame:
    """Convert columns to the types expected by the raw database table."""

    converted_dataframe = dataframe.copy()

    for column in INTEGER_COLUMNS:
        converted_dataframe[column] = pd.to_numeric(
            converted_dataframe[column],
            errors="coerce",
        ).astype("Int64")

    for column in DATETIME_COLUMNS:
        converted_dataframe[column] = pd.to_datetime(
            converted_dataframe[column],
            errors="coerce",
        )

    for column in FLOAT_COLUMNS:
        converted_dataframe[column] = pd.to_numeric(
            converted_dataframe[column],
            errors="coerce",
        ).astype("float64")

    converted_dataframe["store_and_fwd_flag"] = (
        converted_dataframe["store_and_fwd_flag"].astype("string").str.strip()
    )

    return converted_dataframe


def prepare_raw_taxi_dataframe(
    dataframe: pd.DataFrame,
) -> pd.DataFrame:
    """Prepare a source Yellow Taxi DataFrame for the raw database table."""

    validate_source_columns(dataframe)

    prepared_dataframe = rename_source_columns(dataframe)

    prepared_dataframe = convert_raw_column_types(prepared_dataframe)

    return prepared_dataframe[RAW_COLUMN_ORDER]
