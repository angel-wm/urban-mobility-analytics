import pandas as pd
import pytest

from src.transformations.raw_taxi import (
    RAW_COLUMN_ORDER,
    prepare_raw_taxi_dataframe,
    validate_source_columns,
)


def make_source_dataframe() -> pd.DataFrame:
    return pd.DataFrame(
        {
            "VendorID": ["2"],
            "tpep_pickup_datetime": ["2025-01-01 08:15:00"],
            "tpep_dropoff_datetime": ["2025-01-01 08:30:00"],
            "passenger_count": ["1"],
            "trip_distance": ["3.5"],
            "RatecodeID": ["1"],
            "store_and_fwd_flag": [" Y "],
            "PULocationID": ["161"],
            "DOLocationID": ["236"],
            "payment_type": ["1"],
            "fare_amount": ["18.5"],
            "extra": ["2.5"],
            "mta_tax": ["0.5"],
            "tip_amount": ["4.0"],
            "tolls_amount": ["0"],
            "improvement_surcharge": ["1.0"],
            "total_amount": ["26.5"],
            "congestion_surcharge": ["2.5"],
            "Airport_fee": ["0"],
            "cbd_congestion_fee": ["0"],
        }
    )


def test_validate_source_columns_rejects_missing_column() -> None:
    dataframe = make_source_dataframe().drop(columns=["VendorID"])

    with pytest.raises(ValueError, match="VendorID"):
        validate_source_columns(dataframe)


def test_prepare_raw_taxi_dataframe_builds_expected_schema() -> None:
    prepared = prepare_raw_taxi_dataframe(make_source_dataframe())

    assert list(prepared.columns) == RAW_COLUMN_ORDER

    assert prepared.loc[0, "vendor_id"] == 2
    assert prepared.loc[0, "passenger_count"] == 1
    assert prepared.loc[0, "trip_distance"] == 3.5
    assert prepared.loc[0, "total_amount"] == 26.5
    assert prepared.loc[0, "store_and_fwd_flag"] == "Y"

    assert str(prepared["vendor_id"].dtype) == "Int64"
    assert str(prepared["trip_distance"].dtype) == "float64"
    assert pd.api.types.is_datetime64_any_dtype(prepared["pickup_datetime"])


def test_prepare_raw_taxi_dataframe_coerces_invalid_values() -> None:
    dataframe = make_source_dataframe()

    dataframe.loc[0, "passenger_count"] = "invalid"
    dataframe.loc[0, "trip_distance"] = "invalid"
    dataframe.loc[0, "tpep_pickup_datetime"] = "invalid"

    prepared = prepare_raw_taxi_dataframe(dataframe)

    assert pd.isna(prepared.loc[0, "passenger_count"])
    assert pd.isna(prepared.loc[0, "trip_distance"])
    assert pd.isna(prepared.loc[0, "pickup_datetime"])


def test_prepare_raw_taxi_dataframe_removes_extra_columns() -> None:
    dataframe = make_source_dataframe()
    dataframe["unexpected_column"] = "value"

    prepared = prepare_raw_taxi_dataframe(dataframe)

    assert "unexpected_column" not in prepared.columns
    assert list(prepared.columns) == RAW_COLUMN_ORDER
