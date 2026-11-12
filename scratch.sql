-- clickhouse-local
WITH
country_language_totals AS
(
    SELECT
    country,
    language,
    sum(people) AS speakers
    FROM file('data/dots.csv', CSVWithNames)
    GROUP BY country, language
),
dominant AS
(
    SELECT
    country,
    argMax(language, (speakers, language)) AS dominant_language
    FROM country_language_totals
    GROUP BY country
),
cell_languages AS
(
    SELECT
    geoToH3(lon, lat, 5) AS h3,
    country,
    language,
    sum(people) AS speakers
    FROM file('data/dots.csv', CSVWithNames)
    GROUP BY h3, country, language
)
SELECT
toUInt32(bitAnd(h3, 4294967295)) AS index_lower,
toUInt32(bitShiftRight(h3, 32)) AS index_upper,
frac_dominant_language AS value,
languages
FROM
(
    SELECT
    d.h3 AS h3,
    ifNull(
        sumIf(d.speakers, d.language = c.dominant_language),
        0
    ) / nullIf(sum(d.speakers), 0) AS frac_dominant_language,

    arrayStringConcat(
        arrayMap(
            x -> concat(x.2, ': ', toString(x.1)),
            arrayReverseSort(
                x -> x.1,
                groupArray((d.speakers, d.language))
            )
        ),
        ', '
    ) AS languages
    FROM cell_languages AS d
    INNER JOIN dominant AS c ON d.country = c.country
    GROUP BY d.h3
)
INTO OUTFILE 'out.arrow'
TRUNCATE
FORMAT Arrow
SETTINGS output_format_arrow_compression_method = 'none';
