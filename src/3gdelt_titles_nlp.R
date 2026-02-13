
suppressPackageStartupMessages({
  library(data.table)
  library(stringr)
  library(tidytext)
  library(dplyr)
  library(wordcloud)
  library(RColorBrewer)
})

cat("\n=== STEP 3: TITLE-BASED NLP ANALYSIS ===\n")

base_dir <- "/Users/valentino.virlan/Desktop/project/data"
input_file <- file.path(base_dir, "processed/gdelt_gkg.csv")
out_dir <- file.path(base_dir, "processed")

# Carga del dataset GKG preprocesado
cat("Cargando datos GKG preprocesados...\n")
gkg <- fread(input_file)

# Verificación de la presencia del campo PAGE_TITLE
if (!"gcam" %in% names(gkg)) {
  cat("Advertencia: el dataset no contiene GCAM. Este paso no lo utiliza.\n")
}

# Extracción del título desde el campo V27 (PAGE_TITLE)
cat("Extrayendo títulos de los artículos...\n")

extract_title <- function(x) {
  str_match(x, "<PAGE_TITLE>(.*?)</PAGE_TITLE>")[,2]
}

gkg[, title_raw := extract_title(page_meta)]

# Eliminación de registros sin título válido
gkg <- gkg[!is.na(title_raw) & title_raw != ""]

cat(sprintf("Títulos válidos extraídos: %d\n", nrow(gkg)))

# Limpieza básica del texto
cat("Normalizando texto de los títulos...\n")

gkg[, title_clean := title_raw %>%
      str_to_lower() %>%
      str_replace_all("&amp;", "and") %>%
      str_replace_all("[^a-z\\s]", " ") %>%
      str_squish()
]

# Conversión a tibble para tidytext
titles_tbl <- gkg %>%
  select(event, date, domain, title_clean) %>%
  tibble()

# Tokenización
cat("Tokenizando títulos...\n")

tokens <- titles_tbl %>%
  unnest_tokens(word, title_clean) %>%
  anti_join(stop_words, by = "word") %>%
  filter(nchar(word) > 3)
head(tokens$word, 20)


cat(sprintf("Total de tokens generados: %d\n", nrow(tokens)))

# Frecuencias globales
cat("Calculando frecuencias globales...\n")

freq_global <- tokens %>%
  count(word, sort = TRUE)

print(head(freq_global, 20))

# Wordcloud global
cat("Generando wordcloud global...\n")

set.seed(123)

png(file.path(out_dir, "wordcloud_titles_global.png"), width = 900, height = 600)

wordcloud(
  words = freq_global$word,
  freq  = freq_global$n,
  max.words = 100,
  colors = brewer.pal(8, "Dark2")
)

dev.off()

# Frecuencias por evento
cat("Calculando frecuencias por evento...\n")

freq_event <- tokens %>%
  count(event, word, sort = TRUE)

# Guardado de resultados
fwrite(freq_global, file.path(out_dir, "title_word_frequencies_global.csv"))
fwrite(freq_event,  file.path(out_dir, "title_word_frequencies_by_event.csv"))

cat("Resultados guardados:\n")
cat("title_word_frequencies_global.csv\n")
cat("title_word_frequencies_by_event.csv\n")
cat("wordcloud_titles_global.png\n")

cat("\n=== STEP 3 COMPLETADO ===\n")

cat("\n=== STEP 3.1: WORDCLOUD POR EVENTO ===\n")

events <- unique(tokens$event)

for (ev in events) {
  
  cat(sprintf("Generando wordcloud para evento: %s\n", ev))
  
  freq_ev <- tokens %>%
    filter(event == ev) %>%
    count(word, sort = TRUE)
  
  png(
    filename = file.path(out_dir, paste0("wordcloud_titles_", ev, ".png")),
    width = 900,
    height = 600
  )
  
  wordcloud(
    words = freq_ev$word,
    freq  = freq_ev$n,
    max.words = 100,
    colors = brewer.pal(8, "Dark2")
  )
  
  dev.off()
}


cat("\n=== STEP 3.2: CONFRONTO LESSICALE (TF-IDF) ===\n")

# Calcular TF-IDF por evento
tfidf_event <- tokens %>%
  count(event, word) %>%
  bind_tf_idf(word, event, n)

# Top palabras más distintivas por evento
top_tfidf <- tfidf_event %>%
  group_by(event) %>%
  slice_max(tf_idf, n = 15) %>%
  ungroup()

# Guardar resultados
fwrite(
  top_tfidf,
  file.path(out_dir, "title_top_tfidf_by_event.csv")
)

print(top_tfidf)


# STEP 3.2.b — Palabras comunes a todos los eventos


# Palabras presentes en los tres eventos
common_words <- tokens %>%
  distinct(event, word) %>%
  count(word) %>%
  filter(n == length(unique(tokens$event))) %>%
  arrange(desc(n))

# Guardar
fwrite(
  common_words,
  file.path(out_dir, "title_common_words_all_events.csv")
)

print(head(common_words, 20))


cat("\n=== STEP 3.3: PALABRAS VS ATENCIÓN MEDIÁTICA ===\n")
# Unir tokens con la serie diaria de menciones
tokens <- tokens %>%
  mutate(date = as.Date(date))

men_daily <- men_daily %>%
  mutate(date = as.Date(date))
tokens_attention <- tokens %>%
  left_join(
    men_daily,
    by = c("event", "date", "domain")
  )


# Verificar resultado
cat("Tokens con información de atención:\n")
print(summary(tokens_attention$mentions))

# Clasificar días según nivel de atención
tokens_attention <- tokens_attention %>%
  mutate(
    attention_level = case_when(
      mentions >= quantile(mentions, 0.75, na.rm = TRUE) ~ "alta_atencion",
      mentions <= quantile(mentions, 0.25, na.rm = TRUE) ~ "baja_atencion",
      TRUE ~ "media_atencion"
    )
  )

# Comparar palabras entre alta y baja atención
attention_words <- tokens_attention %>%
  filter(attention_level %in% c("alta_atencion", "baja_atencion")) %>%
  count(attention_level, word, sort = TRUE)

# Guardar resultados
fwrite(
  attention_words,
  file.path(out_dir, "title_words_by_attention_level.csv")
)

cat("Archivo generado: title_words_by_attention_level.csv\n")
cat("\n=== STEP 3.3: PALABRAS VS ATENCIÓN MEDIÁTICA ===\n")

# Unir tokens con la serie diaria de menciones
tokens_attention <- tokens %>%
  left_join(
    men_daily,
    by = c("event", "date", "domain")
  )

# Verificar resultado
cat("Tokens con información de atención:\n")
print(summary(tokens_attention$mentions))

# Clasificar días según nivel de atención
tokens_attention <- tokens_attention %>%
  mutate(
    attention_level = case_when(
      mentions >= quantile(mentions, 0.75, na.rm = TRUE) ~ "alta_atencion",
      mentions <= quantile(mentions, 0.25, na.rm = TRUE) ~ "baja_atencion",
      TRUE ~ "media_atencion"
    )
  )

# Comparar palabras entre alta y baja atención
attention_words <- tokens_attention %>%
  filter(attention_level %in% c("alta_atencion", "baja_atencion")) %>%
  count(attention_level, word, sort = TRUE)

# Guardar resultados
fwrite(
  attention_words,
  file.path(out_dir, "title_words_by_attention_level.csv")
)

cat("Archivo generado: title_words_by_attention_level.csv\n")

cat("\n--- TOP PALABRAS EN DÍAS DE ALTA ATENCIÓN ---\n")

attention_words %>%
  filter(attention_level == "alta_atencion") %>%
  arrange(desc(n)) %>%
  head(20) %>%
  print()

