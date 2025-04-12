from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.google.cloud.transfers.gcs_to_bigquery import GCSToBigQueryOperator
from airflow.utils.dates import days_ago
from google.cloud import storage
import requests
import zipfile
import os

default_args = {
    "owner": "naza",
    "start_date": days_ago(1),
    "retries": 1,
}

def download_and_upload(month):
    url = f"https://s3.amazonaws.com/tripdata/JC-2024{month}-citibike-tripdata.csv.zip"
    local_zip = f"/opt/airflow/tmp/JC-2024{month}-citibike-tripdata.csv.zip"
    local_csv = f"/opt/airflow/tmp/JC-2024{month}-citibike-tripdata.csv"

    os.makedirs("/opt/airflow/tmp", exist_ok=True) 
    with open(local_zip, "wb") as f:
        f.write(requests.get(url).content)
    with zipfile.ZipFile(local_zip, "r") as zip_ref:
        zip_ref.extractall("/opt/airflow/tmp")
    client = storage.Client()
    bucket = client.get_bucket("naza_nyc_bike_rides")
    blob = bucket.blob(f"raw/JC-2024{month}-citibike-tripdata.csv")
    blob.upload_from_filename(local_csv)
    os.remove(local_zip)
    os.remove(local_csv)

with DAG("ingest_citi_bike_2024", default_args=default_args, schedule_interval="@once") as dag:
    months = [f"{i:02d}" for i in range(1, 13)] 

    previous_load_task = None 

    for month in months:
        download_task = PythonOperator(
            task_id=f"download_and_upload_{month}",
            python_callable=download_and_upload,
            op_kwargs={"month": month},
        )
        load_task = GCSToBigQueryOperator(
            task_id=f"load_to_bigquery_{month}",
            bucket="naza_nyc_bike_rides",
            source_objects=[f"raw/JC-2024{month}-citibike-tripdata.csv"],
            destination_project_dataset_table="smiling-audio-448313-p0.nyc_bikes_staging.trips",
            source_format="CSV",
            skip_leading_rows=1,
            write_disposition="WRITE_APPEND",
            time_partitioning={"type": "DAY", "field": "started_at"},
            cluster_fields=["start_station_id"],
        )

        download_task >> load_task

        if previous_load_task is not None: 
            previous_load_task >> download_task

        previous_load_task = load_task 