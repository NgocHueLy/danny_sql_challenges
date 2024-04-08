{{
    config(
        materialized='view'
    )
}}


SELECT * 
FROM {{ source('staging', 'sales') }}

{% if var('is_test_run', default=true) %}

  limit 100

{% endif %}