import pytest
from airflow import DAG
from dags.etl import default_args

def test_dag_structure():
    dag = DAG(
        "ingest_citi_bike_2024",
        default_args=default_args,
        schedule_interval="@once"
    )
    assert dag is not None
    assert len(dag.tasks) == 24  # 12 months * (download + load tasks)
    assert dag.task_ids[0].startswith("download_and_upload")
    assert dag.task_ids[-1].startswith("load_to_bigquery")