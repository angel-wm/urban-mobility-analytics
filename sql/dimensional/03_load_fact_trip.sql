BEGIN;

INSERT INTO marts.fact_trip (
    raw_trip_id,
    ingestion_id,
    pickup_date_key,
    dropoff_date_key,
    pickup_hour_key,
    dropoff_hour_key,
    vendor_key,
    rate_code_key,
    payment_type_key,
    store_and_fwd_key,
    pickup_datetime,
    dropoff_datetime,
    pickup_location_id,
    dropoff_location_id,
    passenger_count,
    trip_distance,
    trip_duration_minutes,
    average_speed_mph,
    fare_amount,
    extra,
    mta_tax,
    tip_amount,
    tolls_amount,
    improvement_surcharge,
    total_amount,
    congestion_surcharge,
    airport_fee,
    cbd_congestion_fee,
    loaded_at,
    has_missing_datetime,
    is_nonpositive_duration,
    is_duration_over_24_hours,
    is_negative_distance,
    is_zero_distance,
    is_pickup_outside_expected_period,
    has_missing_trip_attributes,
    is_negative_fare,
    is_negative_total_amount,
    is_negative_transaction,
    is_unrecognized_vendor,
    is_unrecognized_ratecode,
    is_unrecognized_payment_type,
    is_unrecognized_store_and_fwd,
    is_documented_unknown_ratecode,
    is_documented_unknown_payment_type,
    has_operational_issue,
    has_suspicious_condition,
    has_any_quality_flag,
    is_valid_for_speed_analysis
)
SELECT
    st.raw_trip_id,
    st.ingestion_id,
    pickup_date.date_key,
    dropoff_date.date_key,
    pickup_hour.hour_key,
    dropoff_hour.hour_key,
    vendor.vendor_key,
    rate_code.rate_code_key,
    payment.payment_type_key,
    store_fwd.store_and_fwd_key,
    st.pickup_datetime,
    st.dropoff_datetime,
    st.pickup_location_id,
    st.dropoff_location_id,
    st.passenger_count,
    st.trip_distance,
    st.trip_duration_minutes,
    st.average_speed_mph,
    st.fare_amount,
    st.extra,
    st.mta_tax,
    st.tip_amount,
    st.tolls_amount,
    st.improvement_surcharge,
    st.total_amount,
    st.congestion_surcharge,
    st.airport_fee,
    st.cbd_congestion_fee,
    st.loaded_at,
    st.has_missing_datetime,
    st.is_nonpositive_duration,
    st.is_duration_over_24_hours,
    st.is_negative_distance,
    st.is_zero_distance,
    st.is_pickup_outside_expected_period,
    st.has_missing_trip_attributes,
    st.is_negative_fare,
    st.is_negative_total_amount,
    st.is_negative_transaction,
    st.is_unrecognized_vendor,
    st.is_unrecognized_ratecode,
    st.is_unrecognized_payment_type,
    st.is_unrecognized_store_and_fwd,
    st.is_documented_unknown_ratecode,
    st.is_documented_unknown_payment_type,
    st.has_operational_issue,
    st.has_suspicious_condition,
    st.has_any_quality_flag,
    st.is_valid_for_speed_analysis
FROM staging.taxi_trips AS st

INNER JOIN marts.dim_ingestion AS di
    ON di.ingestion_id = st.ingestion_id

INNER JOIN marts.dim_date AS pickup_date
    ON pickup_date.full_date =
        st.pickup_datetime::DATE

INNER JOIN marts.dim_date AS dropoff_date
    ON dropoff_date.full_date =
        st.dropoff_datetime::DATE

INNER JOIN marts.dim_hour AS pickup_hour
    ON pickup_hour.hour_key =
        EXTRACT(
            HOUR FROM st.pickup_datetime
        )::SMALLINT

INNER JOIN marts.dim_hour AS dropoff_hour
    ON dropoff_hour.hour_key =
        EXTRACT(
            HOUR FROM st.dropoff_datetime
        )::SMALLINT

INNER JOIN marts.dim_vendor AS vendor
    ON vendor.vendor_id = st.vendor_id

INNER JOIN marts.dim_rate_code AS rate_code
    ON rate_code.ratecode_id
        IS NOT DISTINCT FROM st.ratecode_id

INNER JOIN marts.dim_payment_type AS payment
    ON payment.payment_type =
        st.payment_type

INNER JOIN marts.dim_store_and_fwd AS store_fwd
    ON store_fwd.store_and_fwd_flag
        IS NOT DISTINCT FROM
            st.store_and_fwd_flag

ON CONFLICT (raw_trip_id)
DO UPDATE SET
    ingestion_id = EXCLUDED.ingestion_id,
    pickup_date_key = EXCLUDED.pickup_date_key,
    dropoff_date_key = EXCLUDED.dropoff_date_key,
    pickup_hour_key = EXCLUDED.pickup_hour_key,
    dropoff_hour_key = EXCLUDED.dropoff_hour_key,
    vendor_key = EXCLUDED.vendor_key,
    rate_code_key = EXCLUDED.rate_code_key,
    payment_type_key = EXCLUDED.payment_type_key,
    store_and_fwd_key = EXCLUDED.store_and_fwd_key,
    pickup_datetime = EXCLUDED.pickup_datetime,
    dropoff_datetime = EXCLUDED.dropoff_datetime,
    pickup_location_id =
        EXCLUDED.pickup_location_id,
    dropoff_location_id =
        EXCLUDED.dropoff_location_id,
    passenger_count = EXCLUDED.passenger_count,
    trip_distance = EXCLUDED.trip_distance,
    trip_duration_minutes =
        EXCLUDED.trip_duration_minutes,
    average_speed_mph = EXCLUDED.average_speed_mph,
    fare_amount = EXCLUDED.fare_amount,
    extra = EXCLUDED.extra,
    mta_tax = EXCLUDED.mta_tax,
    tip_amount = EXCLUDED.tip_amount,
    tolls_amount = EXCLUDED.tolls_amount,
    improvement_surcharge =
        EXCLUDED.improvement_surcharge,
    total_amount = EXCLUDED.total_amount,
    congestion_surcharge =
        EXCLUDED.congestion_surcharge,
    airport_fee = EXCLUDED.airport_fee,
    cbd_congestion_fee =
        EXCLUDED.cbd_congestion_fee,
    loaded_at = EXCLUDED.loaded_at,
    has_missing_datetime =
        EXCLUDED.has_missing_datetime,
    is_nonpositive_duration =
        EXCLUDED.is_nonpositive_duration,
    is_duration_over_24_hours =
        EXCLUDED.is_duration_over_24_hours,
    is_negative_distance =
        EXCLUDED.is_negative_distance,
    is_zero_distance = EXCLUDED.is_zero_distance,
    is_pickup_outside_expected_period =
        EXCLUDED.is_pickup_outside_expected_period,
    has_missing_trip_attributes =
        EXCLUDED.has_missing_trip_attributes,
    is_negative_fare = EXCLUDED.is_negative_fare,
    is_negative_total_amount =
        EXCLUDED.is_negative_total_amount,
    is_negative_transaction =
        EXCLUDED.is_negative_transaction,
    is_unrecognized_vendor =
        EXCLUDED.is_unrecognized_vendor,
    is_unrecognized_ratecode =
        EXCLUDED.is_unrecognized_ratecode,
    is_unrecognized_payment_type =
        EXCLUDED.is_unrecognized_payment_type,
    is_unrecognized_store_and_fwd =
        EXCLUDED.is_unrecognized_store_and_fwd,
    is_documented_unknown_ratecode =
        EXCLUDED.is_documented_unknown_ratecode,
    is_documented_unknown_payment_type =
        EXCLUDED.is_documented_unknown_payment_type,
    has_operational_issue =
        EXCLUDED.has_operational_issue,
    has_suspicious_condition =
        EXCLUDED.has_suspicious_condition,
    has_any_quality_flag =
        EXCLUDED.has_any_quality_flag,
    is_valid_for_speed_analysis =
        EXCLUDED.is_valid_for_speed_analysis;

COMMIT;
