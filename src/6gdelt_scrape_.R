suppressPackageStartupMessages({
  library(data.table)
  library(stringr)
  library(tidytext)
  library(dplyr)
})

cat("\n=== STEP 6.1: PREPROCESAMIENTO Y TOKENIZACIÓN DEL TEXTO ===\n")

base_dir <- "/Users/valentino.virlan/Desktop/project/data"
input_file <- file.path(base_dir, "processed/scraped_articles.csv")
output_file <- file.path(base_dir, "processed/text_tokens.csv")

cat("Cargando artículos scrapeados...\n")
articles <- fread(input_file)

# Nos quedamos solo con artículos con texto válido
articles <- articles[status == "ok" & !is.na(text)]

cat(sprintf("Artículos con texto válido: %d\n", nrow(articles)))

# Limpieza básica del texto
# Se normaliza el contenido para reducir ruido sintáctico

cat("Normalizando texto...\n")

articles[, text_clean := text %>%
           str_to_lower() %>%
           str_replace_all("&amp;", "and") %>%
           str_replace_all("[^a-z\\s]", " ") %>%
           str_squish()
]

# Conversión a tibble para tidytext
text_tbl <- articles %>%
  select(event, date, domain, text_clean) %>%
  tibble()

# Tokenización
# Cada palabra se trata como unidad léxica básica

cat("Tokenizando texto...\n")

tokens_text <- text_tbl %>%
  unnest_tokens(word, text_clean)

# Eliminación de stopwords
# Se eliminan palabras funcionales sin contenido semántico

tokens_text <- tokens_text %>%
  anti_join(stop_words, by = "word")

# Filtrado por longitud
# Se descartan tokens muy cortos para evitar ruido

tokens_text <- tokens_text %>%
  filter(nchar(word) > 3)

cat(sprintf("Total de tokens generados: %d\n", nrow(tokens_text)))

# Guardado del dataset de tokens
fwrite(as.data.table(tokens_text), output_file)

cat("\n✓ Tokens del texto guardados correctamente:\n")
cat("text_tokens.csv\n")
cat("\n=== STEP 6.1 COMPLETADO ===\n")

# Numero token totali
nrow(tokens_text)

# Token più frequenti
tokens_text %>%
  count(word, sort = TRUE) %>%
  head(20)

# Token per evento
tokens_text %>%
  count(event) %>%
  print()


suppressPackageStartupMessages({
    library(data.table)
    library(dplyr)
    library(tidytext)
  })

cat("\n=== STEP 6.2: COMPARACIÓN TÍTULO VS CONTENIDO ===\n")

base_dir <- "/Users/valentino.virlan/Desktop/project/data"
tokens_text_file  <- file.path(base_dir, "processed/text_tokens.csv")
tokens_title_file <- file.path(base_dir, "processed/title_word_frequencies_global.csv")

cat("Cargando tokens del texto...\n")
text_tokens <- fread(tokens_text_file)

cat("Cargando frecuencias de títulos...\n")
title_freq <- fread(tokens_title_file)

# Normalización de estructuras
title_tokens <- title_freq %>%
  select(word, n) %>%
  mutate(source = "title")

text_freq <- text_tokens %>%
  count(word) %>%
  mutate(source = "text")

# Unificación de ambos conjuntos
comparison <- bind_rows(
  title_tokens %>% rename(freq = n),
  text_freq  %>% rename(freq = n)
)

# Cálculo de frecuencias relativas
comparison <- comparison %>%
  group_by(source) %>%
  mutate(rel_freq = freq / sum(freq)) %>%
  ungroup()

# Palabras más representativas por fuente
top_comparison <- comparison %>%
  group_by(source) %>%
  arrange(desc(rel_freq)) %>%
  slice(1:15)

cat("\n--- PALABRAS MÁS FRECUENTES POR FUENTE ---\n")
print(top_comparison)

# Guardado
fwrite(
  as.data.table(top_comparison),
  file.path(base_dir, "processed/title_vs_text_top_words.csv")
)

cat("\n✓ Comparación guardada correctamente\n")
cat("=== STEP 6.2 COMPLETADO ===\n")


suppressPackageStartupMessages({
  library(data.table)
  library(dplyr)
  library(wordcloud)
  library(RColorBrewer)
})

cat("\n=== STEP 6.3: WORDCLOUD DEL TEXTO SCRAPEADO ===\n")

# Rutas
base_dir   <- "/Users/valentino.virlan/Desktop/project/data"
input_file <- file.path(base_dir, "processed/text_tokens.csv")
output_dir <- file.path(base_dir, "processed")

# Cargar tokens
cat("Cargando tokens del texto...\n")
tokens <- fread(input_file)

# Frecuencias globales
freq_words <- tokens %>%
  count(word, sort = TRUE)

print(head(freq_words, 20))

# Wordcloud
# Mostrar RStudio
set.seed(123)
wordcloud(
  words      = freq_words$word,
  freq       = freq_words$n,
  max.words  = 100,
  min.freq   = 3,
  random.order = FALSE,
  colors     = brewer.pal(8, "Dark2")
)

# Salvar
png(
  filename = file.path(output_dir, "wordcloud_scraped_articles.png"),
  width = 900,
  height = 600
)

set.seed(123)
wordcloud(
  words      = freq_words$word,
  freq       = freq_words$n,
  max.words  = 100,
  min.freq   = 3,
  random.order = FALSE,
  colors     = brewer.pal(8, "Dark2")
)

dev.off()


cat("✓ Wordcloud: wordcloud_scraped_articles.png\n")
cat("=== STEP 6.3 COMPLETADO ===\n")









