# Tests for the musicbrainz functions in media-juggler-lib

use std assert
use std log

use ../media-juggler-lib *
use helpers/assertions.nu *

const test_data_dir = path self ../test-data

export def test_parse_works_from_musicbrainz_relations_bakemonogatari_part_01 [] {
  let input = (
    open ([$test_data_dir "bakemonogatari_part_01_release.json"] | path join)
    | get media
    | get tracks
    | flatten
    | get recording
    | get relations
    | flatten
  )
  let expected = [[iswcs, disambiguation, relations, type-id, languages, id, language, title, type, attributes]; [[], "light novel, English", [{artist: {type-id: "b6e035f4-3ce9-331c-97df-83397230b0df", sort-name: "Ransom, Ko", disambiguation: translator, country: null, type: Person, id: "3192a6d6-bf15-434e-bfea-827865a3cc0a", name: "Ko Ransom"}, type-id: "da6c5d8a-ce13-474d-9375-61feb29039a5", ended: false, direction: backward, target-credit: "", begin: null, attribute-values: {}, attribute-ids: {}, target-type: artist, end: null, source-credit: "", attributes: [], type: translator}, {target-type: artist, end: null, type: writer, source-credit: "", attributes: [], attribute-ids: {}, attribute-values: {}, begin: null, artist: {id: "2c7b9427-6776-4969-8028-5de988724659", name: 西尾維新, type-id: "b6e035f4-3ce9-331c-97df-83397230b0df", sort-name: NISIOISIN, disambiguation: "Japanese novelist", country: JP, type: Person}, ended: false, type-id: "a255bca1-b157-4518-9108-7b147dc3fc68", target-credit: NISIOISIN, direction: backward}, {type: "part of", source-credit: "", attributes: [number], end: null, target-type: series, attribute-ids: {number: "a59c5830-5ec7-38fe-9a21-c7ea54f6650a"}, ordering-key: 1, attribute-values: {number: "1"}, begin: null, target-credit: "", direction: backward, ended: false, series: {disambiguation: "light novel, English", type-id: "b689f694-6305-3d78-954d-df6759a1877b", type: "Work series", id: "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322", name: Bakemonogatari}, type-id: "b0d44366-cdf0-3acb-bee6-0f65a77a6ef0"}, {attribute-ids: {number: "a59c5830-5ec7-38fe-9a21-c7ea54f6650a"}, ordering-key: 1, type: "part of", source-credit: "", attributes: [number], end: null, target-type: series, target-credit: "", direction: backward, ended: false, type-id: "b0d44366-cdf0-3acb-bee6-0f65a77a6ef0", series: {type-id: "b689f694-6305-3d78-954d-df6759a1877b", disambiguation: "light novel, English", type: "Work series", id: "05ef20c8-9286-4b53-950f-eac8cbb32dc3", name: Monogatari}, attribute-values: {number: "1"}, begin: null}, {attributes: [number], source-credit: "", type: "part of", end: null, target-type: series, ordering-key: 2, attribute-ids: {number: "a59c5830-5ec7-38fe-9a21-c7ea54f6650a"}, begin: null, attribute-values: {number: "1"}, direction: backward, target-credit: "", type-id: "b0d44366-cdf0-3acb-bee6-0f65a77a6ef0", series: {disambiguation: "light novel, English", type-id: "b689f694-6305-3d78-954d-df6759a1877b", type: "Work series", id: "6660f123-24a0-46c7-99bf-7ff5dc11ceef", name: "Monogatari Series: First Season"}, ended: false}, {attribute-ids: {}, target-type: url, url: {id: "817e90a9-f58e-48ce-8ea8-e3aed01ed308", resource: "https://bookbrainz.org/work/ae3d4e16-7524-456d-a72f-318a1700b2ad"}, end: null, attributes: [], source-credit: "", type: BookBrainz, type-id: "0ea7cf4e-93dd-4bc4-b748-0f1073cf951c", ended: false, direction: backward, target-credit: "", begin: null, attribute-values: {}}, {attribute-ids: {}, target-type: url, end: null, url: {id: "da650123-1830-464d-ae2d-3063278a5430", resource: "https://openlibrary.org/works/OL19749568W"}, type: "other databases", attributes: [], source-credit: "", ended: false, type-id: "190ea031-4355-405d-a43e-53eb4c5c4ada", target-credit: "", direction: backward, attribute-values: {}, begin: null}, {attribute-ids: {}, target-type: url, type: "other databases", source-credit: "", attributes: [], url: {id: "08766fc9-4f13-4a68-8070-1f8c76d8530b", resource: "https://www.librarything.com/work/18801353"}, end: null, target-credit: "", direction: backward, ended: false, type-id: "190ea031-4355-405d-a43e-53eb4c5c4ada", attribute-values: {}, begin: null}, {target-type: work, type: "other version", source-credit: "", attributes: [translated], end: null, attribute-ids: {translated: "ed11fcb1-5a18-4e1d-b12c-633ed19c8ee1"}, attribute-values: {}, begin: null, target-credit: "", work: {type: Prose, attributes: [], title: 化物語（上）, language: null, id: "35d328d1-7d5d-4c2c-a1e1-47dda806de3e", languages: [], disambiguation: "light novel", type-id: "78a8e727-edc2-35b9-8829-a46111ef6df9", iswcs: []}, direction: backward, ended: false, type-id: "7440b539-19ab-4243-8c03-4f5942ca2218"}], "78a8e727-edc2-35b9-8829-a46111ef6df9", [eng], "1f1a315c-49fe-4d4c-9c07-1903a113f984", eng, "Bakemonogatari: Monster Tale, Part 01", Prose, []]]
  assert equal ($input | parse_works_from_musicbrainz_relations) $expected
}

export def test_parse_contributor_by_type_from_musicbrainz_relations_bakemonogatari_part_01_narrators [] {
  let input = (
    open ([$test_data_dir "bakemonogatari_part_01_release.json"] | path join)
    | get media
    | get tracks
    | flatten
    | get recording
    | get relations
    | flatten
    | uniq
  )
  let expected = [
    [name id];
    ["Cristina Vee" "9fac1f69-0044-4b51-ad1c-6bee4c749b91"]
    ["Erica Mendez" "91225f09-2f8e-4aee-8718-9329cac8ef03"]
    ["Erik Kimerer" "ac830008-5b9c-4f98-ae2b-cac499c40ad8"]
    ["Keith Silverstein" "9c1e9bd5-4ded-4944-8190-1fec6e530e64"]
  ]
  assert equal ($input | parse_contributor_by_type_from_musicbrainz_relations artist vocal "spoken vocals" | sort-by name) $expected
}

export def test_parse_contributors_from_work_relations_bakemonogatari_part_01 [] {
  let input = [{end: null, ended: false, target-credit: "", begin: null, type: translator, attributes: [], attribute-ids: {}, target-type: artist, artist: {country: null, name: "Ko Ransom", id: "3192a6d6-bf15-434e-bfea-827865a3cc0a", disambiguation: translator, type-id: "b6e035f4-3ce9-331c-97df-83397230b0df", sort-name: "Ransom, Ko", type: Person}, type-id: "da6c5d8a-ce13-474d-9375-61feb29039a5", direction: backward, source-credit: "", attribute-values: {}}, {target-credit: NISIOISIN, begin: null, type: writer, end: null, ended: false, attribute-values: {}, direction: backward, source-credit: "", attributes: [], attribute-ids: {}, type-id: "a255bca1-b157-4518-9108-7b147dc3fc68", artist: {country: JP, name: 西尾維新, disambiguation: "Japanese novelist", id: "2c7b9427-6776-4969-8028-5de988724659", type-id: "b6e035f4-3ce9-331c-97df-83397230b0df", sort-name: NISIOISIN, type: Person}, target-type: artist}, {ended: false, end: null, type: "part of", target-credit: "", begin: null, type-id: "b0d44366-cdf0-3acb-bee6-0f65a77a6ef0", target-type: series, attributes: [number], ordering-key: 1, attribute-ids: {number: "a59c5830-5ec7-38fe-9a21-c7ea54f6650a"}, attribute-values: {number: "1"}, direction: backward, source-credit: "", series: {disambiguation: "light novel, English", id: "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322", name: Bakemonogatari, type-id: "b689f694-6305-3d78-954d-df6759a1877b", type: "Work series"}}, {series: {type: "Work series", type-id: "b689f694-6305-3d78-954d-df6759a1877b", name: Monogatari, id: "05ef20c8-9286-4b53-950f-eac8cbb32dc3", disambiguation: "light novel, English"}, source-credit: "", direction: backward, attribute-values: {number: "1"}, ordering-key: 1, attribute-ids: {number: "a59c5830-5ec7-38fe-9a21-c7ea54f6650a"}, attributes: [number], target-type: series, type-id: "b0d44366-cdf0-3acb-bee6-0f65a77a6ef0", target-credit: "", begin: null, type: "part of", end: null, ended: false}, {ordering-key: 2, attribute-ids: {number: "a59c5830-5ec7-38fe-9a21-c7ea54f6650a"}, attributes: [number], target-type: series, type-id: "b0d44366-cdf0-3acb-bee6-0f65a77a6ef0", series: {disambiguation: "light novel, English", id: "6660f123-24a0-46c7-99bf-7ff5dc11ceef", name: "Monogatari Series: First Season", type-id: "b689f694-6305-3d78-954d-df6759a1877b", type: "Work series"}, source-credit: "", direction: backward, attribute-values: {number: "1"}, end: null, ended: false, begin: null, target-credit: "", type: "part of"}, {end: null, ended: false, begin: null, target-credit: "", type: BookBrainz, attributes: [], attribute-ids: {}, url: {id: "817e90a9-f58e-48ce-8ea8-e3aed01ed308", resource: "https://bookbrainz.org/work/ae3d4e16-7524-456d-a72f-318a1700b2ad"}, type-id: "0ea7cf4e-93dd-4bc4-b748-0f1073cf951c", target-type: url, attribute-values: {}, direction: backward, source-credit: ""}, {target-type: url, type-id: "190ea031-4355-405d-a43e-53eb4c5c4ada", url: {resource: "https://openlibrary.org/works/OL19749568W", id: "da650123-1830-464d-ae2d-3063278a5430"}, attribute-ids: {}, attributes: [], source-credit: "", direction: backward, attribute-values: {}, ended: false, end: null, type: "other databases", begin: null, target-credit: ""}, {direction: backward, source-credit: "", attribute-values: {}, target-type: url, type-id: "190ea031-4355-405d-a43e-53eb4c5c4ada", url: {resource: "https://www.librarything.com/work/18801353", id: "08766fc9-4f13-4a68-8070-1f8c76d8530b"}, attributes: [], attribute-ids: {}, type: "other databases", target-credit: "", begin: null, ended: false, end: null}, {ended: false, end: null, type: "other version", target-credit: "", work: {title: 化物語（上）, type-id: "78a8e727-edc2-35b9-8829-a46111ef6df9", language: null, attributes: [], disambiguation: "light novel", id: "35d328d1-7d5d-4c2c-a1e1-47dda806de3e", type: Prose, iswcs: [], languages: []}, begin: null, target-type: work, type-id: "7440b539-19ab-4243-8c03-4f5942ca2218", attribute-ids: {translated: "ed11fcb1-5a18-4e1d-b12c-633ed19c8ee1"}, attributes: [translated], source-credit: "", direction: backward, attribute-values: {}}]
  let expected = [
    [name id entity role];
    ["Ko Ransom", "3192a6d6-bf15-434e-bfea-827865a3cc0a", artist, translator]
    ["NISIOISIN" "2c7b9427-6776-4969-8028-5de988724659" artist writer]
  ]
  assert equal ($input | parse_contributors | sort-by name) $expected
}

export def test_parse_musicbrainz_artist_credit_bakemonogatari_part_01 [] {
  let input = [{name: NISIOISIN, artist: {disambiguation: "Japanese novelist", id: "2c7b9427-6776-4969-8028-5de988724659", name: 西尾維新, country: JP, type-id: "b6e035f4-3ce9-331c-97df-83397230b0df", type: Person, sort-name: NISIOISIN}, joinphrase: " read by "}, {name: "Erik Kimerer", joinphrase: "", artist: {sort-name: "Kimerer, Erik", type: Person, name: "Erik Kimerer", country: US, disambiguation: "voice actor", id: "ac830008-5b9c-4f98-ae2b-cac499c40ad8", type-id: "b6e035f4-3ce9-331c-97df-83397230b0df"}}]
  let expected = [
    [index name id];
    [0 "NISIOISIN" "2c7b9427-6776-4969-8028-5de988724659"]
    [1 "Erik Kimerer" "ac830008-5b9c-4f98-ae2b-cac499c40ad8"]
  ]
  assert equal ($input | parse_musicbrainz_artist_credit) $expected
}

export def test_parse_series_from_musicbrainz_relations_bakemonogatari_part_01_work_relations [] {
  let input = [{attribute-ids: {}, begin: null, target-credit: "", target-type: artist, artist: {name: "Ko Ransom", sort-name: "Ransom, Ko", id: "3192a6d6-bf15-434e-bfea-827865a3cc0a", country: null, type-id: "b6e035f4-3ce9-331c-97df-83397230b0df", disambiguation: translator, type: Person}, ended: false, type-id: "da6c5d8a-ce13-474d-9375-61feb29039a5", source-credit: "", direction: backward, type: translator, end: null, attributes: [], attribute-values: {}}, {target-credit: NISIOISIN, begin: null, target-type: artist, artist: {name: 西尾維新, id: "2c7b9427-6776-4969-8028-5de988724659", sort-name: NISIOISIN, type-id: "b6e035f4-3ce9-331c-97df-83397230b0df", disambiguation: "Japanese novelist", type: Person, country: JP}, type-id: "a255bca1-b157-4518-9108-7b147dc3fc68", ended: false, attribute-ids: {}, end: null, type: writer, attributes: [], attribute-values: {}, source-credit: "", direction: backward}, {target-type: s, target-credit: "", begin: null, ended: false, type-id: "b0d44366-cdf0-3acb-bee6-0f65a77a6ef0", attribute-ids: {number: "a59c5830-5ec7-38fe-9a21-c7ea54f6650a"}, attributes: [number], attribute-values: {number: "1"}, ordering-key: 1, end: null, type: "part of", source-credit: "", series: {disambiguation: "light novel, English", type-id: "b689f694-6305-3d78-954d-df6759a1877b", type: "Work series", name: Bakemonogatari, id: "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322"}, direction: backward}, {direction: backward, source-credit: "", series: {disambiguation: "light novel, English", type-id: "b689f694-6305-3d78-954d-df6759a1877b", type: "Work series", name: Monogatari, id: "05ef20c8-9286-4b53-950f-eac8cbb32dc3"}, ordering-key: 1, attribute-values: {number: "1"}, attributes: [number], type: "part of", end: null, attribute-ids: {number: "a59c5830-5ec7-38fe-9a21-c7ea54f6650a"}, type-id: "b0d44366-cdf0-3acb-bee6-0f65a77a6ef0", ended: false, target-type: series, begin: null, target-credit: ""}, {source-credit: "", series: {id: "6660f123-24a0-46c7-99bf-7ff5dc11ceef", name: "Monogatari Series: First Season", type: "Work series", type-id: "b689f694-6305-3d78-954d-df6759a1877b", disambiguation: "light novel, English"}, direction: backward, ordering-key: 2, attribute-values: {number: "1"}, attributes: [number], type: "part of", end: null, attribute-ids: {number: "a59c5830-5ec7-38fe-9a21-c7ea54f6650a"}, target-type: series, begin: null, target-credit: "", type-id: "b0d44366-cdf0-3acb-bee6-0f65a77a6ef0", ended: false}, {attribute-values: {}, attributes: [], end: null, type: BookBrainz, url: {resource: "https://bookbrainz.org/work/ae3d4e16-7524-456d-a72f-318a1700b2ad", id: "817e90a9-f58e-48ce-8ea8-e3aed01ed308"}, direction: backward, source-credit: "", ended: false, type-id: "0ea7cf4e-93dd-4bc4-b748-0f1073cf951c", target-type: url, begin: null, target-credit: "", attribute-ids: {}}, {attribute-ids: {}, ended: false, type-id: "190ea031-4355-405d-a43e-53eb4c5c4ada", target-credit: "", begin: null, target-type: url, direction: backward, source-credit: "", type: "other databases", end: null, attributes: [], attribute-values: {}, url: {resource: "https://openlibrary.org/works/OL19749568W", id: "da650123-1830-464d-ae2d-3063278a5430"}}, {direction: backward, source-credit: "", end: null, type: "other databases", attributes: [], attribute-values: {}, url: {id: "08766fc9-4f13-4a68-8070-1f8c76d8530b", resource: "https://www.librarything.com/work/18801353"}, attribute-ids: {}, type-id: "190ea031-4355-405d-a43e-53eb4c5c4ada", ended: false, target-credit: "", begin: null, target-type: url}, {target-type: work, target-credit: "", begin: null, ended: false, type-id: "7440b539-19ab-4243-8c03-4f5942ca2218", attribute-ids: {translated: "ed11fcb1-5a18-4e1d-b12c-633ed19c8ee1"}, work: {title: 化物語（上）, language: null, iswcs: [], id: "35d328d1-7d5d-4c2c-a1e1-47dda806de3e", type-id: "78a8e727-edc2-35b9-8829-a46111ef6df9", attributes: [], disambiguation: "light novel", languages: [], type: Prose}, attributes: [translated], attribute-values: {}, type: "other version", end: null, source-credit: "", direction: backward}, {source-credit: "", direction: backward, attributes: [], attribute-values: {}, end: null, type: translator, attribute-ids: {}, target-type: artist, target-credit: "", begin: null, type-id: "da6c5d8a-ce13-474d-9375-61feb29039a5", ended: false, artist: {country: null, disambiguation: translator, type-id: "b6e035f4-3ce9-331c-97df-83397230b0df", type: Person, name: "Ko Ransom", id: "3192a6d6-bf15-434e-bfea-827865a3cc0a", sort-name: "Ransom, Ko"}}, {direction: backward, source-credit: "", end: null, type: writer, attribute-values: {}, attributes: [], attribute-ids: {}, artist: {sort-name: NISIOISIN, id: "2c7b9427-6776-4969-8028-5de988724659", name: 西尾維新, type: Person, type-id: "b6e035f4-3ce9-331c-97df-83397230b0df", disambiguation: "Japanese novelist", country: JP}, ended: false, type-id: "a255bca1-b157-4518-9108-7b147dc3fc68", begin: null, target-credit: NISIOISIN, target-type: artist}, {series: {disambiguation: "light novel, English", type-id: "b689f694-6305-3d78-954d-df6759a1877b", type: "Work series", name: Bakemonogatari, id: "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322"}, source-credit: "", direction: backward, type: "part of", end: null, attributes: [number], attribute-values: {number: "1"}, ordering-key: 1, attribute-ids: {number: "a59c5830-5ec7-38fe-9a21-c7ea54f6650a"}, begin: null, target-credit: "", target-type: series, type-id: "b0d44366-cdf0-3acb-bee6-0f65a77a6ef0", ended: false}, {ended: false, type-id: "b0d44366-cdf0-3acb-bee6-0f65a77a6ef0", target-type: series, target-credit: "", begin: null, attribute-ids: {number: "a59c5830-5ec7-38fe-9a21-c7ea54f6650a"}, attribute-values: {number: "1"}, ordering-key: 1, attributes: [number], end: null, type: "part of", direction: backward, source-credit: "", series: {id: "05ef20c8-9286-4b53-950f-eac8cbb32dc3", name: Monogatari, type: "Work series", type-id: "b689f694-6305-3d78-954d-df6759a1877b", disambiguation: "light novel, English"}}, {type: "part of", end: null, attributes: [number], ordering-key: 2, attribute-values: {number: "1"}, series: {type-id: "b689f694-6305-3d78-954d-df6759a1877b", disambiguation: "light novel, English", type: "Work series", name: "Monogatari Series: First Season", id: "6660f123-24a0-46c7-99bf-7ff5dc11ceef"}, source-credit: "", direction: backward, begin: null, target-credit: "", target-type: series, type-id: "b0d44366-cdf0-3acb-bee6-0f65a77a6ef0", ended: false, attribute-ids: {number: "a59c5830-5ec7-38fe-9a21-c7ea54f6650a"}}, {source-credit: "", direction: backward, url: {resource: "https://bookbrainz.org/work/ae3d4e16-7524-456d-a72f-318a1700b2ad", id: "817e90a9-f58e-48ce-8ea8-e3aed01ed308"}, attribute-values: {}, attributes: [], type: BookBrainz, end: null, attribute-ids: {}, target-type: url, begin: null, target-credit: "", type-id: "0ea7cf4e-93dd-4bc4-b748-0f1073cf951c", ended: false}, {attribute-ids: {}, target-type: url, begin: null, target-credit: "", type-id: "190ea031-4355-405d-a43e-53eb4c5c4ada", ended: false, source-credit: "", direction: backward, url: {resource: "https://openlibrary.org/works/OL19749568W", id: "da650123-1830-464d-ae2d-3063278a5430"}, attribute-values: {}, attributes: [], type: "other databases", end: null}, {ended: false, type-id: "190ea031-4355-405d-a43e-53eb4c5c4ada", begin: null, target-credit: "", target-type: url, attribute-ids: {}, end: null, type: "other databases", attribute-values: {}, attributes: [], url: {id: "08766fc9-4f13-4a68-8070-1f8c76d8530b", resource: "https://www.librarything.com/work/18801353"}, direction: backward, source-credit: ""}, {work: {languages: [], type: Prose, type-id: "78a8e727-edc2-35b9-8829-a46111ef6df9", disambiguation: "light novel", attributes: [], iswcs: [], id: "35d328d1-7d5d-4c2c-a1e1-47dda806de3e", language: null, title: 化物語（上）}, attribute-values: {}, attributes: [translated], type: "other version", end: null, source-credit: "", direction: backward, target-type: work, begin: null, target-credit: "", ended: false, type-id: "7440b539-19ab-4243-8c03-4f5942ca2218", attribute-ids: {translated: "ed11fcb1-5a18-4e1d-b12c-633ed19c8ee1"}}]
  let expected = [
    [name id index];
    ["Bakemonogatari" "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322" "1"]
    ["Monogatari" "05ef20c8-9286-4b53-950f-eac8cbb32dc3" "1"]
    ["Monogatari Series: First Season" "6660f123-24a0-46c7-99bf-7ff5dc11ceef" "1"]
  ]
  assert equal ($input | parse_series_from_musicbrainz_relations | sort-by name) $expected
}

export def test_parse_series_from_musicbrainz_release_bakemonogatari_part_01 [] {
  let input = open ([$test_data_dir "bakemonogatari_part_01_release.json"] | path join)
  let expected = [
    [name id index scope];
    ["Monogatari Series: First Season" "fb6c2a8a-9820-4e09-a0ea-9e12b8bc5e2b" "2" "release group"]
    ["Monogatari, read by Erik Kimerer, Cristina Vee, Erica Mendez & Keith Silverstein" "2c867f6d-09db-477e-99f1-aa7725239720" "2" "release group"]
    ["Bakemonogatari, read by Erik Kimerer, Cristina Vee, Erica Mendez & Keith Silverstein" "94b16acb-7f06-42e1-96ac-7ff970972238" "1" "release group"]
    ["Monogatari" "05ef20c8-9286-4b53-950f-eac8cbb32dc3" "1" "work"]
    ["Bakemonogatari" "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322" "1" "work"]
    ["Monogatari Series: First Season" "6660f123-24a0-46c7-99bf-7ff5dc11ceef" "1" "work"]
  ]
  let actual = $input | parse_series_from_musicbrainz_release
  assert equal ($actual | take 2) ($expected | take 2)
  assert equal ($actual | skip 2) ($expected | skip 2)
}

export def test_parse_audible_asin_from_musicbrainz_release_bakemonogatari_part_01 [] {
  let input = open ([$test_data_dir "bakemonogatari_part_01_release.json"] | path join)
  assert equal ($input | parse_audible_asin_from_musicbrainz_release) []
}

export def test_parse_audible_asin_from_musicbrainz_release_baccano_vol_1 [] {
  let input = open ([$test_data_dir "baccano_vol_1.json"] | path join)
  let expected = ["B0CRSPBW6X"]
  assert equal ($input | parse_audible_asin_from_musicbrainz_release) $expected
}

export def test_parse_genres_and_tags_from_musicbrainz_release_baccano_vol_1 [] {
  let input = open ([$test_data_dir "baccano_vol_1.json"] | path join)
  let expected = {
    genres: []
    tags: [
      [name count scope];
      ["light novel" 1 "release group"]
      ["unabridged" 1 "release group"]
      ["unabridged" 1 "recording"]
    ]
  }
  assert equal ($input | parse_genres_and_tags_from_musicbrainz_release) $expected
}

export def test_parse_genres_and_tags_from_musicbrainz_release_bakemonogatari_part_01 [] {
  let input = open ([$test_data_dir "bakemonogatari_part_01_release.json"] | path join)
  let expected = {
    genres: []
    tags: [
      [name count scope];
      [chapters 1 "release"]
      ["light novel" 1 "release group"]
      [unabridged 1 "release group"]
    ]
  }
  assert equal ($input | parse_genres_and_tags_from_musicbrainz_release) $expected
}

# todo Add tests for Baccano! Vol. 1 for parsing things.
export def test_parse_musicbrainz_release_baccano_vol_1 [] {
  let input = open ([$test_data_dir "baccano_vol_1.json"] | path join)
  let expected = {
    book: {
      musicbrainz_release_id: "64801f58-229a-49f9-9d2d-6a44684ebe38"
      musicbrainz_release_group_id: "4b745bd7-49f7-46d7-bf47-52e9d27b121b"
      musicbrainz_release_types: [
        other
        audiobook
      ]
      artist_credit: "Ryohgo Narita read by Michael Butler Murray"
      title: "Baccano! Vol. 1: The Rolling Bootlegs"
      contributors: [
        [name id entity role];
        ["Katsumi Enami" "9d82c45c-5383-4e19-b868-516ce05d3e60" artist illustrator]
        ["Ryohgo Narita" "efc0e95e-2d3e-4219-8ebb-28ed3751e6ab" artist "primary author"]
        ["Audible Inc." "926e2da3-af75-4571-8159-fcceb8a0aed3" label distributor]
      ]
      musicbrainz_release_country: "XW"
      musicbrainz_release_status: "official"
      amazon_asin: "B0CRSJ8RQV"
      audible_asin: "B0CRSPBW6X"
      tags: [
        [name count scope];
        ["light novel" 1 "release group"]
        [unabridged 1 "release group"]
        [unabridged 1 recording]
      ]
      publication_date: ("2024-05-14T00:00:00" | into datetime)
      series: [
        [name id index scope];
        [
          "Baccano! read by Michael Butler Murray"
          "762cd100-5319-4f9e-8a97-c7f71ae66ad7"
          "1"
          "release group"
        ]
        [
          "Baccano!"
          "c7b56e90-fdc0-4324-a399-7a4c7b534c24"
          "1"
          "work"
        ]
      ]
      front_cover_available: true
      publishers: [
        [id name];
        ["608ea796-44de-4cf2-9b2c-45a797bbabfb" "Yen Audio"]
      ]
      total_discs: 1
      total_tracks: 1
      packaging: "None"
      script: "Latn"
      language: "eng"
    }
    tracks: [
      [
        index
        disc_number
        media
        musicbrainz_track_id
        title
        musicbrainz_recording_id
        tags
        musicbrainz_works
        contributors
        duration
        artist_credit
      ];
      [
        1
        1
        "Digital Media"
        "81c1f9ae-d00d-4ac3-8dd4-058369c94ae3"
        "Baccano! Vol. 1: The Rolling Bootlegs"
        "7c7064d1-fd42-414c-a8d3-52cce1e58ad1"
        [
          [name count scope];
          [unabridged 1 recording]
        ]
        [
          [id title bookbrainz_work_id open_library_work_id wikidata_work_id];
          [
            "4b5f1fcc-1765-43c3-89f9-a20998cfb5a4"
            "Baccano!, Vol. 1: The Rolling Bootlegs"
            "7269bea2-8a0d-4290-85e8-84701d37e8df"
            OL20063674W
            null
          ]
        ]
        [
          [id, name, entity, role];
          ["efc0e95e-2d3e-4219-8ebb-28ed3751e6ab", "Ryohgo Narita", artist, writer]
          ["22c39a37-28b7-4ff2-aa0b-67f93279a1ef", "Michael Butler Murray", artist, narrator]
          ["5cfde560-3992-4706-9fad-fc20c11c97fa", "Taylor Engel", artist, translator]
        ]
        22996000000000ns
        "Ryohgo Narita read by Michael Butler Murray"
      ]
    ]
  }
  let actual = ($input | parse_musicbrainz_release)
  assert_equal_deep $actual $expected
}

export def test_parse_musicbrainz_release_bakemonogatari_part_01 [] {
  let input = open ([$test_data_dir "bakemonogatari_part_01_release.json"] | path join)
  let expected = {
    book: {
      musicbrainz_release_id: "b2c07b6e-0f22-44b1-a87a-99e0f9c9623b"
      musicbrainz_release_group_id: "b931acdb-2292-4f34-9dfa-151e33ae17a7"
      musicbrainz_release_types:
      [
        other
        audiobook
      ]
      artist_credit: "NISIOISIN illustration by VOFAN read by Erik Kimerer, Cristina Vee, Erica Mendez & Keith Silverstein"
      title: "Bakemonogatari: Monster Tale, Part 01"
      contributors: [
        [id name entity role];
        ["4448c994-30ba-4095-8b6b-6068c3cc2152" VOFAN artist illustrator]
        ["9fac1f69-0044-4b51-ad1c-6bee4c749b91" "Cristina Vee" artist narrator]
        ["91225f09-2f8e-4aee-8718-9329cac8ef03" "Erica Mendez" artist narrator]
        ["ac830008-5b9c-4f98-ae2b-cac499c40ad8" "Erik Kimerer" artist narrator]
        ["9c1e9bd5-4ded-4944-8190-1fec6e530e64" "Keith Silverstein" artist narrator]
        ["2c7b9427-6776-4969-8028-5de988724659" NISIOISIN artist "primary author"]
        ["158b7958-b872-4944-88a5-fd9d75c5d2e8" "Libro.fm" label distributor]
        ["47375c4f-1441-4e35-a700-b2d975a95b98" "Kodansha USA" label publisher]
      ]
      isbn: "9781949980523"
      musicbrainz_release_country: "XW"
      musicbrainz_release_status: "official"
      tags: [
        [name count scope];
        [chapters 1 release]
        ["light novel" 1 "release group"]
        [unabridged 1 "release group"]
      ]
      publication_date: ("2020-03-24T00:00:00" | into datetime)
      series: [
        [name id index scope];
        [
          "Monogatari Series: First Season"
          "fb6c2a8a-9820-4e09-a0ea-9e12b8bc5e2b"
          "2"
          "release group"
        ]
        [
          "Monogatari, read by Erik Kimerer, Cristina Vee, Erica Mendez & Keith Silverstein"
          "2c867f6d-09db-477e-99f1-aa7725239720"
          "2"
          "release group"
        ]
        [
          "Bakemonogatari, read by Erik Kimerer, Cristina Vee, Erica Mendez & Keith Silverstein"
          "94b16acb-7f06-42e1-96ac-7ff970972238"
          "1"
          "release group"
        ]
        [
          Monogatari
          "05ef20c8-9286-4b53-950f-eac8cbb32dc3"
          "1"
          work
        ]
        [
          Bakemonogatari
          "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322"
          "1"
          work
        ]
        [
          "Monogatari Series: First Season"
          "6660f123-24a0-46c7-99bf-7ff5dc11ceef"
          "1"
          work
        ]
      ]
      chapters: [[index, start, length, title]; [0, 0ns, 15000000000ns, "Opening Credits"], [1, 15000000000ns, 55000000000ns, Copyright], [2, 70000000000ns, 370000000000ns, "Chapter One: Hitagi Crab, Chapter 001"], [3, 440000000000ns, 904000000000ns, "Chapter One: Hitagi Crab, Chapter 002"], [4, 1344000000000ns, 1437000000000ns, "Chapter One: Hitagi Crab, Chapter 003"], [5, 2781000000000ns, 1581000000000ns, "Chapter One: Hitagi Crab, Chapter 004"], [6, 4362000000000ns, 2430000000000ns, "Chapter One: Hitagi Crab, Chapter 005"], [7, 6792000000000ns, 1958000000000ns, "Chapter One: Hitagi Crab, Chapter 006"], [8, 8750000000000ns, 692000000000ns, "Chapter One: Hitagi Crab, Chapter 007"], [9, 9442000000000ns, 68000000000ns, "Chapter One: Hitagi Crab, Chapter 008"], [10, 9510000000000ns, 439000000000ns, "Chapter Two: Mayoi Snail, Chapter 001"], [11, 9949000000000ns, 2782000000000ns, "Chapter Two: Mayoi Snail, Chapter 002"], [12, 12731000000000ns, 1420000000000ns, "Chapter Two: Mayoi Snail, Chapter 003"], [13, 14151000000000ns, 1678000000000ns, "Chapter Two: Mayoi Snail, Chapter 004"], [14, 15829000000000ns, 1863000000000ns, "Chapter Two: Mayoi Snail, Chapter 005"], [15, 17692000000000ns, 3922000000000ns, "Chapter Two: Mayoi Snail, Chapter 006"], [16, 21614000000000ns, 1354000000000ns, "Chapter Two: Mayoi Snail, Chapter 007"], [17, 22968000000000ns, 1319000000000ns, "Chapter Two: Mayoi Snail, Chapter 008"], [18, 24287000000000ns, 154000000000ns, "Chapter Two: Mayoi Snail, Chapter 009"], [19, 24441000000000ns, 230000000000ns, Afterword], [20, 24671000000000ns, 30000000000ns, "End Credits"]]
      front_cover_available: true
      publishers: [
        [id name];
        ["0ba425d2-adf8-4fb9-bc3e-2d24215f7374", "Vertical"]
      ]
      total_discs: 1
      total_tracks: 21
      packaging: "None"
      script: "Latn"
      language: "eng"
    }
    tracks: [
      [index, disc_number, media, musicbrainz_track_id, title, musicbrainz_recording_id, musicbrainz_works, contributors, duration, artist_credit]; [1, 1, "Digital Media", "1af64466-4b91-4d49-8c48-743c8bbdc542", "Opening Credits", "ddf19afa-8d0a-4d7d-95f5-c6f0ad6daaf5", [[id, title, bookbrainz_work_id, open_library_work_id, wikidata_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "ae3d4e16-7524-456d-a72f-318a1700b2ad", "OL19749568W", null]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 15000000000ns, "NISIOISIN read by Erik Kimerer"], [2, 1, "Digital Media", "7a41a13e-18f2-48a2-943e-ab65e646800b", Copyright, "19af78c6-fa48-4b1d-b211-c916dbdb29cc", [[id, title, bookbrainz_work_id, open_library_work_id, wikidata_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "ae3d4e16-7524-456d-a72f-318a1700b2ad", "OL19749568W", null]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 55000000000ns, "NISIOISIN read by Erik Kimerer"], [3, 1, "Digital Media", "ee624e13-4ba9-4ebb-ae65-f3bb4da8f09c", "Chapter One: Hitagi Crab, Chapter 001", "6a9b6fcf-bcdf-4077-9f92-21153773ae7c", [[id, title, bookbrainz_work_id, open_library_work_id, wikidata_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "ae3d4e16-7524-456d-a72f-318a1700b2ad", "OL19749568W", null]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["9fac1f69-0044-4b51-ad1c-6bee4c749b91", "Cristina Vee", artist, narrator], ["91225f09-2f8e-4aee-8718-9329cac8ef03", "Erica Mendez", artist, narrator], ["9c1e9bd5-4ded-4944-8190-1fec6e530e64", "Keith Silverstein", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 370000000000ns, "NISIOISIN read by Erik Kimerer, Cristina Vee, Erica Mendez & Keith Silverstein"], [4, 1, "Digital Media", "e54e6d65-a8ef-481a-b5cc-e1df1b34fd34", "Chapter One: Hitagi Crab, Chapter 002", "eff08c59-06fe-4b4c-8f12-923d8228fa45", [[id, title, bookbrainz_work_id, open_library_work_id, wikidata_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "ae3d4e16-7524-456d-a72f-318a1700b2ad", "OL19749568W", null]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["9fac1f69-0044-4b51-ad1c-6bee4c749b91", "Cristina Vee", artist, narrator], ["91225f09-2f8e-4aee-8718-9329cac8ef03", "Erica Mendez", artist, narrator], ["9c1e9bd5-4ded-4944-8190-1fec6e530e64", "Keith Silverstein", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 904000000000ns, "NISIOISIN read by Erik Kimerer, Cristina Vee, Erica Mendez & Keith Silverstein"], [5, 1, "Digital Media", "1fe66e7b-defe-4f6a-89ba-a63e46bd57d2", "Chapter One: Hitagi Crab, Chapter 003", "17cc0da0-ee32-4686-81b7-85202cc29775", [[id, title, bookbrainz_work_id, open_library_work_id, wikidata_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "ae3d4e16-7524-456d-a72f-318a1700b2ad", "OL19749568W", null]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["9fac1f69-0044-4b51-ad1c-6bee4c749b91", "Cristina Vee", artist, narrator], ["91225f09-2f8e-4aee-8718-9329cac8ef03", "Erica Mendez", artist, narrator], ["9c1e9bd5-4ded-4944-8190-1fec6e530e64", "Keith Silverstein", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 1437000000000ns, "NISIOISIN read by Erik Kimerer, Cristina Vee, Erica Mendez & Keith Silverstein"], [6, 1, "Digital Media", "5790db34-a353-4648-9c90-b067f4c97b18", "Chapter One: Hitagi Crab, Chapter 004", "359596d6-213a-49e2-a0b4-1c01968ca660", [[id, title, bookbrainz_work_id, open_library_work_id, wikidata_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "ae3d4e16-7524-456d-a72f-318a1700b2ad", "OL19749568W", null]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["9fac1f69-0044-4b51-ad1c-6bee4c749b91", "Cristina Vee", artist, narrator], ["91225f09-2f8e-4aee-8718-9329cac8ef03", "Erica Mendez", artist, narrator], ["9c1e9bd5-4ded-4944-8190-1fec6e530e64", "Keith Silverstein", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 1581000000000ns, "NISIOISIN read by Erik Kimerer, Cristina Vee, Erica Mendez & Keith Silverstein"], [7, 1, "Digital Media", "4a96c1b7-20a9-4e39-becf-56dfe96423a0", "Chapter One: Hitagi Crab, Chapter 005", "83fb8681-62eb-4b31-9269-bf2e2d3703d0", [[id, title, bookbrainz_work_id, open_library_work_id, wikidata_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "ae3d4e16-7524-456d-a72f-318a1700b2ad", "OL19749568W", null]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["9fac1f69-0044-4b51-ad1c-6bee4c749b91", "Cristina Vee", artist, narrator], ["91225f09-2f8e-4aee-8718-9329cac8ef03", "Erica Mendez", artist, narrator], ["9c1e9bd5-4ded-4944-8190-1fec6e530e64", "Keith Silverstein", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 2430000000000ns, "NISIOISIN read by Erik Kimerer, Cristina Vee, Erica Mendez & Keith Silverstein"], [8, 1, "Digital Media", "f68880dd-fd54-459e-a3f6-32a0c405cc93", "Chapter One: Hitagi Crab, Chapter 006", "99a7fc25-4765-4df7-951e-7f6e870cab85", [[id, title, bookbrainz_work_id, open_library_work_id, wikidata_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "ae3d4e16-7524-456d-a72f-318a1700b2ad", "OL19749568W", null]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["9fac1f69-0044-4b51-ad1c-6bee4c749b91", "Cristina Vee", artist, narrator], ["91225f09-2f8e-4aee-8718-9329cac8ef03", "Erica Mendez", artist, narrator], ["9c1e9bd5-4ded-4944-8190-1fec6e530e64", "Keith Silverstein", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 1958000000000ns, "NISIOISIN read by Erik Kimerer, Cristina Vee, Erica Mendez & Keith Silverstein"], [9, 1, "Digital Media", "46f366db-03b8-47e3-822b-e5088bdb6194", "Chapter One: Hitagi Crab, Chapter 007", "85176035-3856-443f-bb17-d602d0b6a4c0", [[id, title, bookbrainz_work_id, open_library_work_id, wikidata_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "ae3d4e16-7524-456d-a72f-318a1700b2ad", "OL19749568W", null]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["9fac1f69-0044-4b51-ad1c-6bee4c749b91", "Cristina Vee", artist, narrator], ["91225f09-2f8e-4aee-8718-9329cac8ef03", "Erica Mendez", artist, narrator], ["9c1e9bd5-4ded-4944-8190-1fec6e530e64", "Keith Silverstein", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 692000000000ns, "NISIOISIN read by Erik Kimerer, Cristina Vee, Erica Mendez & Keith Silverstein"], [10, 1, "Digital Media", "c2ee3a84-58c2-4152-a420-7d55d58bd05e", "Chapter One: Hitagi Crab, Chapter 008", "a201d5c4-a6f7-4609-abc2-dcb54052c7ea", [[id, title, bookbrainz_work_id, open_library_work_id, wikidata_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "ae3d4e16-7524-456d-a72f-318a1700b2ad", "OL19749568W", null]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["9fac1f69-0044-4b51-ad1c-6bee4c749b91", "Cristina Vee", artist, narrator], ["91225f09-2f8e-4aee-8718-9329cac8ef03", "Erica Mendez", artist, narrator], ["9c1e9bd5-4ded-4944-8190-1fec6e530e64", "Keith Silverstein", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 68000000000ns, "NISIOISIN read by Erik Kimerer, Cristina Vee, Erica Mendez & Keith Silverstein"], [11, 1, "Digital Media", "88981d2d-9af9-4bf9-a96a-e040b9afe48b", "Chapter Two: Mayoi Snail, Chapter 001", "59f48ed4-bfbf-4b4c-8df5-d5133366da4d", [[id, title, bookbrainz_work_id, open_library_work_id, wikidata_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "ae3d4e16-7524-456d-a72f-318a1700b2ad", "OL19749568W", null]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["9fac1f69-0044-4b51-ad1c-6bee4c749b91", "Cristina Vee", artist, narrator], ["91225f09-2f8e-4aee-8718-9329cac8ef03", "Erica Mendez", artist, narrator], ["9c1e9bd5-4ded-4944-8190-1fec6e530e64", "Keith Silverstein", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 439000000000ns, "NISIOISIN read by Erik Kimerer, Cristina Vee, Erica Mendez & Keith Silverstein"], [12, 1, "Digital Media", "c11d5faa-4893-4825-98b3-c1b200957800", "Chapter Two: Mayoi Snail, Chapter 002", "bda5b5e5-9ed2-4ce2-9221-c8797e1247d8", [[id, title, bookbrainz_work_id, open_library_work_id, wikidata_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "ae3d4e16-7524-456d-a72f-318a1700b2ad", "OL19749568W", null]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["9fac1f69-0044-4b51-ad1c-6bee4c749b91", "Cristina Vee", artist, narrator], ["91225f09-2f8e-4aee-8718-9329cac8ef03", "Erica Mendez", artist, narrator], ["9c1e9bd5-4ded-4944-8190-1fec6e530e64", "Keith Silverstein", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 2782000000000ns, "NISIOISIN read by Erik Kimerer, Cristina Vee, Erica Mendez & Keith Silverstein"], [13, 1, "Digital Media", "ce379ad4-e31c-4ae8-83ea-c5ebe4ed57ec", "Chapter Two: Mayoi Snail, Chapter 003", "6dee17b8-2198-44df-8841-a0f311771623", [[id, title, bookbrainz_work_id, open_library_work_id, wikidata_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "ae3d4e16-7524-456d-a72f-318a1700b2ad", "OL19749568W", null]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["9fac1f69-0044-4b51-ad1c-6bee4c749b91", "Cristina Vee", artist, narrator], ["91225f09-2f8e-4aee-8718-9329cac8ef03", "Erica Mendez", artist, narrator], ["9c1e9bd5-4ded-4944-8190-1fec6e530e64", "Keith Silverstein", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 1420000000000ns, "NISIOISIN read by Erik Kimerer, Cristina Vee, Erica Mendez & Keith Silverstein"], [14, 1, "Digital Media", "a6a8838d-4b2f-4e4c-8c3b-58b6aa2df200", "Chapter Two: Mayoi Snail, Chapter 004", "01aadb9b-055c-4839-b8da-b7f146493b23", [[id, title, bookbrainz_work_id, open_library_work_id, wikidata_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "ae3d4e16-7524-456d-a72f-318a1700b2ad", "OL19749568W", null]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["9fac1f69-0044-4b51-ad1c-6bee4c749b91", "Cristina Vee", artist, narrator], ["91225f09-2f8e-4aee-8718-9329cac8ef03", "Erica Mendez", artist, narrator], ["9c1e9bd5-4ded-4944-8190-1fec6e530e64", "Keith Silverstein", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 1678000000000ns, "NISIOISIN read by Erik Kimerer, Cristina Vee, Erica Mendez & Keith Silverstein"], [15, 1, "Digital Media", "c688dcc3-5200-4fd7-8566-15fc29b75c09", "Chapter Two: Mayoi Snail, Chapter 005", "7feca352-c937-4220-8dee-28ebfaa3bc6d", [[id, title, bookbrainz_work_id, open_library_work_id, wikidata_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "ae3d4e16-7524-456d-a72f-318a1700b2ad", "OL19749568W", null]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["9fac1f69-0044-4b51-ad1c-6bee4c749b91", "Cristina Vee", artist, narrator], ["91225f09-2f8e-4aee-8718-9329cac8ef03", "Erica Mendez", artist, narrator], ["9c1e9bd5-4ded-4944-8190-1fec6e530e64", "Keith Silverstein", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 1863000000000ns, "NISIOISIN read by Erik Kimerer, Cristina Vee, Erica Mendez & Keith Silverstein"], [16, 1, "Digital Media", "9822b36c-d3dc-4f4a-b200-5519c09fae62", "Chapter Two: Mayoi Snail, Chapter 006", "5798acc6-7724-4af8-9078-89c475a12ed2", [[id, title, bookbrainz_work_id, open_library_work_id, wikidata_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "ae3d4e16-7524-456d-a72f-318a1700b2ad", "OL19749568W", null]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["9fac1f69-0044-4b51-ad1c-6bee4c749b91", "Cristina Vee", artist, narrator], ["91225f09-2f8e-4aee-8718-9329cac8ef03", "Erica Mendez", artist, narrator], ["9c1e9bd5-4ded-4944-8190-1fec6e530e64", "Keith Silverstein", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 3922000000000ns, "NISIOISIN read by Erik Kimerer, Cristina Vee, Erica Mendez & Keith Silverstein"], [17, 1, "Digital Media", "9e2f4206-f380-4a50-8d3f-43faf675e429", "Chapter Two: Mayoi Snail, Chapter 007", "d3396b1a-5896-4c39-b5d9-37d478a7f4f9", [[id, title, bookbrainz_work_id, open_library_work_id, wikidata_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "ae3d4e16-7524-456d-a72f-318a1700b2ad", "OL19749568W", null]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["9fac1f69-0044-4b51-ad1c-6bee4c749b91", "Cristina Vee", artist, narrator], ["91225f09-2f8e-4aee-8718-9329cac8ef03", "Erica Mendez", artist, narrator], ["9c1e9bd5-4ded-4944-8190-1fec6e530e64", "Keith Silverstein", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 1354000000000ns, "NISIOISIN read by Erik Kimerer, Cristina Vee, Erica Mendez & Keith Silverstein"], [18, 1, "Digital Media", "85e22b41-9038-4fe0-acaa-adfd8d5d60c5", "Chapter Two: Mayoi Snail, Chapter 008", "60ee765c-41d4-477a-b6b4-85d280c953d5", [[id, title, bookbrainz_work_id, open_library_work_id, wikidata_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "ae3d4e16-7524-456d-a72f-318a1700b2ad", "OL19749568W", null]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["9fac1f69-0044-4b51-ad1c-6bee4c749b91", "Cristina Vee", artist, narrator], ["91225f09-2f8e-4aee-8718-9329cac8ef03", "Erica Mendez", artist, narrator], ["9c1e9bd5-4ded-4944-8190-1fec6e530e64", "Keith Silverstein", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 1319000000000ns, "NISIOISIN read by Erik Kimerer, Cristina Vee, Erica Mendez & Keith Silverstein"], [19, 1, "Digital Media", "1948d583-f1c3-4997-9234-fe96479dd0a5", "Chapter Two: Mayoi Snail, Chapter 009", "88df0c01-8617-4796-a41b-ad4463fd0cc7", [[id, title, bookbrainz_work_id, open_library_work_id, wikidata_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "ae3d4e16-7524-456d-a72f-318a1700b2ad", "OL19749568W", null]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["9fac1f69-0044-4b51-ad1c-6bee4c749b91", "Cristina Vee", artist, narrator], ["91225f09-2f8e-4aee-8718-9329cac8ef03", "Erica Mendez", artist, narrator], ["9c1e9bd5-4ded-4944-8190-1fec6e530e64", "Keith Silverstein", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 154000000000ns, "NISIOISIN read by Erik Kimerer, Cristina Vee, Erica Mendez & Keith Silverstein"], [20, 1, "Digital Media", "0146128e-31d1-4e37-be88-cebc09f178dd", Afterword, "5b57067e-a537-4075-bb59-2240af0fcc97", [[id, title, bookbrainz_work_id, open_library_work_id, wikidata_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "ae3d4e16-7524-456d-a72f-318a1700b2ad", "OL19749568W", null]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["ac830008-5b9c-4f98-ae2b-cac499c40ad8", "Erik Kimerer", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 230000000000ns, "NISIOISIN read by Erik Kimerer"], [21, 1, "Digital Media", "ab132164-d144-4c71-97f1-b35966da72a5", "End Credits", "3b927907-6b99-4437-920c-70f387a0437e", [[id, title, bookbrainz_work_id, open_library_work_id, wikidata_work_id]; ["1f1a315c-49fe-4d4c-9c07-1903a113f984", "Bakemonogatari: Monster Tale, Part 01", "ae3d4e16-7524-456d-a72f-318a1700b2ad", "OL19749568W", null]], [[id, name, entity, role]; ["2c7b9427-6776-4969-8028-5de988724659", NISIOISIN, artist, writer], ["9c1e9bd5-4ded-4944-8190-1fec6e530e64", "Keith Silverstein", artist, narrator], ["b4641041-b9f9-4baa-a463-d2c5c7ec9dfe", "Brandon Schuster", artist, engineer], ["3192a6d6-bf15-434e-bfea-827865a3cc0a", "Ko Ransom", artist, translator], ["86fd3cfe-7eb8-47f8-a87c-1c668cff97a5", "Steve Staley", artist, director]], 30000000000ns, "NISIOISIN read by Keith Silverstein"]
    ]
  }
  let actual = ($input | parse_musicbrainz_release)
  assert_equal_deep $actual $expected
}

export def test_parse_musicbrainz_series_monogatari_work [] {
  let input = open ([$test_data_dir "monogatari_work_series.json"] | path join)
  let expected = {
    id: "05ef20c8-9286-4b53-950f-eac8cbb32dc3"
    name: "Monogatari"
    parent_series: []
    subseries: [
      [id name];
      ["4c7a3056-279a-451d-a7ee-3f6f6536f1f0" "Nekomonogatari"]
      ["6660f123-24a0-46c7-99bf-7ff5dc11ceef" "Monogatari Series: First Season"]
      ["b3e14bc3-014f-438b-b5c6-6b38081334ad" "Monogatari Series: Second Season"]
    ]
    genres: [
      [name, count];
      [fiction, 1],
      [mystery, 1],
      [paranormal, 1],
      [psychological, 1],
      [romance, 1],
      ["school life", 1],
      [supernatural, 1],
      [vampire, 1]
    ]
    tags: [
      [name, count];
      ["light novel", 1],
    ]
  }
  assert equal ($input | parse_musicbrainz_series) $expected
}

export def test_parse_musicbrainz_series_monogatari_first_season_work [] {
  let input = open ([$test_data_dir "monogatari_first_season_work_series.json"] | path join)
  let expected = {
    id: "6660f123-24a0-46c7-99bf-7ff5dc11ceef"
    name: "Monogatari Series: First Season"
    parent_series: [
      [id name];
      ["05ef20c8-9286-4b53-950f-eac8cbb32dc3" "Monogatari"]
    ]
    subseries: [
      [id name];
      ["0ee55526-d9a0-4d3d-9f6a-f46dc19c8322" "Bakemonogatari"]
    ]
    genres: [
      [name, count];
      [fiction, 1],
      [mystery, 1],
      [paranormal, 1],
      [psychological, 1],
      [romance, 1],
      ["school life", 1],
      [supernatural, 1],
      [vampire, 1]
    ]
    tags: [
      [name, count];
      ["light novel", 1],
    ]
  }
  assert equal ($input | parse_musicbrainz_series) $expected
}

export def test_parse_musicbrainz_series_bakemonogatari_work [] {
  let input = open ([$test_data_dir "bakemonogatari_work_series.json"] | path join)
  let expected = {
    id: "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322"
    name: "Bakemonogatari"
    parent_series: [
      [id name];
      ["6660f123-24a0-46c7-99bf-7ff5dc11ceef" "Monogatari Series: First Season"]
    ]
    subseries: []
    genres: [
      [name, count];
      [fiction, 1],
      [mystery, 1],
      [paranormal, 1],
      [psychological, 1],
      [romance, 1],
      ["school life", 1],
      ["speculative fiction", 1],
      [vampire, 1]
    ]
    tags: [
      [name, count];
      ["light novel", 1],
    ]
  }
  assert equal ($input | parse_musicbrainz_series) $expected
}

export def test_fetch_and_parse_musicbrainz_series_cached [] {
  let cache = {|type, series_id, update|
    if ($series_id == "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322") {
      {
        id: "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322"
        name: "Bakemonogatari"
        parent_series: [
          [id name];
          ["6660f123-24a0-46c7-99bf-7ff5dc11ceef" "Monogatari Series: First Season"]
        ]
        subseries: []
        genres: [
          [name, count];
          [fiction, 1],
          ["light novel", 1],
          [mystery, 1],
          [paranormal, 1],
          [psychological, 1],
          [romance, 1],
          ["school life", 1],
          ["speculative fiction", 1],
          [vampire, 1]
        ]
        tags: []
      }
    }
  }
  let expected = {
    id: "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322"
    name: "Bakemonogatari"
    parent_series: [
      [id name];
      ["6660f123-24a0-46c7-99bf-7ff5dc11ceef" "Monogatari Series: First Season"]
    ]
    subseries: []
    genres: [
      [name, count];
      [fiction, 1],
      ["light novel", 1],
      [mystery, 1],
      [paranormal, 1],
      [psychological, 1],
      [romance, 1],
      ["school life", 1],
      ["speculative fiction", 1],
      [vampire, 1]
    ]
    tags: []
  }
  assert equal ("0ee55526-d9a0-4d3d-9f6a-f46dc19c8322" | fetch_and_parse_musicbrainz_series $cache) $expected
}

export def test_build_series_tree_up_three_levels [] {
  let monogatari_series_cache = {|type series_id, update|
    if $series_id == "05ef20c8-9286-4b53-950f-eac8cbb32dc3" {
      {
        id: "05ef20c8-9286-4b53-950f-eac8cbb32dc3"
        name: "Monogatari"
        parent_series: []
        subseries: [
          [id name];
          ["4c7a3056-279a-451d-a7ee-3f6f6536f1f0" "Nekomonogatari"]
          ["6660f123-24a0-46c7-99bf-7ff5dc11ceef" "Monogatari Series: First Season"]
          ["b3e14bc3-014f-438b-b5c6-6b38081334ad" "Monogatari Series: Second Season"]
        ]
        genres: [
          [name, count];
          [fiction, 1],
          ["light novel", 1],
          [mystery, 1],
          [paranormal, 1],
          [psychological, 1],
          [romance, 1],
          ["school life", 1],
          [supernatural, 1],
          [vampire, 1]
        ]
        tags: []
      }
    } else if $series_id == "6660f123-24a0-46c7-99bf-7ff5dc11ceef" {
      {
        id: "6660f123-24a0-46c7-99bf-7ff5dc11ceef"
        name: "Monogatari Series: First Season"
        parent_series: [
          [id name];
          ["05ef20c8-9286-4b53-950f-eac8cbb32dc3" "Monogatari"]
        ]
        subseries: [
          [id name];
          ["0ee55526-d9a0-4d3d-9f6a-f46dc19c8322" "Bakemonogatari"]
        ]
        genres: [
          [name, count];
          [fiction, 1],
          ["light novel", 1],
          [mystery, 1],
          [paranormal, 1],
          [psychological, 1],
          [romance, 1],
          ["school life", 1],
          [supernatural, 1],
          [vampire, 1]
        ]
        tags: []
      }
    } else if $series_id == "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322" {
      {
        id: "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322"
        name: "Bakemonogatari"
        parent_series: [
          [id name];
          ["6660f123-24a0-46c7-99bf-7ff5dc11ceef" "Monogatari Series: First Season"]
        ]
        subseries: []
        genres: [
          [name, count];
          [fiction, 1],
          ["light novel", 1],
          [mystery, 1],
          [paranormal, 1],
          [psychological, 1],
          [romance, 1],
          ["school life", 1],
          ["speculative fiction", 1],
          [vampire, 1]
        ]
        tags: []
      }
    }
  }
  let expected = {
    id: "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322"
    name: "Bakemonogatari"
    parent_series: [
      [id name parent_series subseries genres tags];
      [
        "6660f123-24a0-46c7-99bf-7ff5dc11ceef"
        "Monogatari Series: First Season"
        [
          [id name parent_series subseries genres tags];
          [
            "05ef20c8-9286-4b53-950f-eac8cbb32dc3"
            "Monogatari"
            []
            [
              [id name];
              ["4c7a3056-279a-451d-a7ee-3f6f6536f1f0" "Nekomonogatari"]
              ["6660f123-24a0-46c7-99bf-7ff5dc11ceef" "Monogatari Series: First Season"]
              ["b3e14bc3-014f-438b-b5c6-6b38081334ad" "Monogatari Series: Second Season"]
            ]
            [
              [name, count];
              [fiction, 1],
              ["light novel", 1],
              [mystery, 1],
              [paranormal, 1],
              [psychological, 1],
              [romance, 1],
              ["school life", 1],
              [supernatural, 1],
              [vampire, 1]
            ]
            []
          ]
        ]
        [
          [id name];
          ["0ee55526-d9a0-4d3d-9f6a-f46dc19c8322" "Bakemonogatari"]
        ]
        [
          [name, count];
          [fiction, 1],
          ["light novel", 1],
          [mystery, 1],
          [paranormal, 1],
          [psychological, 1],
          [romance, 1],
          ["school life", 1],
          [supernatural, 1],
          [vampire, 1]
        ]
        []
      ]
    ]
    subseries: []
    genres: [
      [name, count];
      [fiction, 1],
      ["light novel", 1],
      [mystery, 1],
      [paranormal, 1],
      [psychological, 1],
      [romance, 1],
      ["school life", 1],
      ["speculative fiction", 1],
      [vampire, 1]
    ]
    tags: []
  }
  let input = {
    id: "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322"
    name: "Bakemonogatari"
    parent_series: [
      [id name];
      ["6660f123-24a0-46c7-99bf-7ff5dc11ceef" "Monogatari Series: First Season"]
    ]
    subseries: []
    genres: [
      [name, count];
      [fiction, 1],
      ["light novel", 1],
      [mystery, 1],
      [paranormal, 1],
      [psychological, 1],
      [romance, 1],
      ["school life", 1],
      ["speculative fiction", 1],
      [vampire, 1]
    ]
    tags: []
  }
  assert equal ($input | build_series_tree_up 5 $monogatari_series_cache) $expected
}

export def test_build_series_tree_up_three_levels_2 [] {
  let monogatari_series_cache = {|type series_id, update|
    log info $"$series_id: ($series_id)"
    if $series_id == "05ef20c8-9286-4b53-950f-eac8cbb32dc3" {
      {
        id: "05ef20c8-9286-4b53-950f-eac8cbb32dc3"
        name: "Monogatari"
        parent_series: []
        subseries: [
          [id name];
          ["4c7a3056-279a-451d-a7ee-3f6f6536f1f0" "Nekomonogatari"]
          ["6660f123-24a0-46c7-99bf-7ff5dc11ceef" "Monogatari Series: First Season"]
          ["b3e14bc3-014f-438b-b5c6-6b38081334ad" "Monogatari Series: Second Season"]
        ]
        genres: [
          [name, count];
          [fiction, 1],
          ["light novel", 1],
          [mystery, 1],
          [paranormal, 1],
          [psychological, 1],
          [romance, 1],
          ["school life", 1],
          [supernatural, 1],
          [vampire, 1]
        ]
        tags: []
      }
    } else if $series_id == "6660f123-24a0-46c7-99bf-7ff5dc11ceef" {
      {
        id: "6660f123-24a0-46c7-99bf-7ff5dc11ceef"
        name: "Monogatari Series: First Season"
        parent_series: [
          [id name];
          ["05ef20c8-9286-4b53-950f-eac8cbb32dc3" "Monogatari"]
        ]
        subseries: [
          [id name];
          ["0ee55526-d9a0-4d3d-9f6a-f46dc19c8322" "Bakemonogatari"]
        ]
        genres: [
          [name, count];
          [fiction, 1],
          ["light novel", 1],
          [mystery, 1],
          [paranormal, 1],
          [psychological, 1],
          [romance, 1],
          ["school life", 1],
          [supernatural, 1],
          [vampire, 1]
        ]
        tags: []
      }
    } else if $series_id == "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322" {
      {
        id: "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322"
        name: "Bakemonogatari"
        parent_series: [
          [id name];
          ["6660f123-24a0-46c7-99bf-7ff5dc11ceef" "Monogatari Series: First Season"]
        ]
        subseries: []
        genres: [
          [name, count];
          [fiction, 1],
          ["light novel", 1],
          [mystery, 1],
          [paranormal, 1],
          [psychological, 1],
          [romance, 1],
          ["school life", 1],
          ["speculative fiction", 1],
          [vampire, 1]
        ]
        tags: []
      }
    }
  }
  let expected = {
    id: "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322"
    name: "Bakemonogatari"
    parent_series: [
      [id name parent_series subseries genres tags];
      [
        "6660f123-24a0-46c7-99bf-7ff5dc11ceef"
        "Monogatari Series: First Season"
        [
          [id name parent_series subseries genres tags];
          [
            "05ef20c8-9286-4b53-950f-eac8cbb32dc3"
            "Monogatari"
            []
            [
              [id name];
              ["4c7a3056-279a-451d-a7ee-3f6f6536f1f0" "Nekomonogatari"]
              ["6660f123-24a0-46c7-99bf-7ff5dc11ceef" "Monogatari Series: First Season"]
              ["b3e14bc3-014f-438b-b5c6-6b38081334ad" "Monogatari Series: Second Season"]
            ]
            [
              [name, count];
              [fiction, 1],
              ["light novel", 1],
              [mystery, 1],
              [paranormal, 1],
              [psychological, 1],
              [romance, 1],
              ["school life", 1],
              [supernatural, 1],
              [vampire, 1]
            ]
            []
          ]
        ]
        [
          [id name];
          ["0ee55526-d9a0-4d3d-9f6a-f46dc19c8322" "Bakemonogatari"]
        ]
        [
          [name, count];
          [fiction, 1],
          ["light novel", 1],
          [mystery, 1],
          [paranormal, 1],
          [psychological, 1],
          [romance, 1],
          ["school life", 1],
          [supernatural, 1],
          [vampire, 1]
        ]
        []
      ]
    ]
    subseries: []
    genres: [
      [name, count];
      [fiction, 1],
      ["light novel", 1],
      [mystery, 1],
      [paranormal, 1],
      [psychological, 1],
      [romance, 1],
      ["school life", 1],
      ["speculative fiction", 1],
      [vampire, 1]
    ]
    tags: []
  }
  let input = {
    id: "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322"
    name: "Bakemonogatari"
    parent_series: [
      [id name];
      ["6660f123-24a0-46c7-99bf-7ff5dc11ceef" "Monogatari Series: First Season"]
    ]
    subseries: []
    genres: [
      [name, count];
      [fiction, 1],
      ["light novel", 1],
      [mystery, 1],
      [paranormal, 1],
      [psychological, 1],
      [romance, 1],
      ["school life", 1],
      ["speculative fiction", 1],
      [vampire, 1]
    ]
    tags: []
  }
  assert equal ($input | build_series_tree_up 5 $monogatari_series_cache) $expected
}

# def test_build_series_tree_up_max_depth [] {
#   let expected = {
#     id: "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322"
#     name: "Bakemonogatari"
#     parent_series: [
#       [id name parent_series subseries genres tags];
#       [
#         "6660f123-24a0-46c7-99bf-7ff5dc11ceef"
#         "Monogatari Series: First Season"
#         [
#           # [id name];
#           # ["05ef20c8-9286-4b53-950f-eac8cbb32dc3" "Monogatari"]
#           [id name parent_series subseries genres tags];
#           [
#             "05ef20c8-9286-4b53-950f-eac8cbb32dc3"
#             "Monogatari"
#             []
#             [
#               [id name];
#               ["4c7a3056-279a-451d-a7ee-3f6f6536f1f0" "Nekomonogatari"]
#               ["6660f123-24a0-46c7-99bf-7ff5dc11ceef" "Monogatari Series: First Season"]
#               ["b3e14bc3-014f-438b-b5c6-6b38081334ad" "Monogatari Series: Second Season"]
#             ]
#             [
#               [name, count];
#               [fiction, 1],
#               ["light novel", 1],
#               [mystery, 1],
#               [paranormal, 1],
#               [psychological, 1],
#               [romance, 1],
#               ["school life", 1],
#               [supernatural, 1],
#               [vampire, 1]
#             ]
#             []
#           ]
#         ]
#         [
#           [id name];
#           ["0ee55526-d9a0-4d3d-9f6a-f46dc19c8322" "Bakemonogatari"]
#         ]
#         [
#           [name, count];
#           [fiction, 1],
#           ["light novel", 1],
#           [mystery, 1],
#           [paranormal, 1],
#           [psychological, 1],
#           [romance, 1],
#           ["school life", 1],
#           [supernatural, 1],
#           [vampire, 1]
#         ]
#         []
#       ]
#     ]
#     subseries: []
#     genres: [
#       [name, count];
#       [fiction, 1],
#       ["light novel", 1],
#       [mystery, 1],
#       [paranormal, 1],
#       [psychological, 1],
#       [romance, 1],
#       ["school life", 1],
#       ["speculative fiction", 1],
#       [vampire, 1]
#     ]
#     tags: []
#   }
#   let input = {
#     id: "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322"
#     name: "Bakemonogatari"
#     parent_series: [
#       [id name];
#       ["6660f123-24a0-46c7-99bf-7ff5dc11ceef" "Monogatari Series: First Season"]
#     ]
#     subseries: []
#     genres: [
#       [name, count];
#       [fiction, 1],
#       ["light novel", 1],
#       [mystery, 1],
#       [paranormal, 1],
#       [psychological, 1],
#       [romance, 1],
#       ["school life", 1],
#       ["speculative fiction", 1],
#       [vampire, 1]
#     ]
#     tags: []
#   }
#   assert equal ($input | build_series_tree_up 4 $monogatari_series_cache) $expected
# }

# Not exported, so the test runner skips it.
# organize_subseries is recursive and triggers a Nushell bug with recursive functions.
def test_organize_subseries_two_subseries [] {
  let input = [
    [id name parent_series subseries genres tags];
    [
      "05ef20c8-9286-4b53-950f-eac8cbb32dc3"
      "Monogatari"
      []
      [
        [id name];
        ["4c7a3056-279a-451d-a7ee-3f6f6536f1f0" "Nekomonogatari"]
        ["6660f123-24a0-46c7-99bf-7ff5dc11ceef" "Monogatari Series: First Season"]
        ["b3e14bc3-014f-438b-b5c6-6b38081334ad" "Monogatari Series: Second Season"]
      ]
      [
        [name, count];
        [fiction, 1],
        ["light novel", 1],
        [mystery, 1],
        [paranormal, 1],
        [psychological, 1],
        [romance, 1],
        ["school life", 1],
        [supernatural, 1],
        [vampire, 1]
      ]
      []
    ]
    [
      "6660f123-24a0-46c7-99bf-7ff5dc11ceef"
      "Monogatari Series: First Season"
      [
        [id name];
        ["05ef20c8-9286-4b53-950f-eac8cbb32dc3" "Monogatari"]
      ]
      [
        [id name];
        ["0ee55526-d9a0-4d3d-9f6a-f46dc19c8322" "Bakemonogatari"]
      ]
      [
        [name, count];
        [fiction, 1],
        ["light novel", 1],
        [mystery, 1],
        [paranormal, 1],
        [psychological, 1],
        [romance, 1],
        ["school life", 1],
        [supernatural, 1],
        [vampire, 1]
      ]
      []
    ]
    [
      "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322"
      "Bakemonogatari"
      [
        [id name];
        ["6660f123-24a0-46c7-99bf-7ff5dc11ceef" "Monogatari Series: First Season"]
      ]
      []
      [
        [name, count];
        [fiction, 1],
        ["light novel", 1],
        [mystery, 1],
        [paranormal, 1],
        [psychological, 1],
        [romance, 1],
        ["school life", 1],
        ["speculative fiction", 1],
        [vampire, 1]
      ]
      []
    ]
  ]
  let expected = [
    [id name parent_series subseries genres tags];
    [
      "05ef20c8-9286-4b53-950f-eac8cbb32dc3"
      "Monogatari"
      []
      [
        [id name];
        ["4c7a3056-279a-451d-a7ee-3f6f6536f1f0" "Nekomonogatari"]
        ["6660f123-24a0-46c7-99bf-7ff5dc11ceef" "Monogatari Series: First Season"]
        ["b3e14bc3-014f-438b-b5c6-6b38081334ad" "Monogatari Series: Second Season"]
      ]
      [
        [name, count];
        [fiction, 1],
        ["light novel", 1],
        [mystery, 1],
        [paranormal, 1],
        [psychological, 1],
        [romance, 1],
        ["school life", 1],
        [supernatural, 1],
        [vampire, 1]
      ]
      []
    ]
    [
      "6660f123-24a0-46c7-99bf-7ff5dc11ceef"
      "Monogatari Series: First Season"
      [
        [id name];
        ["05ef20c8-9286-4b53-950f-eac8cbb32dc3" "Monogatari"]
      ]
      [
        [id name];
        ["0ee55526-d9a0-4d3d-9f6a-f46dc19c8322" "Bakemonogatari"]
      ]
      [
        [name, count];
        [fiction, 1],
        ["light novel", 1],
        [mystery, 1],
        [paranormal, 1],
        [psychological, 1],
        [romance, 1],
        ["school life", 1],
        [supernatural, 1],
        [vampire, 1]
      ]
      []
    ]
    [
      "0ee55526-d9a0-4d3d-9f6a-f46dc19c8322"
      "Bakemonogatari"
      [
        [id name];
        ["6660f123-24a0-46c7-99bf-7ff5dc11ceef" "Monogatari Series: First Season"]
      ]
      []
      [
        [name, count];
        [fiction, 1],
        ["light novel", 1],
        [mystery, 1],
        [paranormal, 1],
        [psychological, 1],
        [romance, 1],
        ["school life", 1],
        ["speculative fiction", 1],
        [vampire, 1]
      ]
      []
    ]
  ]
  assert equal ($input | organize_subseries) $expected
}

export def test_parse_musicbrainz_work_c7a83643-33a3-48ab-b54e-f56554359802 [] {
  let input = open ([$test_data_dir "work_c7a83643-33a3-48ab-b54e-f56554359802.json"] | path join)
  let expected = {
    id: "c7a83643-33a3-48ab-b54e-f56554359802"
    title: "Full Metal Panic! Volume 1: Fighting Boy Meets Girl"
    language: "eng"
    genres: [
      [name, count];
      [action, 1],
      [fiction, 1],
      [mecha, 1],
      [military, 1]
    ]
    tags: [
      [name, count];
      ["light novel", 1],
    ]
  }
  assert equal ($input | parse_musicbrainz_work) $expected
}

export def test_escape_special_lucene_characters_empty_input [] {
  let input = ""
  let expected = ""
  assert equal ($input | escape_special_lucene_characters) $expected
}

export def test_escape_special_lucene_characters_escape_backslash [] {
  let input = 'The \Backslash'
  let expected = 'The \\Backslash'
  assert equal ($input | escape_special_lucene_characters) $expected
}

export def test_escape_special_lucene_characters_escape_all_special_characters [] {
  let input = 'Whoa, there is/are a lot of special-characters to escape like ^, ~, ", *, +, \, am I right!? {[(&&Yikes:||)]}'
  let expected = 'Whoa, there is\/are a lot of special\-characters to escape like \^, \~, \", \*, \+, \\, am I right\!\? \{\[\(\&&Yikes\:\||\)\]\}'
  assert equal ($input | escape_special_lucene_characters) $expected
}

export def test_append_to_musicbrainz_query_empty_input [] {
  let input = ""
  let metadata = {
    musicbrainz_release_country: "WX"
  }
  let expected = 'country:"WX"'
  assert equal ($input | append_to_musicbrainz_query $metadata musicbrainz_release_country country) $expected
}

export def test_append_to_musicbrainz_query_empty_metadata [] {
  let input = ""
  let metadata = {}
  let expected = ""
  assert equal ($input | append_to_musicbrainz_query $metadata musicbrainz_release_country country) $expected
}

export def test_append_to_musicbrainz_query_existing_input [] {
  let input = 'country:"WX"'
  let metadata = {
    musicbrainz_release_country: "WX"
    language: "eng"
  }
  let expected = 'country:"WX" AND lang:"eng"'
  assert equal ($input | append_to_musicbrainz_query $metadata language lang) $expected
}

export def test_append_to_musicbrainz_query_existing_input_with_transform [] {
  let input = 'country:"WX"'
  let metadata = {
    musicbrainz_release_country: "WX"
    language: "english"
  }
  let expected = 'country:"WX" AND lang:"eng"'
  let transform = {|language| if $language == "english" {"eng"} else {$language}}
  assert equal ($input | append_to_musicbrainz_query $metadata language lang --transform $transform) $expected
}

export def test_artist_credit_to_string_bakemonogatari_part_01 [] {
  let input = [
    {
      "joinphrase": " illustration by ",
      "name": "NISIOISIN",
      "artist": {
        "type-id": "b6e035f4-3ce9-331c-97df-83397230b0df",
        "id": "2c7b9427-6776-4969-8028-5de988724659",
        "name": "西尾維新",
        "aliases": [
          {
            "primary": true,
            "sort-name": "NISIOISIN",
            "ended": false,
            "type": "Artist name",
            "end": null,
            "name": "NISIOISIN",
            "locale": "en",
            "begin": null,
            "type-id": "894afba6-2816-3c24-8072-eadb66bd04bc"
          },
          {
            "locale": "en",
            "name": "Nishio Ishin",
            "type-id": "894afba6-2816-3c24-8072-eadb66bd04bc",
            "begin": null,
            "end": null,
            "sort-name": "Nishio Ishin",
            "primary": false,
            "ended": false,
            "type": "Artist name"
          },
          {
            "type-id": "894afba6-2816-3c24-8072-eadb66bd04bc",
            "begin": null,
            "name": "Nisio Isin",
            "locale": "en",
            "primary": false,
            "sort-name": "Isin, Nisio",
            "ended": false,
            "type": "Artist name",
            "end": null
          }
        ],
        "tags": [],
        "genres": [],
        "country": "JP",
        "sort-name": "NISIOISIN",
        "type": "Person",
        "disambiguation": "Japanese novelist"
      }
    },
    {
      "joinphrase": " read by ",
      "name": "VOFAN",
      "artist": {
        "country": "TW",
        "genres": [],
        "tags": [],
        "disambiguation": "Taiwanese illustrator",
        "type": "Person",
        "sort-name": "VOFAN",
        "id": "4448c994-30ba-4095-8b6b-6068c3cc2152",
        "type-id": "b6e035f4-3ce9-331c-97df-83397230b0df",
        "aliases": [
          {
            "begin": null,
            "type-id": "d4dcd0c0-b341-3612-a332-c0ce797b25cf",
            "locale": "en",
            "name": "Yuanheng Dai",
            "end": null,
            "ended": false,
            "type": "Legal name",
            "primary": false,
            "sort-name": "Dai, Yuanheng"
          },
          {
            "begin": null,
            "type-id": "894afba6-2816-3c24-8072-eadb66bd04bc",
            "locale": "ja",
            "name": "戴源亨",
            "end": null,
            "ended": false,
            "type": "Artist name",
            "primary": false,
            "sort-name": "VOFAN"
          }
        ],
        "name": "VOFAN"
      }
    },
    {
      "artist": {
        "name": "Erik Kimerer",
        "aliases": [
          {
            "locale": null,
            "name": "Eric Kimerer",
            "type-id": "1937e404-b981-3cb7-8151-4c86ebfc8d8e",
            "begin": null,
            "end": null,
            "type": "Search hint",
            "ended": false,
            "sort-name": "Eric Kimerer",
            "primary": null
          },
          {
            "end": null,
            "primary": false,
            "sort-name": "Kimerer, Erik Scott",
            "ended": false,
            "type": "Artist name",
            "locale": "en",
            "name": "Erik Scott Kimerer",
            "type-id": "894afba6-2816-3c24-8072-eadb66bd04bc",
            "begin": null
          }
        ],
        "type-id": "b6e035f4-3ce9-331c-97df-83397230b0df",
        "id": "ac830008-5b9c-4f98-ae2b-cac499c40ad8",
        "sort-name": "Kimerer, Erik",
        "type": "Person",
        "disambiguation": "voice actor",
        "tags": [],
        "genres": [],
        "country": "US"
      },
      "joinphrase": ", ",
      "name": "Erik Kimerer"
    },
    {
      "artist": {
        "type-id": "b6e035f4-3ce9-331c-97df-83397230b0df",
        "id": "9fac1f69-0044-4b51-ad1c-6bee4c749b91",
        "aliases": [],
        "name": "Cristina Vee",
        "genres": [],
        "tags": [],
        "country": "US",
        "type": "Person",
        "sort-name": "Vee, Cristina",
        "disambiguation": ""
      },
      "joinphrase": ", ",
      "name": "Cristina Vee"
    },
    {
      "name": "Erica Mendez",
      "joinphrase": " & ",
      "artist": {
        "type": "Person",
        "sort-name": "Mendez, Erica",
        "disambiguation": "voice actor",
        "genres": [],
        "tags": [],
        "country": "US",
        "aliases": [],
        "name": "Erica Mendez",
        "type-id": "b6e035f4-3ce9-331c-97df-83397230b0df",
        "id": "91225f09-2f8e-4aee-8718-9329cac8ef03"
      }
    },
    {
      "artist": {
        "type-id": "b6e035f4-3ce9-331c-97df-83397230b0df",
        "id": "9c1e9bd5-4ded-4944-8190-1fec6e530e64",
        "name": "Keith Silverstein",
        "aliases": [
          {
            "end": null,
            "sort-name": "Silverstein, Keith David",
            "primary": false,
            "ended": false,
            "type": "Legal name",
            "begin": null,
            "type-id": "d4dcd0c0-b341-3612-a332-c0ce797b25cf",
            "locale": "en",
            "name": "Keith David Silverstein"
          }
        ],
        "tags": [],
        "genres": [],
        "country": "US",
        "sort-name": "Silverstein, Keith",
        "type": "Person",
        "disambiguation": "US voice actor"
      },
      "joinphrase": "",
      "name": "Keith Silverstein"
    }
  ]
  let expected = "NISIOISIN illustration by VOFAN read by Erik Kimerer, Cristina Vee, Erica Mendez & Keith Silverstein"
  assert equal ($input | artist_credit_to_string) $expected
}

export def test_artist_credit_to_string_baccano_vol_1 [] {
  let input = [
    {
      "joinphrase": " read by "
      "name": "Ryohgo Narita"
      "artist": {
        "id": "efc0e95e-2d3e-4219-8ebb-28ed3751e6ab"
        "genres": []
        "country": "JP"
        "type-id": "b6e035f4-3ce9-331c-97df-83397230b0df"
        "disambiguation": "author"
        "aliases": [
          {
            "end": null
            "begin": null
            "type": "Artist name"
            "primary": false
            "ended": false
            "locale": "en"
            "type-id": "894afba6-2816-3c24-8072-eadb66bd04bc"
            "name": "Ryohgo Narita"
            "sort-name": "Narita, Ryohgo"
          },
          {
            "primary": false
            "type": "Artist name"
            "type-id": "894afba6-2816-3c24-8072-eadb66bd04bc"
            "ended": false
            "locale": "en"
            "name": "Ryougo Narita"
            "sort-name": "Narita, Ryougo"
            "end": null
            "begin": null
          },
          {
            "primary": true
            "type": "Artist name"
            "locale": "en"
            "ended": false
            "type-id": "894afba6-2816-3c24-8072-eadb66bd04bc"
            "name": "Ryōgo Narita"
            "sort-name": "Narita, Ryōgo"
            "end": null
            "begin": null
          }
        ]
        "type": "Person"
        "tags": []
        "sort-name": "Narita, Ryōgo"
        "name": "成田良悟"
      }
    }
    {
      "joinphrase": "",
      "name": "Michael Butler Murray",
      "artist": {
        "type": "Person",
        "aliases": [],
        "disambiguation": "narrator",
        "type-id": "b6e035f4-3ce9-331c-97df-83397230b0df",
        "name": "Michael Butler Murray",
        "sort-name": "Murray, Michael Butler",
        "tags": [],
        "id": "22c39a37-28b7-4ff2-aa0b-67f93279a1ef",
        "genres": [],
        "country": null
      }
    }
  ]
  let expected = "Ryohgo Narita read by Michael Butler Murray"
  assert equal ($input | artist_credit_to_string) $expected
}
