{{
    config(
        materialized='view'
    )
}}


SELECT * 
FROM {{ source('staging', 'product_details') }}

{% if var('is_test_run', default=true) %}

  limit 100

{% endif %}