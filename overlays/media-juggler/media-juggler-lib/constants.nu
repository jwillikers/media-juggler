# Constants shared across the library

export const media_juggler_version = "0.0.1"

export const user_agent = $"MediaJuggler/($media_juggler_version) \( https://github.com/jwillikers/media-juggler \)"

export const hardcover_api_url = "https://api.hardcover.app/v1/graphql"

export const wikidata_api_url = "https://www.wikidata.org/w/rest.php/wikibase/v1"

export const wikidata_sparql_api_url = "https://query.wikidata.org/sparql?format=json&query="

export const ereader_profiles = [
  [model height width disk_label];
  ["Kobo Elipsa 2E" 1872 1404 "KOBOeReader"]
]

export const image_extensions = [
  avif
  bmp
  gif
  jpeg
  jpg
  jxl
  png
  svg
  tiff
  webp
]

export const audiobook_accompanying_document_file_extensions = [
  cbz
  epub
  pdf
]

# Allowed tags
export const tag_allowlist = [
  [name aliases];
  [abridged []]
  ["accompanying document" []] # MusicBrainz
  [book []]
  [chapters []] # MusicBrainz
  [explicit []]
  [josei []]
  ["light novel" []]
  [manga []]
  [manhua []]
  [manhwa []]
  [novel []]
  [novelette []]
  [novella []]
  [omnibus []]
  [seinen []]
  [shogi []] # Subject
  [shōjo [shojo]]
  [shōnen [shonen]]
  ["short story" []]
  ["short story collection" []]
  ["unabridged" []]
]

# Allowed genres
export const genre_allowlist = [
  [name aliases wikidata_ids];
  [action ["action fiction"] [Q1762165 Q15637293 Q104537024 Q20087918]]
  [adventure ["adventure fiction"] [Q21802675 Q15712918 Q104536877]]
  [apocalyptic ["apocalyptic fiction"] [Q3919251]]
  ["biography" [] [Q36279]]
  [comedy ["comedy fiction" "comedic fiction" "comic fiction" "humorous fiction"] [Q121389176 Q40831 Q15286013 Q11298158]]
  ["comedy drama" [dramedy] [Q859369 Q15712927 Q104536976]]
  ["coming-of-age" ["coming of age" "coming of age story"] [Q2975633 Q135684998]]
  ["contemporary fantasy" ["modern fantasy" "indigenous fantasy"] [Q1128592]]
  [cooking [] [Q139412567 Q139412557 Q11080558]]
  [crime ["crime fiction"] [Q5937792]]
  ["danmei" [] [Q18461548]]
  ["dark fantasy" ["fantasy horror"] [Q794912 Q111254005]]
  ["detective" ["detective fiction"] [Q186424]]
  ["drama" [] [Q21010853 Q15637299 Q104536999]]
  ["ecchi" [] [Q219559]]
  ["economic history" [] [Q47398]]
  ["epic" [] [Q121368788 Q136913634]]
  ["erotic" [erotica] [Q181001 Q110293051 Q14831027]]
  [fantasy [] [Q132311 Q15637301 Q104536908]]
  ["fantasy comedy" ["comic fantasy"] [Q1637212 Q136842300]]
  [fiction [] [Q8253]]
  [grimdark [] [Q25338354]]
  ["harem" [] [Q690342 Q111253933]]
  ["hentai" [] [Q172067 Q21997246]]
  ["high fantasy" ["epic fantasy"] [Q326439 Q138948720]]
  ["history" ["historical non-fiction"] [Q116513838]]
  ["historiography" [] [Q30277550]]
  ["historical fantasy" [] [Q603291]]
  ["historical fiction" [] [Q1196408 Q101240934 Q11125143]]
  ["historical mystery" [] [Q1093312]]
  [horror [] [Q16575965 Q12767035]]
  ["isekai" [] [Q53911753]]
  ["iyashikei" [] [Q97358333]]
  [LitRPG ["literary role-playing game" "literary RPG"] [Q25493967]]
  ["magical girl" ["magical girl fiction"] [Q141567443 Q752321]]
  ["martial arts" [] [Q136806262]]
  [mecha ["mecha fiction"] [Q141567454 Q4292083]]
  [metafiction ["meta fiction"] [Q531067]]
  [military [] [Q21803247 Q136913640]]
  ["military science fiction" [] [Q904447]]
  ["musical drama" ["music drama"] [Q123777276 Q141446184 Q141446165]]
  [mystery [] [Q6585139 Q15637305]]
  [neo-noir [] [Q2421031]]
  [non-fiction [nonfiction] [Q213051]]
  ["paranormal" [] [Q7135551]]
  [post-apocalyptic [] [Q197949 Q103016666 Q103111961]]
  ["psychological" [] [Q101240581 Q101240583]]
  ["psychological drama" [] [Q108102008 Q139963570]]
  ["psychological horror" [] [Q604725 Q139041604]]
  ["psychological thriller" [] [Q590103 Q139041618]]
  ["romance" [romantic "romantic fiction"] [Q19765983 Q15637310 Q104536775]]
  ["romantic comedy" [romcom rom-com] [Q860626 Q15712145]]
  ["romantic fantasy" [romantasy] [Q930383]]
  ["sexual comedy" ["sex comedy" "erotic comedy"] [Q2991560 Q138807680]]
  # todo Should school and school life be separate genres?
  ["school" [] [Q5366097 Q104536849]]
  ["school life" [] [Q10670466]]
  ["science fantasy" [] [Q930383 Q137198951 Q1080374]]
  ["science fiction" [sci-fi] [Q24925 Q5366020 Q103925653]]
  ["slice of life" [] [Q2561438 Q15428604]]
  ["space opera" ["space drama"] [Q468478]]
  ["speculative fiction" [] [Q9326077]]
  ["sports" [spokon] [Q139794801 Q2281511]]
  ["steampunk" [] [Q223685 Q139558719]]
  ["supernatural" ["supernaturalist"] [Q7644030 Q61942616]]
  ["superhero" [] [Q7643432 Q139794817]]
  ["sword and sorcery" ["sword & sorcery" "S&S" "heroic fantasy"] [Q1999690 Q139071253]]
  [thriller [suspense] [Q182015 Q101240755]]
  ["urban fantasy" [] [Q1188977 Q141447645]]
  ["vampire" [] [Q111019576 Q111019582]]
  ["villainess" [] []]
  ["western" [] [Q367591 Q139270219]]
  ["xianxia" [] [Q24907097]]
  ["yanki" ["yankee" "yanki" "yankii" "yankī"] [Q11345398 Q140723524]]
  ["young adult" ["ya"] [Q111984153]]
  ["yuri" [] [Q320568]]
]

export const intended_public_wikidata = [
  [name aliases wikidata_id age_range gender];
  [shōnen [shonen] Q231302 {begin: 10 end: 21} male]
  [seinen [] Q237338 {begin: 18 end: 40} male]
  [shōjo [shojo] Q242492 {begin: 10 end: 21} female]
  [josei [shojo] Q503106 {begin: 18 end: 40} female]
]

export const form_of_creative_work_wikidata = [
  [name wikidata_id];
  ["comic" Q1004]
  ["comic book" Q1760610]
  ["comic book album" Q2831984]
  ["comic strip" Q838795]
  ["graphic novel" Q725377]
  ["light novel" Q747381]
  ["manfra" Q3285662]
  [manga Q8274]
  ["manga chapter" Q53460949]
  ["manga volume" Q125632018]
  [manhua Q754669]
  ["manhua volume" Q137923898]
  [manhwa Q562214]
  ["manhwa volume" Q137923899]
  [novel Q8261]
  # todo [novellette ]
  [novella Q149537]
  ["short story" Q49084]
  ["short story collection" Q1279564]
  ["yonkoma" Q865484]
]

# Age rating map between the ComicInfo and MetronInfo schemas
export const age_rating_map = [
  [comic_info metron_info age_range_begin];
  [Unknown Everyone 0]
  ["Rating Pending" null null]
  ["Early Childhood" Everyone 0]
  ["G" Everyone 0]
  ["Everyone 10+" Everyone 10]
  ["PG" Everyone 10]
  ["Kids to Adults" Everyone 0]
  ["Teen" Teen 13]
  ["MA15+" "Teen Plus" 15]
  ["Mature 17+" "Mature" 17]
  ["M" "Mature" 17]
  ["R18+" "Adult" 18]
  ["Adults Only 18+" "Adult" 18]
  ["X18+" "Explicit" 18]
]

export const intended_public_to_age_rating_comic_info_map = [
  [intended_publics comic_info_age_rating metron_info_age_rating];
  [[shōjo shōnen] "PG" "Everyone"]
  [[jose seinen] "Teen" "Teen"]
]

export const genre_to_age_rating_comic_info_map = [
  [genres comic_info_age_rating metron_info_age_rating];
  [[ecchi] "Teen" "Teen"]
  [[erotic] "M" "Mature"]
  [[hentai] "X18+" "Adult"]
]

# https://en.wikipedia.org/wiki/IETF_language_tag
# https://en.wikipedia.org/wiki/List_of_ISO_639-3_codes
export const iso_language_codes_map = [
  [language iso_639_1 iso_639_3 ietf_bcp_47 default_language wikidata_id];
  ["english" "en" "eng" "en" true Q1860]
  ["american english" "en" "eng" "en-US" false Q7976]
  ["british english" "en" "eng" "en-GB" false Q7979]
  ["chinese" "zh" "zho" "zh" true Q7850]
  ["german" "de" "deu" "de" false Q188]
  ["japanese" "ja" "jpn" "ja" true Q5287]
  ["japanese hiragana" "ja" "jpn" "ja-hira" false Q53979341]
  ["japanese katakana" "ja" "jpn" "ja-kana" false Q53979342]
  ["japanese kana" "ja" "jpn" "ja-hrkt" false Q53979345]
  ["japanese kanji" "ja" "jpn" "ja-hani" false Q53979504]
  ["japanese romanized" "ja" "jpn" "ja-Latn" false Q53979348]
  ["korean" "ko" "kor" "ko" true Q9176]
  ["spanish" "es" "spa" "es" true Q1321]
]

export const comic_info_fields = [
  [tag delimiter];
  [Title null]
  [LocalizedSeries null]
  [Series null]
  [SeriesGroup ","]
  [StoryArc ","]
  [StoryArcNumber ","]
  [AlternativeSeries null]
  [AlternativeCount null]
  [SeriesSort null]
  [Count null]
  [Number null]
  [Volume null]
  [Summary null]
  [Notes null]
  [Year null]
  [Month null]
  [Day null]
  [Locations ","]
  [Characters ","]
  [Teams ","]
  [MainCharacterOrTeam null]
  [ScanInformation null]
  [Writer ","]
  [Penciller ","]
  [Inker ","]
  [Colorist ","]
  [Letterer ","]
  [CoverArtist ","]
  [Editor ","]
  [Translator ","]
  [Publisher null]
  [Imprint null]
  [Genre ","]
  [Tags ","]
  [Web " "]
  [PageCount null]
  [LanguageISO null]
  [GTIN null]
  [Format null]
  [Manga null]
  [AgeRating null]
]

export const comic_vine_roles_map = [
  [comic_vine_roles comic_info_roles];
  [[Writer] [Writer]]
  [[Penciller] [Penciller]]
  [[Inker] [Inker]]
  [[Colorist] [Colorist]]
  [[Letterer] [Letterer]]
  # I think ComicTagger does Penciller and Inker by default for Artist.
  # I also include Colorist since usually, there's color of some sort in most comics and manga, even if it's only on the cover for manga.
  [[Artist] [Penciller Inker Colorist]]
  # [[Designer] []]
  # CoverArtist requires both the Cover and the Artist roles.
  [[Cover Artist] [CoverArtist]]
  [[Editor] [Editor]]
  [[Translator] [Translator]]
  # [[Production] []]
]

# Map Hardcover's contributor roles to the roles used for credits, which follow the Comic Vine roles used by ComicTagger.
#
# Each Hardcover role maps to a list of credit roles.
# Hardcover roles which aren't listed keep their Hardcover name, which is ignored when writing ComicInfo.xml.
# Specializations of Hardcover roles are handled by hardcover_contribution_roles.
#
# https://docs.hardcover.app/librarians/standards/contributorstandards/
# https://hardcover.app/browse/roles
export const hardcover_roles_map = {
  # Authorship & Writing
  "Author": [Writer]
  "Co-Author": [Writer]
  "Co-Writer": [Writer]
  "Contributing Author": [Writer]
  "Story": [Writer]
  "Writer": [Writer]
  # Origins & Attribution
  # The creator of the original story is credited as the writer, such as the author of a light novel adapted into a manga.
  "Co-Creator": [Writer]
  "Creator": [Writer]
  "Original Author": [Writer]
  "Original Creator": [Writer]
  "Original Story": [Writer]
  "Original Work": [Writer]
  "Series Creator": [Writer]
  # Adaptation & Scripts
  "Adaptation": [Adapter]
  "Adapter": [Adapter]
  "Localizer": [Adapter]
  "Scenario": [Writer]
  "Scenarist": [Writer]
  "Script": [Writer]
  "Scriptwriter": [Writer]
  # Art & Illustration
  "Art": [Artist]
  "Artist": [Artist]
  "Artwork": [Artist]
  "Cartoonist": [Writer Artist]
  "Comic": [Artist]
  "Cover": ["Cover Artist"]
  "Cover Art": ["Cover Artist"]
  "Cover Artist": ["Cover Artist"]
  "Cover Illustrator": ["Cover Artist"]
  "Drawings": [Artist]
  "Illustrations": [Artist]
  "Illustrator": [Artist]
  "Interior Artist": [Artist]
  "Line Art": [Artist]
  # A mangaka writes and draws the manga, including its covers.
  "Mangaka": [Writer Artist "Cover Artist"]
  "Penciller": [Penciller]
  "Pencils": [Penciller]
  # Color, Inking & Lettering
  "Color Artist": [Colorist]
  "Colorist": [Colorist]
  "Colors": [Colorist]
  "Inker": [Inker]
  "Inks": [Inker]
  "Letterer": [Letterer]
  "Lettering": [Letterer]
  # Editing & Review
  "Assistant Editor": [Editor]
  "Associate Editor": [Editor]
  "Co-Editor": [Editor]
  "Consultant Editor": [Editor]
  "Editing": [Editor]
  "Editor": [Editor]
  "Editor-in-Chief": [Editor]
  "General Editor": [Editor]
  "Series Editor": [Editor]
  # Translation & Language
  "Translation": [Translator]
  "Translator": [Translator]
  # Narration & Spoken Word
  "Narration": [Narrator]
  "Narrator": [Narrator]
  "Reader": [Narrator]
  "Reading": [Narrator]
  "Voice Actor": [Narrator]
}

# Credit roles for artwork, which become cover art when a Hardcover role has the "Cover" specialization
export const hardcover_art_credit_roles = [Artist Penciller Inker Colorist]

# Hardcover specializations for which the base role's credit roles would be misleading.
# "Original Story" credits work on the original story of an adaptation, like the illustrator of a light novel adapted into a manga, and "Touch-up" credits touching up artwork, like sound effects, rather than drawing it.
# Contributions with these specializations keep their Hardcover name instead of being mapped to credit roles.
export const hardcover_unmapped_specializations = ["Original Story" "Touch-up"]

export const opf_identifier_schemes = [
  [schemes type];
  # [[GOODREADS] goodreads_version_id]
  [[HARDCOVER-SLUG HARDCOVER] hardcover_book_slug]
  # [[HARDCOVER-ID] hardcover_book_id]
  [[HARDCOVER-EDITION] hardcover_edition_id]
  [[COMICVINE] comic_vine_issue_id]
  [[COMICVINE-VOLUME] comic_vine_volume_id]
  [[BOOKBRAINZ-EDITION] bookbrainz_edition_id]
  [[WIKIDATA-EDITION] wikidata_item_id]
  [[OPENLIBRARY-EDITION OPENLIBRARY] open_library_edition_id]
  [[OPENLIBRARY-WORK] open_library_work_id]
  # [ISBN isbn]
  # [STORYGRAPH storygraph_edition_id]
  # [GOOGLE google_books_id]
]

# https://id.loc.gov/vocabulary/relators.html
export const opf_roles_map = {
  "Adapter": "adapter"
  "Artist": "artist"
  "Book Designer": "book designer"
  "Book Jacket Designer": "book jacket designer"
  "Book Producer": "book producer"
  "Cartographer": "cartographer"
  "Colorist": "colorist"
  "Commentator": "commentator for written text"
  "Composer": "composer"
  "Consultant": "consultant"
  "Cover Designer": "cover designer"
  "Creator": "creator"
  "Designer": "designer"
  "Distributor": "distributor"
  "Editor": "editor"
  "Foreword": "writer of foreword"
  # Kavita treats the illustrator as Inker.
  "Illustrator": "illustrator"
  "Inker": "inker"
  "Introduction": "writer of introduction"
  "Narrator": "narrator"
  "Penciller": "penciller"
  "Photographer": "photographer"
  "Preface": "writer of preface"
  "Proofreader": "proofreader"
  "Translator": "translator"
  "Writer": "author"
}

export const release_only_contributor_roles = [distributor illustrator publisher]
