
suppressPackageStartupMessages({
  library(data.table)
  library(stringr)
})

cat("\n=== STEP 2: GDELT PREPROCESS ===\n")

base_dir <- "/Users/valentino.virlan/Desktop/project"
raw_dir  <- file.path(base_dir, "data/raw")
out_dir  <- file.path(base_dir, "data/processed")

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

detect_event <- function(path) {
  if (grepl("ukraine", path, ignore.case = TRUE)) return("ukraine")
  if (grepl("gaza", path, ignore.case = TRUE)) return("gaza")
  if (grepl("venezuela", path, ignore.case = TRUE)) return("venezuela")
  return(NA_character_)
}

gkg_files <- list.files(raw_dir, pattern = "gkg.csv.zip$", full.names = TRUE)
men_files <- list.files(raw_dir, pattern = "mentions.CSV.zip$", full.names = TRUE)

cat(sprintf("GKG files encontrados: %d\n", length(gkg_files)))
cat(sprintf("Mentions files encontrados: %d\n", length(men_files)))

cat("\nVerificando estructura de columnas GKG...\n")

dt_check <- fread(
  gkg_files[1],
  sep = "\t",
  header = FALSE,
  fill = TRUE,
  showProgress = FALSE
)

setnames(dt_check, paste0("V", seq_len(ncol(dt_check))))

cat(sprintf("Número de columnas detectadas: %d\n", ncol(dt_check)))

for (i in seq_len(ncol(dt_check))) {
  cat("\nColumna V", i, "\n", sep = "")
  print(head(dt_check[[i]], 2))
}

cat("\nVerificación empírica completada\n")

cat("\nConstruyendo mapeo completo de las 27 columnas GKG...\n")

gkg_column_map <- data.table(
  column = paste0("V", 1:27),
  description = c(
    "Identificador interno del registro",
    "Timestamp del documento",
    "Contador de fuentes",
    "Dominio de la fuente",
    "URL del artículo",
    "Eventos codificados (CAMEO básico)",
    "Eventos codificados (CAMEO extendido)",
    "Themes temáticos",
    "Conteo de themes",
    "Localizaciones geográficas",
    "Localizaciones extendidas",
    "Personas mencionadas (texto)",
    "Personas mencionadas (IDs)",
    "Organizaciones mencionadas (texto)",
    "Organizaciones mencionadas (IDs)",
    "Tono agregado V1.5 (polaridad)",
    "Themes mejorados",
    "GCAM (señales semánticas avanzadas)",
    "Imagen principal",
    "Imágenes adicionales",
    "Enlaces a redes sociales",
    "Embeds de video",
    "Citas textuales",
    "Entidades nombradas adicionales",
    "Contexto numérico",
    "Campo técnico no utilizado",
    "Metadatos de página y título (PAGE_TITLE)"
  )
)

fwrite(gkg_column_map, file.path(out_dir, "gkg_column_map.csv"))

cat("Mapeo de columnas guardado como gkg_column_map.csv\n")

COL_DATETIME <- 2
COL_URL      <- 5
COL_THEMES   <- 8
COL_PERSONS  <- 12
COL_ORGS     <- 13
COL_TONE     <- 16
COL_GCAM     <- 18

cat("\nProcesando GKG...\n")

gkg_list <- lapply(gkg_files, function(f) {
  
  dt <- try(
    fread(f, sep = "\t", header = FALSE, fill = TRUE, showProgress = FALSE),
    silent = TRUE
  )
  
  if (inherits(dt, "try-error")) return(NULL)
  
  setnames(dt, paste0("V", seq_len(ncol(dt))))
  
  dt_out <- dt[, .(
    datetime = get(paste0("V", COL_DATETIME)),
    url      = get(paste0("V", COL_URL)),
    themes   = get(paste0("V", COL_THEMES)),
    persons  = get(paste0("V", COL_PERSONS)),
    orgs     = get(paste0("V", COL_ORGS)),
    tone_raw = get(paste0("V", COL_TONE)),
    gcam     = get(paste0("V", COL_GCAM)),
    page_meta  = V27,
    event    = detect_event(f)
  )]
  
  dt_out[]
})

gkg <- rbindlist(gkg_list, fill = TRUE)
cat(sprintf("Filas GKG procesadas: %d\n", nrow(gkg)))

gkg[, date := as.Date(substr(datetime, 1, 8), "%Y%m%d")]

gkg[, domain := tolower(
  sub("^www\\.", "", str_extract(url, "(?<=://)[^/]+"))
)]

gkg[, tone := suppressWarnings(
  as.numeric(tstrsplit(tone_raw, ",")[[1]])
)]

extract_title <- function(x) {
  str_match(x, "<PAGE_TITLE>(.*?)</PAGE_TITLE>")[,2]
}
gkg[, title_raw := extract_title(page_meta)]


gcam_coverage <- mean(!is.na(gkg$gcam) & gkg$gcam != "") * 100
cat(sprintf("Cobertura GCAM: %.2f%% de los documentos\n", gcam_coverage))

cat("\nProcesando Mentions...\n")

men_list <- lapply(men_files, function(f) {
  
  dt <- try(
    fread(f, sep = "\t", header = FALSE, fill = TRUE, showProgress = FALSE),
    silent = TRUE
  )
  
  if (inherits(dt, "try-error")) return(NULL)
  
  setnames(dt, paste0("V", seq_len(ncol(dt))))
  
  dt_out <- dt[, .(
    datetime = V3,
    url      = V6,
    event    = detect_event(f)
  )]
  
  dt_out[]
})

men <- rbindlist(men_list, fill = TRUE)
cat(sprintf("Filas Mentions procesadas: %d\n", nrow(men)))

men[, date := as.Date(substr(datetime, 1, 8), "%Y%m%d")]

men[, domain := tolower(
  sub("^www\\.", "", str_extract(url, "(?<=://)[^/]+"))
)]

men_daily <- men[, .(mentions = .N), by = .(event, date, domain)]

cat("\nConstruyendo panel final...\n")

panel <- merge(
  gkg,
  men_daily,
  by = c("event", "date", "domain"),
  all.x = TRUE
)

panel[is.na(mentions), mentions := 0]

fwrite(gkg,       file.path(out_dir, "gdelt_gkg.csv"))
fwrite(men_daily, file.path(out_dir, "gdelt_mentions_daily.csv"))
fwrite(panel,     file.path(out_dir, "gdelt_panel.csv"))

cat("\nArchivos guardados correctamente\n")
cat("gdelt_gkg.csv\n")
cat("gdelt_mentions_daily.csv\n")
cat("gdelt_panel.csv\n")
cat("gkg_column_map.csv\n")
cat("\n=== STEP 2 COMPLETADO ===\n")

