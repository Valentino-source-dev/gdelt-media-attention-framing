
suppressPackageStartupMessages({
  library(data.table)
})

cat("\n=== STEP 5.1: SELECCIÓN DE ARTÍCULOS A SCRAPEAR ===\n")

# Definición de rutas
base_dir <- "/Users/valentino.virlan/Desktop/project/data"
input_file <- file.path(base_dir, "processed/gdelt_panel.csv")
output_file <- file.path(base_dir, "processed/articles_to_scrape.csv")

# Cargar panel GDELT (contenido + atención)
cat("Cargando panel GDELT...\n")
panel <- fread(input_file)

# Verificación rápida
cat(sprintf("Total de artículos en el panel: %d\n", nrow(panel)))

# Eliminamos URLs faltantes o duplicadas
panel <- panel[!is.na(url) & url != ""]
panel <- unique(panel, by = "url")

# Selección de artículos con mayor atención mediática
# Se seleccionan los top 50 artículos por evento según mentions

cat("Seleccionando artículos con mayor atención por evento...\n")

top_articles <- panel[
  order(-mentions),
  .SD[1:50],
  by = event
]

# Añadimos una columna que documenta el criterio de selección
top_articles[, selection_reason := "top_mentions_by_event"]

# Seleccionamos solo las columnas necesarias para el scraping
articles_to_scrape <- top_articles[, .(
  event,
  date,
  domain,
  url,
  mentions,
  title_raw,
  selection_reason
)]

# Guardar resultado
fwrite(articles_to_scrape, output_file)

cat("\n✓ Archivo guardado correctamente:\n")
cat("articles_to_scrape.csv\n")

# Prints de control para el reporte y el oral
cat("\n--- ARTÍCULOS SELECCIONADOS POR EVENTO ---\n")
print(articles_to_scrape[, .N, by = event])

cat("\n--- EJEMPLOS DE ARTÍCULOS A SCRAPEAR ---\n")
print(head(articles_to_scrape, 5))

cat("\n=== STEP 5.1 COMPLETADO ===\n")


#SCRAPING DE ARTÍCULOS
#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(data.table)
  library(rvest)
  library(httr)
  library(stringr)
})

cat("\n=== STEP 5.2: SCRAPING DE ARTÍCULOS SELECCIONADOS ===\n")

base_dir <- "/Users/valentino.virlan/Desktop/project/data"
input_file <- file.path(base_dir, "processed/articles_to_scrape.csv")
output_file <- file.path(base_dir, "processed/scraped_articles.csv")

cat("Cargando lista de artículos a scrapear...\n")
articles <- fread(input_file)

cat(sprintf("Total de URLs a procesar: %d\n", nrow(articles)))

# Función para scrapear título y primeros párrafos
scrape_article <- function(url) {
  
  tryCatch({
    
    response <- GET(
      url,
      timeout(10),
      add_headers(`User-Agent` = "Mozilla/5.0 (Academic Research)")
    )
    
    if (status_code(response) != 200) {
      return(list(status = "http_error", title = NA, text = NA))
    }
    
    html <- read_html(response)
    
    # Extraer título HTML
    title <- html %>%
      html_elements("title") %>%
      html_text(trim = TRUE) %>%
      .[1]
    
    # Extraer primeros párrafos
    paragraphs <- html %>%
      html_elements("p") %>%
      html_text(trim = TRUE)
    
    paragraphs <- paragraphs[
      nchar(paragraphs) > 50
    ]
    
    text <- paste(
      head(paragraphs, 3),
      collapse = " "
    )
    
    if (is.na(text) || nchar(text) < 100) {
      return(list(status = "no_text", title = title, text = NA))
    }
    
    list(
      status = "ok",
      title = title,
      text = text
    )
    
  }, error = function(e) {
    list(status = "error", title = NA, text = NA)
  })
}

cat("Iniciando scraping con control de errores y rate limiting...\n")

results <- vector("list", nrow(articles))

for (i in seq_len(nrow(articles))) {
  
  cat(sprintf("Procesando [%d/%d]\n", i, nrow(articles)))
  
  res <- scrape_article(articles$url[i])
  
  results[[i]] <- data.table(
    event   = articles$event[i],
    date    = articles$date[i],
    domain  = articles$domain[i],
    url     = articles$url[i],
    title   = res$title,
    text    = res$text,
    status  = res$status
  )
  
  Sys.sleep(runif(1, 1, 2))
}

scraped <- rbindlist(results, fill = TRUE)

cat("\nResumen del scraping:\n")
print(scraped[, .N, by = status])

fwrite(scraped, output_file)

cat("\n✓ Archivo guardado correctamente:\n")
cat("scraped_articles.csv\n")

cat("\n=== STEP 5.2 COMPLETADO ===\n")


